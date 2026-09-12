$TRACK_CENTER_SPACING_FT = 3.0
$PIVOT_RADIUS_FT = $TRACK_CENTER_SPACING_FT / 2.0
$FULL_TURN_RADIUS_FT = 10.0
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

    $targetRadius = $PIVOT_RADIUS_FT + (($FULL_TURN_RADIUS_FT - $PIVOT_RADIUS_FT) * $throttleNorm)
    $turnRatio = ($PIVOT_RADIUS_FT / $targetRadius) * $effectiveRudder

    return [pscustomobject]@{
        Left = ClampValue ($drive * (1.0 + $turnRatio)) -1.0 1.0
        Right = ClampValue ($drive * (1.0 - $turnRatio)) -1.0 1.0
    }
}

function GetCellColor([double]$value) {
    $magnitude = [math]::Round([math]::Abs($value) * 180)
    if ($value -gt 0) { return ('rgb({0},255,{0})' -f (255 - $magnitude), (255 - $magnitude)) }
    if ($value -lt 0) { return ('rgb(255,{0},{0})' -f (255 - $magnitude), (255 - $magnitude)) }
    return '#ffffff'
}

function AddHeatmap([string]$title, [string]$propertyName, [int]$originX) {
    $cellSize = 20
    $gridSize = 21 * $cellSize
    $svg = @("<text x='$($originX + ($gridSize / 2))' y='64' text-anchor='middle' font-size='18' font-weight='700'>$title</text>")

    for ($throttleStep = 10; $throttleStep -ge -10; $throttleStep--) {
        $throttle = $throttleStep / 10.0
        $row = 10 - $throttleStep
        for ($rudderStep = -10; $rudderStep -le 10; $rudderStep++) {
            $rudder = $rudderStep / 10.0
            $column = $rudderStep + 10
            $command = GetTrackCommands $throttle $rudder
            $value = $command.$propertyName
            $x = $originX + ($column * $cellSize)
            $y = 90 + ($row * $cellSize)
            $svg += "<rect x='$x' y='$y' width='$cellSize' height='$cellSize' fill='$(GetCellColor $value)' stroke='#d1d5db' stroke-width='0.5'><title>Throttle $([math]::Round($throttle * 100))%, Rudder $([math]::Round($rudder * 100))%: $([math]::Round($value * 100))%</title></rect>"
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

$leftHeatmap = AddHeatmap 'Left Track Command' 'Left' 105
$rightHeatmap = AddHeatmap 'Right Track Command' 'Right' 650
$outputPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'images\steering_track_output_heatmap.svg'

$svg = @"
<svg xmlns='http://www.w3.org/2000/svg' width='1180' height='660' viewBox='0 0 1180 660'>
    <rect width='1180' height='660' fill='white'/>
  <text x='590' y='30' text-anchor='middle' font-size='22' font-weight='700'>PB600 Internal Track Commands at 10% Stick Increments</text>
    <text x='590' y='638' text-anchor='middle' font-size='13'>Green: forward command | Red: reverse command | White: neutral</text>
  $($leftHeatmap -join '')
  $($rightHeatmap -join '')
</svg>
"@

Set-Content -Path $outputPath -Value $svg -NoNewline
Write-Output "Wrote $outputPath"