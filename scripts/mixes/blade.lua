-- ============================================================
-- PB600 BLADE CONTROL
--
-- Outputs:
--   1 Lift
--   2 Tilt
--   3 Angle
--   4 Slew
--   5 Left Wing
--   6 Right Wing
--
-- GV1 = Coordination intensity %
-- GV2 = Blade working depth %
-- GV4 = Reverse auto-lift %
--
-- SD:
--   -1024 = Transport
--       0 = Plow
--    1024 = Groom
--
-- SC:
--   Up    = ELE Lift / AIL Tilt
--   Middle= AIL Slew / ELE Angle
--
-- LS / RS = manual wings
-- SB Up   = coordination enabled
-- SF Up   = E-stop
-- ============================================================


-- ============================================================
-- PHYSICAL CALIBRATION / CODE TUNING
-- ============================================================

local LIFT_DOWN_FULL_TIME = 11.0
local LIFT_UP_FULL_TIME   = 17.0

-- Blade reverse lift relative to GV4.
--
-- 1.00 = same percentage as tiller
-- 1.50 = 50% more blade lift than GV4
-- 0.75 = 25% less blade lift than GV4
local BLADE_REVERSE_LIFT_FACTOR = 1.00

local TILT_FULL_TIME  = 5.0
local ANGLE_FULL_TIME = 6.7
local SLEW_FULL_TIME  = 6.7
local WING_FULL_TIME  = 3.75

local INPUT_DEADBAND = 0.02

-- Default non-Transport blade geometry.
-- These normally should not need live adjustment.
local WORK_WING_OPEN = 0.40
local WORK_ANGLE     = -0.50

-- Coordination ranges as fractions of full actuator stroke.
-- GV1 scales all of these together.
local COORD_WING_RANGE  = 0.15
local COORD_SLEW_RANGE  = 0.12
local COORD_TILT_RANGE  = 0.08
local COORD_ANGLE_RANGE = 0.10

local COORD_RUD_DEADBAND = 0.12

-- ============================================================
-- OUTPUT DIRECTION CALIBRATION
--
-- These preserve the directions used by the working scripts.
-- Change only if an actuator moves backwards.
-- ============================================================

local LIFT_SIGN  =  -1
local TILT_SIGN  =  1
local ANGLE_SIGN =  1
local SLEW_SIGN  =  1
local LW_SIGN    =  1
local RW_SIGN    =  1


-- ============================================================
-- STATE
-- ============================================================

-- Physical-position estimate.
--
-- Lift:
--   0 = Transport/full up
--  -1 = Full down
--
-- Wings:
--   0 = closed
--   1 = fully open
--
-- Tilt/Slew/Angle:
--   0 = centered/Transport reference
local pos = {
  lift  = 0,
  tilt  = 0,
  angle = 0,
  slew  = 0,
  lw    = 0,
  rw    = 0
}

-- Separate coordination offsets so returning the rudder to
-- center returns the coordinated motion without changing the
-- operator's manually selected base position.
local coordPos = {
  tilt  = 0,
  angle = 0,
  slew  = 0,
  lw    = 0,
  rw    = 0
}

local initialized = false
local lastSd = nil
local lastTime = getTime()

local modeTransition = false

-- ============================================================
-- REVERSE AUTO-LIFT STATE
--
-- idle
-- lifting
-- ready
-- returning
-- ============================================================

local reverseState = "idle"

-- Exact blade height before reverse lift begins.
local reverseReturnLift = 0

-- Raised blade target for the current reverse cycle.
local reverseLiftTarget = 0

local modeTarget = {
  lift  = 0,
  tilt  = 0,
  angle = 0,
  slew  = 0,
  lw    = 0,
  rw    = 0
}


-- ============================================================
-- HELPERS
-- ============================================================

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end


local function clamp1024(v)
  return clamp(v, -1024, 1024)
end


-- Handles either +/-1024 or +/-100 source scaling.
local function normStick(v)

  if type(v) ~= "number" then
    return 0
  end

  if math.abs(v) > 100 then
    return v / 1024
  end

  return v / 100
end


local function deadband(v)

  if math.abs(v) < INPUT_DEADBAND then
    return 0
  end

  return v
end


-- Move an internally modeled actuator position toward a target.
--
-- Positions are expressed as fractions of full actuator stroke.
-- fullTime is full-stroke travel time.
--
-- Returns:
--   newPosition, channelOutput
local function moveToward(position, target, fullTime, outputSign, dt)

  local err = target - position

  if math.abs(err) < 0.001 then
    return target, 0
  end

  local step = dt / fullTime

  if step <= 0 then
    return position, 0
  end

  local direction

  if err > 0 then
    direction = 1
  else
    direction = -1
  end

  if math.abs(err) <= step then
    position = target
  else
    position = position + (direction * step)
  end

  local output =
    direction * outputSign * 1024

  return position, output
end


-- Blade lift uses different calibrated travel times up vs. down.
local function moveLiftToward(position, target, dt)

  local err = target - position

  if math.abs(err) < 0.001 then
    return target, 0
  end

  local direction
  local fullTime

  if err > 0 then
    -- Toward zero = raising
    direction = 1
    fullTime = LIFT_UP_FULL_TIME
  else
    -- More negative = lowering
    direction = -1
    fullTime = LIFT_DOWN_FULL_TIME
  end

  local step = dt / fullTime

  if step <= 0 then
    return position, 0
  end

  if math.abs(err) <= step then
    position = target
  else
    position = position + (direction * step)
  end

  return position, direction * LIFT_SIGN * 1024
end


-- Keep the modeled blade-lift position synchronized during manual motion.
local function manualLiftPosition(position, command, dt)

  if command == 0 then
    return position
  end

  local physicalDirection = command / LIFT_SIGN
  local fullTime

  if physicalDirection > 0 then
    fullTime = LIFT_UP_FULL_TIME
  else
    fullTime = LIFT_DOWN_FULL_TIME
  end

  position = position + (physicalDirection * dt / fullTime)

  return clamp(position, -1, 0)
end


-- Update position estimate while an operator directly drives an axis.
local function manualPosition(position, command, fullTime, outputSign, dt)

  if command == 0 then
    return position
  end

  local physicalDirection =
    command / outputSign

  position =
    position +
    (physicalDirection * dt / fullTime)

  return clamp(position, -1, 1)
end


local function setModeTarget(sd, bladeDepth)

  if sd == -1024 then

    -- TRANSPORT
    modeTarget.lift  = 0
    modeTarget.tilt  = 0
    modeTarget.angle = 0
    modeTarget.slew  = 0
    modeTarget.lw    = 0
    modeTarget.rw    = 0

  else

    -- PLOW / GROOM working geometry
    modeTarget.lift  = -bladeDepth
    modeTarget.tilt  = 0
    modeTarget.angle = WORK_ANGLE
    modeTarget.slew  = 0
    modeTarget.lw    = WORK_WING_OPEN
    modeTarget.rw    = WORK_WING_OPEN

  end
end

local function applyDeadband(v, db)

  if math.abs(v) <= db then
    return 0
  end

  local sign = (v >= 0) and 1 or -1

  return sign *
    ((math.abs(v) - db) / (1 - db))
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

  local sd = getValue("sd") or 0
  local sc = getValue("sc") or 0
  local sb = getValue("sb") or 0
  local sf = getValue("sf") or 0

  local ail = deadband(normStick(getValue("ail")))
  local ele = deadband(normStick(getValue("ele")))

  local thr =
  deadband(
    normStick(getValue("thr"))
  )

  local rud =
    applyDeadband(
      normStick(getValue("rud")),
      COORD_RUD_DEADBAND
    )

  local ls = deadband(normStick(getValue("ls")))
  local rs = deadband(normStick(getValue("rs")))

  local eStop =
    sf > 0

  local inGroom =
    sd > 500

  local coordEnabled =
    inGroom and sb > 500


  -- ----------------------------------------------------------
  -- GLOBAL VARIABLES
  -- ----------------------------------------------------------

  local gCoord =
    clamp((getValue("gvar1") or 0) / 100, 0, 1)

  local bladeDepth =
    clamp((getValue("gvar2") or 0) / 100, 0, 1)

  local reverseLift =
    clamp(
      (getValue("gvar4") or 0) / 100,
      0,
      1
    )

  local bladeReverseLift =
    reverseLift *
    BLADE_REVERSE_LIFT_FACTOR

  -- ----------------------------------------------------------
  -- INITIALIZATION
  --
  -- Avoids unexplained actuator motion immediately after
  -- loading/rebooting the radio.
  -- ----------------------------------------------------------

  if not initialized then

    setModeTarget(sd, bladeDepth)

    pos.lift  = modeTarget.lift
    pos.tilt  = modeTarget.tilt
    pos.angle = modeTarget.angle
    pos.slew  = modeTarget.slew
    pos.lw    = modeTarget.lw
    pos.rw    = modeTarget.rw

    lastSd = sd
    initialized = true
  end


  -- ----------------------------------------------------------
  -- E-STOP
  --
  -- Do not advance modeled actuator positions while stopped.
  -- ----------------------------------------------------------

  if eStop then

    return
      0, -- Lift
      0, -- Tilt
      0, -- Angle
      0, -- Slew
      0, -- LW
      0  -- RW
  end


  -- ----------------------------------------------------------
  -- MODE TRANSITION DETECTION
  --
  -- Blade automatically moves only when Transport is involved.
  -- Plow <-> Groom does not reposition the base blade.
  -- ----------------------------------------------------------

  if lastSd ~= nil and sd ~= lastSd then

    if lastSd == -1024 or sd == -1024 then

      setModeTarget(sd, bladeDepth)
      modeTransition = true

      -- Remove old coordination before moving modes.
      coordPos.tilt  = 0
      coordPos.angle = 0
      coordPos.slew  = 0
      coordPos.lw    = 0
      coordPos.rw    = 0
    end

    -- Any mode change out of Groom cancels the dedicated
    -- reverse-clearance state. Normal mode positioning then
    -- takes authority over blade lift.
    if sd <= 500 then
      reverseState = "idle"
    end

    lastSd = sd
  end


  -- ----------------------------------------------------------
  -- OUTPUT COMMANDS
  -- ----------------------------------------------------------

  local liftCmd  = 0
  local tiltCmd  = 0
  local angleCmd = 0
  local slewCmd  = 0
  local lwCmd    = 0
  local rwCmd    = 0


  -- ==========================================================
  -- AUTOMATIC MODE TRANSITION
  -- ==========================================================

  if modeTransition then

    pos.lift, liftCmd =
      moveLiftToward(
        pos.lift,
        modeTarget.lift,
        dt
      )

    pos.angle, angleCmd =
      moveToward(
        pos.angle,
        modeTarget.angle,
        ANGLE_FULL_TIME,
        ANGLE_SIGN,
        dt
      )

    pos.lw, lwCmd =
      moveToward(
        pos.lw,
        modeTarget.lw,
        WING_FULL_TIME,
        LW_SIGN,
        dt
      )

    pos.rw, rwCmd =
      moveToward(
        pos.rw,
        modeTarget.rw,
        WING_FULL_TIME,
        RW_SIGN,
        dt
      )


    local finished =
      pos.lift  == modeTarget.lift
      and pos.angle == modeTarget.angle
      and pos.lw == modeTarget.lw
      and pos.rw == modeTarget.rw

    if finished then
      modeTransition = false
    end

  else
    -- ==========================================================
    -- REVERSE AUTO-LIFT
    -- ==========================================================

    local reverseRequested =
      inGroom
      and thr < -INPUT_DEADBAND


    -- ----------------------------------------------------------
    -- START REVERSE LIFT
    -- ----------------------------------------------------------

    if reverseState == "idle"
      and reverseRequested
    then

      -- Remember EXACTLY where the blade was before reverse.
      reverseReturnLift =
        pos.lift

      -- Raise by GV4 percentage, limited by physical upper home.
      reverseLiftTarget =
        math.min(
          0,
          reverseReturnLift + bladeReverseLift
        )

      reverseState =
        "lifting"
    end


    -- ----------------------------------------------------------
    -- LIFTING
    -- ----------------------------------------------------------

    if reverseState == "lifting" then

      pos.lift, liftCmd =
        moveLiftToward(
          pos.lift,
          reverseLiftTarget,
          dt
        )

      -- moveLiftToward() does not return a done flag in your
      -- blade script, so determine completion from position.
      if math.abs(
          pos.lift - reverseLiftTarget
        ) < 0.001
      then

        if reverseRequested then

          reverseState =
            "ready"

        else

          -- Reverse was released before blade finished rising.
          -- Finish the entire lift first, then return.
          reverseState =
            "returning"

        end
      end


    -- ----------------------------------------------------------
    -- HOLD WHILE BACKING
    -- ----------------------------------------------------------

    elseif reverseState == "ready" then

      liftCmd = 0

      if not reverseRequested then

        reverseState =
          "returning"

      end


    -- ----------------------------------------------------------
    -- RETURN TO EXACT PRE-REVERSE HEIGHT
    -- ----------------------------------------------------------

    elseif reverseState == "returning" then

      pos.lift, liftCmd =
        moveLiftToward(
          pos.lift,
          reverseReturnLift,
          dt
        )

      if math.abs(
          pos.lift - reverseReturnLift
        ) < 0.001
      then

        reverseState =
          "idle"

      end

    end

  -- ==========================================================
  -- MANUAL BLADE CONTROL
  -- ==========================================================
 
  -- ==========================================================
    -- MANUAL BLADE CONTROL
    --
    -- Suppressed during reverse lift/hold/return so an operator
    -- input cannot fight the automatic clearance movement.
    -- ==========================================================
    if reverseState == "idle" then

      -- SC UP:
      -- ELE = Lift
      -- AIL = Tilt
      if sc < -500 then

        liftCmd =
          ele * 1024

        tiltCmd =
          ail * 1024

        pos.lift =
          manualLiftPosition(
            pos.lift,
            ele,
            dt
          )

        pos.tilt =
          manualPosition(
            pos.tilt,
            ail,
            TILT_FULL_TIME,
            TILT_SIGN,
            dt
          )


      elseif math.abs(sc) <= 500 then

        slewCmd =
          ail * 1024

        angleCmd =
          ele * 1024

        pos.slew =
          manualPosition(
            pos.slew,
            ail,
            SLEW_FULL_TIME,
            SLEW_SIGN,
            dt
          )

        pos.angle =
          manualPosition(
            pos.angle,
            ele,
            ANGLE_FULL_TIME,
            ANGLE_SIGN,
            dt
          )

      end


      -- Wings remain manually available.
      lwCmd =
        ls * 1024

      rwCmd =
        rs * 1024

      pos.lw =
        manualPosition(
          pos.lw,
          ls,
          WING_FULL_TIME,
          LW_SIGN,
          dt
        )

      pos.rw =
        manualPosition(
          pos.rw,
          rs,
          WING_FULL_TIME,
          RW_SIGN,
          dt
        )

    end
  end

  -- ==========================================================
  -- GROOM COORDINATION
  --
  -- Coordination has authority ONLY during normal Groom
  -- operation.  It is completely suppressed during:
  --
  --   * Mode transitions
  --   * Reverse auto-lift
  --   * Reverse hold
  --   * Reverse return
  --
  -- This prevents coordination outputs from being added to
  -- automatic positioning outputs.
  -- ==========================================================

  if coordEnabled
    and not modeTransition
    and reverseState == "idle"
  then

    local desiredLW =
      rud * COORD_WING_RANGE * gCoord

    local desiredRW =
      -rud * COORD_WING_RANGE * gCoord

    local desiredSlew =
      rud * COORD_SLEW_RANGE * gCoord

    local desiredTilt =
      rud * COORD_TILT_RANGE * gCoord

    local desiredAngle =
      math.abs(rud) *
      COORD_ANGLE_RANGE *
      gCoord


    local coordCmd


    coordPos.lw, coordCmd =
      moveToward(
        coordPos.lw,
        desiredLW,
        WING_FULL_TIME,
        LW_SIGN,
        dt
      )

    lwCmd =
      lwCmd + coordCmd


    coordPos.rw, coordCmd =
      moveToward(
        coordPos.rw,
        desiredRW,
        WING_FULL_TIME,
        RW_SIGN,
        dt
      )

    rwCmd =
      rwCmd + coordCmd


    coordPos.slew, coordCmd =
      moveToward(
        coordPos.slew,
        desiredSlew,
        SLEW_FULL_TIME,
        SLEW_SIGN,
        dt
      )

    slewCmd =
      slewCmd + coordCmd


    coordPos.tilt, coordCmd =
      moveToward(
        coordPos.tilt,
        desiredTilt,
        TILT_FULL_TIME,
        TILT_SIGN,
        dt
      )

    tiltCmd =
      tiltCmd + coordCmd


    coordPos.angle, coordCmd =
      moveToward(
        coordPos.angle,
        desiredAngle,
        ANGLE_FULL_TIME,
        ANGLE_SIGN,
        dt
      )

    angleCmd =
      angleCmd + coordCmd

  end

  -- ==========================================================
  -- FINAL OUTPUT
  -- ==========================================================

  return
    clamp1024(liftCmd),
    clamp1024(tiltCmd),
    clamp1024(angleCmd),
    clamp1024(slewCmd),
    clamp1024(lwCmd),
    clamp1024(rwCmd)
end


return {
  run = run,
  output = {
    "Lift",
    "Tilt",
    "Angle",
    "Slew",
    "LW",
    "RW"
  }
}