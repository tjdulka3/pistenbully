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
--   Throttle -> speed uses a smooth S-curve
--   0 -> full power   ~5.0 sec, S-shaped acceleration
--   full -> zero      ~2.0 sec, linear hydrostatic braking
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

-- Steering blends a throttle-scaled rudder deadband and rescaled rudder
-- input. Full-rudder authority decays linearly between the ratios implied by
-- the 1.5 ft low-speed and 10 ft full-speed turn-radius targets. The final differential is multiplied by drive demand,
-- so a stationary pivot is not commanded at zero throttle.
local TRACK_CENTER_SPACING_FT =
  3.0

local PIVOT_RADIUS_FT =
  TRACK_CENTER_SPACING_FT / 2.0

local FULL_TURN_RADIUS_FT =
  10.0

local LOW_SPEED_TURN_RATIO =
  1.0

local FULL_SPEED_TURN_RATIO =
  PIVOT_RADIUS_FT /
  FULL_TURN_RADIUS_FT

local TURN_GAIN =
  1.0


-- The old speed-taper steering reduction is intentionally replaced by the
-- geometric turn model above. The system still keeps a small deadband for
-- stick noise, but steering authority is now defined by the required turn
-- radius rather than a speed-dependent scaling factor.
local THROTTLE_DEADBAND_MIN =
  0.020

local THROTTLE_DEADBAND_MAX =
  0.100


-- Time-based hydrostatic output rates.
--
-- Acceleration now uses an S-shaped rate profile:
--
--   start of acceleration -> 60% of base rate
--   middle              -> 140% of base rate
--   end                 -> 60% of base rate
--
-- ACCEL_RATE is calibrated so a 0 -> 100% straight-line
-- acceleration still takes approximately 5 seconds overall.
--
-- Deceleration remains intentionally faster and linear.
local ACCEL_RATE =
  191

local ACCEL_MIN_MULT =
  0.60

local ACCEL_MID_BOOST =
  0.80

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


-- Current INTERNAL track outputs.
--
-- Longitudinal motion is hydrostatically smoothed while the
-- steering differential is applied immediately.
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


  -- EdgeTX stick sources are signed (-1024 .. 1024). Positive intermediate
  -- values must remain positive; treating them as an unsigned source centered
  -- at 512 would incorrectly command reverse below approximately half stick.
  if math.abs(v) > 100 then

    return
      v / 1024

  end


  return
    v / 100

end


-- ============================================================
-- THROTTLE -> VEHICLE SPEED DEMAND CURVE
--
-- Real hydrostatic travel control is not modeled as a simple
-- linear throttle-to-track-speed relationship.
--
-- Use a smoothstep curve:
--
--   y = 3x^2 - 2x^3
--
-- Approximate demand points:
--
--    0% throttle ->   0% speed demand
--   20% throttle ->  10% speed demand
--   40% throttle ->  35% speed demand
--   50% throttle ->  50% speed demand
--   60% throttle ->  65% speed demand
--   80% throttle ->  90% speed demand
--  100% throttle -> 100% speed demand
--
-- This gives finer low-speed control, stronger mid-range
-- response, and a gentle taper toward maximum travel speed.
--
-- Sign is preserved for reverse.
-- ============================================================

local function throttleToSpeedDemand(throttle)

  local sign =
    throttle < 0
      and -1
      or 1


  local x =
    clamp(
      math.abs(throttle),
      0,
      1
    )


  -- Direct speed demand from the requested throttle.
  -- The turning geometry is handled separately and is the
  -- source of truth for the left/right track split.
  return
    x *
    sign

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

    -- --------------------------------------------------------
    -- HYDROSTATIC ACCELERATION S-CURVE
    --
    -- Rate starts softly, builds through the middle of the
    -- acceleration event, then tapers as the requested track
    -- speed is approached.
    --
    -- For a 0 -> full-power command:
    --
    --   start  ~= 115 units/sec
    --   middle ~= 267 units/sec
    --   finish ~= 115 units/sec
    --
    -- Total full-range acceleration remains about 5 seconds.
    -- --------------------------------------------------------

    local targetMagnitude =
      math.abs(target)


    local progress =
      0


    if targetMagnitude > 1 then

      progress =
        clamp(
          math.abs(prev) /
          targetMagnitude,
          0,
          1
        )

    end


    -- 4p(1-p) is 0 at both ends and 1 at the midpoint.
    local middleShape =
      4 *
      progress *
      (1 - progress)


    local accelMultiplier =
      ACCEL_MIN_MULT +
      ACCEL_MID_BOOST *
      middleShape


    rate =
      accelRate *
      accelMultiplier


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
  --
  -- Steering model:
  --
  --   1) rudder deadband widens from 2% to 10% with throttle
  --   2) remaining rudder is rescaled to retain full travel
  --   3) full-rudder turn ratio decays linearly from 1.0 to 0.15 with throttle
  -- ==========================================================

  local throttleNorm =
    clamp(
      math.abs(thr),
      0,
      1
    )


  local rudderNorm =
    clamp(
      math.abs(rud),
      0,
      1
    )


  local deadband =
    0.02 +
    (0.10 - 0.02) *
    throttleNorm


  local effectiveRudder =
    0


  if rudderNorm > deadband then

    effectiveRudder =
      (rudderNorm - deadband) /
      (1 - deadband)

    if rud < 0 then
      effectiveRudder = -effectiveRudder
    end

  end


  local fullRudderTurnRatio =
    LOW_SPEED_TURN_RATIO +
    (
      FULL_SPEED_TURN_RATIO -
      LOW_SPEED_TURN_RATIO
    ) *
    throttleNorm


  local turnRatio =
    0


  if math.abs(effectiveRudder) > 0 then

    turnRatio =
      fullRudderTurnRatio *
      effectiveRudder

  end


  local drive =
    throttleToSpeedDemand(
      thr
    )


  if math.abs(thr) < THROTTLE_DEADBAND_MIN then
    drive = 0
  end


  local leftCmd =
    drive *
    (1 + turnRatio)


  local rightCmd =
    drive *
    (1 - turnRatio)


  leftCmd =
    clamp(
      leftCmd,
      -1,
      1
    )


  rightCmd =
    clamp(
      rightCmd,
      -1,
      1
    )


  local reverseAllowed =
    isGroom
    and reverseRequested
    and reverseState == "ready"


  if isGroom
    and not reverseAllowed
  then

    if leftCmd < 0 then
      leftCmd = 0
    end

    if rightCmd < 0 then
      rightCmd = 0
    end

  end


  if reverseState == "lifting" then

    if leftCmd < 0 then
      leftCmd = 0
    end

    if rightCmd < 0 then
      rightCmd = 0
    end

  end


  local leftOut =
    leftCmd *
    1024


  local rightOut =
    rightCmd *
    1024


  leftOut =
    clamp(
      leftOut,
      -1024,
      1024
    )


  rightOut =
    clamp(
      rightOut,
      -1024,
      1024
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