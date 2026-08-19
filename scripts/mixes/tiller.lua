-- ============================================================
-- PB600 TILLER CONTROL
--
-- Outputs:
--   1 Tiller Angle
--   2 Tiller Lift
--   3 Left Finisher
--   4 Right Finisher
--   5 Tiller Swing Coordination
--
-- GV1 = Coordination intensity %
-- GV3 = Tiller Groom depth %
-- GV4 = Blade/Tiller reverse auto-lift %
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
-- SB:
--   -1024 = Up      = Manual Swing via S2 radio mix
--       0 = Neutral = Coordinated Swing only
--    1024 = Down    = Coordinated Swing +
--                      Blade/Tiller coordination
--
-- SE / SG = manual finishers
-- SF Up   = E-stop
-- ============================================================


-- ============================================================
-- PHYSICAL CALIBRATION
-- ============================================================

local TILLER_LIFT_DOWN_FULL = 11.0
local TILLER_LIFT_UP_FULL   = 17.0

local TILLER_ANGLE_FULL =
  3.75

local FIN_FULL_TIME =
  2.0


local INPUT_DEADBAND =
  0.02


-- Tiller angle coordination range at GV1=100%.
local ANGLE_COORD_RANGE =
  0.10


-- Larger deadband for implement coordination so small incidental
-- rudder movement does not move the tiller angle.
local COORD_RUD_DEADBAND =
  0.12


-- Swing uses a smaller deadband so it responds naturally to turns.
local SWING_RUD_DEADBAND =
  0.05


-- Maximum coordinated swing servo travel at full rudder.
-- 0.70 = 70% of normal Lua output range.
local SWING_COORD_GAIN =
  0.70


-- ============================================================
-- OUTPUT DIRECTION
-- ============================================================

local LIFT_SIGN =
  -1

local ANGLE_SIGN =
  1


-- If coordinated swing moves opposite the desired direction,
-- change this between 1 and -1.
local SWING_SIGN =
  1


-- ============================================================
-- STATE
-- ============================================================

-- Lift:
--   0  = fully raised
--  -1  = fully lowered
local liftPos =
  0


-- Angle:
--   0 = Transport / Plow reference
local anglePos =
  0


-- Coordination offset is modeled separately.
local coordAnglePos =
  0


local initialized =
  false

local lastSd =
  nil

local lastTime =
  getTime()


local modeTransition =
  false


local modeLiftTarget =
  0

local modeAngleTarget =
  0


local finMoveRemaining =
  0

local finMoveDirection =
  0


-- Reverse state:
--
-- idle
-- lifting
-- ready
-- returning
local reverseState =
  "idle"


-- Exact lift position before reverse auto-lift.
local reverseReturnLift =
  0


-- Raised target for current reverse cycle.
local reverseLiftTarget =
  0

--- one short rehome
local lastSh = false

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


local function clamp1024(v)

  return clamp(
    v,
    -1024,
    1024
  )

end


local function normStick(v)

  if type(v) ~= "number" then
    return 0
  end


  if math.abs(v) > 100 then

    return
      v / 1024

  end


  return
    v / 100

end


local function deadband(v)

  if math.abs(v) <
    INPUT_DEADBAND
  then

    return 0

  end


  return v

end


local function applyDeadband(v, db)

  if math.abs(v) <= db then
    return 0
  end


  local sign =
    (v >= 0)
    and 1
    or -1


  return
    sign *
    (
      (math.abs(v) - db)
      /
      (1 - db)
    )

end


local function moveToward(
  position,
  target,
  fullTime,
  outputSign,
  dt
)

  local err =
    target - position


  if math.abs(err) < 0.001 then

    return
      target,
      0,
      true

  end


  local step =
    dt / fullTime


  if step <= 0 then

    return
      position,
      0,
      false

  end


  local direction

  if err > 0 then
    direction = 1
  else
    direction = -1
  end


  local done =
    false


  if math.abs(err) <= step then

    position =
      target

    done =
      true

  else

    position =
      position +
      direction * step

  end


  local output =
    direction *
    outputSign *
    1024


  return
    position,
    output,
    done

end


-- ============================================================
-- ASYMMETRIC TILLER LIFT
-- ============================================================

local function moveLiftToward(
  position,
  target,
  dt
)

  local err =
    target - position


  if math.abs(err) < 0.001 then

    return
      target,
      0,
      true

  end


  local direction
  local fullTime


  if err > 0 then

    -- Toward zero = raising.
    direction =
      1

    fullTime =
      TILLER_LIFT_UP_FULL

  else

    -- More negative = lowering.
    direction =
      -1

    fullTime =
      TILLER_LIFT_DOWN_FULL

  end


  local step =
    dt / fullTime


  if step <= 0 then

    return
      position,
      0,
      false

  end


  local done =
    false


  if math.abs(err) <= step then

    position =
      target

    done =
      true

  else

    position =
      position +
      direction * step

  end


  local output =
    direction *
    LIFT_SIGN *
    1024


  return
    position,
    output,
    done

end


-- ============================================================
-- MANUAL POSITION TRACKING
-- ============================================================

local function manualLiftPosition(
  position,
  command,
  dt
)

  if command == 0 then
    return position
  end


  local physicalDirection =
    command / LIFT_SIGN


  local fullTime

  if physicalDirection > 0 then

    fullTime =
      TILLER_LIFT_UP_FULL

  else

    fullTime =
      TILLER_LIFT_DOWN_FULL

  end


  position =
    position +
    (
      physicalDirection *
      dt /
      fullTime
    )


  return
    clamp(
      position,
      -1,
      0
    )

end


local function manualPosition(
  position,
  command,
  fullTime,
  outputSign,
  dt
)

  if command == 0 then
    return position
  end


  local physicalDirection =
    command /
    outputSign


  position =
    position +
    (
      physicalDirection *
      dt /
      fullTime
    )


  return
    clamp(
      position,
      -1,
      1
    )

end


-- ============================================================
-- MAIN
-- ============================================================

local function run()

  local now =
    getTime()


  local dt =
    (now - lastTime) / 100


  lastTime =
    now


  if dt < 0 then
    dt = 0
  end


  if dt > 0.25 then
    dt = 0.25
  end


  -- ----------------------------------------------------------
  -- INPUTS
  -- ----------------------------------------------------------

  local sd =
    getValue("sd") or 0


  local sc =
    getValue("sc") or 0


  local sb =
    getValue("sb") or 0


  local sf =
    getValue("sf") or 0


  local thr =
    deadband(
      normStick(
        getValue("thr")
      )
    )


  -- Separate rudder values for:
  --
  -- 1. Implement coordination
  -- 2. Swing coordination
  --
  -- Swing deliberately has the smaller deadband.

  local rawRud =
    normStick(
      getValue("rud")
    )


  local coordRud =
    applyDeadband(
      rawRud,
      COORD_RUD_DEADBAND
    )


  local swingRud =
    applyDeadband(
      rawRud,
      SWING_RUD_DEADBAND
    )


  local ail =
    deadband(
      normStick(
        getValue("ail")
      )
    )


  local ele =
    deadband(
      normStick(
        getValue("ele")
      )
    )


  local se =
    deadband(
      normStick(
        getValue("se")
      )
    )


  local sg =
    deadband(
      normStick(
        getValue("sg")
      )
    )


  local eStop =
    sf > 0


  local inGroom =
    sd > 500

  --- one shot rehome
  local sh =
    (getValue("sh") or 0) > 500

  local homeReset =
  sh and not lastSh

  lastSh =
    sh

  -- Full implement coordination:
  --
  -- SB Down only.
  local coordEnabled =
    inGroom
    and sb > 500


  -- Swing coordination:
  --
  -- SB Neutral or SB Down.
  --
  -- SB Up (-1024) remains manual S2 control through the
  -- CH9 radio mix.
  local swingCoordEnabled =
    sb > -500


  -- ----------------------------------------------------------
  -- GLOBAL VARIABLES
  -- ----------------------------------------------------------

  local gCoord =
    clamp(
      (getValue("gvar1") or 0)
      /
      100,
      0,
      1
    )


  local groomDepth =
    clamp(
      (getValue("gvar3") or 0)
      /
      100,
      0,
      1
    )


  local reverseLift =
    clamp(
      (getValue("gvar4") or 0)
      /
      100,
      0,
      1
    )


  local groomAngle =
    clamp(
      (getValue("gvar5") or 0)
      /
      100,
      0,
      1
    )


  -- ==========================================================
  -- SH HOME RESET
  --
  -- Treat current physical tiller position as the new
  -- modeled zero/home position.
  --
  -- No actuator movement is commanded.
  -- ==========================================================

  if homeReset
    and not modeTransition
    and reverseState == "idle"
  then

    -- Current physical tiller position becomes zero/home.
    liftPos =
      0

    anglePos =
      0

    -- Clear coordination offset.
    coordAnglePos =
      0

    -- Clear automatic state.
    modeTransition =
      false

    reverseState =
      "idle"

    reverseReturnLift =
      0

    reverseLiftTarget =
      0

    finMoveRemaining =
      0

    finMoveDirection =
      0

    -- Prevent motion on the reset cycle.
    return
      0, -- TAng
      0, -- TLift
      0, -- FinL
      0, -- FinR
      0  -- Swing
  end
  
  -- ----------------------------------------------------------
  -- INITIALIZE WITHOUT MOVEMENT
  -- ----------------------------------------------------------

  if not initialized then

    if inGroom then

      liftPos =
        -groomDepth


      anglePos =
        groomAngle

    else

      liftPos =
        0


      anglePos =
        0

    end


    lastSd =
      sd


    initialized =
      true

  end


  -- ----------------------------------------------------------
  -- E-STOP
  --
  -- Swing Lua output also goes neutral under E-stop.
  -- With SB Up, CH9 manual S2 behavior remains dependent on
  -- the radio mix unless you separately gate CH9 with SF.
  -- ----------------------------------------------------------

  if eStop then

    return
      0, -- Angle
      0, -- Lift
      0, -- FinL
      0, -- FinR
      0  -- Swing

  end


  -- ----------------------------------------------------------
  -- MODE TRANSITIONS
  --
  -- Tiller moves automatically only when Groom is entered
  -- or exited.
  -- ----------------------------------------------------------

  if lastSd ~= nil
    and sd ~= lastSd
  then

    local from =
      lastSd


    local to =
      sd


    if to == 1024 then

      -- ENTER GROOM

      modeLiftTarget =
        -groomDepth


      modeAngleTarget =
        groomAngle


      modeTransition =
        true


      finMoveRemaining =
        FIN_FULL_TIME


      finMoveDirection =
        -1


    elseif from == 1024 then

      -- LEAVE GROOM

      modeLiftTarget =
        0


      modeAngleTarget =
        0


      modeTransition =
        true


      finMoveRemaining =
        FIN_FULL_TIME


      finMoveDirection =
        1


      reverseState =
        "idle"

    end


    lastSd =
      sd

  end


  -- ----------------------------------------------------------
  -- OUTPUT COMMANDS
  -- ----------------------------------------------------------

  local angleCmd =
    0


  local liftCmd =
    0


  local finLCmd =
    0


  local finRCmd =
    0


  local swingCmd =
    0


  -- ==========================================================
  -- SWING COORDINATION
  --
  -- Independent of SD.
  --
  -- SB Neutral:
  --   coordinated swing only
  --
  -- SB Down:
  --   coordinated swing +
  --   Groom implement coordination when in Groom
  --
  -- SB Up:
  --   Swing Lua output = 0;
  --   S2 radio mix owns CH9.
  -- ==========================================================

  if swingCoordEnabled then

    swingCmd =
      swingRud *
      SWING_COORD_GAIN *
      SWING_SIGN *
      1024

  end


  -- ==========================================================
  -- NORMAL MODE TRANSITION
  --
  -- Automatic tiller Lift/Angle/Finishers have authority.
  --
  -- Swing is independent and may continue following Rudder
  -- in SB Neutral/Down.
  -- ==========================================================

  if modeTransition then

    local liftDone
    local angleDone


    liftPos,
    liftCmd,
    liftDone =
      moveLiftToward(
        liftPos,
        modeLiftTarget,
        dt
      )


    anglePos,
    angleCmd,
    angleDone =
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
        finMoveDirection *
        1024


      finRCmd =
        finMoveDirection *
        1024


      if finMoveRemaining <= 0 then

        finMoveRemaining =
          0

      end

    end


    if liftDone
      and angleDone
      and finMoveRemaining <= 0
    then

      modeTransition =
        false

    end


  -- ==========================================================
  -- NORMAL NON-TRANSITION OPERATION
  -- ==========================================================

  else

    -- ========================================================
    -- GROOM-ONLY REVERSE AUTO-LIFT
    -- ========================================================

    if inGroom then

      local reverseRequested =
        thr < -INPUT_DEADBAND


      -- ------------------------------------------------------
      -- START REVERSE LIFT
      -- ------------------------------------------------------

      if reverseState == "idle"
        and reverseRequested
      then

        reverseReturnLift =
          liftPos


        reverseLiftTarget =
          math.min(
            0,
            reverseReturnLift +
            reverseLift
          )


        reverseState =
          "lifting"

      end


      -- ------------------------------------------------------
      -- LIFTING
      -- ------------------------------------------------------

      if reverseState ==
        "lifting"
      then

        local done


        liftPos,
        liftCmd,
        done =
          moveLiftToward(
            liftPos,
            reverseLiftTarget,
            dt
          )


        if done then

          if reverseRequested then

            reverseState =
              "ready"

          else

            reverseState =
              "returning"

          end

        end


      -- ------------------------------------------------------
      -- READY / HOLD WHILE BACKING
      -- ------------------------------------------------------

      elseif reverseState ==
        "ready"
      then

        liftCmd =
          0


        if not reverseRequested then

          reverseState =
            "returning"

        end


      -- ------------------------------------------------------
      -- RETURN TO EXACT PRE-REVERSE HEIGHT
      -- ------------------------------------------------------

      elseif reverseState ==
        "returning"
      then

        local done


        liftPos,
        liftCmd,
        done =
          moveLiftToward(
            liftPos,
            reverseReturnLift,
            dt
          )


        if done then

          reverseState =
            "idle"

        end

      end

    end


    -- ========================================================
    -- MANUAL TILLER CONTROL
    --
    -- SC Down works in:
    --
    --   Transport
    --   Plow
    --   Groom
    --
    -- Automatic transition/reverse movement retain priority.
    -- ========================================================

    if reverseState ==
        "idle"
      and sc > 500
    then

      -- ELE = Lift
      -- AIL = Angle

      liftCmd =
        ele *
        1024


      angleCmd =
        ail *
        1024


      liftPos =
        manualLiftPosition(
          liftPos,
          ele,
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


    -- ========================================================
    -- MANUAL FINISHERS
    -- ========================================================

    finLCmd =
      se *
      1024


    finRCmd =
      sg *
      1024


    -- ========================================================
    -- GROOM-ONLY TILLER ANGLE COORDINATION
    --
    -- SB Down only.
    -- ========================================================

    if inGroom then

      local desiredCoordAngle =
        0


      if coordEnabled
        and reverseState == "idle"
        and math.abs(ail) <
            INPUT_DEADBAND
      then

        desiredCoordAngle =
          coordRud *
          ANGLE_COORD_RANGE *
          gCoord

      end


      local coordCmd


      coordAnglePos,
      coordCmd =
        moveToward(
          coordAnglePos,
          desiredCoordAngle,
          TILLER_ANGLE_FULL,
          ANGLE_SIGN,
          dt
        )


      angleCmd =
        angleCmd +
        coordCmd

    end

  end


  -- ==========================================================
  -- FINAL OUTPUT
  -- ==========================================================

  return
    clamp1024(angleCmd),
    clamp1024(liftCmd),
    clamp1024(finLCmd),
    clamp1024(finRCmd),
    clamp1024(swingCmd)

end


return {

  run =
    run,


  output = {

    "TAng",
    "TLift",
    "FinL",
    "FinR",
    "Swing"

  }

}