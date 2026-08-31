-- ============================================================
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
-- COLORS
-- ============================================================

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

local COL_BLACK =
  lcd.RGB(0, 0, 0)

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

local FIN_FULL_TIME =
  2.0

local WING_FULL_TIME =
  4.0


-- ============================================================
-- VISUAL CALIBRATION
-- ============================================================

local OUTPUT_DEADBAND =
  0.025

local LINKAGE_WIDTH =
  4


-- ------------------------------------------------------------
-- TOP VIEW
-- ------------------------------------------------------------

local MAX_BLADE_SLEW_DEG =
  28

local MAX_TILLER_SWING_DEG =
  32

local TILLER_TOP_W =
  18

local TILLER_TOP_H =
  108


-- ------------------------------------------------------------
-- TOP-VIEW TRACKS
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- TOP-VIEW TILLER COMB
-- ------------------------------------------------------------

local TILLER_COMB_W =
  14

local TILLER_COMB_H =
  108

local TILLER_COMB_GAP =
  3

local TILLER_COMB_LINE_SPACING =
  9


-- ------------------------------------------------------------
-- WINGS
--
-- wingPos = 0:
--      45 degrees forward
--
-- wingPos = 1:
--      15 degrees rearward
--
-- Straight is approximately 75% of travel.
-- ------------------------------------------------------------

local WING_LENGTH =
  30

local WING_WIDTH =
  8

-- Wings are drawn heavier when the blade is in PLOW mode so
-- the straight/open blade reads as one substantial cutting edge.
local WING_WIDTH_PLOW =
  14

local WING_UP_ANGLE_DEG =
  45

local WING_DOWN_ANGLE_DEG =
  -15

local WING_STRAIGHT_POS =
  WING_UP_ANGLE_DEG /
  (WING_UP_ANGLE_DEG - WING_DOWN_ANGLE_DEG)


-- ------------------------------------------------------------
-- FINISHERS
-- ------------------------------------------------------------

local FINISHER_W =
  28

local FINISHER_UP_H =
  5

local FINISHER_DOWN_H =
  22

local FINISHER_GAP =
  1


-- ------------------------------------------------------------
-- SIDE VIEW
-- ------------------------------------------------------------

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


local SIDE_ROAD_WHEEL_R =
  15

local SIDE_ROAD_WHEEL_COUNT =
  6

local SIDE_ROAD_WHEEL_MARGIN =
  8


local SIDE_CHASSIS_H =
  14


-- ============================================================
-- HOME STATE
-- ============================================================

local homeActive =
  false

local homeArmed =
  false

local lastSh =
  false

local HOME_SLIDER_DEADBAND =
  100


-- ============================================================
-- PERSISTENT VISUAL STATE
-- ============================================================

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
-- INTEGRATORS
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


-- ============================================================
-- WING MODE ANIMATION
-- ============================================================

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


-- ============================================================
-- TRACK ANIMATION
-- ============================================================

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
  phase,
  innerEdgeBottom
)

  -- ----------------------------------------------------------
  -- GRAY TRACK BED
  -- ----------------------------------------------------------

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


  -- ----------------------------------------------------------
  -- TRACK OUTLINE / GROUSER COLOR
  -- ----------------------------------------------------------

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


  -- ----------------------------------------------------------
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
  -- ----------------------------------------------------------

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

        -- -----------------------------------------------
        -- 100% GROUSER
        -- -----------------------------------------------

        barH =
          usableH

      else

        -- -----------------------------------------------
        -- 80% GROUSER
        -- -----------------------------------------------

        barH =
          math.floor(
            usableH *
            TOP_TRACK_SHORT_GROUSER
          )

      end


      local barY


      if barH == usableH then

        -- -----------------------------------------------
        -- FULL GROUSER
        --
        -- Runs from outside edge to inside edge.
        -- -----------------------------------------------

        barY =
          y + 2


      elseif innerEdgeBottom then

        -- -----------------------------------------------
        -- UPPER TRACK
        --
        -- Cat is BELOW the track.
        --
        -- Anchor the 80% grouser at the lower/inside
        -- edge and let it extend upward/outward.
        -- -----------------------------------------------

        barY =
          y +
          h -
          2 -
          barH


      else

        -- -----------------------------------------------
        -- LOWER TRACK
        --
        -- Cat is ABOVE the track.
        --
        -- Anchor the 80% grouser at the upper/inside
        -- edge and let it extend downward/outward.
        -- -----------------------------------------------

        barY =
          y + 2

      end


      -- -----------------------------------------------
      -- TWO-PIXEL-THICK GROUSER
      -- -----------------------------------------------

      lcd.drawLine(
        barX,
        barY,
        barX,
        barY + barH - 1,
        SOLID,
        CUSTOM_COLOR
      )


      lcd.drawLine(
        barX + 1,
        barY,
        barX + 1,
        barY + barH - 1,
        SOLID,
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


-- ============================================================
-- TOP VIEW BODY
-- ============================================================

local function drawTopBody(
  cx,
  cy
)

  -- ----------------------------------------------------------
  -- UPPER TRACK
  --
  -- 38 px wide versus the original 25 px.
  --
  -- The track center remains approximately where it was,
  -- so the additional width sticks farther outside the cat.
  --
  -- TRUE tells drawTopTrack() that the cat-side edge
  -- is the BOTTOM of this track.
  -- ----------------------------------------------------------

  drawTopTrack(
    cx - 74,
    cy - 56,
    TOP_TRACK_LENGTH,
    TOP_TRACK_W,
    trackPhaseL,
    true
  )


  -- ----------------------------------------------------------
  -- LOWER TRACK
  --
  -- FALSE tells drawTopTrack() that the cat-side edge
  -- is the TOP of this track.
  -- ----------------------------------------------------------

  drawTopTrack(
    cx - 74,
    cy + 18,
    TOP_TRACK_LENGTH,
    TOP_TRACK_W,
    trackPhaseR,
    false
  )


  -- ----------------------------------------------------------
  -- MAIN BODY
  -- ----------------------------------------------------------

  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )


  lcd.drawFilledRectangle(
    cx - 61,
    cy - 21,
    122,
    42,
    CUSTOM_COLOR
  )


  -- ----------------------------------------------------------
  -- REAR DECK
  -- ----------------------------------------------------------

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


  -- ----------------------------------------------------------
  -- CAB
  -- ----------------------------------------------------------

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


  -- ----------------------------------------------------------
  -- WINDSHIELD
  -- ----------------------------------------------------------

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


  -- Main blade.
  for i =
    -bladeHalfWidth,
    bladeHalfWidth
  do

    drawRotatedLine(
      bladeX + i,
      bladeY - bladeHalfHeight,
      bladeX + i,
      bladeY + bladeHalfHeight,
      bladeX,
      bladeY,
      bladeSlewAngle,
      COL_BLACK,
      1
    )

  end


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
    tillerX -
      TILLER_TOP_W / 2,
    tillerY,
    hitchX,
    hitchY,
    swingAngle,
    COL_BLACK,
    LINKAGE_WIDTH
  )


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


  -- ==========================================================
  -- YELLOW REAR COMB
  -- ==========================================================

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


  for xx =
    combLeft,
    combRight
  do

    drawRotatedLine(
      xx,
      combTop,
      xx,
      combBottom,
      hitchX,
      hitchY,
      swingAngle,
      COL_YELLOW,
      1
    )

  end


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


  -- ==========================================================
  -- UPPER FINISHER
  -- ==========================================================

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


  for yy =
    finLTop,
    finLBottom
  do

    drawRotatedLine(
      finLLeft,
      yy,
      finLRight,
      yy,
      hitchX,
      hitchY,
      swingAngle,
      COL_YELLOW,
      1
    )

  end


  -- ==========================================================
  -- LOWER FINISHER
  -- ==========================================================

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


  for yy =
    finRTop,
    finRBottom
  do

    drawRotatedLine(
      finRLeft,
      yy,
      finRRight,
      yy,
      hitchX,
      hitchY,
      swingAngle,
      COL_YELLOW,
      1
    )

  end

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


  -- Gray track body.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK
  )


  lcd.drawFilledRectangle(
    trackLeft,
    trackTop,
    SIDE_TRACK_HALF_LENGTH * 2,
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


  -- Track outline.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_TRACK_BAR
  )


  lcd.drawRectangle(
    trackLeft,
    trackTop,
    SIDE_TRACK_HALF_LENGTH * 2,
    SIDE_TRACK_H,
    CUSTOM_COLOR
  )


  lcd.drawCircle(
    trackLeft,
    trackCenterY,
    SIDE_TRACK_RADIUS,
    CUSTOM_COLOR
  )


  lcd.drawCircle(
    trackRight,
    trackCenterY,
    SIDE_TRACK_RADIUS,
    CUSTOM_COLOR
  )


  -- ==========================================================
  -- SIX EVENLY-SPACED ROAD WHEELS
  -- ==========================================================

  lcd.setColor(
    CUSTOM_COLOR,
    COL_BLACK
  )


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


    lcd.drawFilledCircle(
      wheelX,
      trackCenterY,
      SIDE_ROAD_WHEEL_R,
      COL_BLACK
    )

        lcd.drawFilledCircle(
      wheelX,
      trackCenterY,
      SIDE_ROAD_WHEEL_R*.1,
      COL_METAL
    )

  end


  -- ==========================================================
  -- FULL-LENGTH UPPER BODY / CHASSIS
  --
  -- Stretch the bodywork to the complete visual length of the
  -- rounded track assembly underneath.
  -- ==========================================================

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


  -- ==========================================================
  -- CAB
  --
  -- The cab and rear deck now span the full track footprint.
  -- The front is a long sloped nose, followed by the main cab,
  -- then a low rear deck all the way to the back of the tracks.
  -- ==========================================================

  local cabX =
    cx - 34


  -- Cab width reduced 25% from 56 px to 42 px.
  -- Keeping the front of the rectangular cab in the same place
  -- gives the recovered width to the rear deck.
  local cabW =
    42


  local cabBottom =
    chassisTop + 1


  local cabH =
    68


  local cabY =
    cabBottom -
    cabH


  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )


  lcd.drawFilledRectangle(
    cabX,
    cabY,
    cabW,
    cabH,
    CUSTOM_COLOR
  )


  -- ==========================================================
  -- LONG SLOPED CAB NOSE
  --
  -- The lower point now starts at the full front of the track
  -- footprint so the cab/body silhouette spans the tracks.
  -- ==========================================================

  local noseTopY =
    cabY + 6


  local noseBottomY =
    cabBottom


  local noseTopX =
    cabX


  local noseBottomX =
    bodyFront


  local noseHeight =
    noseBottomY -
    noseTopY


  lcd.setColor(
    CUSTOM_COLOR,
    COL_RED
  )


  for yy = 0, noseHeight do

    local t =
      yy /
      noseHeight


    local leftX =
      noseTopX +
      (
        noseBottomX -
        noseTopX
      ) *
      t


    lcd.drawLine(
      leftX,
      noseTopY + yy,
      cabX,
      noseTopY + yy,
      SOLID,
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


  -- ==========================================================
  -- WINDSHIELD
  -- ==========================================================

  local glassTopY =
    cabY + 10


  local glassBottomY =
    cabY + 46


  -- Windshield narrowed to match the smaller cab.
  local glassRearX =
    cabX + 31


  -- Steeper windshield:
  -- only 7 px of forward sweep from top to bottom instead of 16.
  local glassFrontTopX =
    cabX + 4


  local glassFrontBottomX =
    cabX - 3


  local glassH =
    glassBottomY -
    glassTopY


  lcd.setColor(
    CUSTOM_COLOR,
    COL_GLASS
  )


  for yy = 0, glassH do

    local t =
      yy /
      glassH


    local glassFrontX =
      glassFrontTopX +
      (
        glassFrontBottomX -
        glassFrontTopX
      ) *
      t


    lcd.drawLine(
      glassFrontX,
      glassTopY + yy,
      glassRearX,
      glassTopY + yy,
      SOLID,
      CUSTOM_COLOR
    )

  end


  -- ==========================================================
  -- FULL-LENGTH REAR DECK
  -- ==========================================================

  lcd.setColor(
    CUSTOM_COLOR,
    COL_METAL
  )


  local deckX =
    cabX +
    cabW


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


  for i = -7, 7 do

    drawRotatedLine(
      bladeX + i,
      bladeY -
        bladeHalfHeight,
      bladeX + i,
      bladeY +
        bladeHalfHeight,
      bladeX,
      bladeY,
      bladeAngle,
      COL_BLACK,
      1
    )

  end

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


  -- Tiller body.
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


  -- ==========================================================
  -- MOTOR INDICATOR
  -- ==========================================================

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


  -- ==========================================================
  -- SIDE-VIEW COMB
  -- ==========================================================

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

    return

  end


  -- ==========================================================
  -- TIME
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
  -- SOURCES
  -- ==========================================================

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


  -- ==========================================================
  -- POSITION INTEGRATION
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


  -- ==========================================================
  -- WING POSITION
  --
  -- Automatic mode moves use SD directly so the display does
  -- not depend on short CH5/CH6 output pulses.
  --
  -- TRANSPORT = 45 degrees forward
  -- PLOW      = in-line with blade
  -- GROOM     = in-line with blade
  -- ==========================================================

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
