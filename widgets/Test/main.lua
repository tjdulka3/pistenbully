-- ============================================================
-- PB600 OPERATOR DASHBOARD
--
-- TOP VIEW
--   * Animated tracks
--   * Blade slew
--   * Tiller swing
--   * Yellow finishers above/below tiller body
--
-- SIDE VIEW
--   * Blade lift
--   * Blade angle
--   * Tiller lift
--   * Tiller angle
--   * Tiller motor indicator
--   * Yellow rear comb
--
-- TILLER MOTOR:
--
--   CH14 == -1024  -> RED
--   CH14 >  -1024  -> GREEN
--
-- FINISHERS:
--
--   Fixed-size short yellow rectangles.
--
--   UP:
--     tucked close to tiller body
--
--   DOWN:
--     moved outward from tiller body
--
-- SH:
--   Resets visual actuator positions to zero/home.
--
-- Designed for RadioMaster TX16S MK3
-- Full screen: 800 x 400
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


local function update(wgt, options)

  wgt.options = options

end


local function background(wgt)

end


-- ============================================================
-- COLOR PALETTE
-- ============================================================

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

local COL_FWD =
  lcd.RGB(16, 179, 57)

local COL_RED =
  lcd.RGB(180, 35, 30)

local COL_RED_DARK =
  lcd.RGB(95, 25, 22)

local COL_YELLOW =
  lcd.RGB(225, 185, 25)

local COL_METAL =
  lcd.RGB(125, 130, 135)

local COL_TRACK =
  COL_METAL

local COL_TRACK_BAR =
  lcd.RGB(70, 70, 75)

local COL_GLASS =
  lcd.RGB(30, 75, 100)

local COL_BACKGROUND =
  lcd.RGB(44, 143, 176)


-- ============================================================
-- ACTUATOR TIMING
-- ============================================================

local BLADE_LIFT_DOWN_FULL = 11.0
local BLADE_LIFT_UP_FULL   = 17.0
local BLADE_ANGLE_FULL     = 6.7
local BLADE_SLEW_FULL      = 6.7

local TILLER_LIFT_DOWN_FULL = 11.0
local TILLER_LIFT_UP_FULL   = 17.0
local TILLER_ANGLE_FULL     = 3.75

local FIN_FULL_TIME = 2.0


-- ============================================================
-- VISUAL CALIBRATION
-- ============================================================

local OUTPUT_DEADBAND = 0.025


-- TOP VIEW

local MAX_BLADE_SLEW_PIXELS = 34
local MAX_TILLER_SWING_DEG  = 32

local TILLER_TOP_W = 18
local TILLER_TOP_H = 108


-- Finishers.
local FINISHER_W = 26
local FINISHER_H = 7

local FINISHER_UP_GAP = 3
local FINISHER_DOWN_GAP = 20


-- SIDE VIEW

local MAX_BLADE_ANGLE_DEG = 30
local MAX_TILLER_ANGLE_DEG = 26

local TILLER_MOTOR_R = 7

local TRACK_ANIM_SPEED = 55


-- ============================================================
-- HOME STATE
-- ============================================================

local homeActive = false
local homeArmed = false
local lastSh = false

local HOME_SLIDER_DEADBAND = 100


-- ============================================================
-- PERSISTENT VISUAL STATE
-- ============================================================

local bladeSlewPos = 0
local tillerSwingPos = 0

local trackPhaseL = 0
local trackPhaseR = 0

local finLPos = 0
local finRPos = 0

local bladeLiftPos = 0
local bladeAnglePos = 0

local tillerLiftPos = 0
local tillerAnglePos = 0

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
-- ROTATION
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
      CUSTOM_COLOR
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


local function integrateFinisher(
  position,
  command,
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
    FIN_FULL_TIME

  return clamp(
    position,
    0,
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
-- HOME
-- ============================================================

local function updateHomeState(
  bladeTransition,
  tillerTransition
)

  local sh =
    (getValue("sh") or 0) > 500

  local homePressed =
    sh
    and not lastSh

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

    bladeLiftPos = 0
    bladeAnglePos = 0
    bladeSlewPos = 0

    tillerLiftPos = 0
    tillerAnglePos = 0

    finLPos = 0
    finRPos = 0

    homeArmed = true
    homeActive = false

  end


  if homeArmed
    and wingsCentered
  then

    homeArmed = false
    homeActive = true

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
    MIDSIZE + CUSTOM_COLOR
  )


  -- RIGHT STICK MODE

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
    SMLSIZE + CUSTOM_COLOR
  )


  -- SB MODE

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
      SMLSIZE + CUSTOM_COLOR
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
      SMLSIZE + CUSTOM_COLOR
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
      SMLSIZE + CUSTOM_COLOR
    )

  end


  -- MACHINE MODE

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


  local bladeTransition =
    getLogicalSwitchValue(10)

  local tillerTransition =
    getLogicalSwitchValue(11)


  local flags =
    SMLSIZE + CUSTOM_COLOR


  if bladeTransition
    or tillerTransition
  then

    flags =
      flags + INVERS

  end


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )


  lcd.drawText(
    x + 695,
    y + 10,
    mode,
    flags
  )


  -- HOME

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
      CUSTOM_COLOR
    )

  end


  -- E-STOP

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
      BLINK +
      CUSTOM_COLOR
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
    SMLSIZE + CUSTOM_COLOR
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
    math.floor(
      phase
    )


  while p < w do

    lcd.drawLine(
      x + p,
      y + 2,
      x + p + 8,
      y + h - 2,
      SOLID,
      CUSTOM_COLOR
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
    CUSTOM_COLOR
  )


  lcd.drawLine(
    cx - 61,
    cy + 11,
    bladeCenterX + 17,
    cy + 29,
    SOLID,
    CUSTOM_COLOR
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


  -- HITCH

  drawRotatedLine(
    hitchX,
    hitchY,
    tillerX -
      TILLER_TOP_W / 2,
    tillerY,
    hitchX,
    hitchY,
    swingAngle,
    COL_METAL,
    3
  )


  -- TILLER BODY

  for xx =
    -TILLER_TOP_W / 2,
    TILLER_TOP_W / 2
  do

    drawRotatedLine(
      tillerX + xx,
      tillerY -
        TILLER_TOP_H / 2,
      tillerX + xx,
      tillerY +
        TILLER_TOP_H / 2,
      hitchX,
      hitchY,
      swingAngle,
      COL_RED,
      1
    )

  end


  drawRotatedLine(
    tillerX -
      TILLER_TOP_W / 2,
    tillerY -
      TILLER_TOP_H / 2,
    tillerX -
      TILLER_TOP_W / 2,
    tillerY +
      TILLER_TOP_H / 2,
    hitchX,
    hitchY,
    swingAngle,
    COL_TEXT,
    1
  )


  drawRotatedLine(
    tillerX +
      TILLER_TOP_W / 2,
    tillerY -
      TILLER_TOP_H / 2,
    tillerX +
      TILLER_TOP_W / 2,
    tillerY +
      TILLER_TOP_H / 2,
    hitchX,
    hitchY,
    swingAngle,
    COL_TEXT,
    1
  )


  drawRotatedLine(
    tillerX -
      TILLER_TOP_W / 2,
    tillerY -
      TILLER_TOP_H / 2,
    tillerX +
      TILLER_TOP_W / 2,
    tillerY -
      TILLER_TOP_H / 2,
    hitchX,
    hitchY,
    swingAngle,
    COL_TEXT,
    1
  )


  drawRotatedLine(
    tillerX -
      TILLER_TOP_W / 2,
    tillerY +
      TILLER_TOP_H / 2,
    tillerX +
      TILLER_TOP_W / 2,
    tillerY +
      TILLER_TOP_H / 2,
    hitchX,
    hitchY,
    swingAngle,
    COL_TEXT,
    1
  )


  -- FINISHER DRAWER

  local function drawTopFinisher(
    centerX,
    centerY
  )

    local left =
      centerX -
      FINISHER_W / 2

    local right =
      centerX +
      FINISHER_W / 2

    local top =
      centerY -
      FINISHER_H / 2

    local bottom =
      centerY +
      FINISHER_H / 2


    -- Yellow fill.
    for yy = top, bottom do

      drawRotatedLine(
        left,
        yy,
        right,
        yy,
        hitchX,
        hitchY,
        swingAngle,
        COL_YELLOW,
        1
      )

    end


    -- Yellow outline too.
    drawRotatedLine(
      left,
      top,
      right,
      top,
      hitchX,
      hitchY,
      swingAngle,
      COL_YELLOW,
      1
    )


    drawRotatedLine(
      left,
      bottom,
      right,
      bottom,
      hitchX,
      hitchY,
      swingAngle,
      COL_YELLOW,
      1
    )


    drawRotatedLine(
      left,
      top,
      left,
      bottom,
      hitchX,
      hitchY,
      swingAngle,
      COL_YELLOW,
      1
    )


    drawRotatedLine(
      right,
      top,
      right,
      bottom,
      hitchX,
      hitchY,
      swingAngle,
      COL_YELLOW,
      1
    )

  end


  -- LEFT FINISHER / ABOVE

  local finLGap =
    FINISHER_UP_GAP +
    (
      FINISHER_DOWN_GAP -
      FINISHER_UP_GAP
    ) *
    finLPos


  local finLY =
    tillerY -
    TILLER_TOP_H / 2 -
    finLGap -
    FINISHER_H / 2


  drawTopFinisher(
    tillerX,
    finLY
  )


  -- RIGHT FINISHER / BELOW

  local finRGap =
    FINISHER_UP_GAP +
    (
      FINISHER_DOWN_GAP -
      FINISHER_UP_GAP
    ) *
    finRPos


  local finRY =
    tillerY +
    TILLER_TOP_H / 2 +
    finRGap +
    FINISHER_H / 2


  drawTopFinisher(
    tillerX,
    finRY
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
    CUSTOM_COLOR
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
    SMLSIZE + CUSTOM_COLOR
  )


  lcd.drawText(
    x + 205,
    y + 295,
    string.format(
      "Tiller Swing %4.0f%%",
      tillerSwingPos * 100
    ),
    SMLSIZE + CUSTOM_COLOR
  )

end


-- ============================================================
-- SIDE VIEW BODY
-- ============================================================

local function drawSideBody(
  cx,
  cy
)

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


  for wx = -55, 50, 35 do

    lcd.drawCircle(
      cx + wx,
      cy + 33,
      10,
      CUSTOM_COLOR
    )

  end


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


  lcd.drawFilledRectangle(
    cx - 58,
    cy - 75,
    55,
    7,
    CUSTOM_COLOR
  )


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
-- ============================================================

local function drawSideBlade(
  cx,
  cy
)

  local bladeDepth =
    clamp(
      (getValue("gvar2") or 0) /
      100,
      0.01,
      1
    )


  local visualLift =
    clamp(
      bladeLiftPos /
      bladeDepth,
      0,
      1
    )


  local bladeX =
    cx - 132


  local trackBottomY =
    cy + 48


  local bladeHalfHeight =
    35


  local bladeUpCenterY =
    cy - 48


  local bladeDownCenterY =
    trackBottomY -
    bladeHalfHeight


  local bladeY =
    bladeUpCenterY +
    visualLift *
    (
      bladeDownCenterY -
      bladeUpCenterY
    )


  local bladeAngle =
    -bladeAnglePos *
    math.rad(
      MAX_BLADE_ANGLE_DEG
    )


  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )


  lcd.drawLine(
    cx - 64,
    cy - 9,
    bladeX + 12,
    bladeY - 10,
    SOLID,
    CUSTOM_COLOR
  )


  lcd.drawLine(
    cx - 64,
    cy + 8,
    bladeX + 12,
    bladeY + 10,
    SOLID,
    CUSTOM_COLOR
  )


  for i = -7, 7 do

    drawRotatedLine(
      bladeX + i,
      bladeY - bladeHalfHeight,
      bladeX + i,
      bladeY + bladeHalfHeight,
      bladeX,
      bladeY,
      bladeAngle,
      COL_YELLOW,
      1
    )

  end


  drawRotatedLine(
    bladeX - 8,
    bladeY - bladeHalfHeight,
    bladeX - 8,
    bladeY + bladeHalfHeight,
    bladeX,
    bladeY,
    bladeAngle,
    COL_TEXT,
    2
  )


  drawRotatedLine(
    bladeX + 8,
    bladeY - bladeHalfHeight,
    bladeX + 8,
    bladeY + bladeHalfHeight,
    bladeX,
    bladeY,
    bladeAngle,
    COL_TEXT,
    1
  )


  drawRotatedLine(
    bladeX - 8,
    bladeY - bladeHalfHeight,
    bladeX + 8,
    bladeY - bladeHalfHeight,
    bladeX,
    bladeY,
    bladeAngle,
    COL_TEXT,
    1
  )


  drawRotatedLine(
    bladeX - 8,
    bladeY + bladeHalfHeight,
    bladeX + 8,
    bladeY + bladeHalfHeight,
    bladeX,
    bladeY,
    bladeAngle,
    COL_TEXT,
    2
  )

end


-- ============================================================
-- SIDE VIEW TILLER
-- ============================================================

local function drawSideTiller(
  cx,
  cy
)

  local groomDepth =
    clamp(
      (getValue("gvar3") or 0) /
      100,
      0.01,
      1
    )


  local groomAngle =
    clamp(
      (getValue("gvar5") or 0) /
      100,
      0,
      1
    )


  local visualLift =
    clamp(
      tillerLiftPos /
      groomDepth,
      0,
      1
    )


  local tillerX =
    cx + 137


  local trackBottomY =
    cy + 48


  local tillerHalfHeight =
    9


  local tillerUpY =
    cy - 42


  local tillerDownY =
    trackBottomY -
    tillerHalfHeight


  local tillerY =
    tillerUpY +
    visualLift *
    (
      tillerDownY -
      tillerUpY
    )


  local expectedAngle =
    groomAngle *
    visualLift


  local angleDeviation =
    tillerAnglePos -
    expectedAngle


  local tillerAngle =
    -angleDeviation *
    math.rad(
      MAX_TILLER_ANGLE_DEG
    )


  -- LINKAGE

  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )


  lcd.drawLine(
    cx + 64,
    cy - 7,
    tillerX - 31,
    tillerY - 5,
    SOLID,
    CUSTOM_COLOR
  )


  lcd.drawLine(
    cx + 64,
    cy + 5,
    tillerX - 31,
    tillerY + 5,
    SOLID,
    CUSTOM_COLOR
  )


  -- HOUSING

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


  -- TILLER MOTOR INDICATOR

  local tillerMotor =
    getValue("ch14") or -1024


  local motorActive =
    tillerMotor > -1024


  local motorColor =
    COL_ALERT


  if motorActive then
    motorColor = COL_FWD
  end


  local motorLocalX =
    tillerX - 18


  local motorLocalY =
    tillerY


  local motorX, motorY =
    rotatePoint(
      motorLocalX,
      motorLocalY,
      tillerX,
      tillerY,
      tillerAngle
    )


  lcd.setColor(
    CUSTOM_COLOR,
    motorColor
  )


  lcd.drawFilledCircle(
    motorX,
    motorY,
    TILLER_MOTOR_R,
    CUSTOM_COLOR
  )


  -- YELLOW REAR COMB

  drawRotatedLine(
    tillerX + 31,
    tillerY + 7,
    tillerX + 62,
    tillerY + 12,
    tillerX,
    tillerY,
    tillerAngle,
    COL_YELLOW,
    2
  )


  for i = 0, 5 do

    local tx =
      tillerX +
      37 +
      i * 5


    drawRotatedLine(
      tx,
      tillerY + 10,
      tx + 2,
      tillerY + 18,
      tillerX,
      tillerY,
      tillerAngle,
      COL_YELLOW,
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
    CUSTOM_COLOR
  )


  drawSideBlade(
    cx,
    cy
  )


  drawSideTiller(
    cx,
    cy
  )


  drawSideBody(
    cx,
    cy
  )


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
    SMLSIZE + CUSTOM_COLOR
  )


  lcd.drawText(
    x + 10,
    y + 298,
    string.format(
      "Blade Angle %4.0f%%",
      bladeAnglePos * 100
    ),
    SMLSIZE + CUSTOM_COLOR
  )


  lcd.drawText(
    x + 203,
    y + 278,
    string.format(
      "Tiller Lift %3.0f%%",
      tillerLiftPos * 100
    ),
    SMLSIZE + CUSTOM_COLOR
  )


  lcd.drawText(
    x + 203,
    y + 298,
    string.format(
      "Tiller Angle %4.0f%%",
      tillerAnglePos * 100
    ),
    SMLSIZE + CUSTOM_COLOR
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

    lcd.setColor(
      CUSTOM_COLOR,
      COL_TEXT
    )

    lcd.drawText(
      z.x + 2,
      z.y + z.h - 14,
      "Need at least 800x400",
      SMLSIZE + CUSTOM_COLOR
    )

    return

  end


  -- TIME

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


  -- SOURCES

  local leftTrack =
    norm(
      getValue("ch3") or 0
    )


  local rightTrack =
    -norm(
      getValue("ch1") or 0
    )


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


  local finLCmd =
    norm(
      getValue("ch7") or 0
    )


  local finRCmd =
    norm(
      getValue("ch8") or 0
    )


  -- TRANSITIONS

  local bladeTransition =
    getLogicalSwitchValue(10)


  local tillerTransition =
    getLogicalSwitchValue(11)


  -- POSITION INTEGRATION

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


  finLPos =
    integrateFinisher(
      finLPos,
      finLCmd,
      dt
    )


  finRPos =
    integrateFinisher(
      finRPos,
      finRCmd,
      dt
    )


  updateTrackAnimation(
    leftTrack,
    rightTrack,
    dt
  )


  updateHomeState(
    bladeTransition,
    tillerTransition
  )


  if homeActive then

    local movement =
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
      or
      math.abs(finLCmd)
        > OUTPUT_DEADBAND
      or
      math.abs(finRCmd)
        > OUTPUT_DEADBAND


    if movement then
      homeActive = false
    end

  end


  -- DRAW

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
    CUSTOM_COLOR
  )


  lcd.drawLine(
    400,
    50,
    400,
    380,
    SOLID,
    CUSTOM_COLOR
  )


  lcd.drawLine(
    0,
    380,
    800,
    380,
    SOLID,
    CUSTOM_COLOR
  )


  drawTopView(
    0,
    63
  )


  drawSideView(
    400,
    63
  )


  -- TRANSITION STATUS

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
      INVERS +
      CUSTOM_COLOR
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
      INVERS +
      CUSTOM_COLOR
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
      INVERS +
      CUSTOM_COLOR
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