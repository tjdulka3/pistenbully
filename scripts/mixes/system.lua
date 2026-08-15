----------------------------------------------------------
-- PB600 SYSTEM + TRACK CONTROL (FINAL + LOCK OUTPUTS)
----------------------------------------------------------

local lastSd = nil
local bladeEnd = 0
local tillerEnd = 0

-- smoothing state
local lastL = 0
local lastR = 0

----------------------------------------------------------
-- HELPERS
----------------------------------------------------------
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- directional smoothing (fully symmetric)
local function smoothDirectional(prev, target, accelRate, decelRate, reverseBoost)
  local delta = target - prev

  local crossingZero = (prev > 0 and target < 0) or (prev < 0 and target > 0)
  local sameDirection = (prev >= 0 and target >= 0) or (prev <= 0 and target <= 0)
  local accelerating = sameDirection and (math.abs(target) > math.abs(prev))

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

----------------------------------------------------------
-- MAIN
----------------------------------------------------------
local function run()

  local now = getTime()

  local sd  = getValue("sd")
  local thr = getValue("thr") / 100
  local rud = -getValue("rud") / 100

  local sf = getValue("sf") or 0
  local eStop = (sf > 0)

  --------------------------------------------------------
  -- TIMING
  --------------------------------------------------------
  local bladeLiftBase = (getValue("gvar14") / 100) * 6.7
  local bladeMaxTime = math.max(bladeLiftBase * 1.5, bladeLiftBase)

  local tLiftDown = (getValue("gvar11") / 100) * 12.5
  local tLiftUp   = (getValue("gvar12") / 100) * 12.5
  local tAngle    = (getValue("gvar13") / 100) * 3.75
  local tFin      = (getValue("gvar15") / 100) * 2.0

  local tillerMaxTime = math.max(tLiftDown, tLiftUp, tAngle, tFin)

  --------------------------------------------------------
  -- TRANSITIONS
  --------------------------------------------------------
  if lastSd ~= nil and sd ~= lastSd then
    if (lastSd == -1024) or (sd == -1024) then
      bladeEnd = now + (bladeMaxTime * 100)
    end
    if (lastSd == 1024) or (sd == 1024) then
      tillerEnd = now + (tillerMaxTime * 100)
    end
  end

  lastSd = sd

  local bladeActive  = now < bladeEnd
  local tillerActive = now < tillerEnd

  local isGroom = (sd > 50)


  ----------------------------------------------------------
  -- LOCK STATE DEFINITIONS
  --
  -- LockMode (system-level behavior state)
  --
  --  -1024 = NO LOCK
  --          Normal operation
  --          Full track control enabled
  --
  --     0  = SOFT LOCK (TRANSITION)
  --          Active during blade/tiller transitions
  --          Track output is reduced (scaled down)
  --          Machine still moves, but with limited power
  --
  --  1024 = HARD LOCK
  --          Tracks forced to zero output
  --          Used for safety / invalid states
  --
  --
  -- LockReason (why the lock is active)
  --
  --  -1024 = NONE
  --          No active constraint
  --
  --   -512 = BLADE TRANSITION
  --          Blade moving to/from transport or plow
  --          Causes soft lock (reduced track power)
  --
  --     0  = TILLER TRANSITION
  --          Tiller moving to/from transport or groom
  --          Causes soft lock (reduced track power)
  --
  --   512  = GROOM REVERSE BLOCK
  --          Reverse motion not allowed in groom mode
  --          Causes hard lock (tracks = 0)
  --
  --  1024 = E-STOP (EMERGENCY STOP)
  --          Triggered by SF switch
  --          Immediate full stop of tracks
  --
  --
  -- DESIGN NOTES:
  --
  -- • LockMode controls "how" the machine behaves
  -- • LockReason explains "why" the lock is active
  --
  -- • These outputs are intended to:
  --     - Replace logical switches in the radio
  --     - Drive UI indicators (operator + debug panels)
  --     - Enable future logic (e.g. warnings, flashing states)
  --
  ----------------------------------------------------------

  --------------------------------------------------------
  -- LOCK MODE + REASON
  --------------------------------------------------------
  local lockMode   = -1024
  local lockReason = -1024

  if bladeActive then
    lockMode   = 0
    lockReason = -512
  elseif tillerActive then
    lockMode   = 0
    lockReason = 0
  end

  if isGroom and thr < 0 then
    lockMode   = 1024
    lockReason = 512
  end

  --------------------------------------------------------
  -- TRACK CONTROL
  --------------------------------------------------------

  if math.abs(rud) < 0.02 then rud = 0 end

  --------------------------------------------------------
  -- TUNING (SAFE MID)
  --------------------------------------------------------
----------------------------------------------------------
-- TRACK CONTROL TUNING PARAMETERS
----------------------------------------------------------
--
-- These parameters control the "feel" of the snowcat.
-- Adjust gradually and test on snow for best results.
--
-- All values are tuned around a realistic PB600 baseline.
--
----------------------------------------------------------

-- TURN RESPONSE
----------------------------------------------------------
-- Controls how aggressively the machine turns based on rudder input
--
-- Recommended: 0.25 – 0.40
-- Default:     0.30
--
-- ↓ Lower (0.20–0.25):
--    • Softer, smoother turning
--    • Less sensitive to small stick inputs
--    • Better for precision grooming
--
-- ↑ Higher (0.35–0.50):
--    • Sharper, more aggressive turning
--    • Faster response to stick movement
--    • Can feel twitchy if too high
--
local turnGain = 0.10


-- HIGH-SPEED STEERING REDUCTION (DESTROKING)
----------------------------------------------------------
-- Reduces steering authority as speed increases
-- Simulates hydrostatic pump destroking at high speed
--
-- Recommended: 0.50 – 0.75
-- Default:     0.60
--
-- ↓ Lower (0.40–0.50):
--    • Strong turning even at high speed
--    • More agile but less realistic
--
-- ↑ Higher (0.65–0.80):
--    • Turning heavily reduced at speed
--    • More stable, more realistic "heavy machine" feel
--
local speedFactor = 0.60


-- ACCELERATION RATE (PUMP BUILD-UP)
----------------------------------------------------------
-- Controls how fast the tracks accelerate toward target speed
-- Simulates hydraulic pressure build-up
--
-- Recommended: 40 – 80
-- Default:     60
--
-- ↓ Lower (40–50):
--    • Slower acceleration
--    • Heavier machine feel
--    • More realistic under load
--
-- ↑ Higher (70–90):
--    • Faster response
--    • More "electric" feel
--    • Less realistic
--
local accelRate = 75


-- DECELERATION RATE (HYDROSTATIC BRAKING)
----------------------------------------------------------
-- Controls how quickly the machine slows down when throttle is reduced
-- Simulates hydraulic braking (pressure release)
--
-- Recommended: 120 – 180
-- Default:     140
--
-- ↓ Lower (100–120):
--    • Longer stopping distance
--    • Smoother deceleration
--
-- ↑ Higher (160–200):
--    • Strong braking
--    • Short stopping distance
--    • Can feel abrupt if too high
--
local decelRate = 160


-- REVERSE TRANSITION BOOST (PRESSURE DUMP)
----------------------------------------------------------
-- Extra braking force when changing direction (forward ↔ reverse)
-- Simulates rapid hydraulic pressure dump before reversing flow
--
-- Recommended: 80 – 140
-- Default:     100
--
-- ↓ Lower (60–80):
--    • Smooth direction changes
--    • Slower transition through zero
--
-- ↑ Higher (120–160):
--    • Very fast direction reversal
--    • Strong "braking then go" feel
--    • Too high can feel jerky
--
local reverseBoost = 100


-- PIVOT BLENDING (SPIN-IN-PLACE CONTROL)
----------------------------------------------------------
-- Controls how quickly the system transitions from pivot steering
-- (spin in place) to normal driving as throttle increases
--
-- Recommended multiplier: 1.5 – 2.5
-- Default behavior uses: abs(thr) * 2
--
-- ↓ Lower (1.5):
--    • Pivot mode active longer
--    • Easier to spin at low speeds
--
-- ↑ Higher (2.5–3.0):
--    • Pivot only at very low throttle
--    • More stable forward driving
--
-- Example:
-- local pivotBlend = clamp(abs(thr) * 2, 0, 1)
--
----------------------------------------------------------

-- TURN DISTRIBUTION (INSIDE vs OUTSIDE TRACK)
----------------------------------------------------------
-- Controls how power is split during a turn
--
-- Default:
--   outside track gain  = 0.7
--   inside track reduce = 0.4
--
-- ↓ Lower inside reduction (0.3):
--    • Less power drop on inside track
--    • Smoother, wider turns
--
-- ↑ Higher outside gain (0.8):
--    • More aggressive turning
--    • Sharper pivot feel
--
-- These values directly affect turning realism
--
----------------------------------------------------------

-- DEADBAND (RUDDER)
----------------------------------------------------------
-- Small input threshold to prevent jitter near center
--
-- Recommended: 0.01 – 0.05
-- Default:     0.02
--
-- ↓ Lower:
--    • More sensitive to tiny inputs
--    • May cause jitter
--
-- ↑ Higher:
--    • Smoother center
--    • Slight delay in response
--
----------------------------------------------------------

-- NOTES
----------------------------------------------------------
-- • accelRate < decelRate is REQUIRED for realistic behavior
-- • reverseBoost only affects direction changes (not steady driving)
-- • speedFactor is key to "heavy machine" feel
-- • turnGain + distribution tuning define steering personality
--
-- Suggested tuning order:
--   1. turnGain
--   2. speedFactor
--   3. accelRate / decelRate
--   4. reverseBoost
--   5. fine-tune distribution
--
----------------------------------------------------------

  --------------------------------------------------------

  local speedScale = 1 - (math.abs(thr) * speedFactor)
  local rudCurve   = rud * math.abs(rud)
  local turn       = rudCurve * turnGain * speedScale

  --------------------------------------------------------
  -- PIVOT + DRIVE BLENDING
  --------------------------------------------------------
  local pivotBlend = clamp(math.abs(thr) * 2, 0, 1)

  local driveLeft  = thr * (1 + turn * 0.7)
  local driveRight = thr * (1 - turn * 0.4)

  local pivotLeft  = turn
  local pivotRight = -turn

  local left  = (driveLeft  * pivotBlend) + (pivotLeft  * (1 - pivotBlend))
  local right = (driveRight * pivotBlend) + (pivotRight * (1 - pivotBlend))

  --------------------------------------------------------
  -- LIMIT OUTPUT
  --------------------------------------------------------
  local maxT = math.abs(thr)
  left  = clamp(left,  -maxT, maxT)
  right = clamp(right, -maxT, maxT)

  --------------------------------------------------------
  -- LOCK BEHAVIOR
  --------------------------------------------------------
  if isGroom then
    if left < 0 then left = 0 end
    if right < 0 then right = 0 end
  end

  if lockMode == 0 then
    left  = left * 0.25
    right = right * 0.25
  end

  if lockMode == 1024 then
    left = 0
    right = 0
  end

  --------------------------------------------------------
  -- PIVOT OVERRIDE
  --------------------------------------------------------
  local sb = getValue("sb") or 0
  if sb > 50 and lockMode == -1024 then
    left  = thr + rud
    right = thr - rud
  end

  --------------------------------------------------------
  -- E-STOP (HARD STOP)
  --------------------------------------------------------
  if eStop then
    lastL = 0
    lastR = 0
    lockMode   = 1024
    lockReason = 1024

    return
      bladeActive  and 1024 or -1024,
      tillerActive and 1024 or -1024,
      0,
      0,
      lockMode,
      lockReason
  end

  --------------------------------------------------------
  -- OUTPUT PIPELINE
  --------------------------------------------------------
  local targetL = left * 1024
  local targetR = right * 1024

  local leftOut  = smoothDirectional(lastL, targetL, accelRate, decelRate, reverseBoost)
  local rightOut = smoothDirectional(lastR, targetR, accelRate, decelRate, reverseBoost)

  lastL = leftOut
  lastR = rightOut

  --------------------------------------------------------
  -- OUTPUTS
  --------------------------------------------------------
  return
    bladeActive  and 1024 or -1024,
    tillerActive and 1024 or -1024,
    leftOut,
    -rightOut,
    lockMode,
    lockReason
end

return {
  run = run,
  output = { "BladeTr","TillerTr","TrackL","TrackR","LockMode","LockReason" }
}