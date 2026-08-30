-- ============================================================
-- PB600 OPERATOR DISPLAY
-- Phase 1:
--   Animated snowcat
--   Animated tracks
--   Blade lift + angle
--   Tiller lift + swing
--
-- Designed for RadioMaster TX16S MK3
-- 800 x 400 full-screen widget
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

  widget.options = options

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

local COL_SNOW =
  lcd.RGB(190, 205, 212)


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

  return clamp(
    v / 1024,
    -1,
    1
  )

end


local function lerp(a, b, t)

  return
    a +
    ((b - a) * t)

end


-- ============================================================
-- SIMPLE ROTATION
--
-- Used for blade angle and tiller swing.
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
-- BACKGROUND GRID
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
    354,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )


  -- Horizontal perspective-ish lines.
  for y = 90, 390, 30 do

    lcd.drawLine(
      0,
      y,
      800,
      y,
      SOLID,
      FORCE
    )

  end


  -- Vertical lines.
  for x = 20, 800, 40 do

    lcd.drawLine(
      x,
      46,
      x,
      400,
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
  -- MACHINE MODE
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
    330,
    12,
    "MODE:",
    SMLSIZE
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_ACTIVE
  )

  lcd.drawText(
    380,
    12,
    mode,
    SMLSIZE + BOLD
  )


  -- ----------------------------------------------------------
  -- COORDINATION MODE
  --
  -- Current convention:
  --
  -- SB Up      = manual
  -- SB Neutral = swing coordination
  -- SB Down    = full coordination
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
    520,
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
-- TRACK ANIMATION
-- ============================================================

local trackPhaseL = 0
local trackPhaseR = 0
local lastAnimTime = getTime()


local function updateTrackAnimation(
  left,
  right
)

  local now =
    getTime()


  local dt =
    (now - lastAnimTime) / 100


  lastAnimTime =
    now


  if dt < 0 then
    dt = 0
  end


  if dt > 0.1 then
    dt = 0.1
  end


  local speed =
    55


  trackPhaseL =
    trackPhaseL +
    left *
    speed *
    dt


  trackPhaseR =
    trackPhaseR +
    right *
    speed *
    dt


  while trackPhaseL > 16 do
    trackPhaseL = trackPhaseL - 16
  end


  while trackPhaseL < 0 do
    trackPhaseL = trackPhaseL + 16
  end


  while trackPhaseR > 16 do
    trackPhaseR = trackPhaseR - 16
  end


  while trackPhaseR < 0 do
    trackPhaseR = trackPhaseR + 16
  end

end


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


  -- Moving cleats.
  local offset =
    math.floor(phase)


  local spacing =
    16


  local p =
    -spacing + offset


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
      p + spacing

  end

end


-- ============================================================
-- SNOWCAT BODY
-- ============================================================

local function drawBody(
  cx,
  cy
)

  -- Main chassis.
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


  -- Deck.
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


  -- Cab roof.
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


  -- Center chassis line.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawLine(
    cx - 75,
    cy,
    cx + 75,
    cy,
    SOLID,
    FORCE
  )

end


-- ============================================================
-- BLADE
--
-- Blade Lift:
--   CH2
--
-- Blade Angle:
--   CH10
--
-- We use a top/oblique visual model:
--
--   lift changes vertical scene position
--   angle rotates blade around its center
-- ============================================================

local function drawBlade(
  cx,
  cy,
  lift,
  angle
)

  -- Normalize lift into a useful screen offset.
  --
  -- Physical Lua output is a velocity command rather than an
  -- absolute position, so for this first version the display
  -- reacts to command direction.
  --
  -- We'll add a persistent position integrator next.
  local liftOffset =
    lift * 18


  local bladeX =
    cx - 135


  local bladeY =
    cy +
    liftOffset


  local angleRad =
    angle *
    math.rad(24)


  -- Push frame.
  drawRotatedLine(
    bladeX + 38,
    bladeY,
    cx - 70,
    cy,
    bladeX + 10,
    bladeY,
    angleRad,
    COL_METAL,
    3
  )


  -- Blade body.
  for i = -7, 7 do

    drawRotatedLine(
      bladeX - 48,
      bladeY + i,
      bladeX + 48,
      bladeY + i,
      bladeX,
      bladeY,
      angleRad,
      COL_YELLOW,
      1
    )

  end


  -- Blade top edge.
  drawRotatedLine(
    bladeX - 50,
    bladeY - 8,
    bladeX + 50,
    bladeY - 8,
    bladeX,
    bladeY,
    angleRad,
    COL_TEXT,
    2
  )


  -- Cutting edge.
  drawRotatedLine(
    bladeX - 50,
    bladeY + 9,
    bladeX + 50,
    bladeY + 9,
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
-- Lift:
--   CH12
--
-- Swing:
--   CH9
-- ============================================================

local function drawTiller(
  cx,
  cy,
  lift,
  swing
)

  local tillerX =
    cx + 155


  local liftOffset =
    lift * 20


  local tillerY =
    cy +
    liftOffset


  local swingRad =
    swing *
    math.rad(32)


  -- Draw hitch.
  drawRotatedLine(
    cx + 70,
    cy,
    tillerX - 48,
    tillerY,
    tillerX - 48,
    tillerY,
    swingRad,
    COL_METAL,
    3
  )


  -- Tiller main frame.
  for i = -12, 12 do

    drawRotatedLine(
      tillerX - 55,
      tillerY + i,
      tillerX + 55,
      tillerY + i,
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
      tillerY + i,
      tillerX + 43,
      tillerY + i,
      tillerX,
      tillerY,
      swingRad,
      COL_TRACK,
      1
    )

  end


  -- Outer frame.
  drawRotatedLine(
    tillerX - 57,
    tillerY - 14,
    tillerX + 57,
    tillerY - 14,
    tillerX,
    tillerY,
    swingRad,
    COL_TEXT,
    2
  )


  drawRotatedLine(
    tillerX - 57,
    tillerY + 14,
    tillerX + 57,
    tillerY + 14,
    tillerX,
    tillerY,
    swingRad,
    COL_TEXT,
    2
  )

end


-- ============================================================
-- STATUS VALUES
-- ============================================================

local function drawValues(
  leftTrack,
  rightTrack,
  bladeLift,
  bladeAngle,
  tillerLift,
  tillerSwing
)

  local y =
    352


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
    y,
    string.format(
      "L TRACK %4.0f%%",
      leftTrack * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    135,
    y,
    string.format(
      "R TRACK %4.0f%%",
      rightTrack * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    270,
    y,
    string.format(
      "BLIFT %4.0f%%",
      bladeLift * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    385,
    y,
    string.format(
      "BANGLE %4.0f%%",
      bladeAngle * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    520,
    y,
    string.format(
      "TLIFT %4.0f%%",
      tillerLift * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    645,
    y,
    string.format(
      "SWING %4.0f%%",
      tillerSwing * 100
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


  -- Full-screen layout expected.
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
  -- CURRENT MACHINE VALUES
  -- ==========================================================

  -- Current physical assignments:
  --
  -- CH1 = Right Track
  -- CH3 = Left Track
  --
  -- NOTE:
  -- Right-track channel polarity is reversed physically in
  -- system.lua, so invert it again here for a logical
  -- forward-positive display.
  local rightTrack =
    -norm(
      getValue("ch1") or 0
    )


  local leftTrack =
    norm(
      getValue("ch3") or 0
    )


  local bladeLift =
    norm(
      getValue("ch2") or 0
    )


  local bladeAngle =
    norm(
      getValue("ch10") or 0
    )


  local tillerLift =
    norm(
      getValue("ch12") or 0
    )


  local tillerSwing =
    norm(
      getValue("ch9") or 0
    )


  -- ==========================================================
  -- TRACK ANIMATION
  -- ==========================================================

  updateTrackAnimation(
    leftTrack,
    rightTrack
  )


  -- ==========================================================
  -- DRAW
  -- ==========================================================

  lcd.clear(
    COL_BG
  )


  drawSceneBackground()


  drawHeader()


  -- Main snowcat center.
  local cx =
    395

  local cy =
    220


  -- Tracks behind body.
  drawTrack(
    cx - 72,
    cy + 25,
    145,
    25,
    trackPhaseL
  )


  drawTrack(
    cx - 72,
    cy - 5,
    145,
    25,
    trackPhaseR
  )


  drawBody(
    cx,
    cy
  )


  drawBlade(
    cx,
    cy,
    bladeLift,
    bladeAngle
  )


  drawTiller(
    cx,
    cy,
    tillerLift,
    tillerSwing
  )


  drawValues(
    leftTrack,
    rightTrack,
    bladeLift,
    bladeAngle,
    tillerLift,
    tillerSwing
  )

end


-- ============================================================
-- WIDGET EXPORT
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