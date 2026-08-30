-- ============================================================
-- PB600 OPERATOR DISPLAY
--
-- Phase 2:
--   Animated snowcat
--   Animated tracks
--   Persistent blade lift + angle model
--   Persistent tiller lift + swing model
--   Blade/tiller pitch during transitions
--   Implements return visually LEVEL when transition completes
--
-- Designed for RadioMaster TX16S MK3
-- Full-screen 800 x 400 EdgeTX widget
-- ============================================================

local name = "PB600OP"
local options = {}


-- ============================================================
-- WIDGET LIFECYCLE
-- ============================================================

local function create(zone, options)

  return {
    zone = zone,
    options = options
  }

end


local function update(widget, options)

  widget.options =
    options

end


local function background(widget)

end


-- ============================================================
-- COLORS
-- ============================================================

local COL_BG =
  lcd.RGB(28, 42, 52)

local COL_HEADER =
  lcd.RGB(18, 22, 26)

local COL_GRID =
  lcd.RGB(65, 82, 92)

local COL_TEXT =
  lcd.RGB(225, 225, 225)

local COL_DIM =
  lcd.RGB(130, 145, 150)

local COL_RED =
  lcd.RGB(190, 38, 32)

local COL_RED_DARK =
  lcd.RGB(100, 25, 22)

local COL_YELLOW =
  lcd.RGB(235, 190, 25)

local COL_TRACK =
  lcd.RGB(25, 25, 27)

local COL_TRACK_BAR =
  lcd.RGB(75, 75, 78)

local COL_METAL =
  lcd.RGB(110, 115, 120)

local COL_ACTIVE =
  lcd.RGB(0, 170, 115)

local COL_WARN =
  lcd.RGB(225, 145, 0)

local COL_ALERT =
  lcd.RGB(210, 45, 45)


-- ============================================================
-- PHYSICAL TIMING
--
-- Match blade.lua / tiller.lua
-- ============================================================

local BLADE_LIFT_DOWN_FULL =
  11.0

local BLADE_LIFT_UP_FULL =
  17.0

local BLADE_ANGLE_FULL =
  6.7

local TILLER_LIFT_DOWN_FULL =
  11.0

local TILLER_LIFT_UP_FULL =
  17.0


-- Servo swing is positional, so we don't need a time
-- integrator for CH9.
--
-- CH9 itself represents tiller swing position.
-- ============================================================


-- ============================================================
-- VISUAL SETTINGS
-- ============================================================

-- Maximum vertical screen movement for the blade/tiller.
local BLADE_LIFT_PIXELS =
  36

local TILLER_LIFT_PIXELS =
  34


-- Maximum left/right visual blade angle.
local BLADE_ANGLE_DEG =
  28


-- Maximum tiller swing angle.
local TILLER_SWING_DEG =
  34


-- Temporary visual pitch while an implement is moving
-- automatically.
local TRANSITION_PITCH_DEG =
  10


-- Smoothing for visual pitch.
local PITCH_SMOOTHING =
  0.18


-- Small actuator output threshold to ignore noise.
local OUTPUT_DEADBAND =
  0.025


-- ============================================================
-- VISUAL STATE
-- ============================================================

-- Blade lift position:
--
--   0 = raised / home
--   1 = fully lowered
local bladeLiftPos =
  0


-- Blade angle:
--
--  -1 = fully one direction
--   0 = straight
--  +1 = fully opposite direction
local bladeAnglePos =
  0


-- Tiller lift:
--
--   0 = raised
--   1 = fully lowered
local tillerLiftPos =
  0


-- Tiller swing comes from CH9 directly because it is a
-- positional servo.
local tillerSwingPos =
  0


-- Temporary visual transition pitch.
local bladeVisualPitch =
  0

local tillerVisualPitch =
  0


-- Track tread animation.
local trackPhaseL =
  0

local trackPhaseR =
  0


local lastTime =
  getTime()


-- ============================================================
-- HELPERS
-- ============================================================

local function clamp(v, lo, hi)

  if v < lo then
    return lo
  end

  if v > hi then
    return hi
  end

  return v

end


local function norm(v)

  if type(v) ~= "number" then
    return 0
  end


  return
    clamp(
      v / 1024,
      -1,
      1
    )

end


local function applyDeadband(v, db)

  if math.abs(v) <= db then
    return 0
  end

  return v

end


local function approach(
  current,
  target,
  amount
)

  return
    current +
    (
      target -
      current
    ) *
    amount

end


-- ============================================================
-- ROTATION HELPERS
-- ============================================================

local function rotatePoint(
  px,
  py,
  cx,
  cy,
  angle
)

  local s =
    math.sin(angle)

  local c =
    math.cos(angle)


  local x =
    px - cx

  local y =
    py - cy


  return

    cx +
    x * c -
    y * s,

    cy +
    x * s +
    y * c

end


local function drawRotatedLine(
  x1,
  y1,
  x2,
  y2,
  cx,
  cy,
  angle,
  color,
  width
)

  local rx1, ry1 =
    rotatePoint(
      x1,
      y1,
      cx,
      cy,
      angle
    )


  local rx2, ry2 =
    rotatePoint(
      x2,
      y2,
      cx,
      cy,
      angle
    )


  lcd.setColor(
    CUSTOM_COLOR,
    color
  )


  width =
    width or 1


  for i = 0, width - 1 do

    lcd.drawLine(
      rx1,
      ry1 + i,
      rx2,
      ry2 + i,
      SOLID,
      FORCE
    )

  end

end


-- ============================================================
-- POSITION INTEGRATORS
-- ============================================================

local function integrateLift(
  position,
  command,
  downFullTime,
  upFullTime,
  dt
)

  command =
    applyDeadband(
      command,
      OUTPUT_DEADBAND
    )


  if command == 0 then

    return
      position

  end


  -- IMPORTANT:
  --
  -- These signs assume:
  --
  --   positive CH output = LOWER
  --   negative CH output = RAISE
  --
  -- If the display moves opposite your physical actuator,
  -- flip the sign here rather than changing the drawing code.

  local rate


  if command > 0 then

    -- Lowering
    rate =
      1 /
      downFullTime

  else

    -- Raising
    rate =
      1 /
      upFullTime

  end


  position =
    position +
    (
      command *
      rate *
      dt
    )


  return
    clamp(
      position,
      0,
      1
    )

end


local function integrateBidirectional(
  position,
  command,
  fullTime,
  dt
)

  command =
    applyDeadband(
      command,
      OUTPUT_DEADBAND
    )


  if command == 0 then

    return
      position

  end


  position =
    position +
    (
      command *
      dt /
      fullTime
    )


  return
    clamp(
      position,
      -1,
      1
    )

end


-- ============================================================
-- TRACK ANIMATION
-- ============================================================

local function updateTrackAnimation(
  left,
  right,
  dt
)

  local visualSpeed =
    55


  trackPhaseL =
    trackPhaseL +
    left *
    visualSpeed *
    dt


  trackPhaseR =
    trackPhaseR +
    right *
    visualSpeed *
    dt


  while trackPhaseL > 16 do

    trackPhaseL =
      trackPhaseL -
      16

  end


  while trackPhaseL < 0 do

    trackPhaseL =
      trackPhaseL +
      16

  end


  while trackPhaseR > 16 do

    trackPhaseR =
      trackPhaseR -
      16

  end


  while trackPhaseR < 0 do

    trackPhaseR =
      trackPhaseR +
      16

  end

end


-- ============================================================
-- BACKGROUND
-- ============================================================

local function drawSceneBackground()

  lcd.setColor(
    CUSTOM_COLOR,
    COL_BG
  )


  lcd.drawFilledRectangle(
    0,
    46,
    800,
    294,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )


  for y = 90, 330, 30 do

    lcd.drawLine(
      0,
      y,
      800,
      y,
      SOLID,
      FORCE
    )

  end


  for x = 20, 800, 40 do

    lcd.drawLine(
      x,
      46,
      x,
      340,
      SOLID,
      FORCE
    )

  end

end


-- ============================================================
-- HEADER
-- ============================================================

local function drawHeader()

  lcd.setColor(
    CUSTOM_COLOR,
    COL_HEADER
  )


  lcd.drawFilledRectangle(
    0,
    0,
    800,
    46,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )


  lcd.drawText(
    12,
    9,
    "PistenBully 600",
    MIDSIZE
  )


  -- ----------------------------------------------------------
  -- OPERATING MODE
  -- ----------------------------------------------------------

  local sd =
    getValue("sd") or 0


  local mode =
    "PLOW"


  if sd < -500 then

    mode =
      "TRANSPORT"

  elseif sd > 500 then

    mode =
      "GROOM"

  end


  lcd.drawText(
    320,
    12,
    "MODE:",
    SMLSIZE
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_ACTIVE
  )


  lcd.drawText(
    368,
    12,
    mode,
    SMLSIZE + BOLD
  )


  -- ----------------------------------------------------------
  -- SB CONTROL MODE
  -- ----------------------------------------------------------

  local sb =
    getValue("sb") or 0


  local coordText =
    "MANUAL"


  if sb > 500 then

    coordText =
      "FULL COORD"

  elseif sb > -500 then

    coordText =
      "SWING COORD"

  end


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )


  lcd.drawText(
    500,
    12,
    coordText,
    SMLSIZE
  )


  -- ----------------------------------------------------------
  -- E-STOP
  -- ----------------------------------------------------------

  local sf =
    getValue("sf") or 0


  if sf > 0 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ALERT
    )


    lcd.drawText(
      700,
      12,
      "E-STOP",
      SMLSIZE + INVERS + BLINK
    )

  end

end


-- ============================================================
-- TRACK DRAWING
-- ============================================================

local function drawTrack(
  x,
  y,
  w,
  h,
  phase
)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK
  )


  lcd.drawFilledRectangle(
    x,
    y,
    w,
    h,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK_BAR
  )


  lcd.drawRectangle(
    x,
    y,
    w,
    h,
    CUSTOM_COLOR
  )


  local offset =
    math.floor(
      phase
    )


  local spacing =
    16


  local p =
    -spacing +
    offset


  while p < w do

    lcd.drawLine(
      x + p,
      y + 3,
      x + p + 8,
      y + h - 3,
      SOLID,
      FORCE
    )


    p =
      p +
      spacing

  end

end


-- ============================================================
-- SNOWCAT BODY
-- ============================================================

local function drawBody(
  cx,
  cy
)

  -- Chassis.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED_DARK
  )


  lcd.drawFilledRectangle(
    cx - 75,
    cy - 32,
    150,
    65,
    CUSTOM_COLOR
  )


  -- Rear deck.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )


  lcd.drawFilledRectangle(
    cx - 42,
    cy - 40,
    110,
    42,
    CUSTOM_COLOR
  )


  -- Cab.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )


  lcd.drawFilledRectangle(
    cx - 58,
    cy - 82,
    65,
    52,
    CUSTOM_COLOR
  )


  lcd.drawFilledRectangle(
    cx - 63,
    cy - 88,
    75,
    8,
    CUSTOM_COLOR
  )


  -- Windshield.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_BG
  )


  lcd.drawFilledRectangle(
    cx - 49,
    cy - 75,
    46,
    25,
    CUSTOM_COLOR
  )

end


-- ============================================================
-- BLADE
--
-- liftPos:
--   0 = raised
--   1 = lowered
--
-- anglePos:
--  -1..1
--
-- visualPitch:
--   temporary pitch only while transitioning
-- ============================================================

local function drawBlade(
  cx,
  cy,
  liftPos,
  anglePos,
  visualPitch
)

  local bladeX =
    cx - 145


  local bladeY =
    cy -
    25 +
    (
      liftPos *
      BLADE_LIFT_PIXELS
    )


  local angleRad =
    anglePos *
    math.rad(
      BLADE_ANGLE_DEG
    )


  -- Pitch is shown as a visual rise/fall across the blade.
  local pitchOffset =
    math.sin(
      visualPitch
    ) *
    24


  -- Hitch arms.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )


  lcd.drawLine(
    cx - 68,
    cy - 8,
    bladeX + 40,
    bladeY - pitchOffset,
    SOLID,
    FORCE
  )


  lcd.drawLine(
    cx - 68,
    cy + 12,
    bladeX + 40,
    bladeY + pitchOffset,
    SOLID,
    FORCE
  )


  -- Blade face.
  for i = -8, 8 do

    drawRotatedLine(
      bladeX - 50,
      bladeY + i - pitchOffset,
      bladeX + 50,
      bladeY + i + pitchOffset,
      bladeX,
      bladeY,
      angleRad,
      COL_YELLOW,
      1
    )

  end


  -- Top edge.
  drawRotatedLine(
    bladeX - 52,
    bladeY - 9 - pitchOffset,
    bladeX + 52,
    bladeY - 9 + pitchOffset,
    bladeX,
    bladeY,
    angleRad,
    COL_TEXT,
    2
  )


  -- Cutting edge.
  drawRotatedLine(
    bladeX - 52,
    bladeY + 10 - pitchOffset,
    bladeX + 52,
    bladeY + 10 + pitchOffset,
    bladeX,
    bladeY,
    angleRad,
    COL_METAL,
    2
  )

end


-- ============================================================
-- TILLER
--
-- liftPos:
--   0 = raised
--   1 = lowered
--
-- swingPos:
--  -1..1
--
-- visualPitch:
--   temporary pitch while raising/lowering
-- ============================================================

local function drawTiller(
  cx,
  cy,
  liftPos,
  swingPos,
  visualPitch
)

  local tillerX =
    cx + 165


  local tillerY =
    cy -
    18 +
    (
      liftPos *
      TILLER_LIFT_PIXELS
    )


  local swingRad =
    swingPos *
    math.rad(
      TILLER_SWING_DEG
    )


  local pitchOffset =
    math.sin(
      visualPitch
    ) *
    22


  -- Hitch.
  drawRotatedLine(
    cx + 65,
    cy,
    tillerX - 54,
    tillerY - pitchOffset,
    tillerX - 54,
    tillerY,
    swingRad,
    COL_METAL,
    3
  )


  -- Main tiller body.
  for i = -13, 13 do

    drawRotatedLine(
      tillerX - 57,
      tillerY + i - pitchOffset,
      tillerX + 57,
      tillerY + i + pitchOffset,
      tillerX,
      tillerY,
      swingRad,
      COL_RED,
      1
    )

  end


  -- Roller.
  for i = -8, 8 do

    drawRotatedLine(
      tillerX - 43,
      tillerY + i - pitchOffset,
      tillerX + 43,
      tillerY + i + pitchOffset,
      tillerX,
      tillerY,
      swingRad,
      COL_TRACK,
      1
    )

  end


  -- Frame.
  drawRotatedLine(
    tillerX - 58,
    tillerY - 14 - pitchOffset,
    tillerX + 58,
    tillerY - 14 + pitchOffset,
    tillerX,
    tillerY,
    swingRad,
    COL_TEXT,
    2
  )


  drawRotatedLine(
    tillerX - 58,
    tillerY + 14 - pitchOffset,
    tillerX + 58,
    tillerY + 14 + pitchOffset,
    tillerX,
    tillerY,
    swingRad,
    COL_TEXT,
    2
  )

end


-- ============================================================
-- STATUS STRIP
-- ============================================================

local function drawStatusStrip(
  leftTrack,
  rightTrack
)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_HEADER
  )


  lcd.drawFilledRectangle(
    0,
    340,
    800,
    60,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )


  lcd.drawText(
    15,
    352,
    string.format(
      "L TRACK %4.0f%%",
      leftTrack * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    135,
    352,
    string.format(
      "R TRACK %4.0f%%",
      rightTrack * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    270,
    352,
    string.format(
      "B LIFT %3.0f%%",
      bladeLiftPos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    385,
    352,
    string.format(
      "B ANG %4.0f%%",
      bladeAnglePos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    510,
    352,
    string.format(
      "T LIFT %3.0f%%",
      tillerLiftPos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    635,
    352,
    string.format(
      "SWING %4.0f%%",
      tillerSwingPos * 100
    ),
    SMLSIZE
  )

end


-- ============================================================
-- REFRESH
-- ============================================================

local function refresh(
  widget,
  event,
  touchState
)

  local z =
    widget.zone


  if z.w < 790
    or z.h < 390
  then

    lcd.clear(
      COL_BG
    )


    lcd.setColor(
      CUSTOM_COLOR,
      COL_TEXT
    )


    lcd.drawText(
      z.x + 10,
      z.y + 10,
      "PB600OP requires full-screen 800x400",
      SMLSIZE
    )


    return

  end


  -- ==========================================================
  -- FRAME TIME
  -- ==========================================================

  local now =
    getTime()


  local dt =
    (now - lastTime) /
    100


  lastTime =
    now


  if dt < 0 then
    dt = 0
  end


  if dt > 0.20 then
    dt = 0.20
  end


  -- ==========================================================
  -- CURRENT CHANNEL VALUES
  -- ==========================================================

  -- Track assignments:
  --
  -- CH1 = Right Track
  -- CH3 = Left Track
  --
  -- Right physical channel is reversed by system.lua,
  -- so invert it again for logical forward-positive display.

  local rightTrack =
    -norm(
      getValue("ch1") or 0
    )


  local leftTrack =
    norm(
      getValue("ch3") or 0
    )


  local bladeLiftCmd =
    norm(
      getValue("ch2") or 0
    )


  local bladeAngleCmd =
    norm(
      getValue("ch10") or 0
    )


  local tillerLiftCmd =
    norm(
      getValue("ch12") or 0
    )


  -- CH9 is a position servo.
  tillerSwingPos =
    norm(
      getValue("ch9") or 0
    )


  -- ==========================================================
  -- TRANSITION STATES
  -- ==========================================================

  local bladeTransition =
    getLogicalSwitchValue(10) -- L11


  local tillerTransition =
    getLogicalSwitchValue(11) -- L12


  -- ==========================================================
  -- PERSISTENT POSITION INTEGRATORS
  -- ==========================================================

  bladeLiftPos =
    integrateLift(
      bladeLiftPos,
      bladeLiftCmd,
      BLADE_LIFT_DOWN_FULL,
      BLADE_LIFT_UP_FULL,
      dt
    )


  bladeAnglePos =
    integrateBidirectional(
      bladeAnglePos,
      bladeAngleCmd,
      BLADE_ANGLE_FULL,
      dt
    )


  tillerLiftPos =
    integrateLift(
      tillerLiftPos,
      tillerLiftCmd,
      TILLER_LIFT_DOWN_FULL,
      TILLER_LIFT_UP_FULL,
      dt
    )


  -- ==========================================================
  -- TRANSITION PITCH TARGETS
  --
  -- Pitch exists only while L11/L12 indicate movement.
  --
  -- Once the transition ends, target pitch returns to zero,
  -- so the implement visually settles LEVEL in either the
  -- raised or lowered position.
  -- ==========================================================

  local bladePitchTarget =
    0


  if bladeTransition then

    if bladeLiftCmd > OUTPUT_DEADBAND then

      -- Lowering
      bladePitchTarget =
        math.rad(
          TRANSITION_PITCH_DEG
        )

    elseif bladeLiftCmd < -OUTPUT_DEADBAND then

      -- Raising
      bladePitchTarget =
        -math.rad(
          TRANSITION_PITCH_DEG
        )

    end

  end


  bladeVisualPitch =
    approach(
      bladeVisualPitch,
      bladePitchTarget,
      PITCH_SMOOTHING
    )


  local tillerPitchTarget =
    0


  if tillerTransition then

    if tillerLiftCmd > OUTPUT_DEADBAND then

      -- Lowering
      tillerPitchTarget =
        math.rad(
          TRANSITION_PITCH_DEG
        )

    elseif tillerLiftCmd < -OUTPUT_DEADBAND then

      -- Raising
      tillerPitchTarget =
        -math.rad(
          TRANSITION_PITCH_DEG
        )

    end

  end


  tillerVisualPitch =
    approach(
      tillerVisualPitch,
      tillerPitchTarget,
      PITCH_SMOOTHING
    )


  -- ==========================================================
  -- TRACK ANIMATION
  -- ==========================================================

  updateTrackAnimation(
    leftTrack,
    rightTrack,
    dt
  )


  -- ==========================================================
  -- DRAW
  -- ==========================================================

  lcd.clear(
    COL_BG
  )


  drawSceneBackground()


  drawHeader()


  local cx =
    395


  local cy =
    210


  -- Tracks behind body.
  drawTrack(
    cx - 72,
    cy + 28,
    145,
    26,
    trackPhaseL
  )


  drawTrack(
    cx - 72,
    cy - 4,
    145,
    26,
    trackPhaseR
  )


  drawBody(
    cx,
    cy
  )


  drawBlade(
    cx,
    cy,
    bladeLiftPos,
    bladeAnglePos,
    bladeVisualPitch
  )


  drawTiller(
    cx,
    cy,
    tillerLiftPos,
    tillerSwingPos,
    tillerVisualPitch
  )


  drawStatusStrip(
    leftTrack,
    rightTrack
  )

end


-- ============================================================
-- EXPORT
-- ============================================================

return {

  name =
    name,

  options =
    options,

  create =
    create,

  update =
    update,

  refresh =
    refresh,

  background =
    background

}