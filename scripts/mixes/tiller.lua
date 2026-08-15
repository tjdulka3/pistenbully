-- ============================================================
-- PB600 TILLER CONTROL
--
-- Outputs:
--   1 Tiller Angle
--   2 Tiller Lift
--   3 Left Finisher
--   4 Right Finisher
--
-- GV1 = Coordination intensity %
-- GV3 = Tiller Groom depth %
-- GV4 = Reverse auto-lift %
-- GV5 = Tiller working angle %
--
-- SD:
--   -1024 = Transport
--       0 = Plow
--    1024 = Groom
--
-- SC Down:
--   AIL = Tiller Angle
--   ELE = Tiller Lift
--
-- SE / SG = manual finishers
-- SB Up   = coordination enabled
-- SF Up   = E-stop
-- ============================================================


-- ============================================================
-- PHYSICAL CALIBRATION
-- ============================================================

local TILLER_LIFT_FULL  = 12.5
local TILLER_ANGLE_FULL = 3.75
local FIN_FULL_TIME     = 2.0

local INPUT_DEADBAND = 0.02

-- Tiller angle coordination range at GV1=100.
local ANGLE_COORD_RANGE = 0.10


-- ============================================================
-- OUTPUT DIRECTION
-- ============================================================

-- Entering Groom in the known-good script used:
--   internal lift direction -1
--   final output -liftOut
--
-- Therefore lowering the tiller produces + channel output.
local LIFT_SIGN  = -1

-- Entering Groom used positive tiller angle output.
local ANGLE_SIGN = 1


-- ============================================================
-- STATE
-- ============================================================

-- Lift position:
--   0  = fully raised
--  -1  = fully lowered
local liftPos = 0

-- Angle:
--   0 = raised/Transport-Plow reference
local anglePos = 0

-- Coordination offset is kept separately.
local coordAnglePos = 0

local initialized = false
local lastSd = nil
local lastTime = getTime()

local modeTransition = false

local modeLiftTarget  = 0
local modeAngleTarget = 0

local finMoveRemaining = 0
local finMoveDirection = 0


-- Reverse state:
--
-- idle
-- lifting
-- ready
-- returning
local reverseState = "idle"

-- Exact position before auto-lift.
local reverseReturnLift = 0

-- Target raised position for this reverse cycle.
local reverseLiftTarget = 0


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


local function moveToward(position, target, fullTime, outputSign, dt)

  local err = target - position

  if math.abs(err) < 0.001 then
    return target, 0, true
  end

  local step = dt / fullTime

  if step <= 0 then
    return position, 0, false
  end

  local direction

  if err > 0 then
    direction = 1
  else
    direction = -1
  end

  local done = false

  if math.abs(err) <= step then
    position = target
    done = true
  else
    position =
      position +
      (direction * step)
  end

  local output =
    direction *
    outputSign *
    1024

  return position, output, done
end


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

  local thr =
    deadband(normStick(getValue("thr")))

  local rud =
    deadband(normStick(getValue("rud")))

  local ail =
    deadband(normStick(getValue("ail")))

  local ele =
    deadband(normStick(getValue("ele")))

  local se =
    deadband(normStick(getValue("se")))

  local sg =
    deadband(normStick(getValue("sg")))

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

  local groomDepth =
    clamp((getValue("gvar3") or 0) / 100, 0, 1)

  local reverseLift =
    clamp((getValue("gvar4") or 0) / 100, 0, 1)

  local groomAngle =
    clamp((getValue("gvar5") or 0) / 100, 0, 1)


  -- ----------------------------------------------------------
  -- INITIALIZE WITHOUT MOVEMENT
  -- ----------------------------------------------------------

  if not initialized then

    if inGroom then
      liftPos  = -groomDepth
      anglePos = groomAngle
    else
      liftPos  = 0
      anglePos = 0
    end

    lastSd = sd
    initialized = true
  end


  -- ----------------------------------------------------------
  -- E-STOP
  -- ----------------------------------------------------------

  if eStop then

    return
      0, -- Angle
      0, -- Lift
      0, -- FinL
      0  -- FinR
  end


  -- ----------------------------------------------------------
  -- MODE TRANSITIONS
  --
  -- Tiller moves only when Groom is entered or exited.
  -- ----------------------------------------------------------

  if lastSd ~= nil and sd ~= lastSd then

    local from = lastSd
    local to   = sd

    if to == 1024 then

      -- ENTER GROOM
      modeLiftTarget  = -groomDepth
      modeAngleTarget = groomAngle

      modeTransition = true

      finMoveRemaining = FIN_FULL_TIME
      finMoveDirection = -1


    elseif from == 1024 then

      -- LEAVE GROOM
      modeLiftTarget  = 0
      modeAngleTarget = 0

      modeTransition = true

      finMoveRemaining = FIN_FULL_TIME
      finMoveDirection = 1

      reverseState = "idle"
    end

    lastSd = sd
  end


  -- ----------------------------------------------------------
  -- OUTPUTS
  -- ----------------------------------------------------------

  local angleCmd = 0
  local liftCmd  = 0
  local finLCmd  = 0
  local finRCmd  = 0


  -- ==========================================================
  -- NORMAL MODE TRANSITION
  -- ==========================================================

  if modeTransition then

    local liftDone
    local angleDone

    liftPos, liftCmd, liftDone =
      moveToward(
        liftPos,
        modeLiftTarget,
        TILLER_LIFT_FULL,
        LIFT_SIGN,
        dt
      )

    anglePos, angleCmd, angleDone =
      moveToward(
        anglePos,
        modeAngleTarget,
        TILLER_ANGLE_FULL,
        ANGLE_SIGN,
        dt
      )

    if finMoveRemaining > 0 then

      finMoveRemaining =
        finMoveRemaining - dt

      finLCmd =
        finMoveDirection * 1024

      finRCmd =
        finMoveDirection * 1024

      if finMoveRemaining <= 0 then
        finMoveRemaining = 0
      end
    end


    if liftDone
      and angleDone
      and finMoveRemaining <= 0
    then

      modeTransition = false
    end


  -- ==========================================================
  -- REVERSE AUTO-LIFT
  -- ==========================================================

  elseif inGroom then

    local reverseRequested =
      thr < -INPUT_DEADBAND


    -- Start automatic lift.
    if reverseState == "idle"
      and reverseRequested
    then

      reverseReturnLift =
        liftPos

      -- Raise toward zero by GV4 percent of full travel.
      reverseLiftTarget =
        math.min(
          0,
          reverseReturnLift + reverseLift
        )

      reverseState = "lifting"
    end


    -- --------------------------------------
    -- LIFTING
    -- --------------------------------------

    if reverseState == "lifting" then

      local done

      liftPos, liftCmd, done =
        moveToward(
          liftPos,
          reverseLiftTarget,
          TILLER_LIFT_FULL,
          LIFT_SIGN,
          dt
        )

      if done then

        if reverseRequested then
          reverseState = "ready"
        else
          reverseState = "returning"
        end
      end


    -- --------------------------------------
    -- READY / HOLDING WHILE BACKING
    -- --------------------------------------

    elseif reverseState == "ready" then

      liftCmd = 0

      if not reverseRequested then
        reverseState = "returning"
      end


    -- --------------------------------------
    -- RETURNING TO EXACT PRE-REVERSE HEIGHT
    -- --------------------------------------

    elseif reverseState == "returning" then

      local done

      liftPos, liftCmd, done =
        moveToward(
          liftPos,
          reverseReturnLift,
          TILLER_LIFT_FULL,
          LIFT_SIGN,
          dt
        )

      if done then
        reverseState = "idle"
      end

    end


    -- ========================================================
    -- MANUAL TILLER CONTROL
    --
    -- Only when no automatic reverse movement is active.
    -- ========================================================

    if reverseState == "idle"
      and sc > 500
    then

      -- SC DOWN:
      -- ELE = Lift
      -- AIL = Angle

      liftCmd =
        ele * 1024

      angleCmd =
        ail * 1024

      liftPos =
        manualPosition(
          liftPos,
          ele,
          TILLER_LIFT_FULL,
          LIFT_SIGN,
          dt
        )

      anglePos =
        manualPosition(
          anglePos,
          ail,
          TILLER_ANGLE_FULL,
          ANGLE_SIGN,
          dt
        )
    end


    -- Manual finishers when no mode transition is running.
    finLCmd =
      se * 1024

    finRCmd =
      sg * 1024


    -- ========================================================
    -- TILLER ANGLE COORDINATION
    -- ========================================================

    local desiredCoordAngle = 0

    if coordEnabled
      and reverseState == "idle"
      and math.abs(ail) < INPUT_DEADBAND
    then

      desiredCoordAngle =
        rud *
        ANGLE_COORD_RANGE *
        gCoord
    end

    local coordCmd

    coordAnglePos, coordCmd =
      moveToward(
        coordAnglePos,
        desiredCoordAngle,
        TILLER_ANGLE_FULL,
        ANGLE_SIGN,
        dt
      )

    angleCmd =
      angleCmd + coordCmd


  else

    -- Not Groom:
    -- Manual finishers still available if desired.
    finLCmd =
      se * 1024

    finRCmd =
      sg * 1024

  end


  -- ==========================================================
  -- FINAL OUTPUT
  -- ==========================================================

  return
    clamp1024(angleCmd),
    clamp1024(liftCmd),
    clamp1024(finLCmd),
    clamp1024(finRCmd)
end


return {
  run = run,
  output = {
    "TAng",
    "TLift",
    "FinL",
    "FinR"
  }
}