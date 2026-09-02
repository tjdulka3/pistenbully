-- PB600 OPERATOR DASHBOARD
--
-- TOP VIEW
--   * Animated PistenBully-style tracks
--   * Vertical alternating 100% / 80% grousers
--   * 80% grousers anchored at cat side
--   * Black blade with angular slew
--   * Animated blade wings
--   * Reversed tiller swing
--   * Yellow finishers
--   * Yellow tiller comb
--
-- SIDE VIEW
--   * PB600-like body proportions
--   * Large rounded gray track body
--   * Six large evenly-spaced black road wheels
--   * Thin black chassis
--   * Sloped cab nose / windshield
--   * Blade lift + subtle angle
--   * Tiller lift + angle
--   * Tiller motor indicator
--   * 25%-larger tachometer and speedometer above side view
--
-- WINGS
--
--   Left  = CH5
--   Right = CH6
--
--   Visual range:
--
--      UP       = 45 degrees forward
--      STRAIGHT = 0 degrees
--      FULL     = 15 degrees rearward
--

local name = "PB600OP"
local options = {}

-- WIDGET LIFECYCLE

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

-- COLORS

local COL_GRID =
  lcd.RGB(70, 70, 75)

local COL_TEXT =
  lcd.RGB(200, 200, 200)

local COL_ACTIVE =
  lcd.RGB(0, 160, 120)

local COL_ALERT =
  lcd.RGB(200, 40, 40)

local COL_FWD =
  lcd.RGB(16, 179, 57)

local COL_RED =
  lcd.RGB(180, 35, 30)

local COL_YELLOW =
  lcd.RGB(225, 185, 25)

local COL_WHITE =
  lcd.RGB(255, 255, 255)

local COL_AMBER =
  lcd.RGB(255, 165, 0)

local COL_BLACK =
  lcd.RGB(0, 0, 0)

local COL_METAL =
  lcd.RGB(125, 130, 135)

local COL_TRACK =
  lcd.RGB(70, 70, 75)

local COL_TRACK_BAR =
  COL_METAL

local COL_GLASS =
  lcd.RGB(30, 75, 100)

local COL_BACKGROUND =
  lcd.RGB(44, 143, 176)

-- ACTUATOR TIMING

local BLADE_LIFT_DOWN_FULL = 11.0
local BLADE_LIFT_UP_FULL   = 17.0
local BLADE_ANGLE_FULL     = 6.7
local BLADE_SLEW_FULL      = 6.7

local TILLER_LIFT_DOWN_FULL = 11.0
local TILLER_LIFT_UP_FULL   = 17.0
local TILLER_ANGLE_FULL     = 3.75

local FIN_FULL_TIME =
  2.0

local WING_FULL_TIME =
  4.0

-- VISUAL CALIBRATION

local OUTPUT_DEADBAND =
  0.025

local LINKAGE_WIDTH =
  4

-- TOP VIEW

local MAX_BLADE_SLEW_DEG =
  28

local MAX_TILLER_SWING_DEG =
  32

local TILLER_TOP_W =
  18

local TILLER_TOP_H =
  108

-- TOP-VIEW TRACKS

-- Original track width was 25 pixels.
-- 38 pixels is approximately 50% wider.
local TOP_TRACK_W =
  38

local TOP_TRACK_LENGTH =
  148

local TOP_TRACK_GROUSER_SPACING =
  8

local TOP_TRACK_SHORT_GROUSER =
  0.80

-- TOP-VIEW TILLER COMB

local TILLER_COMB_W =
  14

local TILLER_COMB_H =
  108

local TILLER_COMB_GAP =
  3

local TILLER_COMB_LINE_SPACING =
  9

-- WINGS
--
-- wingPos = 0:
--      45 degrees forward
--
-- wingPos = 1:
--      15 degrees rearward
--
-- Straight is approximately 75% of travel.

local WING_LENGTH =
  30

local WING_WIDTH =
  8

-- Wings are drawn heavier when the blade is in PLOW mode so
-- the straight/open blade reads as one substantial cutting edge.
local WING_WIDTH_PLOW =
  8

local WING_UP_ANGLE_DEG =
  45

local WING_DOWN_ANGLE_DEG =
  -15

local WING_STRAIGHT_POS =
  WING_UP_ANGLE_DEG /
  (WING_UP_ANGLE_DEG - WING_DOWN_ANGLE_DEG)

-- FINISHERS

local FINISHER_W =
  28

local FINISHER_UP_H =
  5

local FINISHER_DOWN_H =
  22

local FINISHER_GAP =
  1

-- SIDE VIEW

local MAX_BLADE_ANGLE_DEG =
  8

local MAX_TILLER_ANGLE_DEG =
  26

local TILLER_MOTOR_R =
  7

local TRACK_ANIM_SPEED =
  55

local SIDE_TRACK_H =
  38

local SIDE_TRACK_RADIUS =
  19

local SIDE_TRACK_HALF_LENGTH =
  76

-- Reduced so the background-colored track interior is
-- visibly exposed between adjacent road wheels.
local SIDE_ROAD_WHEEL_R =
  14

local SIDE_ROAD_WHEEL_COUNT =
  6

local SIDE_ROAD_WHEEL_MARGIN =
  8

local SIDE_CHASSIS_H =
  14

-- ANALOG GAUGES

local TACH_GAUGE_MAX_RPM =
  2200

local SPEED_GAUGE_MAX_KMH =
  25

local PB600_MAX_SPEED_KMH =
  23

-- 50% larger than the original 38 px radius.
-- 25% larger than the previous 57 px radius.
local GAUGE_RADIUS =
  71

local GAUGE_START_DEG =
  225

local GAUGE_SWEEP_DEG =
  270

-- VIEW LAYOUT
--
-- Move both snowcat drawings lower to reserve room for three
-- telemetry rows above them.

local TOP_VIEW_CAT_Y_OFFSET =
  185

-- Side-view cat moved farther down so the larger gauges
-- sit cleanly above it without overlapping the cab.
local SIDE_VIEW_CAT_Y_OFFSET =
  225

-- Gauges now live above the SIDE VIEW snowcat.
-- The pair is centered in the 400 px right-hand view.
-- Place the 142 px diameter gauges as high as possible
-- within the side-view content area without clipping.
local SIDE_GAUGE_CENTER_Y_OFFSET =
  72

-- Upper-right aligned within the 400 px SIDE VIEW panel.
-- Gauge diameter is 142 px. Centers at 169 and 321 leave
-- about 8 px between the right gauge and panel edge.
local SIDE_GAUGE_PAIR_CENTER_X_OFFSET =
  245

local SIDE_GAUGE_SPACING =
  152

-- TOP-VIEW LIGHT TELEMETRY
--
-- CH17 = Headlights
-- CH18 = Warning lights
-- CH19 = Spotlights

-- Stacked light telemetry in the upper-right corner
-- of the TOP VIEW panel.
local LIGHT_INDICATOR_RADIUS =
  8

local LIGHT_LIST_LABEL_X_OFFSET =
  292

local LIGHT_LIST_INDICATOR_X_OFFSET =
  382

local LIGHT_LIST_FIRST_Y_OFFSET =
  18

local LIGHT_LIST_ROW_SPACING =
  24

local LIGHT_ON_THRESHOLD =
  0

-- HOME STATE

local homeActive =
  false

local homeArmed =
  false

local lastSh =
  false

local HOME_SLIDER_DEADBAND =
  100

-- PERSISTENT VISUAL STATE

local bladeSlewPos =
  0

local leftWingPos =
  0

local rightWingPos =
  0

local lastWingMode =
  nil

local wingModeMoving =
  false

local wingModeTarget =
  0

local tillerSwingPos =
  0

local trackPhaseL =
  0

local trackPhaseR =
  0

local finLPos =
  0

local finRPos =
  0

local bladeLiftPos =
  0

local bladeAnglePos =
  0

local tillerLiftPos =
  0

local tillerAnglePos =
  0

local lastTime =
  getTime()

-- HELPERS

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

-- ROTATION

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
  x1, y1, x2, y2,
  cx, cy, angle,
  color, width
)
  local rx1, ry1 = rotatePoint(x1, y1, cx, cy, angle)
  local rx2, ry2 = rotatePoint(x2, y2, cx, cy, angle)

  lcd.setColor(CUSTOM_COLOR, color)

  width = width or 1

  if width <= 1 then
    lcd.drawLine(rx1, ry1, rx2, ry2, SOLID, CUSTOM_COLOR)
    return
  end

  local dx = rx2 - rx1
  local dy = ry2 - ry1
  local len = math.sqrt(dx * dx + dy * dy)

  if len < 0.001 then
    lcd.drawFilledCircle(rx1, ry1, math.max(1, width / 2), CUSTOM_COLOR)
    return
  end

  local half = width / 2
  local ox = -dy / len * half
  local oy =  dx / len * half

  local ax = rx1 + ox
  local ay = ry1 + oy
  local bx = rx2 + ox
  local by = ry2 + oy
  local cx2 = rx2 - ox
  local cy2 = ry2 - oy
  local dx2 = rx1 - ox
  local dy2 = ry1 - oy

  lcd.drawFilledTriangle(
    ax, ay,
    bx, by,
    cx2, cy2,
    CUSTOM_COLOR
  )

  lcd.drawFilledTriangle(
    ax, ay,
    cx2, cy2,
    dx2, dy2,
    CUSTOM_COLOR
  )
end

-- INTEGRATORS

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

local function integrateWing(
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
    WING_FULL_TIME

  return clamp(
    position,
    0,
    1
  )

end

-- WING MODE ANIMATION

local function getWingMode()

  local sd =
    getValue("sd") or 0

  if sd < -500 then
    return "TRANSPORT"
  end

  if sd > 500 then
    return "GROOM"
  end

  return "PLOW"

end

local function getWingModeTarget(mode)

  if mode == "TRANSPORT" then
    return 0
  end

  return WING_STRAIGHT_POS

end

local function moveWingToward(
  position,
  target,
  dt
)

  local step =
    dt /
    WING_FULL_TIME

  if position < target then

    position =
      position + step

    if position > target then
      position = target
    end

  elseif position > target then

    position =
      position - step

    if position < target then
      position = target
    end

  end

  return clamp(
    position,
    0,
    1
  )

end

-- TRACK ANIMATION

local function updateTrackAnimation(
  leftTrack,
  rightTrack,
  dt
)

  trackPhaseL =
    trackPhaseL -
    leftTrack *
    TRACK_ANIM_SPEED *
    dt

  trackPhaseR =
    trackPhaseR -
    rightTrack *
    TRACK_ANIM_SPEED *
    dt

  while trackPhaseL >= TOP_TRACK_GROUSER_SPACING do
    trackPhaseL =
      trackPhaseL -
      TOP_TRACK_GROUSER_SPACING
  end

  while trackPhaseL < 0 do
    trackPhaseL =
      trackPhaseL +
      TOP_TRACK_GROUSER_SPACING
  end

  while trackPhaseR >= TOP_TRACK_GROUSER_SPACING do
    trackPhaseR =
      trackPhaseR -
      TOP_TRACK_GROUSER_SPACING
  end

  while trackPhaseR < 0 do
    trackPhaseR =
      trackPhaseR +
      TOP_TRACK_GROUSER_SPACING
  end

end

-- HOME

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

    leftWingPos =
      0

    rightWingPos =
      0

    tillerLiftPos =
      0

    tillerAnglePos =
      0

    finLPos =
      0

    finRPos =
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

-- HEADER

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

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x + 695,
    y + 10,
    mode,
    SMLSIZE + CUSTOM_COLOR
  )

end

-- VIEW TITLE

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

-- TOP VIEW TRACK

local function drawTopTrack(
  x,
  y,
  w,
  h,
  phase,
  innerEdgeBottom
)

  -- BLACK TRACK BED

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

  -- TRACK OUTLINE / GROUSER COLOR

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

  -- PISTENBULLY-STYLE GROUSERS
  --
  -- Every other grouser spans:
  --
  --      100% of track width
  --       80% of track width
  --
  -- The short grouser is NOT centered.
  --
  -- It begins at the side of the track nearest the cat
  -- and extends toward the outside.
  --
  -- UPPER TRACK:
  --      cat is below the track
  --      short grouser begins at bottom edge
  --
  -- LOWER TRACK:
  --      cat is above the track
  --      short grouser begins at top edge

  local usableH =
    h - 4

  local p =
    -TOP_TRACK_GROUSER_SPACING +
    math.floor(
      phase
    )

  local barIndex =
    math.floor(
      p /
      TOP_TRACK_GROUSER_SPACING
    )

  while p <
    w + TOP_TRACK_GROUSER_SPACING
  do

    local barX =
      x + p

    if barX >= x + 2
      and
      barX <= x + w - 3
    then

      local barH

      if math.abs(barIndex) % 2 == 0 then

        -- 100% GROUSER

        barH =
          usableH

      else

        -- 80% GROUSER

        barH =
          math.floor(
            usableH *
            TOP_TRACK_SHORT_GROUSER
          )

      end

      local barY

      if barH == usableH then

        -- FULL GROUSER
        --
        -- Runs from outside edge to inside edge.

        barY =
          y + 2

      elseif innerEdgeBottom then

        -- UPPER TRACK
        --
        -- Cat is BELOW the track.
        --
        -- Anchor the 80% grouser at the lower/inside
        -- edge and let it extend upward/outward.

        barY =
          y +
          h -
          2 -
          barH

      else

        -- LOWER TRACK
        --
        -- Cat is ABOVE the track.
        --
        -- Anchor the 80% grouser at the upper/inside
        -- edge and let it extend downward/outward.

        barY =
          y + 2

      end

      -- TWO-PIXEL-THICK GROUSER

      lcd.drawFilledRectangle(
        barX,
        barY,
        2,
        barH,
        CUSTOM_COLOR
      )

    end

    p =
      p +
      TOP_TRACK_GROUSER_SPACING

    barIndex =
      barIndex + 1

  end

end

-- TOP VIEW BODY

local function drawTopBody(
  cx,
  cy
)

  -- UPPER TRACK
  --
  -- 38 px wide versus the original 25 px.
  --
  -- The track center remains approximately where it was,
  -- so the additional width sticks farther outside the cat.
  --
  -- TRUE tells drawTopTrack() that the cat-side edge
  -- is the BOTTOM of this track.

  drawTopTrack(
    cx - 74,
    cy - 56,
    TOP_TRACK_LENGTH,
    TOP_TRACK_W,
    trackPhaseL,
    true
  )

  -- LOWER TRACK
  --
  -- FALSE tells drawTopTrack() that the cat-side edge
  -- is the TOP of this track.

  drawTopTrack(
    cx - 74,
    cy + 18,
    TOP_TRACK_LENGTH,
    TOP_TRACK_W,
    trackPhaseR,
    false
  )

  -- MAIN BODY

  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  lcd.drawFilledRectangle(
    cx - 81,
    cy - 21,
    122,
    42,
    CUSTOM_COLOR
  )

  -- REAR DECK

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

  -- CAB

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

  -- WINDSHIELD

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

-- TOP VIEW BLADE

local function drawTopBlade(
  cx,
  cy
)

  local bladeX =
    cx - 124

  local bladeY =
    cy

  local bladeHalfHeight =
    61

  local bladeHalfWidth =
    8

  local bladeSlewAngle =
    bladeSlewPos *
    math.rad(
      MAX_BLADE_SLEW_DEG
    )

  local attachTopX, attachTopY =
    rotatePoint(
      bladeX + 12,
      bladeY - 29,
      bladeX,
      bladeY,
      bladeSlewAngle
    )

  local attachBottomX, attachBottomY =
    rotatePoint(
      bladeX + 12,
      bladeY + 29,
      bladeX,
      bladeY,
      bladeSlewAngle
    )

  drawRotatedLine(
    cx - 61,
    cy - 11,
    attachTopX,
    attachTopY,
    0,
    0,
    0,
    COL_BLACK,
    LINKAGE_WIDTH
  )

  drawRotatedLine(
    cx - 61,
    cy + 11,
    attachBottomX,
    attachBottomY,
    0,
    0,
    0,
    COL_BLACK,
    LINKAGE_WIDTH
  )

  -- Main blade as one filled rotated bar.
  drawRotatedLine(
    bladeX,
    bladeY - bladeHalfHeight,
    bladeX,
    bladeY + bladeHalfHeight,
    bladeX,
    bladeY,
    bladeSlewAngle,
    COL_BLACK,
    bladeHalfWidth * 2 + 1
  )

  local topTipX, topTipY =
    rotatePoint(
      bladeX,
      bladeY - bladeHalfHeight,
      bladeX,
      bladeY,
      bladeSlewAngle
    )

  local bottomTipX, bottomTipY =
    rotatePoint(
      bladeX,
      bladeY + bladeHalfHeight,
      bladeX,
      bladeY,
      bladeSlewAngle
    )

  local leftRelativeDeg =
    WING_UP_ANGLE_DEG +
    (
      WING_DOWN_ANGLE_DEG -
      WING_UP_ANGLE_DEG
    ) *
    leftWingPos

  local rightRelativeDeg =
    WING_UP_ANGLE_DEG +
    (
      WING_DOWN_ANGLE_DEG -
      WING_UP_ANGLE_DEG
    ) *
    rightWingPos

  -- Make the wings visually heavier in PLOW mode.
  -- Transport/Groom retain the normal wing thickness.
  local wingDrawWidth =
    WING_WIDTH

  if getWingMode() == "PLOW" then

    wingDrawWidth =
      WING_WIDTH_PLOW

  end

  -- Angles are relative to the main blade:
  --   +45 = folded forward (toward screen-left)
  --     0 = exactly in-line with blade
  --   -15 = rearward
  --
  -- Build each wing endpoint in the blade's LOCAL coordinate
  -- system first, then rotate that endpoint with blade slew.
  -- This guarantees the Transport shape looks like a shallow
  -- close-parenthesis: both wing tips are forward of the blade.

  local leftRelativeRad =
    math.rad(
      leftRelativeDeg
    )

  local rightRelativeRad =
    math.rad(
      rightRelativeDeg
    )

  -- Upper / left wing local endpoint:
  -- forward means LEFT + UP.
  local leftLocalEndX =
    bladeX -
    math.sin(
      leftRelativeRad
    ) *
    WING_LENGTH

  local leftLocalEndY =
    bladeY -
    bladeHalfHeight -
    math.cos(
      leftRelativeRad
    ) *
    WING_LENGTH

  local leftEndX, leftEndY =
    rotatePoint(
      leftLocalEndX,
      leftLocalEndY,
      bladeX,
      bladeY,
      bladeSlewAngle
    )

  drawRotatedLine(
    topTipX,
    topTipY,
    leftEndX,
    leftEndY,
    0,
    0,
    0,
    COL_BLACK,
    wingDrawWidth
  )

  -- Lower / right wing local endpoint:
  -- forward means LEFT + DOWN.
  local rightLocalEndX =
    bladeX -
    math.sin(
      rightRelativeRad
    ) *
    WING_LENGTH

  local rightLocalEndY =
    bladeY +
    bladeHalfHeight +
    math.cos(
      rightRelativeRad
    ) *
    WING_LENGTH

  local rightEndX, rightEndY =
    rotatePoint(
      rightLocalEndX,
      rightLocalEndY,
      bladeX,
      bladeY,
      bladeSlewAngle
    )

  drawRotatedLine(
    bottomTipX,
    bottomTipY,
    rightEndX,
    rightEndY,
    0,
    0,
    0,
    COL_BLACK,
    wingDrawWidth
  )

end

-- TOP VIEW TILLER

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
    tillerX -
      TILLER_TOP_W / 2,
    tillerY,
    hitchX,
    hitchY,
    swingAngle,
    COL_BLACK,
    LINKAGE_WIDTH
  )

  drawRotatedLine(
    tillerX,
    tillerY - TILLER_TOP_H / 2,
    tillerX,
    tillerY + TILLER_TOP_H / 2,
    hitchX,
    hitchY,
    swingAngle,
    COL_RED,
    TILLER_TOP_W
  )

  -- YELLOW REAR COMB

  local combLeft =
    tillerX +
    TILLER_TOP_W / 2 +
    TILLER_COMB_GAP

  local combRight =
    combLeft +
    TILLER_COMB_W

  local combTop =
    tillerY -
    TILLER_COMB_H / 2

  local combBottom =
    tillerY +
    TILLER_COMB_H / 2

  drawRotatedLine(
    (combLeft + combRight) / 2,
    combTop,
    (combLeft + combRight) / 2,
    combBottom,
    hitchX,
    hitchY,
    swingAngle,
    COL_YELLOW,
    combRight - combLeft + 1
  )

  local combLineY =
    combTop +
    TILLER_COMB_LINE_SPACING

  while combLineY < combBottom do

    drawRotatedLine(
      combLeft,
      combLineY,
      combRight,
      combLineY,
      hitchX,
      hitchY,
      swingAngle,
      COL_BLACK,
      2
    )

    combLineY =
      combLineY +
      TILLER_COMB_LINE_SPACING

  end

  -- UPPER FINISHER

  local finLH =
    FINISHER_UP_H +
    (
      FINISHER_DOWN_H -
      FINISHER_UP_H
    ) *
    finLPos

  local finLBottom =
    tillerY -
    TILLER_TOP_H / 2 -
    FINISHER_GAP

  local finLTop =
    finLBottom -
    finLH

  local finLLeft =
    tillerX -
    FINISHER_W / 2

  local finLRight =
    tillerX +
    FINISHER_W / 2

  drawRotatedLine(
    finLLeft,
    (finLTop + finLBottom) / 2,
    finLRight,
    (finLTop + finLBottom) / 2,
    hitchX,
    hitchY,
    swingAngle,
    COL_YELLOW,
    math.max(1, finLBottom - finLTop + 1)
  )

  -- LOWER FINISHER

  local finRH =
    FINISHER_UP_H +
    (
      FINISHER_DOWN_H -
      FINISHER_UP_H
    ) *
    finRPos

  local finRTop =
    tillerY +
    TILLER_TOP_H / 2 +
    FINISHER_GAP

  local finRBottom =
    finRTop +
    finRH

  local finRLeft =
    tillerX -
    FINISHER_W / 2

  local finRRight =
    tillerX +
    FINISHER_W / 2

  drawRotatedLine(
    finRLeft,
    (finRTop + finRBottom) / 2,
    finRRight,
    (finRTop + finRBottom) / 2,
    hitchX,
    hitchY,
    swingAngle,
    COL_YELLOW,
    math.max(1, finRBottom - finRTop + 1)
  )

end

-- ANALOG GAUGE HELPERS

local function gaugePoint(
  cx,
  cy,
  radius,
  deg
)

  local rad =
    math.rad(
      deg
    )

  return
    cx + math.cos(rad) * radius,
    cy + math.sin(rad) * radius

end

local function drawAnalogGauge(
  cx,
  cy,
  radius,
  value,
  scaleMax,
  majorStep,
  label,
  valueText
)

  value =
    clamp(
      value,
      0,
      scaleMax
    )

  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawFilledCircle(
    cx,
    cy,
    radius,
    CUSTOM_COLOR
  )

  lcd.setColor(
    CUSTOM_COLOR,
    COL_BLACK
  )

  lcd.drawCircle(
    cx,
    cy,
    radius,
    CUSTOM_COLOR
  )

  lcd.drawCircle(
    cx,
    cy,
    radius - 2,
    CUSTOM_COLOR
  )

  local tickValue =
    0

  while tickValue <= scaleMax + 0.001 do

    local ratio =
      tickValue /
      scaleMax

    local angle =
      GAUGE_START_DEG +
      ratio *
      GAUGE_SWEEP_DEG

    local x1, y1 =
      gaugePoint(
        cx,
        cy,
        radius - 3,
        angle
      )

    local x2, y2 =
      gaugePoint(
        cx,
        cy,
        radius - 10,
        angle
      )

    lcd.drawLine(
      x1,
      y1,
      x2,
      y2,
      SOLID,
      CUSTOM_COLOR
    )

    local tx, ty =
      gaugePoint(
        cx,
        cy,
        radius - 21,
        angle
      )

    lcd.drawText(
      tx,
      ty,
      string.format(
        "%d",
        tickValue
      ),
      SMLSIZE +
      CENTER +
      VCENTER +
      CUSTOM_COLOR
    )

    tickValue =
      tickValue +
      majorStep

  end

  local needleRatio =
    value /
    scaleMax

  local needleAngle =
    GAUGE_START_DEG +
    needleRatio *
    GAUGE_SWEEP_DEG

  local nx, ny =
    gaugePoint(
      cx,
      cy,
      radius - 13,
      needleAngle
    )

  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  lcd.drawLine(
    cx,
    cy,
    nx,
    ny,
    SOLID,
    CUSTOM_COLOR
  )

  lcd.drawLine(
    cx + 1,
    cy,
    nx + 1,
    ny,
    SOLID,
    CUSTOM_COLOR
  )

  lcd.drawFilledCircle(
    cx,
    cy,
    4,
    CUSTOM_COLOR
  )

  lcd.setColor(
    CUSTOM_COLOR,
    COL_BLACK
  )

  lcd.drawText(
    cx,
    cy - 28,
    valueText,
    SMLSIZE +
    CENTER +
    CUSTOM_COLOR
  )

  lcd.drawText(
    cx,
    cy + 8,
    label,
    SMLSIZE +
    CENTER +
    CUSTOM_COLOR
  )

end

local function getGaugeTelemetry()

  local throttleAbs =
    math.abs(
      getValue("thr") or 0
    )

  local rpm =
    clamp(
      throttleAbs / 1024,
      0,
      1
    ) *
    TACH_GAUGE_MAX_RPM

  local leftOutput =
    norm(
      getValue("ch3") or 0
    )

  local rightOutput =
    -norm(
      getValue("ch1") or 0
    )

  local vehicleOutput =
    math.abs(
      (
        leftOutput +
        rightOutput
      ) / 2
    )

  local speedKmh =
    clamp(
      vehicleOutput,
      0,
      1
    ) *
    PB600_MAX_SPEED_KMH

  return rpm, speedKmh

end

-- LIGHT TELEMETRY

local function drawLightIndicator(
  labelX,
  indicatorX,
  cy,
  label,
  channelName,
  onColor
)

  local output =
    getValue(channelName) or -1024

  local active =
    output > LIGHT_ON_THRESHOLD

  local fillColor =
    COL_GRID

  if active then

    fillColor =
      onColor

  end

  -- Label first, indicator immediately to its right.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    labelX,
    cy,
    label,
    SMLSIZE +
    RIGHT +
    VCENTER +
    CUSTOM_COLOR
  )

  lcd.setColor(
    CUSTOM_COLOR,
    fillColor
  )

  lcd.drawFilledCircle(
    indicatorX,
    cy,
    LIGHT_INDICATOR_RADIUS,
    CUSTOM_COLOR
  )

  lcd.setColor(
    CUSTOM_COLOR,
    COL_BLACK
  )

  lcd.drawCircle(
    indicatorX,
    cy,
    LIGHT_INDICATOR_RADIUS,
    CUSTOM_COLOR
  )

end

local function drawTopLightTelemetry(
  x,
  y
)

  local labelX =
    x + LIGHT_LIST_LABEL_X_OFFSET

  local indicatorX =
    x + LIGHT_LIST_INDICATOR_X_OFFSET

  local row1Y =
    y + LIGHT_LIST_FIRST_Y_OFFSET

  local row2Y =
    row1Y +
    LIGHT_LIST_ROW_SPACING

  local row3Y =
    row2Y +
    LIGHT_LIST_ROW_SPACING

  drawLightIndicator(
    labelX,
    indicatorX,
    row1Y,
    "HEADLIGHTS",
    "ch17",
    COL_WHITE
  )

  drawLightIndicator(
    labelX,
    indicatorX,
    row2Y,
    "WARNING",
    "ch18",
    COL_AMBER
  )

  drawLightIndicator(
    labelX,
    indicatorX,
    row3Y,
    "SPOTLIGHTS",
    "ch19",
    COL_WHITE
  )

end

-- STATUS BAR
--
-- Compact version of the machine-status logic from the
-- previous operator panel. Kept visual-only here to avoid
-- adding extra tone/CPU work to the optimized widget.

local function getMachineStatus()

  local sf =
    getValue("sf") or 0

  local sd =
    getValue("sd") or 0

  local thr =
    getValue("thr") or 0

  local bladeTransition =
    getLogicalSwitchValue(10)

  local tillerTransition =
    getLogicalSwitchValue(11)

  if sf > 0 then
    return "E-STOP", COL_ALERT
  end

  if sd > 500
    and thr < -50
    and tillerTransition
  then
    return "REVERSE: TILLER LIFT", COL_AMBER
  end

  if bladeTransition
    and tillerTransition
  then
    return "TRANSITION: BLADE + TILLER", COL_AMBER
  end

  if bladeTransition then
    return "TRANSITION: BLADE", COL_AMBER
  end

  if tillerTransition then
    return "TRANSITION: TILLER", COL_AMBER
  end

  if sd < -500 then
    return "RUN: TRANSPORT", COL_FWD
  end

  if sd > 500 then
    return "RUN: GROOM", COL_FWD
  end

  return "RUN: PLOW", COL_FWD

end


local function drawStatusBar(
  x,
  y
)

  local status, statusColor =
    getMachineStatus()

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x + 15,
    y,
    "STATUS:",
    SMLSIZE + CUSTOM_COLOR
  )

  lcd.setColor(
    CUSTOM_COLOR,
    statusColor
  )

  lcd.drawText(
    x + 90,
    y,
    status,
    SMLSIZE + CUSTOM_COLOR
  )

  if homeActive then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )

    lcd.drawText(
      x + 385,
      y,
      "HOME",
      SMLSIZE +
      RIGHT +
      INVERS +
      CUSTOM_COLOR
    )

  end

end


-- TOP VIEW

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

  -- Snowcat moved lower to leave room for telemetry above.
  local cy =
    y + TOP_VIEW_CAT_Y_OFFSET

  -- LIGHT OUTPUT TELEMETRY

  drawTopLightTelemetry(
    x,
    y
  )

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

  -- Bottom status bar from the previous operator panel.
  drawStatusBar(
    x,
    y + 318
  )

end

-- SIDE VIEW BODY

local function drawSideBody(
  cx,
  cy
)

  local trackCenterY =
    cy + 30

  local trackTop =
    trackCenterY -
    SIDE_TRACK_H / 2

  local trackLeft =
    cx -
    SIDE_TRACK_HALF_LENGTH

  local trackRight =
    cx +
    SIDE_TRACK_HALF_LENGTH

  -- ==========================================================
  -- SIDE TRACK CAPSULE
  --
  -- Draw a black outer capsule, then overlay a background-color
  -- inner capsule inset by 2 px. Wheels are drawn afterward.
  -- ==========================================================

  local trackInset =
    4

  -- OUTER TRACK CAPSULE

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK
  )

  lcd.drawFilledRectangle(
    trackLeft,
    trackTop,
    trackRight - trackLeft,
    SIDE_TRACK_H,
    CUSTOM_COLOR
  )

  lcd.drawFilledCircle(
    trackLeft,
    trackCenterY,
    SIDE_TRACK_RADIUS,
    CUSTOM_COLOR
  )

  lcd.drawFilledCircle(
    trackRight,
    trackCenterY,
    SIDE_TRACK_RADIUS,
    CUSTOM_COLOR
  )

  -- INNER BACKGROUND-COLOR CAPSULE
  --
  -- Circle centers stay unchanged.
  -- Radius shrinks by 2 px.
  -- Rectangle spans only between the circle centers.

  local innerRadius =
    SIDE_TRACK_RADIUS -
    trackInset

  local innerTop =
    trackCenterY -
    innerRadius

  local innerHeight =
    innerRadius * 2

  lcd.setColor(
    CUSTOM_COLOR,
    COL_BACKGROUND
  )

  lcd.drawFilledRectangle(
    trackLeft,
    innerTop,
    trackRight - trackLeft,
    innerHeight,
    CUSTOM_COLOR
  )

  lcd.drawFilledCircle(
    trackLeft,
    trackCenterY,
    innerRadius,
    CUSTOM_COLOR
  )

  lcd.drawFilledCircle(
    trackRight,
    trackCenterY,
    innerRadius,
    CUSTOM_COLOR
  )


  -- SIX EVENLY-SPACED ROAD WHEELS
  --
  -- The inner track capsule above is already filled with
  -- COL_BACKGROUND. These smaller black wheels are then drawn
  -- over it, leaving visible background-color gaps between them.
 
  local wheelLeft =
    trackLeft

  local wheelRight =
    trackRight

  local wheelSpacing =
    (wheelRight - wheelLeft) /
    (SIDE_ROAD_WHEEL_COUNT - 1)

  for i = 0, SIDE_ROAD_WHEEL_COUNT - 1 do

    local wheelX =
      wheelLeft +
      wheelSpacing * i

    lcd.setColor(
      CUSTOM_COLOR,
      COL_BLACK
    )

    lcd.drawFilledCircle(
      wheelX,
      trackCenterY,
      SIDE_ROAD_WHEEL_R,
      CUSTOM_COLOR
    )

    lcd.setColor(
      CUSTOM_COLOR,
      COL_METAL
    )

    lcd.drawFilledCircle(
      wheelX,
      trackCenterY,
      math.max(1, SIDE_ROAD_WHEEL_R * 0.10),
      CUSTOM_COLOR
    )

  end

  -- FULL-LENGTH UPPER BODY / CHASSIS
  --
  -- Stretch the bodywork to the complete visual length of the
  -- rounded track assembly underneath.

  local bodyFront =
    trackLeft -
    SIDE_TRACK_RADIUS

  local bodyRear =
    trackRight +
    SIDE_TRACK_RADIUS

  local bodyLength =
    bodyRear -
    bodyFront

  local chassisBottom =
    trackTop - 1

  local chassisTop =
    chassisBottom -
    SIDE_CHASSIS_H

  lcd.setColor(
    CUSTOM_COLOR,
    COL_BLACK
  )

  lcd.drawFilledRectangle(
    bodyFront,
    chassisTop,
    bodyLength,
    SIDE_CHASSIS_H,
    CUSTOM_COLOR
  )

  
  -- CAB / ENGINE HOUSING
  --
  -- The cab is moved forward so the lower leading edge of its
  -- sloped nose aligns with the leading edge of the track.
  --
  -- Behind the cab is a red engine housing at half cab height,
  -- followed by the gray rear deck.

  -- Cab widened by the 27 px recovered from halving the
  -- backpack/engine enclosure width.
  local cabW =
    69

  local cabBottom =
    chassisTop + 1

  local cabH =
    68

  local cabY =
    cabBottom -
    cabH

  -- Cab front and windshield share this slope.
  local cabFrontSlope =
    0.20

  local noseTopY =
    cabY + 6

  local noseBottomY =
    cabBottom

  local noseHeight =
    noseBottomY -
    noseTopY

  -- Position the rectangular part of the cab so the bottom
  -- point of the sloped nose lands exactly at bodyFront.
  local cabX =
    bodyFront +
    noseHeight *
    cabFrontSlope

  local noseTopX =
    cabX

  local noseBottomX =
    bodyFront

  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  -- Main rectangular cab.
  lcd.drawFilledRectangle(
    cabX,
    cabY,
    cabW,
    cabH,
    CUSTOM_COLOR
  )

  -- SLOPED CAB FRONT

  lcd.drawFilledTriangle(
    noseTopX,
    noseTopY,
    cabX,
    noseBottomY,
    noseBottomX,
    noseBottomY,
    CUSTOM_COLOR
  )

  -- Fill the lower nose area cleanly into the chassis.
  local noseBaseW =
    cabX -
    noseBottomX

  if noseBaseW > 0 then

    lcd.drawFilledRectangle(
      noseBottomX,
      cabBottom - 8,
      noseBaseW,
      8,
      CUSTOM_COLOR
    )

  end

  -- Roof.
  lcd.drawFilledRectangle(
    cabX - 3,
    cabY - 6,
    cabW + 7,
    6,
    CUSTOM_COLOR
  )

  -- LARGE WINDSHIELD
  --
  -- Front edge uses exactly the same slope as the cab nose.

  local glassTopY =
    cabY + 8

  local glassBottomY =
    cabBottom - 9

  local glassH =
    glassBottomY -
    glassTopY

  local glassFrontTopX =
    cabX + 3

  local oldGlassWidth =
    cabW - 7

  local newGlassWidth =
    oldGlassWidth * 0.75

  local glassRearX =
    glassFrontTopX +
    newGlassWidth

  lcd.setColor(
    CUSTOM_COLOR,
    COL_GLASS
  )

  local glassFrontBottomX =
    glassFrontTopX -
    glassH * cabFrontSlope

  lcd.drawFilledTriangle(
    glassFrontTopX,
    glassTopY,
    glassRearX,
    glassTopY,
    glassRearX,
    glassBottomY,
    CUSTOM_COLOR
  )

  lcd.drawFilledTriangle(
    glassFrontTopX,
    glassTopY,
    glassRearX,
    glassBottomY,
    glassFrontBottomX,
    glassBottomY,
    CUSTOM_COLOR
  )

  -- RED ENGINE HOUSING
  --
  -- Half the height of the cab and placed directly behind it. with one half its height red/top and black/bottom

  local engineX =
    cabX +
    cabW

  local engineH =
    math.floor(
      cabH * 0.50
    )

  local engineY =
    cabBottom -
    engineH

  -- Leave enough room at the rear for the gray deck.
  -- Backpack / engine enclosure is half its previous width.
  local engineW =
    27

  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )

  lcd.drawFilledRectangle(
    engineX,
    engineY,
    engineW,
    engineH,
    CUSTOM_COLOR
  )

    lcd.setColor(
    CUSTOM_COLOR,
    COL_BLACK
  )

  lcd.drawFilledRectangle(
    engineX,
    engineY+(engineH/2),
    engineW,
    engineH/2,
    CUSTOM_COLOR
  )

      lcd.setColor(
    CUSTOM_COLOR,
    COL_BLACK
  )

  lcd.drawFilledTriangle(
    engineX-40,
    engineY+engineH,
    engineX,
    engineY+engineH,
    engineX,
    engineY+engineH-(engineH/2),
    CUSTOM_COLOR
  )

  -- EXHAUST PIPE
  --
  -- Small gray rectangle centered on the engine housing.

  -- Exhaust is 25% wider and 50% taller.
  local exhaustW =
    20

  local exhaustH =
    21

  local exhaustX =
    engineX +
    math.floor(
      (engineW - exhaustW) / 2
    )

  local exhaustY =
    engineY -
    exhaustH

  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  lcd.drawFilledRectangle(
    exhaustX,
    exhaustY,
    exhaustW,
    exhaustH,
    CUSTOM_COLOR
  )

    lcd.drawFilledRectangle(
    exhaustX+(exhaustW/4),
    exhaustY-exhaustH,
    exhaustW/2,
    exhaustH,
    CUSTOM_COLOR
  )

  -- FULL-LENGTH REAR DECK

  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )

  local deckX =
    engineX +
    engineW

  local deckY =
    chassisTop - 13

  local deckW =
    bodyRear -
    deckX

  lcd.drawFilledRectangle(
    deckX,
    deckY,
    deckW,
    12,
    CUSTOM_COLOR
  )

end

-- SIDE VIEW BLADE

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
    cy + 49

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

  drawRotatedLine(
    cx - 64,
    cy - 9,
    bladeX + 12,
    bladeY - 10,
    0,
    0,
    0,
    COL_BLACK,
    LINKAGE_WIDTH
  )

  drawRotatedLine(
    cx - 64,
    cy + 8,
    bladeX + 12,
    bladeY + 10,
    0,
    0,
    0,
    COL_BLACK,
    LINKAGE_WIDTH
  )

  drawRotatedLine(
    bladeX,
    bladeY - bladeHalfHeight,
    bladeX,
    bladeY + bladeHalfHeight,
    bladeX,
    bladeY,
    bladeAngle,
    COL_BLACK,
    15
  )

end

-- SIDE VIEW TILLER

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
    cy + 49

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

  drawRotatedLine(
    cx + 64,
    cy - 7,
    tillerX - 31,
    tillerY - 5,
    0,
    0,
    0,
    COL_BLACK,
    LINKAGE_WIDTH
  )

  drawRotatedLine(
    cx + 64,
    cy + 5,
    tillerX - 31,
    tillerY + 5,
    0,
    0,
    0,
    COL_BLACK,
    LINKAGE_WIDTH
  )

  -- Tiller body as one filled rotated bar.
  drawRotatedLine(
    tillerX - 31,
    tillerY,
    tillerX + 31,
    tillerY,
    tillerX,
    tillerY,
    tillerAngle,
    COL_RED,
    19
  )

  -- MOTOR INDICATOR

  local tillerMotor =
    getValue("ch14") or -1024

  local tillerMotorSpeed =
    getValue("s1") or -1024

  local motorColor =
    COL_GLASS

  if tillerMotorSpeed > -1024 then
    motorColor = COL_YELLOW
  else
    motorColor = COL_GLASS
  end

  if tillerMotor > -1024 then

    motorColor =
      COL_FWD

  end

  local motorX, motorY =
    rotatePoint(
      tillerX - 18,
      tillerY,
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

  -- SIDE-VIEW COMB

  drawRotatedLine(
    tillerX + 31,
    tillerY + 7,
    tillerX + 62,
    tillerY + 12,
    tillerX,
    tillerY,
    tillerAngle,
    COL_YELLOW,
    3
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
      2
    )

  end

end

-- SIDE VIEW

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

  -- Snowcat moved lower to leave three telemetry rows above.
  local cy =
    y + SIDE_VIEW_CAT_Y_OFFSET

  -- TACHOMETER / SPEEDOMETER
  --
  -- Gauges are 25% larger than the previous version and are
  -- centered above the SIDE VIEW snowcat.

  local rpm, speedKmh =
    getGaugeTelemetry()

  local gaugeCenterY =
    y + SIDE_GAUGE_CENTER_Y_OFFSET

  local gaugePairCenterX =
    x + SIDE_GAUGE_PAIR_CENTER_X_OFFSET

  local tachCenterX =
    gaugePairCenterX -
    SIDE_GAUGE_SPACING / 2

  local speedCenterX =
    gaugePairCenterX +
    SIDE_GAUGE_SPACING / 2

  drawAnalogGauge(
    tachCenterX,
    gaugeCenterY,
    GAUGE_RADIUS,
    rpm,
    TACH_GAUGE_MAX_RPM,
    500,
    "RPM",
    string.format(
      "%d",
      math.floor(rpm + 0.5)
    )
  )

  drawAnalogGauge(
    speedCenterX,
    gaugeCenterY,
    GAUGE_RADIUS,
    speedKmh,
    SPEED_GAUGE_MAX_KMH,
    5,
    "km/h",
    string.format(
      "%.1f",
      speedKmh
    )
  )

  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )

  lcd.drawLine(
    x + 12,
    cy + 49,
    x + 379,
    cy + 49,
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


  -- Third telemetry row.
  --
  -- Blade Tilt is a centered actuator output (-100..+100%).
  local bladeTiltPct =
    ((getValue("ch4") or 0) / 1024) * 100


  -- Tiller motor CH14 uses -1024 as OFF and +1024 as full.
  local tillerMotorPct =
    clamp(
      ((getValue("ch14") or -1024) + 1024) / 2048,
      0,
      1
    ) * 100


  lcd.drawText(
    x + 10,
    y + 318,
    string.format(
      "Blade Tilt %4.0f%%",
      bladeTiltPct
    ),
    SMLSIZE + CUSTOM_COLOR
  )


  lcd.drawText(
    x + 203,
    y + 318,
    string.format(
      "Tiller Motor %3.0f%%",
      tillerMotorPct
    ),
    SMLSIZE + CUSTOM_COLOR
  )

end

-- REFRESH

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

  local leftWingCmd =
    norm(
      getValue("ch5") or 0
    )

  local rightWingCmd =
    norm(
      getValue("ch6") or 0
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
    -norm(
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

  -- WING POSITION
  --
  -- Automatic mode moves use SD directly so the display does
  -- not depend on short CH5/CH6 output pulses.
  --
  -- TRANSPORT = 45 degrees forward
  -- PLOW      = in-line with blade
  -- GROOM     = in-line with blade

  local currentWingMode =
    getWingMode()

  if lastWingMode == nil then

    lastWingMode =
      currentWingMode

    wingModeTarget =
      getWingModeTarget(
        currentWingMode
      )

    leftWingPos =
      wingModeTarget

    rightWingPos =
      wingModeTarget

    wingModeMoving =
      false

  elseif currentWingMode ~= lastWingMode then

    lastWingMode =
      currentWingMode

    wingModeTarget =
      getWingModeTarget(
        currentWingMode
      )

    wingModeMoving =
      true

  end

  if wingModeMoving then

    leftWingPos =
      moveWingToward(
        leftWingPos,
        wingModeTarget,
        dt
      )

    rightWingPos =
      moveWingToward(
        rightWingPos,
        wingModeTarget,
        dt
      )

    if math.abs(
      leftWingPos -
      wingModeTarget
    ) < 0.001
      and
      math.abs(
        rightWingPos -
        wingModeTarget
      ) < 0.001
    then

      leftWingPos =
        wingModeTarget

      rightWingPos =
        wingModeTarget

      wingModeMoving =
        false

    end

  else

    leftWingPos =
      integrateWing(
        leftWingPos,
        -leftWingCmd,
        dt
      )

    rightWingPos =
      integrateWing(
        rightWingPos,
        rightWingCmd,
        dt
      )

  end

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
      -finLCmd,
      dt
    )

  finRPos =
    integrateFinisher(
      finRPos,
      -finRCmd,
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
    400,
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

end

-- EXPORT

return {
  name = name,
  options = options,
  create = create,
  update = update,
  refresh = refresh,
  background = background
}
