$TRACK_CENTER_SPACING_FT = 3.0
$PIVOT_RADIUS_FT = $TRACK_CENTER_SPACING_FT / 2.0
$FULL_TURN_RADIUS_FT = 10.0
$TURN_GAIN = 1.0
$RUDDER_DEADBAND = 0.02
$THROTTLE_DEADBAND_MIN = 0.02
$THROTTLE_DEADBAND_MAX = 0.10

function ClampValue([double]$value, [double]$min, [double]$max) {
    if ($value -lt $min) { return $min }
    if ($value -gt $max) { return $max }
    return $value
}

function SmoothStep([double]$edge0, [double]$edge1, [double]$value) {
    $normalized = ClampValue (($value - $edge0) / ($edge1 - $edge0)) 0.0 1.0
    return $normalized * $normalized * (3.0 - (2.0 * $normalized))
}

function SimulateTurn([double]$rudder, [double]$throttle) {
    $rud = ClampValue $rudder -1.0 1.0
    $thr = ClampValue $throttle -1.0 1.0

    if ([math]::Abs($rud) -lt $RUDDER_DEADBAND) {
        $rud = 0.0
    }

    $rudderNorm = ClampValue ([math]::Abs($rud)) 0.0 1.0
    $throttleNorm = ClampValue ([math]::Abs($thr)) 0.0 1.0

    $throttleRudderDeadband = $THROTTLE_DEADBAND_MIN + (($THROTTLE_DEADBAND_MAX - $THROTTLE_DEADBAND_MIN) * $throttleNorm)
    $effectiveRudder = 0.0
    if ($rudderNorm -gt $throttleRudderDeadband) {
        $effectiveRudder = ($rudderNorm - $throttleRudderDeadband) / (1.0 - $throttleRudderDeadband)
        if ($rud -lt 0) { $effectiveRudder = -$effectiveRudder }
    }

    if ([math]::Abs($effectiveRudder) -lt 0.001) {
        return [pscustomobject]@{
            Throttle = $throttle
            Rudder = $rudder
            Turn = 0.0
            TurnRatio = 0.0
            RadiusFt = $PIVOT_RADIUS_FT + (($FULL_TURN_RADIUS_FT - $PIVOT_RADIUS_FT) * $throttleNorm)
        }
    }

    $targetRadiusFt = $PIVOT_RADIUS_FT + (($FULL_TURN_RADIUS_FT - $PIVOT_RADIUS_FT) * $throttleNorm)
    $authority = 1.0 - (0.5 * (SmoothStep 0.50 1.00 $throttleNorm))
    $turnRatio = ($PIVOT_RADIUS_FT / [math]::Max($targetRadiusFt, 0.001)) * $authority * $effectiveRudder
    $turn = ClampValue ($turnRatio * $TURN_GAIN) -1.0 1.0

    [pscustomobject]@{
        Throttle = $throttle
        Rudder = $rudder
        Turn = $turn
        TurnRatio = $turnRatio
        RadiusFt = $targetRadiusFt
    }
}

$throttles = @(0.0, 0.25, 0.50, 0.75, 1.00)
$rudders = @(0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)

Write-Host "Active steering model"
Write-Host "Throttle  RadiusFt  TurnRatio"
foreach ($thr in $throttles) {
    $result = SimulateTurn 1.0 $thr
    Write-Host ("{0:F2}       {1:F2}     {2:F3}" -f $result.Throttle, $result.RadiusFt, $result.TurnRatio)
}

$plotWidth = 760
$plotHeight = 420
$marginLeft = 60
$marginRight = 20
$marginTop = 24
$marginBottom = 44
$chartLeft = $marginLeft
$chartRight = $plotWidth - $marginRight
$chartTop = $marginTop
$chartBottom = $plotHeight - $marginBottom

function MapX([double]$x) {
    return $chartLeft + (($x - 0.0) / (1.0 - 0.0)) * ($chartRight - $chartLeft)
}

function MapY([double]$y) {
    return $chartBottom - (($y - 0.0) / (1.0 - 0.0)) * ($chartBottom - $chartTop)
}

$colors = @('#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf', '#000000')
$series = @()
for ($i = 0; $i -lt $throttles.Count; $i++) {
    $thr = $throttles[$i]
    $points = @()
    foreach ($rud in $rudders) {
        $result = SimulateTurn $rud $thr
        $points += ('{0},{1}' -f (MapX $rud), (MapY $result.Turn))
    }
    $color = $colors[$i]
    $dash = if ($i -eq 0) { " stroke-dasharray='7 4'" } else { "" }
    $series += "<polyline fill='none' stroke='$color' stroke-width='1.6'$dash points='" + ($points -join ' ') + "' />"
}

$axis = @(
    "<line x1='$chartLeft' y1='$chartBottom' x2='$chartRight' y2='$chartBottom' stroke='black' />",
    "<line x1='$chartLeft' y1='$chartTop' x2='$chartLeft' y2='$chartBottom' stroke='black' />"
)

$labels = @()
for ($tick = 0.0; $tick -le 1.0; $tick += 0.2) {
    $x = MapX $tick
    $labels += "<line x1='$x' y1='$chartBottom' x2='$x' y2='$($chartBottom + 5)' stroke='black' />"
    $labels += "<text x='$x' y='$($chartBottom + 18)' text-anchor='middle' font-size='10'>" + ('{0:F1}' -f $tick) + "</text>"
}
for ($tick = 0.0; $tick -le 1.0; $tick += 0.2) {
    $y = MapY $tick
    $labels += "<line x1='$chartLeft' y1='$y' x2='$($chartLeft - 5)' y2='$y' stroke='black' />"
    $labels += "<text x='$($chartLeft - 10)' y='$($y + 3)' text-anchor='end' font-size='10'>" + ('{0:F1}' -f $tick) + "</text>"
}

$legend = @()
for ($i = 0; $i -lt $throttles.Count; $i++) {
    $thr = $throttles[$i]
    $percent = [math]::Round(($thr * 100), 0)
    $color = $colors[$i]
    $legend += "<line x1='620' y1='$($chartTop + 8 + ($i * 14))' x2='635' y2='$($chartTop + 8 + ($i * 14))' stroke='$color' stroke-width='2' />"
    $legend += "<text x='640' y='$($chartTop + 12 + ($i * 14))' font-size='10'>$percent%</text>"
}

$svg = @"
<svg xmlns='http://www.w3.org/2000/svg' width='$plotWidth' height='$plotHeight' viewBox='0 0 $plotWidth $plotHeight'>
  <rect width='100%' height='100%' fill='white'/>
    <text x='380' y='18' text-anchor='middle' font-size='14' font-weight='bold'>PB600 turn ratio vs rudder input</text>
  <text x='380' y='405' text-anchor='middle' font-size='12'>Rudder input</text>
    <text x='20' y='220' transform='rotate(-90 20 220)' text-anchor='middle' font-size='12'>Track differential turn ratio</text>
  $($axis -join "")
  $($labels -join "")
  $($series -join "")
  $($legend -join "")
</svg>
"@

$outputDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'images'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$svgPath = Join-Path $outputDir 'steering_contribution_test.svg'
Set-Content -Path $svgPath -Value $svg -Encoding UTF8
Write-Host "Wrote $svgPath"
