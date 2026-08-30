-- ============================================================
-- PB600 OPERATOR DISPLAY
--
-- Dual-view schematic:
--
--   LEFT  = TOP VIEW
--           * Left/right track animation
--           * Blade slew
--           * Tiller swing
--
--   RIGHT = SIDE VIEW
--           * Blade lift
--           * Blade angle
--           * Tiller lift
--           * Tiller angle
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

  widget.options = options

end


local function background(widget)

end


-- ============================================================
-- COLORS
-- ============================================================

local COL_BG =
  lcd.RGB(15, 15, 18)

local COL_PANEL =
  lcd.RGB(25, 25, 30)

local COL_GRID =
  lcd.RGB(70, 70, 75)

local COL_TEXT =
  lcd.RGB(200, 200, 200)

local COL_DIM =
  lcd.RGB(125, 125, 135)

local COL_ACTIVE =
  lcd.RGB(0, 160, 120)

local COL_WARN =
  lcd.RGB(220, 140, 0)

local COL_ALERT =
  lcd.RGB(200, 40, 40)

local COL_RED =
  lcd.RGB(180, 35, 30)

local COL_RED_DARK =
  lcd.RGB(95, 25, 22)

local COL_YELLOW =
  lcd.RGB(225, 185, 25)

local COL_TRACK =
  lcd.RGB(30, 30, 34)

local COL_TRACK_BAR =
  lcd.RGB(95, 95, 105)

local COL_METAL =
  lcd.RGB(130, 135, 140)

local COL_GLASS =
  lcd.RGB(35, 70, 90)


-- ============================================================
-- PHYSICAL TIMING
--
-- Match current Blade / Tiller mixer scripts.
-- ============================================================

local BLADE_LIFT_DOWN_FULL =
  11.0

local BLADE_LIFT_UP_FULL =
  17.0

local BLADE_ANGLE_FULL =
  6.7

local BLADE_SLEW_FULL =
  6.7


local TILLER_LIFT_DOWN_FULL =
  11.0

local TILLER_LIFT_UP_FULL =
  17.0

local TILLER_ANGLE_FULL =
  3.75


-- ============================================================
-- DISPLAY CALIBRATION
-- ============================================================

local OUTPUT_DEADBAND =
  0.025


-- Top view.
local MAX_BLADE_SLEW_PIXELS =
  42

local MAX_TILLER_SWING_DEG =
  34


-- Side view.
local BLADE_LIFT_PIXELS =
  54

local TILLER_LIFT_PIXELS =
  48

local MAX_BLADE_ANGLE_DEG =
  28

local MAX_TILLER_ANGLE_DEG =
  24


-- Track visual animation speed.
local TRACK_ANIM_SPEED =
  55


-- ============================================================
-- PERSISTENT VISUAL STATE
-- ============================================================

-- ------------------------------------------------------------
-- TOP VIEW
-- ------------------------------------------------------------

-- Blade slew:
-- -1 = full left
--  0 = center
-- +1 = full right
local bladeSlewPos =
  0


-- CH9 is a position servo, so swing can be read directly.
local tillerSwingPos =
  0


local trackPhaseL =
  0

local trackPhaseR =
  0


-- ------------------------------------------------------------
-- SIDE VIEW
-- ------------------------------------------------------------

-- Lift:
-- 0 = raised/home
-- 1 = fully lowered
local bladeLiftPos =
  0

local tillerLiftPos =
  0


-- Angle:
-- -1 .. +1
local bladeAnglePos =
  0

local tillerAnglePos =
  0


-- ------------------------------------------------------------
-- HOME DISPLAY STATE
-- ------------------------------------------------------------

local homeActive =
  false

local homeArmed =
  false

local lastSh =
  false


local HOME_SLIDER_DEADBAND =
  30


-- ------------------------------------------------------------
-- FRAME TIME
-- ------------------------------------------------------------

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


local function dead(v)

  if math.abs(v) <= OUTPUT_DEADBAND then
    return 0
  end

  return v

end


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
    cx + x * c - y * s,
    cy + x * s + y * c

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
    dead(command)

  if command == 0 then
    return position
  end


  local rate


  -- Current model convention:
  --
  -- positive physical channel command = lower
  -- negative physical channel command = raise
  if command > 0 then

    rate =
      1 / downFullTime

  else

    rate =
      1 / upFullTime

  end


  position =
    position +
    command *
    rate *
    dt


  return
    clamp(
      position,
      0,
      1
    )

end


local function integrateAxis(
  position,
  command,
  fullTime,
  dt
)

  command =
    dead(command)

  if command == 0 then
    return position
  end


  position =
    position +
    command *
    dt /
    fullTime


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

  trackPhaseL =
    trackPhaseL +
    left *
    TRACK_ANIM_SPEED *
    dt


  trackPhaseR =
    trackPhaseR +
    right *
    TRACK_ANIM_SPEED *
    dt


  while trackPhaseL >= 14 do

    trackPhaseL =
      trackPhaseL -
      14

  end


  while trackPhaseL < 0 do

    trackPhaseL =
      trackPhaseL +
      14

  end


  while trackPhaseR >= 14 do

    trackPhaseR =
      trackPhaseR -
      14

  end


  while trackPhaseR < 0 do

    trackPhaseR =
      trackPhaseR +
      14

  end

end


-- ============================================================
-- HEADER
-- ============================================================

local function drawHeader()

  lcd.setColor(
    CUSTOM_COLOR,
    COL_PANEL
  )

  lcd.drawFilledRectangle(
    0,
    0,
    800,
    48,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    10,
    9,
    "PistenBully 600",
    MIDSIZE
  )


  -- ----------------------------------------------------------
  -- MACHINE MODE
  -- ----------------------------------------------------------

  local sd =
    getValue("sd") or 0


  local machineMode =
    "PLOW"


  if sd < -500 then

    machineMode =
      "TRANSPORT"

  elseif sd > 500 then

    machineMode =
      "GROOM"

  end


  lcd.drawText(
    285,
    12,
    "MODE:",
    SMLSIZE
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_ACTIVE
  )

  lcd.drawText(
    335,
    12,
    machineMode,
    SMLSIZE + BOLD
  )


  -- ----------------------------------------------------------
  -- SB STATE
  -- ----------------------------------------------------------

  local sb =
    getValue("sb") or 0


  local controlMode =
    "MANUAL"


  if sb > 500 then

    controlMode =
      "FULL COORD"

  elseif sb > -500 then

    controlMode =
      "SWING COORD"

  end


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    465,
    12,
    controlMode,
    SMLSIZE
  )


  -- ----------------------------------------------------------
  -- HOME
  -- ----------------------------------------------------------

  if homeActive then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )

    lcd.drawText(
      610,
      12,
      "HOME",
      SMLSIZE + INVERS
    )

  end


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
      705,
      12,
      "E-STOP",
      SMLSIZE + INVERS + BLINK
    )

  end

end


-- ============================================================
-- PANEL FRAME
-- ============================================================

local function drawPanel(
  x,
  y,
  w,
  h,
  title
)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_PANEL
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
    COL_GRID
  )

  lcd.drawRectangle(
    x,
    y,
    w,
    h,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x + 8,
    y + 5,
    title,
    SMLSIZE + BOLD
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )

  lcd.drawLine(
    x + 5,
    y + 24,
    x + w - 5,
    y + 24,
    SOLID,
    FORCE
  )

end


-- ============================================================
-- TRACK DRAWING
-- ============================================================

local function drawTrackTop(
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


  local p =
    -14 +
    math.floor(phase)


  while p < w do

    lcd.drawLine(
      x + p,
      y + 2,
      x + p + 8,
      y + h - 2,
      SOLID,
      FORCE
    )

    p =
      p + 14

  end

end


-- ============================================================
-- TOP VIEW BODY
-- ============================================================

local function drawTopBody(
  cx,
  cy
)

  -- Tracks.
  drawTrackTop(
    cx - 75,
    cy - 42,
    150,
    24,
    trackPhaseL
  )

  drawTrackTop(
    cx - 75,
    cy + 18,
    150,
    24,
    trackPhaseR
  )


  -- Chassis.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED_DARK
  )

  lcd.drawFilledRectangle(
    cx - 62,
    cy - 18,
    124,
    36,
    CUSTOM_COLOR
  )


  -- Deck.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawFilledRectangle(
    cx - 20,
    cy - 15,
    68,
    30,
    CUSTOM_COLOR
  )


  -- Cab.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  lcd.drawFilledRectangle(
    cx - 52,
    cy - 15,
    35,
    30,
    CUSTOM_COLOR
  )


  -- Windshield.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_GLASS
  )

  lcd.drawFilledRectangle(
    cx - 46,
    cy - 10,
    22,
    20,
    CUSTOM_COLOR
  )

end


-- ============================================================
-- TOP VIEW BLADE
--
-- Slew = entire blade slides left/right.
-- ============================================================

local function drawTopBlade(
  cx,
  cy
)

  local bladeCenterX =
    cx -
    118 +
    bladeSlewPos *
    MAX_BLADE_SLEW_PIXELS


  local bladeY =
    cy


  -- Push frame.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawLine(
    cx - 60,
    cy - 8,
    bladeCenterX + 38,
    bladeY - 8,
    SOLID,
    FORCE
  )

  lcd.drawLine(
    cx - 60,
    cy + 8,
    bladeCenterX + 38,
    bladeY + 8,
    SOLID,
    FORCE
  )


  -- Blade.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_YELLOW
  )

  lcd.drawFilledRectangle(
    bladeCenterX - 10,
    bladeY - 55,
    20,
    110,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawRectangle(
    bladeCenterX - 10,
    bladeY - 55,
    20,
    110,
    CUSTOM_COLOR
  )

end


-- ============================================================
-- TOP VIEW TILLER
--
-- Swing pivots around hitch point.
-- ============================================================

local function drawTopTiller(
  cx,
  cy
)

  local hitchX =
    cx + 65

  local hitchY =
    cy


  local centerX =
    cx + 145

  local centerY =
    cy


  local swingAngle =
    tillerSwingPos *
    math.rad(
      MAX_TILLER_SWING_DEG
    )


  -- Hitch.
  drawRotatedLine(
    hitchX,
    hitchY,
    centerX - 55,
    centerY,
    hitchX,
    hitchY,
    swingAngle,
    COL_METAL,
    3
  )


  -- Tiller frame.
  for i = -16, 16 do

    drawRotatedLine(
      centerX - 55,
      centerY + i,
      centerX + 55,
      centerY + i,
      hitchX,
      hitchY,
      swingAngle,
      COL_RED,
      1
    )

  end


  -- Roller.
  for i = -8, 8 do

    drawRotatedLine(
      centerX - 43,
      centerY + i,
      centerX + 43,
      centerY + i,
      hitchX,
      hitchY,
      swingAngle,
      COL_TRACK,
      1
    )

  end

end


-- ============================================================
-- TOP VIEW
-- ============================================================

local function drawTopView(
  x,
  y,
  w,
  h
)

  drawPanel(
    x,
    y,
    w,
    h,
    "TOP VIEW - TRACKS / BLADE SLEW / TILLER SWING"
  )


  local cx =
    x + 190

  local cy =
    y + 155


  drawTopBlade(
    cx,
    cy
  )


  drawTopBody(
    cx,
    cy
  )


  drawTopTiller(
    cx,
    cy
  )


  -- Labels.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_DIM
  )


  lcd.drawText(
    x + 8,
    y + h - 34,
    string.format(
      "SLEW %4.0f%%",
      bladeSlewPos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    x + 130,
    y + h - 34,
    string.format(
      "SWING %4.0f%%",
      tillerSwingPos * 100
    ),
    SMLSIZE
  )

end


-- ============================================================
-- SIDE VIEW BODY
-- ============================================================

local function drawSideBody(
  cx,
  cy
)

  -- Track.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK
  )

  lcd.drawFilledRectangle(
    cx - 72,
    cy + 12,
    145,
    27,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK_BAR
  )

  lcd.drawRectangle(
    cx - 72,
    cy + 12,
    145,
    27,
    CUSTOM_COLOR
  )


  -- Chassis.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED_DARK
  )

  lcd.drawFilledRectangle(
    cx - 68,
    cy - 18,
    132,
    34,
    CUSTOM_COLOR
  )


  -- Deck.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawFilledRectangle(
    cx - 12,
    cy - 32,
    70,
    18,
    CUSTOM_COLOR
  )


  -- Cab.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  lcd.drawFilledRectangle(
    cx - 54,
    cy - 65,
    46,
    48,
    CUSTOM_COLOR
  )


  -- Roof.
  lcd.drawFilledRectangle(
    cx - 58,
    cy - 70,
    54,
    7,
    CUSTOM_COLOR
  )


  -- Window.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_GLASS
  )

  lcd.drawFilledRectangle(
    cx - 48,
    cy - 57,
    30,
    24,
    CUSTOM_COLOR
  )

end


-- ============================================================
-- SIDE VIEW BLADE
-- ============================================================

local function drawSideBlade(
  cx,
  cy
)

  local hitchX =
    cx - 64

  local hitchY =
    cy - 3


  local bladeX =
    cx - 130


  local raisedY =
    cy - 55


  local bladeY =
    raisedY +
    bladeLiftPos *
    BLADE_LIFT_PIXELS


  local angle =
    bladeAnglePos *
    math.rad(
      MAX_BLADE_ANGLE_DEG
    )


  -- Lift arms.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawLine(
    hitchX,
    hitchY - 8,
    bladeX + 30,
    bladeY - 6,
    SOLID,
    FORCE
  )

  lcd.drawLine(
    hitchX,
    hitchY + 7,
    bladeX + 30,
    bladeY + 6,
    SOLID,
    FORCE
  )


  -- Blade face.
  for i = -7, 7 do

    drawRotatedLine(
      bladeX - 8,
      bladeY - 32 + i,
      bladeX + 8,
      bladeY + 32 + i,
      bladeX,
      bladeY,
      angle,
      COL_YELLOW,
      1
    )

  end


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    bladeX - 34,
    cy + 73,
    string.format(
      "L %3.0f%%",
      bladeLiftPos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    bladeX - 34,
    cy + 89,
    string.format(
      "A %4.0f%%",
      bladeAnglePos * 100
    ),
    SMLSIZE
  )

end


-- ============================================================
-- SIDE VIEW TILLER
-- ============================================================

local function drawSideTiller(
  cx,
  cy
)

  local hitchX =
    cx + 64

  local hitchY =
    cy


  local tillerX =
    cx + 137


  local raisedY =
    cy - 44


  local tillerY =
    raisedY +
    tillerLiftPos *
    TILLER_LIFT_PIXELS


  local angle =
    tillerAnglePos *
    math.rad(
      MAX_TILLER_ANGLE_DEG
    )


  -- Lift linkage.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawLine(
    hitchX,
    hitchY - 5,
    tillerX - 35,
    tillerY - 7,
    SOLID,
    FORCE
  )


  -- Main tiller frame.
  for i = -10, 10 do

    drawRotatedLine(
      tillerX - 38,
      tillerY + i,
      tillerX + 38,
      tillerY + i,
      tillerX,
      tillerY,
      angle,
      COL_RED,
      1
    )

  end


  -- Roller.
  for i = -5, 5 do

    drawRotatedLine(
      tillerX - 29,
      tillerY + i,
      tillerX + 29,
      tillerY + i,
      tillerX,
      tillerY,
      angle,
      COL_TRACK,
      1
    )

  end


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    tillerX - 32,
    cy + 73,
    string.format(
      "L %3.0f%%",
      tillerLiftPos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    tillerX - 32,
    cy + 89,
    string.format(
      "A %4.0f%%",
      tillerAnglePos * 100
    ),
    SMLSIZE
  )

end


-- ============================================================
-- SIDE VIEW
-- ============================================================

local function drawSideView(
  x,
  y,
  w,
  h
)

  drawPanel(
    x,
    y,
    w,
    h,
    "SIDE VIEW - BLADE / TILLER LIFT & ANGLE"
  )


  local cx =
    x + 193

  local cy =
    y + 156


  drawSideBlade(
    cx,
    cy
  )


  drawSideBody(
    cx,
    cy
  )


  drawSideTiller(
    cx,
    cy
  )

end


-- ============================================================
-- HOME STATE
-- ============================================================

local function updateHomeState(
  bladeTransition,
  tillerTransition
)

  local sh =
    (getValue("sh") or 0) > 500


  local pressed =
    sh and not lastSh


  lastSh =
    sh


  local ls =
    getValue("ls") or 0


  local rs =
    getValue("rs") or 0


  local wingControlsCentered =
    math.abs(ls) <= HOME_SLIDER_DEADBAND
    and
    math.abs(rs) <= HOME_SLIDER_DEADBAND


  local anyTransition =
    bladeTransition
    or
    tillerTransition


  if pressed
    and not anyTransition
  then

    -- Match the SH re-home performed in blade.lua / tiller.lua.
    bladeLiftPos =
      0

    bladeAnglePos =
      0

    bladeSlewPos =
      0

    tillerLiftPos =
      0

    tillerAnglePos =
      0


    homeArmed =
      true


    homeActive =
      false

  end


  if homeArmed
    and wingControlsCentered
  then

    homeArmed =
      false


    homeActive =
      true

  end

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
      z.x + 5,
      z.y + 5,
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

  -- Tracks.
  --
  -- CH1 = Right Track, physical polarity inverted in system.lua.
  -- CH3 = Left Track.
  local rightTrack =
    -norm(
      getValue("ch1") or 0
    )


  local leftTrack =
    norm(
      getValue("ch3") or 0
    )


  -- Blade.
  local bladeLiftCmd =
    norm(
      getValue("ch2") or 0
    )


  local bladeAngleCmd =
    norm(
      getValue("ch10") or 0
    )


  local bladeSlewCmd =
    norm(
      getValue("ch11") or 0
    )


  -- Tiller.
  local tillerLiftCmd =
    norm(
      getValue("ch12") or 0
    )


  local tillerAngleCmd =
    norm(
      getValue("ch13") or 0
    )


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
  -- UPDATE PERSISTENT POSITIONS
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
    integrateAxis(
      bladeAnglePos,
      bladeAngleCmd,
      BLADE_ANGLE_FULL,
      dt
    )


  bladeSlewPos =
    integrateAxis(
      bladeSlewPos,
      bladeSlewCmd,
      BLADE_SLEW_FULL,
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


  tillerAnglePos =
    integrateAxis(
      tillerAnglePos,
      tillerAngleCmd,
      TILLER_ANGLE_FULL,
      dt
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
  -- HOME
  -- ==========================================================

  updateHomeState(
    bladeTransition,
    tillerTransition
  )


  -- Any actual implement movement after HOME invalidates it.
  local anyImplementCommand =
    math.abs(bladeLiftCmd) > OUTPUT_DEADBAND
    or math.abs(bladeAngleCmd) > OUTPUT_DEADBAND
    or math.abs(bladeSlewCmd) > OUTPUT_DEADBAND
    or math.abs(tillerLiftCmd) > OUTPUT_DEADBAND
    or math.abs(tillerAngleCmd) > OUTPUT_DEADBAND


  if homeActive
    and anyImplementCommand
  then

    homeActive =
      false

  end


  -- ==========================================================
  -- DRAW
  -- ==========================================================

  lcd.clear(
    COL_BG
  )


  drawHeader()


  drawTopView(
    5,
    54,
    390,
    340
  )


  drawSideView(
    405,
    54,
    390,
    340
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