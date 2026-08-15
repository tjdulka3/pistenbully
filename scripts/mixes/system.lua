-- ============================================================
-- PB600 SYSTEM / TRACK / SAFETY CONTROL
--
-- Outputs:
--   1 TrackL
--   2 TrackR
--   3 TillerMot
--   4 BladeTr
--   5 TillerTr
--
-- GV2 = Blade working depth %
-- GV3 = Tiller Groom depth %
-- GV4 = Reverse auto-lift %
-- GV5 = Tiller working angle %
--
-- SF Up = E-stop
--
-- TillerMot:
--   1024 = motor permitted
--      0 = motor locked out
-- ============================================================


-- ============================================================
-- IMPLEMENT CALIBRATION
-- ============================================================

local BLADE_LIFT_FULL   = 6.7
local BLADE_ANGLE_FULL  = 6.7
local WING_FULL         = 3.75

local TILLER_LIFT_FULL  = 12.5
local TILLER_ANGLE_FULL = 3.75
local FIN_FULL_TIME     = 2.0

-- Must match blade.lua
local WORK_WING_OPEN = 0.40
local WORK_ANGLE     = 0.50


-- ============================================================
-- TRACK TUNING
--
-- These are code constants rather than GVs.
-- ============================================================

local TURN_GAIN        = 0.25
local SPEED_FACTOR     = 0.60

local ACCEL_RATE       = 60
local DECEL_RATE       = 180
local REVERSE_BOOST    = 140

local RUDDER_DEADBAND  = 0.02
local REVERSE_DEADBAND = 0.02

-- Track power while blade/tiller is repositioning.
local TRANSITION_POWER = 0.25


-- ============================================================
-- STATE
-- ============================================================

local initialized = false
local lastSd = nil
local lastTime = getTime()

local bladeTransitionRemaining  = 0
local tillerTransitionRemaining = 0

local lastL = 0
local lastR = 0


-- Automatic reverse sequence:
--
-- idle
-- lifting
-- ready
-- returning
local reverseState = "idle"

local reverseRemaining = 0


-- ============================================================
-- HELPERS
-- ============================================================

local function clamp(v, lo, hi)

  if v < lo then return lo end
  if v > hi then return hi end

  return v
end


local function normStick(v)

  if type(v) ~= "number" then
    return 0
  end

  if math.abs(v) > 100 then
    return v / 1024
  end

  return v / 100
end


local function smoothDirectional(
  prev,
  target,
  accelRate,
  decelRate,
  reverseBoost
)

  local delta =
    target - prev

  local crossingZero =
    (prev > 0 and target < 0) or
    (prev < 0 and target > 0)

  local sameDirection =
    (prev >= 0 and target >= 0) or
    (prev <= 0 and target <= 0)

  local accelerating =
    sameDirection and
    (math.abs(target) > math.abs(prev))


  if math.abs(delta) < accelRate then
    return target
  end


  if crossingZero then

    if prev > 0 then
      return prev - (decelRate + reverseBoost)
    else
      return prev + (decelRate + reverseBoost)
    end
  end


  if accelerating then

    if delta > 0 then
      return prev + accelRate
    else
      return prev - accelRate
    end

  else

    if delta > 0 then
      return prev + decelRate
    else
      return prev - decelRate
    end

  end
end


-- ============================================================
-- MAIN
-- ============================================================

local function run()

  local now = getTime()
  local dt = (now - lastTime) / 100
  lastTime = now

  if dt < 0 then dt = 0 end
  if dt > 0.25 then dt = 0.25 end


  -- ----------------------------------------------------------
  -- INPUTS
  -- ----------------------------------------------------------

  local sd =
    getValue("sd") or 0

  local sf =
    getValue("sf") or 0

  local thr =
    normStick(getValue("thr"))

  local rud =
    -normStick(getValue("rud"))

  if math.abs(rud) < RUDDER_DEADBAND then
    rud = 0
  end

  local eStop =
    sf > 0

  local isGroom =
    sd > 500


  -- ----------------------------------------------------------
  -- GLOBAL VARIABLES
  -- ----------------------------------------------------------

  local bladeDepth =
    clamp(
      (getValue("gvar2") or 0) / 100,
      0,
      1
    )

  local groomDepth =
    clamp(
      (getValue("gvar3") or 0) / 100,
      0,
      1
    )

  local reverseLift =
    clamp(
      (getValue("gvar4") or 0) / 100,
      0,
      1
    )

  local groomAngle =
    clamp(
      (getValue("gvar5") or 0) / 100,
      0,
      1
    )


  -- ----------------------------------------------------------
  -- CALCULATED IMPLEMENT TRANSITION TIMES
  --
  -- These mirror the physical movement expected from
  -- blade.lua and tiller.lua.
  -- ----------------------------------------------------------

  local bladeLiftTime =
    bladeDepth *
    BLADE_LIFT_FULL

  local bladeWingTime =
    WORK_WING_OPEN *
    WING_FULL

  local bladeAngleTime =
    WORK_ANGLE *
    BLADE_ANGLE_FULL

  local bladeTransitionTime =
    math.max(
      bladeLiftTime,
      bladeWingTime,
      bladeAngleTime
    )


  local tillerLiftTime =
    groomDepth *
    TILLER_LIFT_FULL

  local tillerAngleTime =
    groomAngle *
    TILLER_ANGLE_FULL

  local tillerTransitionTime =
    math.max(
      tillerLiftTime,
      tillerAngleTime,
      FIN_FULL_TIME
    )


  local reverseLiftTime =
    reverseLift *
    TILLER_LIFT_FULL


  -- ----------------------------------------------------------
  -- INITIALIZE
  -- ----------------------------------------------------------

  if not initialized then

    lastSd = sd
    initialized = true
  end


  -- ----------------------------------------------------------
  -- E-STOP
  --
  -- Everything stops immediately.
  --
  -- Importantly, transition/reverse timers do NOT advance
  -- while E-stop is held, so the system cannot believe an
  -- actuator completed movement while power was stopped.
  -- ----------------------------------------------------------

  if eStop then

    lastL = 0
    lastR = 0

    return
      0, -- TrackL
      0, -- TrackR
      0, -- TillerMot
      bladeTransitionRemaining > 0 and 1024 or -1024,
      (
        tillerTransitionRemaining > 0 or
        reverseState == "lifting" or
        reverseState == "returning"
      ) and 1024 or -1024
  end


  -- ----------------------------------------------------------
  -- MODE TRANSITION DETECTION
  -- ----------------------------------------------------------

  if lastSd ~= nil
    and sd ~= lastSd
  then

    local from = lastSd
    local to   = sd


    -- Blade only changes base position when Transport
    -- is entered or exited.
    if from == -1024
      or to == -1024
    then

      bladeTransitionRemaining =
        bladeTransitionTime
    end


    -- Tiller only changes base position when Groom
    -- is entered or exited.
    if from == 1024
      or to == 1024
    then

      tillerTransitionRemaining =
        tillerTransitionTime

      -- Changing mode cancels an automatic backing sequence.
      reverseState = "idle"
      reverseRemaining = 0
    end

    lastSd = sd
  end


  -- ----------------------------------------------------------
  -- DECREMENT NORMAL TRANSITION TIMERS
  -- ----------------------------------------------------------

  if bladeTransitionRemaining > 0 then

    bladeTransitionRemaining =
      bladeTransitionRemaining - dt

    if bladeTransitionRemaining < 0 then
      bladeTransitionRemaining = 0
    end
  end


  if tillerTransitionRemaining > 0 then

    tillerTransitionRemaining =
      tillerTransitionRemaining - dt

    if tillerTransitionRemaining < 0 then
      tillerTransitionRemaining = 0
    end
  end


  -- ==========================================================
  -- AUTOMATIC REVERSE / TILLER LIFT
  -- ==========================================================

  local reverseRequested =
    isGroom and
    thr < -REVERSE_DEADBAND


  -- ----------------------------------------------------------
  -- START LIFT
  --
  -- Do not start reverse lift while the tiller is still
  -- completing the normal movement into Groom.
  -- ----------------------------------------------------------

  if reverseState == "idle"
    and reverseRequested
    and tillerTransitionRemaining <= 0
  then

    reverseState =
      "lifting"

    reverseRemaining =
      reverseLiftTime
  end


  -- ----------------------------------------------------------
  -- LIFTING
  -- ----------------------------------------------------------

  if reverseState == "lifting" then

    reverseRemaining =
      reverseRemaining - dt

    if reverseRemaining <= 0 then

      reverseRemaining = 0

      if reverseRequested then

        reverseState =
          "ready"

      else

        -- Reverse command was released before the lift
        -- completed. Finish the lift, then return.
        reverseState =
          "returning"

        reverseRemaining =
          reverseLiftTime
      end
    end


  -- ----------------------------------------------------------
  -- READY / BACKING
  -- ----------------------------------------------------------

  elseif reverseState == "ready" then

    if not reverseRequested then

      reverseState =
        "returning"

      reverseRemaining =
        reverseLiftTime
    end


  -- ----------------------------------------------------------
  -- RETURNING TO GROOM
  -- ----------------------------------------------------------

  elseif reverseState == "returning" then

    reverseRemaining =
      reverseRemaining - dt

    if reverseRemaining <= 0 then

      reverseRemaining = 0
      reverseState = "idle"
    end

  end


  -- ==========================================================
  -- TRANSITION STATUS
  -- ==========================================================

  local bladeTransitionActive =
    bladeTransitionRemaining > 0


  local reverseMovementActive =
    reverseState == "lifting"
    or reverseState == "returning"


  local tillerTransitionActive =
    tillerTransitionRemaining > 0
    or reverseMovementActive


  -- ==========================================================
  -- TILLER MOTOR SAFETY
  --
  -- Rotor is permitted only when:
  --
  --   • Groom mode
  --   • no normal tiller transition
  --   • no automatic reverse cycle
  --   • E-stop is not active
  --
  -- Reverse request locks rotor immediately, before physical
  -- lift movement begins.
  -- ==========================================================

  local tillerMotorEnable = 0

  if isGroom
    and tillerTransitionRemaining <= 0
    and reverseState == "idle"
  then

    tillerMotorEnable = 1024
  end


  -- ==========================================================
  -- TRACK CONTROL
  -- ==========================================================

  local speedScale =
    1 -
    (math.abs(thr) * SPEED_FACTOR)

  local rudCurve =
    rud * math.abs(rud)

  local turn =
    rudCurve *
    TURN_GAIN *
    speedScale


  -- ----------------------------------------------------------
  -- PIVOT + DRIVE BLENDING
  -- ----------------------------------------------------------

  local pivotBlend =
    clamp(
      math.abs(thr) * 2,
      0,
      1
    )

  local driveLeft =
    thr *
    (1 + turn * 0.7)

  local driveRight =
    thr *
    (1 - turn * 0.4)

  local pivotLeft =
    turn

  local pivotRight =
    -turn

  local left =
    (driveLeft * pivotBlend) +
    (pivotLeft * (1 - pivotBlend))

  local right =
    (driveRight * pivotBlend) +
    (pivotRight * (1 - pivotBlend))


  -- ----------------------------------------------------------
  -- THROTTLE CEILING
  -- ----------------------------------------------------------

  local maxT =
    math.abs(thr)

  left =
    clamp(
      left,
      -maxT,
      maxT
    )

  right =
    clamp(
      right,
      -maxT,
      maxT
    )


  -- ==========================================================
  -- REVERSE SAFETY
  --
  -- In Groom, negative track motion is permitted ONLY after
  -- the automatic tiller lift reaches "ready".
  -- ==========================================================

  local reverseAllowed =
    isGroom
    and reverseRequested
    and reverseState == "ready"


  if isGroom
    and not reverseAllowed
  then

    if left < 0 then
      left = 0
    end

    if right < 0 then
      right = 0
    end
  end


  -- ==========================================================
  -- NORMAL IMPLEMENT TRANSITION CREEP
  -- ==========================================================

  if bladeTransitionActive
    or tillerTransitionActive
  then

    left =
      left * TRANSITION_POWER

    right =
      right * TRANSITION_POWER
  end


  -- During the upward reverse clearance movement, reverse
  -- remains fully blocked regardless of the creep multiplier.
  if reverseState == "lifting" then

    if left < 0 then
      left = 0
    end

    if right < 0 then
      right = 0
    end
  end


  -- ==========================================================
  -- TRACK OUTPUT SMOOTHING
  -- ==========================================================

  local targetL =
    left * 1024

  local targetR =
    right * 1024


  local leftOut =
    smoothDirectional(
      lastL,
      targetL,
      ACCEL_RATE,
      DECEL_RATE,
      REVERSE_BOOST
    )


  local rightOut =
    smoothDirectional(
      lastR,
      targetR,
      ACCEL_RATE,
      DECEL_RATE,
      REVERSE_BOOST
    )


  lastL =
    leftOut

  lastR =
    rightOut


  -- ==========================================================
  -- OUTPUTS
  -- ==========================================================

  return
    leftOut,
    -rightOut,
    tillerMotorEnable,
    bladeTransitionActive and 1024 or -1024,
    tillerTransitionActive and 1024 or -1024
end


return {
  run = run,
  output = {
    "TrackL",
    "TrackR",
    "TillerMot",
    "BladeTr",
    "TillerTr"
  }
}