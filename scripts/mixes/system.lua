-- ============================================================
-- PB600 SYSTEM / TRACK / SAFETY CONTROL
--
-- Outputs:
--   1 TrackL
--   2 TrackR
--   3 TillerMot
--   4 BladeTr
--   5 TillerTr
--   6 EngOut
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
--  -1024 = motor locked out
--
-- HYDROSTATIC TARGETS:
--   0 -> full power   ~5.0 sec
--   full -> zero      ~2.0 sec
-- ============================================================


-- ============================================================
-- IMPLEMENT CALIBRATION
-- ============================================================

local BLADE_LIFT_DOWN_FULL = 11.0
local BLADE_LIFT_UP_FULL   = 17.0
local BLADE_ANGLE_FULL     = 6.7
local WING_FULL            = 3.75

local TILLER_LIFT_DOWN_FULL = 11.0
local TILLER_LIFT_UP_FULL   = 17.0
local TILLER_ANGLE_FULL     = 3.75
local FIN_FULL_TIME         = 2.0


-- Must match blade.lua
local WORK_WING_OPEN = 0.40
local WORK_ANGLE     = 0.50


-- ============================================================
-- TRACK / HYDROSTATIC TUNING
-- ============================================================

-- Overall steering authority.
local TURN_GAIN =
  0.40


-- Amount of steering authority removed at maximum
-- actual vehicle speed.
--
-- 0.30 means:
--
--   speed 0%   -> 100% steering retained
--   speed 25%  ->  92.5%
--   speed 50%  ->  85%
--   speed 75%  ->  77.5%
--   speed 100% ->  70%
--
-- IMPORTANT:
-- This is now based on estimated ACTUAL vehicle speed,
-- not throttle-stick position.
local SPEED_FACTOR =
  0.30


-- Throttle point at which the low-speed pivot component
-- has completely transitioned to normal differential drive.
--
-- 0.80 means:
--
--    0% throttle -> 100% pivot component
--   20% throttle ->  75% pivot component
--   40% throttle ->  50% pivot component
--   60% throttle ->  25% pivot component
--   80% throttle ->   0% pivot component
local PIVOT_BLEND_END =
  0.80


-- Time-based output rates in channel units per second.
--
-- 1024 / 205 ~= 5.0 sec
-- 1024 / 512 = 2.0 sec
local ACCEL_RATE =
  205

local DECEL_RATE =
  512


-- Additional pressure-dump rate while crossing zero
-- during a direction reversal.
--
-- Effective crossing-zero rate:
--   512 + 250 = 762 units/sec
--
-- Full power -> zero during reversal:
--   1024 / 762 ~= 1.34 sec
local REVERSE_BOOST =
  250


local RUDDER_DEADBAND =
  0.02

local REVERSE_DEADBAND =
  0.02


-- Track power while blade/tiller is repositioning.
local TRANSITION_POWER =
  0.25


-- ============================================================
-- STATE
-- ============================================================

local initialized =
  false

local lastSd =
  nil

local lastTime =
  getTime()


local bladeTransitionRemaining =
  0

local tillerTransitionRemaining =
  0


-- Current hydrostatically smoothed INTERNAL track outputs.
--
-- These are maintained before the physical Right-track
-- direction inversion at the final return statement.
local lastL =
  0

local lastR =
  0


-- ============================================================
-- AUTOMATIC REVERSE STATE
--
-- idle
-- lifting
-- ready
-- returning
-- ============================================================

local reverseState =
  "idle"


local reverseRemaining =
  0


-- ============================================================
-- HELPERS
-- ============================================================

local function clamp(
  v,
  lo,
  hi
)

  if v < lo then
    return lo
  end

  if v > hi then
    return hi
  end

  return v

end


local function normStick(v)

  if type(v) ~= "number" then
    return 0
  end


  -- EdgeTX sources may appear as +/-1024 or +/-100.
  if math.abs(v) > 100 then

    return
      v / 1024

  end


  return
    v / 100

end


-- ============================================================
-- TIME-BASED HYDROSTATIC SMOOTHING
--
-- accelRate / decelRate / reverseBoost are channel units/sec.
--
-- This makes response timing independent of Lua execution rate.
-- ============================================================

local function smoothDirectional(
  prev,
  target,
  accelRate,
  decelRate,
  reverseBoost,
  dt
)

  local delta =
    target - prev


  -- Already effectively at target.
  if math.abs(delta) < 1 then

    return
      target

  end


  local crossingZero =
    (prev > 0 and target < 0)
    or
    (prev < 0 and target > 0)


  local sameDirection =
    (prev >= 0 and target >= 0)
    or
    (prev <= 0 and target <= 0)


  local accelerating =
    sameDirection
    and
    (
      math.abs(target) >
      math.abs(prev)
    )


  local rate


  -- ----------------------------------------------------------
  -- DIRECTION REVERSAL
  --
  -- Simulates rapid hydrostatic pressure dump as output
  -- crosses through zero.
  -- ----------------------------------------------------------

  if crossingZero then

    rate =
      decelRate +
      reverseBoost


  -- ----------------------------------------------------------
  -- ACCELERATING
  --
  -- Pump builds pressure relatively slowly.
  -- ----------------------------------------------------------

  elseif accelerating then

    rate =
      accelRate


  -- ----------------------------------------------------------
  -- DECELERATING
  --
  -- Hydrostatic braking reduces power more quickly.
  -- ----------------------------------------------------------

  else

    rate =
      decelRate

  end


  local step =
    rate *
    dt


  -- Prevent overshooting the target.
  if math.abs(delta) <= step then

    return
      target

  end


  if delta > 0 then

    return
      prev + step

  else

    return
      prev - step

  end

end


-- ============================================================
-- MAIN
-- ============================================================

local function run()

  local now =
    getTime()


  local dt =
    (now - lastTime) /
    100


  lastTime =
    now


  -- Protect against unusual scheduler pauses.
  if dt < 0 then
    dt = 0
  end


  if dt > 0.25 then
    dt = 0.25
  end


  -- ==========================================================
  -- INPUTS
  -- ==========================================================

  local sd =
    getValue("sd") or 0


  local sf =
    getValue("sf") or 0


  local thr =
    normStick(
      getValue("thr")
    )


  local rud =
    normStick(
      getValue("rud")
    )


  if math.abs(rud) <
    RUDDER_DEADBAND
  then

    rud =
      0

  end


  local eStop =
    sf > 0


  local isGroom =
    sd > 500


  -- ==========================================================
  -- GLOBAL VARIABLES
  -- ==========================================================

  local bladeDepth =
    clamp(
      (getValue("gvar2") or 0) /
      100,
      0,
      1
    )


  local groomDepth =
    clamp(
      (getValue("gvar3") or 0) /
      100,
      0,
      1
    )


  local reverseLift =
    clamp(
      (getValue("gvar4") or 0) /
      100,
      0,
      1
    )


  local groomAngle =
    clamp(
      (getValue("gvar5") or 0) /
      100,
      0,
      1
    )


  -- ==========================================================
  -- IMPLEMENT TRANSITION TIMES
  --
  -- These mirror the physical movements commanded by
  -- blade.lua and tiller.lua.
  -- ==========================================================


  -- ----------------------------------------------------------
  -- BLADE
  -- ----------------------------------------------------------

  local bladeLiftDownTime =
    bladeDepth *
    BLADE_LIFT_DOWN_FULL


  local bladeLiftUpTime =
    bladeDepth *
    BLADE_LIFT_UP_FULL


  local bladeWingTime =
    WORK_WING_OPEN *
    WING_FULL


  local bladeAngleTime =
    WORK_ANGLE *
    BLADE_ANGLE_FULL


  -- ----------------------------------------------------------
  -- TILLER
  -- ----------------------------------------------------------

  local tillerLiftDownTime =
    groomDepth *
    TILLER_LIFT_DOWN_FULL


  local tillerLiftUpTime =
    groomDepth *
    TILLER_LIFT_UP_FULL


  local tillerAngleTime =
    groomAngle *
    TILLER_ANGLE_FULL


  -- ----------------------------------------------------------
  -- REVERSE CLEARANCE
  -- ----------------------------------------------------------

  local BLADE_REVERSE_LIFT_FACTOR =
    1.00


  local bladeReverseLift =
    reverseLift *
    BLADE_REVERSE_LIFT_FACTOR


  local bladeReverseLiftUpTime =
    bladeReverseLift *
    BLADE_LIFT_UP_FULL


  local tillerReverseLiftUpTime =
    reverseLift *
    TILLER_LIFT_UP_FULL


  local reverseLiftUpTime =
    math.max(
      bladeReverseLiftUpTime,
      tillerReverseLiftUpTime
    )


  local bladeReverseLiftDownTime =
    bladeReverseLift *
    BLADE_LIFT_DOWN_FULL


  local tillerReverseLiftDownTime =
    reverseLift *
    TILLER_LIFT_DOWN_FULL


  local reverseLiftDownTime =
    math.max(
      bladeReverseLiftDownTime,
      tillerReverseLiftDownTime
    )


  -- ==========================================================
  -- INITIALIZATION
  -- ==========================================================

  if not initialized then

    lastSd =
      sd


    initialized =
      true

  end


  -- ==========================================================
  -- E-STOP
  --
  -- Track outputs and tiller rotor go to zero immediately.
  --
  -- Timers intentionally do not advance while E-stop is held.
  -- ==========================================================

  if eStop then

    lastL =
      0

    lastR =
      0


    return
      0,       -- TrackL
      0,       -- TrackR
      -1024,   -- TillerMot

      bladeTransitionRemaining > 0
        and 1024
        or -1024,

      (
        tillerTransitionRemaining > 0
        or reverseState == "lifting"
        or reverseState == "returning"
      )
        and 1024
        or -1024,

      0        -- EngOut

  end


  -- ==========================================================
  -- MODE TRANSITION DETECTION
  -- ==========================================================

  if lastSd ~= nil
    and sd ~= lastSd
  then

    local from =
      lastSd


    local to =
      sd


    -- --------------------------------------------------------
    -- BLADE
    --
    -- Blade changes base position only when Transport is
    -- entered or exited.
    -- --------------------------------------------------------

    if from == -1024
      or to == -1024
    then

      if to == -1024 then

        -- Going TO Transport = blade raising
        bladeTransitionRemaining =
          math.max(
            bladeLiftUpTime,
            bladeWingTime,
            bladeAngleTime
          )

      else

        -- Leaving Transport = blade lowering
        bladeTransitionRemaining =
          math.max(
            bladeLiftDownTime,
            bladeWingTime,
            bladeAngleTime
          )

      end

    end


    -- --------------------------------------------------------
    -- TILLER
    --
    -- Tiller changes base position only when Groom is
    -- entered or exited.
    -- --------------------------------------------------------

    if from == 1024
      or to == 1024
    then

      if to == 1024 then

        -- Enter Groom = tiller lowering
        tillerTransitionRemaining =
          math.max(
            tillerLiftDownTime,
            tillerAngleTime,
            FIN_FULL_TIME
          )

      else

        -- Leave Groom = tiller raising
        tillerTransitionRemaining =
          math.max(
            tillerLiftUpTime,
            tillerAngleTime,
            FIN_FULL_TIME
          )

      end


      -- Mode change cancels automatic reverse sequence.
      reverseState =
        "idle"


      reverseRemaining =
        0

    end


    lastSd =
      sd

  end


  -- ==========================================================
  -- NORMAL TRANSITION TIMERS
  -- ==========================================================

  if bladeTransitionRemaining > 0 then

    bladeTransitionRemaining =
      bladeTransitionRemaining -
      dt


    if bladeTransitionRemaining < 0 then

      bladeTransitionRemaining =
        0

    end

  end


  if tillerTransitionRemaining > 0 then

    tillerTransitionRemaining =
      tillerTransitionRemaining -
      dt


    if tillerTransitionRemaining < 0 then

      tillerTransitionRemaining =
        0

    end

  end


  -- ==========================================================
  -- AUTOMATIC REVERSE / BLADE + TILLER LIFT
  -- ==========================================================

  local reverseRequested =
    isGroom
    and thr < -REVERSE_DEADBAND


  -- ----------------------------------------------------------
  -- START AUTO-LIFT
  --
  -- Do not begin until the normal transition into Groom has
  -- completed.
  -- ----------------------------------------------------------

  if reverseState == "idle"
    and reverseRequested
    and tillerTransitionRemaining <= 0
    and bladeTransitionRemaining <= 0
  then

    reverseState =
      "lifting"


    reverseRemaining =
      reverseLiftUpTime

  end


  -- ----------------------------------------------------------
  -- LIFTING
  -- ----------------------------------------------------------

  if reverseState == "lifting" then

    reverseRemaining =
      reverseRemaining -
      dt


    if reverseRemaining <= 0 then

      reverseRemaining =
        0


      if reverseRequested then

        reverseState =
          "ready"

      else

        -- Operator released reverse early.
        --
        -- Blade/Tiller scripts still complete their full lift
        -- before beginning their return.
        reverseState =
          "returning"


        reverseRemaining =
          reverseLiftDownTime

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
        reverseLiftDownTime

    end


  -- ----------------------------------------------------------
  -- RETURNING
  -- ----------------------------------------------------------

  elseif reverseState == "returning" then

    reverseRemaining =
      reverseRemaining -
      dt


    if reverseRemaining <= 0 then

      reverseRemaining =
        0


      reverseState =
        "idle"

    end

  end


  -- ==========================================================
  -- TRANSITION STATUS
  -- ==========================================================

  local reverseMovementActive =
    reverseState == "lifting"
    or reverseState == "returning"


  local bladeTransitionActive =
    bladeTransitionRemaining > 0
    or reverseMovementActive


  local tillerTransitionActive =
    tillerTransitionRemaining > 0
    or reverseMovementActive


  -- ==========================================================
  -- TILLER MOTOR SAFETY
  --
  -- Tiller rotor is allowed only:
  --
  --   Groom
  --   + normal tiller transition finished
  --   + no reverse lift/backing/return cycle active
  -- ==========================================================

  local tillerMotorEnable =
    -1024


  if isGroom
    and tillerTransitionRemaining <= 0
    and reverseState == "idle"
  then

    tillerMotorEnable =
      1024

  end


  -- ==========================================================
  -- TRACK CONTROL
  -- ==========================================================


  -- ----------------------------------------------------------
  -- ACTUAL VEHICLE SPEED ESTIMATE
  --
  -- Derive forward/reverse vehicle speed from the current
  -- HYDROSTATICALLY SMOOTHED track outputs.
  --
  -- We use the signed directional average:
  --
  --   vehicleSpeed =
  --       abs((lastL + lastR) / 2)
  --
  -- rather than average track magnitude.
  --
  -- This is important during a stationary pivot:
  --
  --   Left  = +40%
  --   Right = -40%
  --
  -- Average magnitude would incorrectly indicate 40% speed.
  --
  -- Directional average correctly gives:
  --
  --   (+40 + -40) / 2 = 0%
  --
  -- meaning the vehicle has essentially no longitudinal speed,
  -- so full steering authority remains available.
  -- ----------------------------------------------------------

  local vehicleSpeed =
    math.abs(
      (lastL + lastR) /
      2
    ) /
    1024


  vehicleSpeed =
    clamp(
      vehicleSpeed,
      0,
      1
    )


  -- ----------------------------------------------------------
  -- SPEED-BASED STEERING REDUCTION
  --
  -- Steering authority now follows actual vehicle movement
  -- rather than throttle-stick position.
  --
  -- SPEED_FACTOR = 0.30:
  --
  --   0% actual speed   = 100% steering
  --  25% actual speed   =  92.5%
  --  50% actual speed   =  85%
  --  75% actual speed   =  77.5%
  -- 100% actual speed   =  70%
  -- ----------------------------------------------------------

  local speedScale =
    1 -
    (
      vehicleSpeed *
      SPEED_FACTOR
    )


  -- ----------------------------------------------------------
  -- PROGRESSIVE RUDDER
  --
  -- Squared rudder response gives fine center-stick control
  -- while preserving strong steering near full stick.
  -- ----------------------------------------------------------

  local rudCurve =
    rud *
    math.abs(rud)


  local turn =
    rudCurve *
    TURN_GAIN *
    speedScale


  -- ==========================================================
  -- PIVOT + DRIVE BLENDING
  --
  -- At zero throttle:
  --     pure counter-rotating pivot
  --
  -- As throttle increases:
  --     progressively blend toward differential track drive.
  --
  -- NOTE:
  --
  -- Pivot blending is still based on throttle demand.
  --
  -- SPEED DAMPING is now based on actual hydrostatic speed.
  --
  -- These serve different purposes:
  --
  --   pivotBlend = type of steering geometry
  --   speedScale = amount of steering authority
  -- ==========================================================

  local pivotBlend =
    clamp(
      math.abs(thr) /
      PIVOT_BLEND_END,
      0,
      1
    )


  -- ----------------------------------------------------------
  -- MOVING DIFFERENTIAL DRIVE
  -- ----------------------------------------------------------

  local driveLeft =
    thr *
    (
      1 +
      turn * 0.7
    )


  local driveRight =
    thr *
    (
      1 -
      turn * 0.4
    )


  -- ----------------------------------------------------------
  -- STATIONARY / LOW-SPEED PIVOT
  -- ----------------------------------------------------------

  local pivotLeft =
    turn


  local pivotRight =
    -turn


  -- ----------------------------------------------------------
  -- BLEND THE TWO STEERING MODES
  -- ----------------------------------------------------------

  local left =
    (
      driveLeft *
      pivotBlend
    )
    +
    (
      pivotLeft *
      (1 - pivotBlend)
    )


  local right =
    (
      driveRight *
      pivotBlend
    )
    +
    (
      pivotRight *
      (1 - pivotBlend)
    )


  -- ==========================================================
  -- TRACK OUTPUT LIMITS
  --
  -- Do NOT limit to abs(throttle).
  --
  -- The previous throttle ceiling:
  --
  --   * prevented stationary pivot turns
  --   * clipped outside-track steering boost
  --
  -- Allow the mixer to use the complete track range.
  -- ==========================================================

  left =
    clamp(
      left,
      -1,
      1
    )


  right =
    clamp(
      right,
      -1,
      1
    )


  -- ==========================================================
  -- GROOM REVERSE SAFETY
  --
  -- Reverse track output is permitted only after the
  -- automatic blade/tiller clearance movement completes.
  -- ==========================================================

  local reverseAllowed =
    isGroom
    and reverseRequested
    and reverseState == "ready"


  if isGroom
    and not reverseAllowed
  then

    if left < 0 then

      left =
        0

    end


    if right < 0 then

      right =
        0

    end

  end


  -- ==========================================================
  -- IMPLEMENT TRANSITION CREEP
  -- ==========================================================

  if bladeTransitionActive
    or tillerTransitionActive
  then

    left =
      left *
      TRANSITION_POWER


    right =
      right *
      TRANSITION_POWER

  end


  -- ==========================================================
  -- REVERSE-LIFT HARD BLOCK
  --
  -- Even though transition creep is normally permitted,
  -- absolutely no reverse output is allowed while the
  -- blade/tiller reverse clearance lift is still occurring.
  -- ==========================================================

  if reverseState == "lifting" then

    if left < 0 then

      left =
        0

    end


    if right < 0 then

      right =
        0

    end

  end


  -- ==========================================================
  -- TRACK OUTPUT TARGETS
  -- ==========================================================

  local targetL =
    left *
    1024


  local targetR =
    right *
    1024


  -- ==========================================================
  -- TIME-BASED HYDROSTATIC OUTPUT SMOOTHING
  -- ==========================================================

  local leftOut =
    smoothDirectional(
      lastL,
      targetL,
      ACCEL_RATE,
      DECEL_RATE,
      REVERSE_BOOST,
      dt
    )


  local rightOut =
    smoothDirectional(
      lastR,
      targetR,
      ACCEL_RATE,
      DECEL_RATE,
      REVERSE_BOOST,
      dt
    )


  lastL =
    leftOut


  lastR =
    rightOut


  -- ============================================================
  -- ENGINE / SOUND CARD DRIVE SIGNAL
  --
  -- Models effective drivetrain load using actual hydrostatic
  -- track outputs rather than raw throttle.
  --
  -- 75% = highest track demand
  -- 25% = average track demand
  --
  -- This prevents engine RPM from dropping excessively when
  -- one track is slowed for steering.
  -- ============================================================

  local absL =
    math.abs(leftOut)


  local absR =
    math.abs(rightOut)


  local maxTrack =
    math.max(
      absL,
      absR
    )


  local avgTrack =
    (
      absL +
      absR
    ) /
    2


  local engineMagnitude =
    (
      maxTrack *
      0.75
    )
    +
    (
      avgTrack *
      0.25
    )


  -- Determine effective direction.
  --
  -- Normal reverse:
  -- both tracks are negative.
  --
  -- During a pivot the tracks oppose each other, so retain a
  -- positive engine/load signal rather than allowing cancellation.

  local engineOut


  if leftOut < 0
    and rightOut < 0
  then

    engineOut =
      -engineMagnitude

  else

    engineOut =
      engineMagnitude

  end


  -- Keep tiny residual values at idle from affecting sound.
  if math.abs(engineOut) < 10 then

    engineOut =
      0

  end


  -- ==========================================================
  -- OUTPUTS
  -- ==========================================================

  return

    leftOut,

    -- Right track physical direction is reversed.
    -rightOut,

    tillerMotorEnable,

    bladeTransitionActive
      and 1024
      or -1024,

    tillerTransitionActive
      and 1024
      or -1024,

    engineOut

end


return {

  run =
    run,


  output = {

    "TrackL",
    "TrackR",
    "TMotor",
    "TranB",
    "TranT",
    "EngOut"

  }

}