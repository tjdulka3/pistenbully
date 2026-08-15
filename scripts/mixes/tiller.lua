-- =========================
-- CONSTANTS
-- =========================
local TILLER_LIFT_FULL  = 12.5
local TILLER_ANGLE_FULL = 3.75
local FIN_TIME_FULL     = 2.0

-- =========================
-- STATE
-- =========================
local tangMoveStart = nil
local tangDirection = 0

local finMoveStart = nil
local finDirection = 0

local lastSd = nil

-- NEW: position tracking
local tillerPos = 0

-- =========================
-- MAIN
-- =========================
local function run()

  local now = getTime()

  local rud = getValue("rud") / 1024
  local sb  = getValue("sb")
  local sd  = getValue("sd")

  if math.abs(rud) < 0.02 then rud = 0 end

  local coordMode = sb

  -- =========================
  -- GLOBAL VARIABLES
  -- =========================
  local gAngle = getValue("gvar2") / 100
  local gCoord = getValue("gvar5") / 100

  local liftDownTime = (getValue("gvar11") / 100) * TILLER_LIFT_FULL
  local liftUpTime   = (getValue("gvar12") / 100) * TILLER_LIFT_FULL
  local angleTime    = (getValue("gvar13") / 100) * TILLER_ANGLE_FULL
  local finTime      = (getValue("gvar15") / 100) * FIN_TIME_FULL

  local dt = 0.03

  -- =========================
  -- TRANSITIONS (unchanged)
  -- =========================
  if lastSd ~= nil and sd ~= lastSd then

    local from = lastSd
    local to   = sd

    if to == 1024 then
      tangMoveStart = now
      tangDirection = 1

      finMoveStart = now
      finDirection = -1

    elseif from == 1024 then
      tangMoveStart = now
      tangDirection = -1

      finMoveStart = now
      finDirection = 1
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

  local baseTarget
  if sd == 1024 then
    baseTarget = TRANSPORT_POS
  else
    baseTarget = FLOAT_POS
  end

  local liftTarget
  if shActive then
    liftTarget = BUMP_POS
  else
    liftTarget = baseTarget
  end

  local err = liftTarget - tillerPos
  local moveRate = dt / ((err > 0) and liftUpTime or liftDownTime)

  if math.abs(err) < 0.01 then
    tillerPos = liftTarget
  elseif err > 0 then
    tillerPos = math.min(1.0, tillerPos + moveRate)
  else
    tillerPos = math.max(0.0, tillerPos - moveRate)
  end

  local liftOut = 0
  if err > 0.01 then
    liftOut = -1024
  elseif err < -0.01 then
    liftOut = 1024
  end

  -- =========================
  -- ANGLE (unchanged)
  -- =========================
  local tangOut = 0
  if tangMoveStart ~= nil then
    local elapsed = (now - tangMoveStart) / 100
    if elapsed < angleTime then
      tangOut = tangDirection * 1024
    else
      tangMoveStart = nil
    end
  end

  -- =========================
  -- FIN (unchanged)
  -- =========================
  local finOut = 0
  if finMoveStart ~= nil then
    local elapsed = (now - finMoveStart) / 100
    if elapsed < finTime then
      finOut = finDirection * 1024
    else
      finMoveStart = nil
    end
  end

  -- =========================
  -- COORDINATION
  -- =========================
  if sd ~= -1024 then
    if coordMode == 1024 and sd == 1024 then
      tangOut = tangOut + (rud * gAngle * gCoord * 1024)
    elseif coordMode == 0 then
      tangOut = tangOut + (rud * gAngle * gCoord * 512)
    end
  end

  return
    tangOut,
    -liftOut,
    finOut,
    finOut
end

return {
  run = run,
  output = { "TAng","TLift","FinL","FinR" }
}