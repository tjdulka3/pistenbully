-- =========================
-- CONSTANTS
-- =========================
local BLADE_ANGLE_TIME_FULL = 6.7
local BLADE_LIFT_TIME_FULL  = 6.7

-- =========================
-- STATE
-- =========================
local pos = { lift=0, tilt=0, slew=0, lw=0, rw=0 }
local prev = { lift=0, tilt=0, slew=0, lw=0, rw=0 }

local lastTime = getTime()
local homeStart = nil

local angleMoveStart = nil
local angleDirection = 0

local liftMoveStart = nil
local liftDirection = 0

local lastSd = nil

-- =========================
-- HELPERS
-- =========================
local function clamp(x)
  if x > 1 then return 1 end
  if x < -1 then return -1 end
  return x
end

local function delta(a,b) return a-b end

local function zero(x, db)
  if math.abs(x) < (db * 2) then return 0 end
  return x
end

-- =========================
-- MAIN
-- =========================
local function run()

  local now = getTime()
  local dt = (now - lastTime) / 100
  lastTime = now

  local rud = getValue("rud") / 1024
  local sb  = getValue("sb")
  local sd  = getValue("sd")

  if math.abs(rud) < 0.02 then rud = 0 end

  local coordMode = sb

  -- =========================
  -- GLOBAL VARIABLES
  -- =========================
  local gWing  = getValue("gvar1") / 100
  local gAngle = getValue("gvar2") / 100
  local gSlew  = getValue("gvar3") / 100
  local gTilt  = getValue("gvar4") / 100
  local gCoord = getValue("gvar5") / 100

  local gOut   = getValue("gvar6")
  local gSpeed = getValue("gvar7") / 100
  local gDB    = getValue("gvar8") / 100
  local gHome  = getValue("gvar9") / 10

  local liftTime = (getValue("gvar14") / 100) * BLADE_LIFT_TIME_FULL

  local gBladeAnglePercent = getValue("gvar10") / 100
  local gBladeAngleTime = gBladeAnglePercent * BLADE_ANGLE_TIME_FULL

  -- =========================
  -- TRANSITIONS
  -- =========================
  if lastSd ~= nil and sd ~= lastSd then

    local from = lastSd
    local to   = sd

    if (from == -1024) or (to == -1024) then
      angleMoveStart = now
      angleDirection = (to == -1024) and 1 or -1
    end

    local enteringTransport = (to == -1024)
    local leavingTransport  = (from == -1024 and to ~= -1024)

    if enteringTransport or leavingTransport then
      liftMoveStart = now
      liftDirection = enteringTransport and 1 or -1
    else
      liftMoveStart = nil
    end
  end

  lastSd = sd

 -- =========================
  -- LIFT CONTROL (POSITION-BASED + SH OVERRIDE)
  -- =========================
  local sh = getValue("sh") or 0
  local shActive = (sh > 0)

  local FLOAT_POS     = 0.0
  local TRANSPORT_POS = 1.0
  local BUMP_POS      = 0.10

  -- determine base target from SD
  local baseTarget
  if sd == -1024 then
    baseTarget = TRANSPORT_POS
  else
    baseTarget = FLOAT_POS
  end

  -- SH override
  local liftTarget
  if shActive then
    liftTarget = BUMP_POS
  else
    liftTarget = baseTarget
  end

  -- smooth movement toward target
  local err = liftTarget - pos.lift
  local moveRate = dt / liftTime

  if math.abs(err) < 0.01 then
    pos.lift = liftTarget
  elseif err > 0 then
    pos.lift = clamp(pos.lift + moveRate)
  else
    pos.lift = clamp(pos.lift - moveRate)
  end

  -- =========================
  -- ANGLE OUTPUT
  -- =========================
  local angleOut = 0

  if angleMoveStart ~= nil then
    local elapsed = (now - angleMoveStart) / 100
    if elapsed < gBladeAngleTime then
      angleOut = angleDirection * 1024
    else
      angleMoveStart = nil
    end
  end

  -- =========================
  -- TARGETS
  -- =========================
  local target
  if sd == -1024 then
    target = { lift=pos.lift, tilt=0, slew=0, lw=-1, rw=-1 }
  else
    target = { lift=pos.lift, tilt=0, slew=0, lw=-0.6, rw=-0.6 }
  end

  -- =========================
  -- TRANSPORT OVERRIDE
  -- =========================
  if sd == -1024 then
    if homeStart == nil then homeStart = now end
    local elapsed = (now - homeStart) / 100

    if elapsed < gHome then
      prev.lift = pos.lift
      return -1024, 0, angleOut, 0, -1024, -1024
    end
  else
    homeStart = nil
  end

  -- =========================
  -- POSITION CONTROL
  -- =========================
  for k,v in pairs(pos) do
    if k ~= "lift" then
      local err = target[k] - pos[k]
      local speed = dt * gSpeed

      if math.abs(err) < (gDB * 2) then
        pos[k] = target[k]
      elseif err > 0 then
        pos[k] = pos[k] + speed
      else
        pos[k] = pos[k] - speed
      end

      pos[k] = clamp(pos[k])
    end
  end

  -- =========================
  -- COORDINATION
  -- =========================
  local offset = { lw=0, rw=0, slew=0, tilt=0 }

  if sd ~= -1024 then

    if coordMode == 1024 and (sd == 1024 or sd == 0) then
      offset.lw   =  -rud * gWing * gCoord
      offset.rw   = rud * gWing * gCoord
      offset.slew =  rud * gSlew * gCoord
      offset.tilt =  rud * gTilt * gCoord
    end

  end

  local final = {
    lift = pos.lift,
    tilt = clamp(pos.tilt + offset.tilt),
    slew = clamp(pos.slew + offset.slew),
    lw   = clamp(pos.lw + offset.lw),
    rw   = clamp(pos.rw + offset.rw)
  }

  local out = {}

  for k,v in pairs(final) do
    local d = delta(v, prev[k])
    out[k] = zero(d * gOut, gDB)
    prev[k] = v
  end

  return
    (-out.lift)*1024,
    out.tilt*1024,
    angleOut,
    out.slew*1024,
    out.lw*1024,
    out.rw*1024
end

return {
  run = run,
  output = { "Lift","Tilt","Angle","Slew","LW","RW" }
}