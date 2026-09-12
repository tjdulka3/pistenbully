$TRACK_CENTER_SPACING_FT = 3.0
$PIVOT_RADIUS_FT = $TRACK_CENTER_SPACING_FT / 2.0
$FULL_TURN_RADIUS_FT = 10.0
$LOW_SPEED_TURN_RATIO = 1.0
$FULL_SPEED_TURN_RATIO = $PIVOT_RADIUS_FT / $FULL_TURN_RADIUS_FT
$RUDDER_DEADBAND = 0.02
$THROTTLE_DEADBAND_MIN = 0.02
$THROTTLE_DEADBAND_MAX = 0.10

function ClampValue([double]$value, [double]$min, [double]$max) {
    if ($value -lt $min) { return $min }
    if ($value -gt $max) { return $max }
    return $value
}

function GetTrackCommands([double]$throttle, [double]$rudder) {
    $throttleNorm = [math]::Abs($throttle)
    $drive = if ($throttleNorm -lt $THROTTLE_DEADBAND_MIN) { 0.0 } else { $throttle }
    $rudderInput = if ([math]::Abs($rudder) -lt $RUDDER_DEADBAND) { 0.0 } else { $rudder }
    $rudderNorm = [math]::Abs($rudderInput)
    $deadband = $THROTTLE_DEADBAND_MIN + (($THROTTLE_DEADBAND_MAX - $THROTTLE_DEADBAND_MIN) * $throttleNorm)
    $effectiveRudder = if ($rudderNorm -gt $deadband) { ($rudderNorm - $deadband) / (1.0 - $deadband) } else { 0.0 }

    if ($rudderInput -lt 0) { $effectiveRudder = -$effectiveRudder }

    $fullRudderTurnRatio = $LOW_SPEED_TURN_RATIO + (($FULL_SPEED_TURN_RATIO - $LOW_SPEED_TURN_RATIO) * $throttleNorm)
    $turnRatio = $fullRudderTurnRatio * $effectiveRudder
    $steeringAuthority = [math]::Abs($turnRatio)

    return [pscustomobject]@{
        Left = ClampValue ($drive * (1.0 + $turnRatio)) -1.0 1.0
        Right = ClampValue ($drive * (1.0 - $turnRatio)) -1.0 1.0
        Contribution = $steeringAuthority
    }
}

function GetSteeringColor([double]$contribution, [double]$maximumContribution) {
    $intensity = [math]::Min(1.0, $contribution / $maximumContribution)
    $redBlue = [math]::Round(255.0 * (1.0 - $intensity))
    $green = 255
    return ('rgb({0},{1},{0})' -f $redBlue, $green)
}

function AddHeatmap([string]$title, [int]$originX) {
    $cellSize = 20
    $gridSize = 21 * $cellSize
    $maximumContribution = 0.0
    $svg = @("<text x='$($originX + ($gridSize / 2))' y='64' text-anchor='middle' font-size='18' font-weight='700'>$title</text>")

    for ($throttleStep = -10; $throttleStep -le 10; $throttleStep++) {
        for ($rudderStep = -10; $rudderStep -le 10; $rudderStep++) {
            $command = GetTrackCommands ($throttleStep / 10.0) ($rudderStep / 10.0)
            $maximumContribution = [math]::Max($maximumContribution, $command.Contribution)
        }
    }

    for ($throttleStep = 10; $throttleStep -ge -10; $throttleStep--) {
        $throttle = $throttleStep / 10.0
        $row = 10 - $throttleStep
        for ($rudderStep = -10; $rudderStep -le 10; $rudderStep++) {
            $rudder = $rudderStep / 10.0
            $column = $rudderStep + 10
            $command = GetTrackCommands $throttle $rudder
            $contribution = $command.Contribution
            $x = $originX + ($column * $cellSize)
            $y = 90 + ($row * $cellSize)
            $svg += "<rect x='$x' y='$y' width='$cellSize' height='$cellSize' fill='$(GetSteeringColor $contribution $maximumContribution)' stroke='#d1d5db' stroke-width='0.5'><title>Throttle $([math]::Round($throttle * 100))%, Rudder $([math]::Round($rudder * 100))%: steering authority $([math]::Round($contribution * 100))%</title></rect>"
        }
    }

    foreach ($step in @(-10, -5, 0, 5, 10)) {
        $x = $originX + (($step + 10) * $cellSize) + 10
        $y = 90 + ((10 - $step) * $cellSize) + 14
        $svg += "<text x='$x' y='530' text-anchor='middle' font-size='12'>$($step * 10)%</text>"
        $svg += "<text x='$($originX - 8)' y='$y' text-anchor='end' font-size='12'>$($step * 10)%</text>"
    }

    $centerX = $originX + ($gridSize / 2)
    $centerY = 90 + ($gridSize / 2)
    $svg += "<line x1='$centerX' y1='90' x2='$centerX' y2='510' stroke='#111827' stroke-width='2' opacity='0.8'/>"
    $svg += "<line x1='$originX' y1='$centerY' x2='$($originX + $gridSize)' y2='$centerY' stroke='#111827' stroke-width='2' opacity='0.8'/>"
    $svg += "<circle cx='$centerX' cy='$centerY' r='5' fill='#111827' stroke='white' stroke-width='2'/><text x='$($centerX + 9)' y='$($centerY - 8)' font-size='11' font-weight='700'>0,0</text>"
    $svg += "<text x='$centerX' y='82' text-anchor='middle' font-size='12' font-weight='700'>FORWARD (+)</text>"
    $svg += "<text x='$centerX' y='580' text-anchor='middle' font-size='12' font-weight='700'>REVERSE (-)</text>"
    $svg += "<text x='$($originX + 8)' y='548' text-anchor='start' font-size='12' font-weight='700'>LEFT (-)</text>"
    $svg += "<text x='$($originX + $gridSize - 8)' y='548' text-anchor='end' font-size='12' font-weight='700'>RIGHT (+)</text>"
        $svg += "<text x='$centerX' y='602' text-anchor='middle' font-size='14'>Rudder</text>"
    $svg += "<text x='$($originX - 54)' y='300' text-anchor='middle' font-size='14' transform='rotate(-90 $($originX - 54) 300)'>Throttle</text>"
    return $svg
}

$heatmap = AddHeatmap 'Normalized Steering Authority: |Left - Right| / (2 x |Drive|)' 380
$outputPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'images\steering_track_output_heatmap.svg'

$svg = @"
<svg xmlns='http://www.w3.org/2000/svg' width='1000' height='660' viewBox='0 0 1000 660'>
    <rect width='1000' height='660' fill='white'/>
    <text x='500' y='30' text-anchor='middle' font-size='22' font-weight='700'>PB600 Steering Contribution at 10% Stick Increments</text>
    <text x='500' y='638' text-anchor='middle' font-size='13'>White: no steering authority | Full green: greatest normalized track differential</text>
    $($heatmap -join '')
</svg>
"@

Set-Content -Path $outputPath -Value $svg -NoNewline
Write-Output "Wrote $outputPath"