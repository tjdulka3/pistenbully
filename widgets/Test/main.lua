-- ============================================================
-- PB600 OPERATOR DASHBOARD
--
-- Dual-view machine visualization:
--
-- LEFT / TOP VIEW
--   * Animated Left / Right tracks
--   * Blade slew
--   * Tiller swing
--
-- RIGHT / SIDE VIEW
--   * Blade lift
--   * Blade angle
--   * Tiller lift
--   * Tiller angle
--
-- SH:
--   Resets visual actuator positions to zero/home.
--
-- Designed for RadioMaster TX16S MK3
-- Full screen: 800 x 400
-- ============================================================


local name = "PB600OP"
local options = {}


local function create(zone, options)
  return {
    zone = zone,
    options = options
  }
end


local function update(wgt, options)
  wgt.options = options
end


local function background(wgt)
end


-- ============================================================
-- HOME STATE
-- ============================================================

local homeActive = false
local homeArmed  = false
local lastSh     = false

local HOME_SLIDER_DEADBAND = 100


-- ============================================================
-- PB600 COLOR PALETTE
-- ============================================================

local COL_PANEL =
  lcd.RGB(25, 25, 30)

local COL_GRID =
  lcd.RGB(70, 70, 75)

local COL_TEXT =
  lcd.RGB(200, 200, 200)

local COL_ACTIVE =
  lcd.RGB(0, 160, 120)

local COL_WARN =
  lcd.RGB(220, 140, 0)

local COL_ALERT =
  lcd.RGB(200, 40, 40)

local COL_HYD =
  lcd.RGB(0, 110, 180)

local COL_MOTION =
  lcd.RGB(160, 160, 160)

local COL_FWD =
  lcd.RGB(16, 179, 57)

local COL_REV =
  lcd.RGB(242, 206, 13)


-- Machine drawing colors.

local COL_RED =
  lcd.RGB(180, 35, 30)

local COL_RED_DARK =
  lcd.RGB(95, 25, 22)

local COL_YELLOW =
  lcd.RGB(225, 185, 25)

-- Track body matches deck gray.
local COL_TRACK =
  lcd.RGB(125, 130, 135)

local COL_TRACK_BAR =
  lcd.RGB(70, 70, 75)

local COL_METAL =
  lcd.RGB(125, 130, 135)

local COL_GLASS =
  lcd.RGB(30, 75, 100)


local COL_BACKGROUND =
  lcd.RGB(44, 143, 176)


-- ============================================================
-- PHYSICAL ACTUATOR TIMING
-- ============================================================

local BLADE_LIFT_DOWN_FULL = 11.0
local BLADE_LIFT_UP_FULL   = 17.0
local BLADE_ANGLE_FULL     = 6.7
local BLADE_SLEW_FULL      = 6.7

local TILLER_LIFT_DOWN_FULL = 11.0
local TILLER_LIFT_UP_FULL   = 17.0
local TILLER_ANGLE_FULL     = 3.75


-- ============================================================
-- VISUAL CALIBRATION
-- ============================================================

local OUTPUT_DEADBAND = 0.025

-- Top view.
local MAX_BLADE_SLEW_PIXELS = 34
local MAX_TILLER_SWING_DEG  = 32

-- Side view.
local MAX_BLADE_ANGLE_DEG = 28
local MAX_TILLER_ANGLE_DEG = 24

local TRACK_ANIM_SPEED = 55


-- ============================================================
-- PERSISTENT VISUAL POSITION STATE
-- ============================================================

-- Top view.
local bladeSlewPos    = 0
local tillerSwingPos  = 0
local trackPhaseL     = 0
local trackPhaseR     = 0

-- Side view.
local bladeLiftPos    = 0
local tillerLiftPos   = 0
local bladeAnglePos   = 0
local tillerAnglePos  = 0

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

  return clamp(
    v / 1024,
    -1,
    1
  )

end


local function applyDeadband(v)

  if math.abs(v) <= OUTPUT_DEADBAND then
    return 0
  end

  return v

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

  local s = math.sin(angle)
  local c = math.cos(angle)

  local x = px - cx
  local y = py - cy

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

  width = width or 1

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
    applyDeadband(command)

  if command == 0 then
    return position
  end

  local rate

  if command > 0 then
    rate = 1 / downFullTime
  else
    rate = 1 / upFullTime
  end

  position =
    position +
    command *
    rate *
    dt

  return clamp(
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
    applyDeadband(command)

  if command == 0 then
    return position
  end

  position =
    position +
    command *
    dt /
    fullTime

  return clamp(
    position,
    -1,
    1
  )

end


-- ============================================================
-- TRACK ANIMATION
-- ============================================================

local function updateTrackAnimation(
  leftTrack,
  rightTrack,
  dt
)

  trackPhaseL =
    trackPhaseL +
    leftTrack *
    TRACK_ANIM_SPEED *
    dt

  trackPhaseR =
    trackPhaseR +
    rightTrack *
    TRACK_ANIM_SPEED *
    dt


  while trackPhaseL >= 14 do
    trackPhaseL = trackPhaseL - 14
  end

  while trackPhaseL < 0 do
    trackPhaseL = trackPhaseL + 14
  end

  while trackPhaseR >= 14 do
    trackPhaseR = trackPhaseR - 14
  end

  while trackPhaseR < 0 do
    trackPhaseR = trackPhaseR + 14
  end

end


-- ============================================================
-- HOME RESET
-- ============================================================

local function updateHomeState(
  bladeTransition,
  tillerTransition
)

  local sh =
    (getValue("sh") or 0) > 500

  local homePressed =
    sh and not lastSh

  lastSh =
    sh


  local ls =
    getValue("ls") or 0

  local rs =
    getValue("rs") or 0


  local wingsCentered =
    math.abs(ls) <= HOME_SLIDER_DEADBAND
    and
    math.abs(rs) <= HOME_SLIDER_DEADBAND


  local anyTransition =
    bladeTransition
    or tillerTransition


  if homePressed
    and not anyTransition
  then

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
    and wingsCentered
  then

    homeArmed =
      false

    homeActive =
      true

  end

end


-- ============================================================
-- HEADER
-- ============================================================

local function drawHeader(
  x,
  y
)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x,
    y,
    "Pisten Bully 600",
    MIDSIZE
  )


  -- Right stick mode.
  local sc =
    getValue("sc") or 0

  local stickMode =
    "BLADE SLEW/ANGLE"

  if sc < -500 then

    stickMode =
      "BLADE LIFT/TILT"

  elseif sc > 500 then

    stickMode =
      "TILLER LIFT/ANGLE"

  end

  lcd.drawText(
    x + 260,
    y + 10,
    "STICK MODE: " ..
      stickMode,
    SMLSIZE
  )


  -- SB mode.
  local sb =
    getValue("sb") or 0

  if sb < -500 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )

    lcd.drawText(
      x + 570,
      y + 10,
      "MANUAL",
      SMLSIZE
    )

  elseif sb < 500 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_GRID
    )

    lcd.drawText(
      x + 570,
      y + 10,
      "SWING ONLY",
      SMLSIZE
    )

  else

    lcd.setColor(
      CUSTOM_COLOR,
      COL_GRID
    )

    lcd.drawText(
      x + 570,
      y + 10,
      "COORDINATED",
      SMLSIZE
    )

  end


  -- Machine mode.
  local sd =
    getValue("sd") or 0

  local label =
    "PLOW"

  if sd < -500 then

    label =
      "TRANSPORT"

  elseif sd > 500 then

    label =
      "GROOM"

  end


  local bladeTransition =
    getLogicalSwitchValue(10)

  local tillerTransition =
    getLogicalSwitchValue(11)


  local flags =
    SMLSIZE

  if bladeTransition
    or tillerTransition
  then

    flags =
      SMLSIZE +
      INVERS

  end


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x + 695,
    y + 10,
    label,
    flags
  )


  -- HOME.
  if homeActive then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )

    lcd.drawText(
      x + 640,
      390,
      "HOME",
      SMLSIZE +
      INVERS +
      COL_WARN
    )

  end


  -- E-stop.
  local sf =
    getValue("sf") or 0

  if sf > 0 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ALERT
    )

    lcd.drawText(
      x + 700,
      y + 28,
      "E-STOP",
      SMLSIZE +
      INVERS +
      BLINK
    )

  end

end


-- ============================================================
-- VIEW TITLE
-- ============================================================

local function drawViewTitle(
  x,
  y,
  text
)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x,
    y,
    text,
    SMLSIZE
  )

end


-- ============================================================
-- TOP VIEW TRACK
-- ============================================================

local function drawTopTrack(
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

  drawTopTrack(
    cx - 74,
    cy - 49,
    148,
    25,
    trackPhaseL
  )

  drawTopTrack(
    cx - 74,
    cy + 24,
    148,
    25,
    trackPhaseR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED_DARK
  )

  lcd.drawFilledRectangle(
    cx - 61,
    cy - 21,
    122,
    42,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawFilledRectangle(
    cx - 3,
    cy - 17,
    53,
    34,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  lcd.drawFilledRectangle(
    cx - 50,
    cy - 17,
    39,
    34,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_GLASS
  )

  lcd.drawFilledRectangle(
    cx - 44,
    cy - 11,
    25,
    22,
    CUSTOM_COLOR
  )

end


-- ============================================================
-- TOP VIEW BLADE
-- ============================================================

local function drawTopBlade(
  cx,
  cy
)

  local bladeCenterX =
    cx -
    124 +
    bladeSlewPos *
    MAX_BLADE_SLEW_PIXELS


  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawLine(
    cx - 61,
    cy - 11,
    bladeCenterX + 17,
    cy - 29,
    SOLID,
    FORCE
  )

  lcd.drawLine(
    cx - 61,
    cy + 11,
    bladeCenterX + 17,
    cy + 29,
    SOLID,
    FORCE
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_YELLOW
  )

  lcd.drawFilledRectangle(
    bladeCenterX - 8,
    cy - 61,
    16,
    122,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawRectangle(
    bladeCenterX - 8,
    cy - 61,
    16,
    122,
    CUSTOM_COLOR
  )

end


-- ============================================================
-- TOP VIEW TILLER
-- ============================================================

local function drawTopTiller(
  cx,
  cy
)

  local hitchX =
    cx + 61

  local hitchY =
    cy

  local tillerX =
    cx + 145

  local tillerY =
    cy


  local swingAngle =
    tillerSwingPos *
    math.rad(
      MAX_TILLER_SWING_DEG
    )


  drawRotatedLine(
    hitchX,
    hitchY,
    tillerX - 53,
    tillerY,
    hitchX,
    hitchY,
    swingAngle,
    COL_METAL,
    3
  )


  for i = -17, 17 do

    drawRotatedLine(
      tillerX - 53,
      tillerY + i,
      tillerX + 53,
      tillerY + i,
      hitchX,
      hitchY,
      swingAngle,
      COL_RED,
      1
    )

  end


  for i = -7, 7 do

    drawRotatedLine(
      tillerX - 42,
      tillerY + i,
      tillerX + 42,
      tillerY + i,
      hitchX,
      hitchY,
      swingAngle,
      COL_TRACK_BAR,
      1
    )

  end


  drawRotatedLine(
    tillerX - 54,
    tillerY - 18,
    tillerX + 54,
    tillerY - 18,
    hitchX,
    hitchY,
    swingAngle,
    COL_TEXT,
    1
  )


  drawRotatedLine(
    tillerX - 54,
    tillerY + 18,
    tillerX + 54,
    tillerY + 18,
    hitchX,
    hitchY,
    swingAngle,
    COL_TEXT,
    1
  )

end


-- ============================================================
-- TOP VIEW
-- ============================================================

local function drawTopView(
  x,
  y
)

  drawViewTitle(
    x + 8,
    y,
    "TOP VIEW"
  )


  local cx =
    x + 194

  local cy =
    y + 157


  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )

  lcd.drawLine(
    x + 18,
    cy,
    x + 378,
    cy,
    DOTTED,
    FORCE
  )


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


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x + 15,
    y + 295,
    string.format(
      "Blade Slew %4.0f%%",
      bladeSlewPos * 100
    ),
    SMLSIZE
  )

  lcd.drawText(
    x + 205,
    y + 295,
    string.format(
      "Tiller Swing %4.0f%%",
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

  -- Main track.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK
  )

  lcd.drawFilledRectangle(
    cx - 72,
    cy + 18,
    145,
    30,
    CUSTOM_COLOR
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK_BAR
  )

  lcd.drawRectangle(
    cx - 72,
    cy + 18,
    145,
    30,
    CUSTOM_COLOR
  )


  -- Road wheels.
  for wx = -55, 50, 35 do

    lcd.drawCircle(
      cx + wx,
      cy + 33,
      10
    )

  end


  -- Chassis.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED_DARK
  )

  lcd.drawFilledRectangle(
    cx - 67,
    cy - 15,
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
    cx - 5,
    cy - 34,
    63,
    20,
    CUSTOM_COLOR
  )


  -- Cab.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  lcd.drawFilledRectangle(
    cx - 54,
    cy - 69,
    46,
    54,
    CUSTOM_COLOR
  )


  -- Roof.
  lcd.drawFilledRectangle(
    cx - 58,
    cy - 75,
    55,
    7,
    CUSTOM_COLOR
  )


  -- Glass.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_GLASS
  )

  lcd.drawFilledRectangle(
    cx - 47,
    cy - 59,
    29,
    27,
    CUSTOM_COLOR
  )

end


-- ============================================================
-- SIDE VIEW BLADE
--
-- Visual rules:
--
--  bladeAnglePos = 0
--      => blade vertical
--
--  bladeLiftPos = 1
--      => bottom of blade aligned to bottom of tracks
-- ============================================================

local function drawSideBlade(
  cx,
  cy
)

  local hitchX =
    cx - 64

  local hitchY =
    cy - 2

  local bladeX =
    cx - 131


  -- Track ends at cy + 48:
  --
  -- track begins at cy + 18
  -- track height = 30
  local trackBottomY =
    cy + 48


  -- Blade is roughly 68px tall.
  local bladeHalfHeight =
    34


  -- Preserve current UP height.
  local bladeUpCenterY =
    cy - 56


  -- Fully down places blade bottom exactly at track bottom.
  local bladeDownCenterY =
    trackBottomY -
    bladeHalfHeight


  local bladeY =
    bladeUpCenterY +
    bladeLiftPos *
    (
      bladeDownCenterY -
      bladeUpCenterY
    )


  -- Zero is vertical.
  -- Visual direction remains reversed relative to position model.
  local bladeAngle =
    -bladeAnglePos *
    math.rad(
      MAX_BLADE_ANGLE_DEG
    )


  -- Lift / push linkage.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawLine(
    hitchX,
    hitchY - 8,
    bladeX + 27,
    bladeY - 5,
    SOLID,
    FORCE
  )

  lcd.drawLine(
    hitchX,
    hitchY + 7,
    bladeX + 27,
    bladeY + 5,
    SOLID,
    FORCE
  )


  -- Blade body.
  for i = -6, 6 do

    drawRotatedLine(
      bladeX - 7,
      bladeY - 32 + i,
      bladeX + 7,
      bladeY + 32 + i,
      bladeX,
      bladeY,
      bladeAngle,
      COL_YELLOW,
      1
    )

  end


  -- Cutting edge.
  drawRotatedLine(
    bladeX - 8,
    bladeY - 34,
    bladeX + 8,
    bladeY + 34,
    bladeX,
    bladeY,
    bladeAngle,
    COL_TEXT,
    2
  )

end


-- ============================================================
-- SIDE VIEW TILLER
--
-- Visual rules:
--
--  tillerLiftPos = 1
--      => tiller bottom near track bottom
--
--  tillerAnglePos == GV5 Groom angle
--      => visually horizontal
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
    cx + 139


  local trackBottomY =
    cy + 48


  local tillerHalfHeight =
    10


  -- Preserve current raised height.
  local tillerUpCenterY =
    cy - 44


  -- Groom/down position is visually level with track bottom.
  local tillerDownCenterY =
    trackBottomY -
    tillerHalfHeight


  local tillerY =
    tillerUpCenterY +
    tillerLiftPos *
    (
      tillerDownCenterY -
      tillerUpCenterY
    )


  -- ----------------------------------------------------------
  -- GROOM ANGLE AS VISUAL ZERO
  --
  -- GV5 is the tiller working-angle target used by tiller.lua.
  --
  -- When tillerAnglePos reaches this configured Groom angle,
  -- visualTillerAngle becomes zero and the tiller draws flat.
  -- ----------------------------------------------------------

  local groomAngle =
    clamp(
      (getValue("gvar5") or 0) /
      100,
      0,
      1
    )


  local visualTillerAngle =
    tillerAnglePos -
    groomAngle


  local tillerAngle =
    -visualTillerAngle *
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
    hitchY - 7,
    tillerX - 31,
    tillerY - 6,
    SOLID,
    FORCE
  )

  lcd.drawLine(
    hitchX,
    hitchY + 5,
    tillerX - 31,
    tillerY + 6,
    SOLID,
    FORCE
  )


  -- Short tiller housing.
  for i = -9, 9 do

    drawRotatedLine(
      tillerX - 31,
      tillerY + i,
      tillerX + 31,
      tillerY + i,
      tillerX,
      tillerY,
      tillerAngle,
      COL_RED,
      1
    )

  end


  -- Roller.
  for i = -4, 4 do

    drawRotatedLine(
      tillerX - 24,
      tillerY + i,
      tillerX + 24,
      tillerY + i,
      tillerX,
      tillerY,
      tillerAngle,
      COL_TRACK_BAR,
      1
    )

  end


  -- Housing outline.
  drawRotatedLine(
    tillerX - 32,
    tillerY - 10,
    tillerX + 32,
    tillerY - 10,
    tillerX,
    tillerY,
    tillerAngle,
    COL_TEXT,
    1
  )

  drawRotatedLine(
    tillerX - 32,
    tillerY + 10,
    tillerX + 32,
    tillerY + 10,
    tillerX,
    tillerY,
    tillerAngle,
    COL_TEXT,
    1
  )


  -- Rear comb.
  drawRotatedLine(
    tillerX + 31,
    tillerY + 7,
    tillerX + 60,
    tillerY + 13,
    tillerX,
    tillerY,
    tillerAngle,
    COL_TEXT,
    2
  )


  -- Comb teeth.
  for i = 0, 4 do

    local toothX =
      tillerX +
      38 +
      i * 5

    drawRotatedLine(
      toothX,
      tillerY + 10,
      toothX + 3,
      tillerY + 18,
      tillerX,
      tillerY,
      tillerAngle,
      COL_TEXT,
      1
    )

  end

end


-- ============================================================
-- SIDE VIEW
-- ============================================================

local function drawSideView(
  x,
  y
)

  drawViewTitle(
    x + 8,
    y,
    "SIDE VIEW"
  )


  local cx =
    x + 194

  local cy =
    y + 157


  -- Ground / bottom-of-track reference.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )

  lcd.drawLine(
    x + 12,
    cy + 48,
    x + 379,
    cy + 48,
    DOTTED,
    FORCE
  )


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


  -- Side view values.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x + 10,
    y + 278,
    string.format(
      "Blade Lift %3.0f%%",
      bladeLiftPos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    x + 10,
    y + 298,
    string.format(
      "Blade Angle %4.0f%%",
      bladeAnglePos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    x + 203,
    y + 278,
    string.format(
      "Tiller Lift %3.0f%%",
      tillerLiftPos * 100
    ),
    SMLSIZE
  )


  lcd.drawText(
    x + 203,
    y + 298,
    string.format(
      "Tiller Angle %4.0f%%",
      tillerAnglePos * 100
    ),
    SMLSIZE
  )

end


-- ============================================================
-- REFRESH
-- ============================================================

local function refresh(
  wgt,
  event,
  touchState
)

  local z =
    wgt.zone


  if z.w < 800
    or z.h < 400
  then

    lcd.drawText(
      z.x + 2,
      z.y + z.h - 14,
      "Need at least 800x400",
      SMLSIZE +
      lcd.RGB(
        255,
        255,
        255
      )
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
  -- INPUT / OUTPUT SOURCES
  -- ==========================================================

  local leftTrack =
    norm(
      getValue("ch3") or 0
    )

  local rightTrack =
    -norm(
      getValue("ch1") or 0
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


  -- CH9 is positional.
  tillerSwingPos =
    norm(
      getValue("ch9") or 0
    )


  -- ==========================================================
  -- TRANSITION STATE
  -- ==========================================================

  local bladeTransition =
    getLogicalSwitchValue(10)

  local tillerTransition =
    getLogicalSwitchValue(11)


  -- ==========================================================
  -- PERSISTENT ACTUATOR POSITIONS
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
  -- HOME STATE / VISUAL RE-HOME
  -- ==========================================================

  updateHomeState(
    bladeTransition,
    tillerTransition
  )


  if homeActive then

    local anyMovement =
      math.abs(bladeLiftCmd)
        > OUTPUT_DEADBAND
      or
      math.abs(bladeAngleCmd)
        > OUTPUT_DEADBAND
      or
      math.abs(bladeSlewCmd)
        > OUTPUT_DEADBAND
      or
      math.abs(tillerLiftCmd)
        > OUTPUT_DEADBAND
      or
      math.abs(tillerAngleCmd)
        > OUTPUT_DEADBAND


    if anyMovement then
      homeActive = false
    end

  end


  -- ==========================================================
  -- DRAW
  -- ==========================================================

  lcd.clear(
    COL_BACKGROUND
  )


  drawHeader(
    0,
    5
  )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )


  lcd.drawLine(
    0,
    50,
    800,
    50,
    SOLID,
    FORCE
  )


  lcd.drawLine(
    400,
    50,
    400,
    380,
    SOLID,
    FORCE
  )


  lcd.drawLine(
    0,
    380,
    800,
    380,
    SOLID,
    FORCE
  )


  drawTopView(
    0,
    63
  )


  drawSideView(
    400,
    63
  )


  -- ==========================================================
  -- BOTTOM TRANSITION STATUS
  -- ==========================================================

  if bladeTransition
    and tillerTransition
  then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_FWD
    )

    lcd.drawText(
      300,
      385,
      "BLADE + TILLER TRANSITION",
      SMLSIZE +
      INVERS
    )


  elseif bladeTransition then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_FWD
    )

    lcd.drawText(
      330,
      385,
      "BLADE TRANSITION",
      SMLSIZE +
      INVERS
    )


  elseif tillerTransition then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_FWD
    )

    lcd.drawText(
      330,
      385,
      "TILLER TRANSITION",
      SMLSIZE +
      INVERS
    )

  end

end


-- ============================================================
-- EXPORT
-- ============================================================

return {
  name = name,
  options = options,
  create = create,
  update = update,
  refresh = refresh,
  background = background
}