$TURN_GAIN = 0.40
$STEER_TAPER_START = 0.50
$STEER_MIN_SCALE = 0.50
$PIVOT_BLEND_END = 0.80

function ClampValue([double]$value, [double]$min, [double]$max) {
    if ($value -lt $min) { return $min }
    if ($value -gt $max) { return $max }
    return $value
}

function ThrottleToSpeedDemand([double]$throttle) {
    $sign = 1.0
    if ($throttle -lt 0) { $sign = -1.0 }

    $x = ClampValue ([math]::Abs($throttle)) 0.0 1.0
    $shaped = $x * $x * (3.0 - (2.0 * $x))
    return $shaped * $sign
}

function SpeedScale([double]$vehicleSpeed) {
    $s = ClampValue $vehicleSpeed 0.0 1.0
    if ($s -le $STEER_TAPER_START) { return 1.0 }

    $t = ClampValue (($s - $STEER_TAPER_START) / (1.0 - $STEER_TAPER_START)) 0.0 1.0
    $smooth = $t * $t * (3.0 - (2.0 * $t))
    return 1.0 - ($smooth * (1.0 - $STEER_MIN_SCALE))
}

function SimulateTurn([double]$rudder, [double]$throttle) {
    $rud = ClampValue $rudder -1.0 1.0
    $thr = ClampValue $throttle -1.0 1.0

    $speedDemand = ThrottleToSpeedDemand $thr
    $vehicleSpeed = [math]::Abs($speedDemand)
    $speedFactor = SpeedScale $vehicleSpeed

    $rudCurve = $rud * [math]::Abs($rud)
    $turn = $rudCurve * $TURN_GAIN * $speedFactor

    [pscustomobject]@{
        Throttle = $throttle
        Rudder = $rudder
        SpeedScale = $speedFactor
        Turn = $turn
    }
}

$throttles = @(0.50, 0.75, 1.00)
$rudders = @(0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0)

Write-Host "Representative full-rudder steering curves"
Write-Host "Throttle  SpeedScale  Turn"
foreach ($thr in $throttles) {
    $result = SimulateTurn 1.0 $thr
    Write-Host ("{0:F2}       {1:F3}      {2:F3}" -f $result.Throttle, $result.SpeedScale, $result.Turn)
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
    return $chartBottom - (($y - 0.0) / (0.45 - 0.0)) * ($chartBottom - $chartTop)
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
for ($tick = 0.0; $tick -le 0.4; $tick += 0.1) {
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
  <text x='380' y='18' text-anchor='middle' font-size='14' font-weight='bold'>PB600 turn contribution vs rudder</text>
  <text x='380' y='405' text-anchor='middle' font-size='12'>Rudder input</text>
  <text x='20' y='220' transform='rotate(-90 20 220)' text-anchor='middle' font-size='12'>Steering contribution</text>
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
