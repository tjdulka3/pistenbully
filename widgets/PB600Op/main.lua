-- PB600 OPERATOR DASHBOARD (FINAL)
local name = "PB600OP"
local options = {}
local function create(zone, options)
    local wgt = {zone = zone, options = options, components = {}}
    return wgt
end

local lastBeep = 0

-- HOME indicator state.
--
-- Set when SH is pressed while no automatic implement
-- transition is active.
--
-- Cleared when Blade or Tiller outputs command movement.
local homeActive = false
local lastSh = false

local HOME_MOVE_THRESHOLD = 20

--------------------------------------------------
-- COLOR PALETTE (PB600 STYLE)
--------------------------------------------------

local COL_BG     = lcd.RGB(15,15,18)
local COL_PANEL  = lcd.RGB(25,25,30)
local COL_GRID   = lcd.RGB(70,70,75)
local COL_TEXT   = lcd.RGB(200,200,200)

local COL_ACTIVE = lcd.RGB(0,160,120)
local COL_WARN   = lcd.RGB(220,140,0)
local COL_ALERT  = lcd.RGB(200,40,40)
local COL_HYD    = lcd.RGB(0,110,180)
local COL_MOTION = lcd.RGB(160,160,160)

local COL_FWD = lcd.RGB(16, 179, 57)
local COL_REV = lcd.RGB(242, 206, 13)

--------------------------------------------------
-- SMOOTHING
--------------------------------------------------

local smooth = {}

local function smoothValue(key, target, speed)
  local current = smooth[key] or 0
  local new = current + (target - current) * speed
  smooth[key] = new
  return new
end

----------------------------------------------------------
-- MACHINE STATUS
----------------------------------------------------------
local function getMachineStatus()

  local sf =
    getValue("sf") or 0

  local sd =
    getValue("sd") or 0

  local thr =
    getValue("thr") or 0

  local tranB =
    getLogicalSwitchValue(10)

  local tranT =
    getLogicalSwitchValue(11)



  local eStop =
    sf > 0

  local bladeTransition =
    tranB

  local tillerTransition =
    tranT

  local inGroom =
    sd > 500

  local reverseRequested =
    thr < -50

  --------------------------------------------------------
  -- HOME LATCH
  --------------------------------------------------------

  local sh =
    (getValue("sh") or 0) > 500

  local homePressed =
    sh and not lastSh

  lastSh =
    sh


  local anyTransition =
    bladeTransition
    or tillerTransition


  -- SH is accepted as HOME only while neither Blade nor
  -- Tiller is in an automatic transition/reverse movement.
  --
  -- This matches the Blade/Tiller SH re-home behavior.
  if homePressed
    and not anyTransition
  then

    homeActive =
      true

  end


  -- Any later Blade/Tiller actuator command invalidates
  -- the HOME indication.
  --
  -- Do not immediately clear it on the SH press cycle.
  if homeActive
    and not homePressed
    and implementIsMoving()
  then

    homeActive =
      false

  end

  --------------------------------------------------------
  -- 1. E-STOP
  --------------------------------------------------------

  if eStop then
    return "E-STOP", "alert", true
  end


  --------------------------------------------------------
  -- 2. REVERSE AUTO-LIFT
  --------------------------------------------------------

  if inGroom
    and reverseRequested
    and tillerTransition
  then

    return
      "REVERSE: TILLER LIFT",
      "warn",
      false
  end


  --------------------------------------------------------
  -- 3. MODE TRANSITIONS
  --------------------------------------------------------



  if bladeTransition and not tillerTransition then

    return
      "TRANSITION: BLADE",
      "warn",
      false
  end


  if tillerTransition and not bladeTransition then

    return
      "TRANSITION: TILLER",
      "warn",
      false
  end


  if bladeTransition and tillerTransition
  then

    return
      "TRANSITION: BLADE + TILLER",
      "warn",
      false
  end

  --------------------------------------------------------
  -- 4. NORMAL MACHINE STATE
  --------------------------------------------------------

  if sd < -500 then

    return
      "RUN: TRANSPORT",
      "run",
      false

  elseif sd > 500 then

    return
      "RUN: GROOM",
      "run",
      false

  else

    return
      "RUN: PLOW",
      "run",
      false
  end
end


----------------------------------------------------------
-- HOME STATE
----------------------------------------------------------

local function implementIsMoving()

  -- Blade Lua-owned physical channels.
  local bladeLift  = getValue("ch2")  or 0
  local bladeTilt  = getValue("ch4")  or 0
  local bladeLW    = getValue("ch5")  or 0
  local bladeRW    = getValue("ch6")  or 0
  local bladeAngle = getValue("ch10") or 0
  local bladeSlew  = getValue("ch11") or 0

  -- Tiller Lua-owned physical channels.
  local finL        = getValue("ch7")  or 0
  local finR        = getValue("ch8")  or 0
  local tillerLift  = getValue("ch12") or 0
  local tillerAngle = getValue("ch13") or 0

  return
    math.abs(bladeLift)  > HOME_MOVE_THRESHOLD
    or math.abs(bladeTilt)  > HOME_MOVE_THRESHOLD
    or math.abs(bladeLW)    > HOME_MOVE_THRESHOLD
    or math.abs(bladeRW)    > HOME_MOVE_THRESHOLD
    or math.abs(bladeAngle) > HOME_MOVE_THRESHOLD
    or math.abs(bladeSlew)  > HOME_MOVE_THRESHOLD
    or math.abs(finL)       > HOME_MOVE_THRESHOLD
    or math.abs(finR)       > HOME_MOVE_THRESHOLD
    or math.abs(tillerLift) > HOME_MOVE_THRESHOLD
    or math.abs(tillerAngle)> HOME_MOVE_THRESHOLD
end

--------------------------------------------------
-- COLOR HELPERS
--------------------------------------------------

local function setTrackColor(val)
  local v = math.abs(val)
  if v < 100 then
    lcd.setColor(CUSTOM_COLOR, COL_GRID)
  elseif v < 700 then
    lcd.setColor(CUSTOM_COLOR, COL_MOTION)
  else
    lcd.setColor(CUSTOM_COLOR, COL_WARN)
  end
end

local function setBladeColor(val)
  local v = math.abs(val)
  if v < 150 then
    lcd.setColor(CUSTOM_COLOR, COL_HYD)
  elseif v < 700 then
    lcd.setColor(CUSTOM_COLOR, COL_ACTIVE)
  else
    lcd.setColor(CUSTOM_COLOR, COL_WARN)
  end
end

--------------------------------------------------
-- TRACKS
--------------------------------------------------
local function rgb(r, g, b)
    return (r << 16) + (g << 8) + b
end

local function drawTrack(x, y, h, val, label)

  val = smoothValue(label, val, 0.2)

  local width = 26
  local pct = val / 1024
  local adj_y = y+40
  local mid = adj_y + h/2
  local fill = pct * (h/2)
  local fill_color

  lcd.drawRectangle(x, adj_y, width, h)
  lcd.drawLine(x, mid, x+width, mid, SOLID, FORCE)

  if (val > 0) then
    fill_color = COL_FWD
  else
    fill_color = COL_REV
  end

  local thrLine = ((getValue("thr")/1024) *(h/2)) 
  
  if fill > 0 then
    lcd.drawFilledRectangle(x+1, mid - fill, width-2, fill,fill_color)
    
    if math.abs(thrLine) > 5 then
      -- draw throttle line
      lcd.drawLine(x-5, mid - thrLine-2, x+30, mid-thrLine-2, DOTTED, FORCE)
    end
  else
    lcd.drawFilledRectangle(x+1, mid+1, width-2, -fill, fill_color)
    
    if math.abs(thrLine) > 5 then
    -- draw throttle line
      lcd.drawLine(x-5, mid - thrLine+2, x+30, mid-thrLine+2, DOTTED, FORCE)
    end
  end

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(x + 6, adj_y - 24, label, SMLSIZE)
end

local function drawTracks(x, y)

  local h = 220
  local lx = x + 40
  local rx = lx + 56

  local throttle = getValue("thr") / 1024.0 *100.0
  local throttle_str = string.format("%4.1f%%", throttle)
  local rTrack = (-getValue("ch1")) / 1024.0 *100.0
  local lTrack = getValue("ch3") / 1024.0 *100.0
  local track_str = string.format("%4.1f%% <-> %4.1f%%", lTrack,rTrack)

  drawTrack(lx, y, h, getValue("ch3"), "L")
  drawTrack(rx, y, h, -1*  getValue("ch1"), "R")


  lcd.drawText(x + 40, y - 25, "TRACKS", SMLSIZE)

  local thr = getValue("thr")

  ----------------------------------------------------------
  -- CURRENT MACHINE STATUS
  ----------------------------------------------------------

  local status, statusType, beep =
    getMachineStatus()

  lcd.drawText(
    180,
    390,
    "STATUS:",
    SMLSIZE
  )

  if statusType == "alert" then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ALERT
    )

    lcd.drawText(
      260,
      390,
      status,
      SMLSIZE + INVERS + BLINK
    )

  elseif statusType == "warn" then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_WARN
    )

    lcd.drawText(
      260,
      390,
      status,
      SMLSIZE + INVERS
    )

  else

    lcd.setColor(
      CUSTOM_COLOR,
      COL_FWD
    )

    lcd.drawText(
      260,
      390,
      status,
      SMLSIZE
    )

  end


  ----------------------------------------------------------
  -- E-STOP WARNING TONE
  ----------------------------------------------------------

  if beep then

    local now = getTime()

    if (now - lastBeep) > 60 then

      playTone(
        1200,
        150,
        0,
        PLAY_NOW
      )

      lastBeep = now
    end
  end

  if thr > 50 then
    lcd.drawText(x + 50, y +265, "Forward", SMLSIZE + INVERS + COL_FWD)
    lcd.drawText(x+55, y+290, throttle_str, SMLSIZE)
    lcd.drawText(x+20, y+310, track_str, SMLSIZE)
  elseif thr < -50 then
    lcd.drawText(x + 50, y +265, "Reverse", SMLSIZE + INVERS + BLINK + COL_REV)
    lcd.drawText(x+55, y+290, throttle_str, SMLSIZE)
    lcd.drawText(x+20, y+310, track_str, SMLSIZE)
  end
end

--------------------------------------------------
-- WING STATE HELPERS (CRITICAL FIX)
--------------------------------------------------

local function isFullyRetracted(v)
  return math.abs(v) < 20       -- true zero only
end

local function isFullyExtended(v)
  return math.abs(v) > 1000     -- near max only
end

--------------------------------------------------
-- BLADE (WITH WINGS)
--------------------------------------------------

local function drawBladePanel(x, y)

  -- Center of blade panel
  local cx = x + 160
  local cy = y + 110

  --------------------------------------------------
  -- INPUTS (SMOOTHED)
  --------------------------------------------------

  local angle = smoothValue("ch10", getValue("ch10"), 0.2)
  local slew  = smoothValue("ch11", getValue("ch11"), 0.2)
  local tilt  = smoothValue("ch4",  getValue("ch4"),  0.2)
  local lift  = smoothValue("ch2",  getValue("ch2"),  0.2)

  local lw    = smoothValue("ch5",  getValue("ch5"),  0.2)
  local rw    = smoothValue("ch6",  getValue("ch6"),  0.2)



  --------------------------------------------------
  -- NORMALIZE
  --------------------------------------------------

  local a  = angle / 1024
  local s  = slew  / 1024
  local t  = tilt  / 1024
  local l  = (lift + 1024) / 2048

  local wl = math.abs(lw) / 1024
  local wr = math.abs(rw) / 1024

  --------------------------------------------------
  -- GEOMETRY (UPDATED WIDTH)
  --------------------------------------------------

  local bladeW = 75          -- 25% wider (was 60)
  local halfW  = bladeW / 2  -- 37
  local wingBase = halfW     -- anchor point moves outward

  --------------------------------------------------
  -- CROSSHAIR
  --------------------------------------------------

  lcd.drawLine(cx - 60, cy, cx + 60, cy, SOLID, FORCE)
  lcd.drawLine(cx, cy - 60, cx, cy + 60, SOLID, FORCE)

  --------------------------------------------------
  -- BLADE POSITION
  --------------------------------------------------

  local offset =  (s * 80)
  local liftOffset = l * 80
  lcd.drawFilledRectangle(cx - halfW + offset, cy - liftOffset + 36 , bladeW, 10)

  --------------------------------------------------
  -- TILT
  --------------------------------------------------

  local tiltOffset = t * 40
  lcd.drawFilledRectangle(cx - 3, cy - tiltOffset - 10, 6, 20)

--------------------------------------------------
-- WINGS (FINAL - DIRECTION CORRECT)
--------------------------------------------------

local t = getTime()

-- thresholds (tune slightly if needed)
local EXTEND_TH_R = 1000    -- +100%
local RETRACT_TH_R = -1000  -- -100%
local EXTEND_TH_L = -1000    -- +100%
local RETRACT_TH_L = 1000  -- -100%

--------------------------------------------------
-- LEFT WING GEOMETRY
--------------------------------------------------

local wl_norm = math.abs(lw) / 1024
local wingL = 20 + (wl_norm * 45)

if wl_norm > 0 then
  lcd.drawFilledRectangle(cx - wingBase - wingL, cy - 2, wingL, 4)
else
  lcd.drawLine(cx - wingBase - wingL, cy, cx - wingBase, cy, SOLID, FORCE)
end

--------------------------------------------------
-- LEFT WING STATE (FIXED)
--------------------------------------------------

local lw_flags = SMLSIZE

-- FULLY EXTENDED (+100%)
if lw < EXTEND_TH_L then
  lw_flags = SMLSIZE+INVERS+BLINK

-- FULLY RETRACTED (-100%)
elseif lw > RETRACT_TH_L then
  if (t % 40) < 20 then
    lw_flags = SMLSIZE + INVERS
  end
end

lcd.drawText(cx - 105, cy - 10, "LW", lw_flags)
-- lcd.drawText(cx - 105, cy + 10, string.format("%d",lw), SMLSIZE)

--------------------------------------------------
-- RIGHT WING GEOMETRY
--------------------------------------------------

local wr_norm = math.abs(rw) / 1024
local wingR = 20 + (wr_norm * 45)

if wr_norm > 0 then
  lcd.drawFilledRectangle(cx + wingBase, cy - 2, wingR, 4)
else
  lcd.drawLine(cx + wingBase, cy, cx + wingBase + wingR, cy, SOLID, FORCE)
end

--------------------------------------------------
-- RIGHT WING STATE (FIXED)
--------------------------------------------------

local rw_flags = SMLSIZE

if rw > EXTEND_TH_R then
  rw_flags = SMLSIZE + INVERS+BLINK

elseif rw < RETRACT_TH_R then
  if (t % 40) < 20 then
    rw_flags = SMLSIZE+INVERS
  end
end

lcd.drawText(cx + 85, cy - 10, "RW", rw_flags)
--lcd.drawText(cx + 85, cy + 10, string.format("%d",rw), SMLSIZE)


  --------------------------------------------------
  -- ANGLE BAR
  --------------------------------------------------

  lcd.drawText(cx - 130, cy + 85,"Angle", SMLSIZE)
  lcd.drawRectangle(cx - 70, cy + 90, 140, 10)
  lcd.drawFilledRectangle(cx , cy + 90, a * 70, 10)

    --------------------------------------------------
  -- SLEW BAR
  --------------------------------------------------

  lcd.drawText(cx - 130, cy + 105,"Slew", SMLSIZE)
  lcd.drawRectangle(cx - 70, cy + 110, 140, 10)
  lcd.drawFilledRectangle(cx , cy + 110, s * 70, 10)

  --------------------------------------------------
  -- TITLE
  --------------------------------------------------

  lcd.drawText(cx - 30, y - 25, "BLADE", SMLSIZE)
  if (getLogicalSwitchValue(10)) then
    lcd.drawText(cx - 35, y +5, "Transition", SMLSIZE+INVERS+COL_FWD)
  end

 

end

--------------------------------------------------
-- TILLER (WITH FINISHERS)
--------------------------------------------------

local function drawTillerPanel(x, y)

  -- Center of tiller panel
  local cx = x + 160
  local cy = y + 110

  --------------------------------------------------
  -- INPUTS (SMOOTHED)
  --------------------------------------------------

  local swing = smoothValue("ch9",  getValue("ch9"),  0.2)
  local angle = smoothValue("ch13", getValue("ch13"), 0.2)
  local lift  = smoothValue("ch14", getValue("ch12"), 0.2)
  local rot   = smoothValue("ch15", getValue("ch14"), 0.2)

  local finL  = getValue("ch7")
  local finR  = getValue("ch8")

  --------------------------------------------------
  -- NORMALIZE
  --------------------------------------------------

  local s = swing / 1024
  local a = angle / 1024
  local l = (lift + 1024)/2048
  local r = (rot+1024) / 1024

  --------------------------------------------------
  -- GEOMETRY (UPDATED WIDTH)
  --------------------------------------------------

  local swingW = 62        -- 25% wider (was 50)
  local halfW  = swingW/2  -- 31

  --------------------------------------------------
  -- CROSSHAIR
  --------------------------------------------------

  lcd.drawLine(cx - 60, cy, cx + 60, cy, SOLID, FORCE)
  lcd.drawLine(cx, cy - 60, cx, cy + 60, SOLID, FORCE)

  --------------------------------------------------
  -- SWING (WIDER)
  --------------------------------------------------

  lcd.drawFilledRectangle(cx - halfW + (s * 50), cy - 5, swingW, 10)

  --------------------------------------------------
  -- TILLER LIFT
  --------------------------------------------------

  local liftOffset = l * 40
  lcd.drawFilledRectangle(cx - 6, cy - liftOffset , 12, 44)  -- slightly thicker

  --------------------------------------------------
  -- ANGLE BAR
  --------------------------------------------------

  lcd.drawText(cx - 130, cy + 82,"Angle", SMLSIZE)
  lcd.drawRectangle(cx - 70, cy + 90, 140, 10)
  lcd.drawFilledRectangle(cx , cy + 90, a * 70, 10)

  --------------------------------------------------
  -- ROTOR BAR
  --------------------------------------------------

  lcd.drawText(cx - 130, cy + 102,"Rotors", SMLSIZE)
  lcd.drawRectangle(cx - 70, cy + 110, 140, 10)
  lcd.drawFilledRectangle(cx -70, cy + 110, r*70 , 10)

  --------------------------------------------------
  -- 🟪 FINISHERS (UNCHANGED LOGIC, MATCH BLADE STYLE)
  --------------------------------------------------

  if finL < 0 then
    lcd.drawText(cx - 95, cy-10, "L", SMLSIZE + INVERS)
  elseif finL > 0 then
    lcd.drawText(cx - 95, cy-10, "L", SMLSIZE + BLINK + INVERS)
  else
    lcd.drawText(cx - 95, cy-10, "L", SMLSIZE)
  end

  if finR < 0 then
    lcd.drawText(cx + 85, cy-10, "R", SMLSIZE + INVERS)
  elseif finR > 0 then
    lcd.drawText(cx + 85, cy-10, "R", SMLSIZE + BLINK+ INVERS)
  else
    lcd.drawText(cx + 85, cy-10, "R", SMLSIZE)
  end

  --------------------------------------------------
  -- TITLE
  --------------------------------------------------

  lcd.drawText(cx - 25, y - 25, "TILLER", SMLSIZE)
  if (getLogicalSwitchValue(11)) then
    lcd.drawText(cx - 35, y +5, "Transition", SMLSIZE+INVERS+COL_FWD)
  end
end

--------------------------------------------------
-- HEADER
--------------------------------------------------
local function drawHeader(x, y)

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(x, y, "Pisten Bully 600", MIDSIZE)

  local sc = getValue("sc")
  local mode = "BLADE SLEW/ANGLE"

  if sc < 0 then mode = "BLADE LIFT/TILT"
  elseif sc > 0 then mode = "STINGER LIFT/ANGLE" end

  lcd.drawText(x+260, y+10, "STICK MODE: "..mode, SMLSIZE)

  local sb = getValue("sb")
  if sb == -1024 then
    lcd.setColor(CUSTOM_COLOR, COL_ACTIVE)
    lcd.drawText(x+570, y+10, "MANUAL", SMLSIZE)
  elseif sb == 0 then
    lcd.setColor(CUSTOM_COLOR, COL_GRID)
    lcd.drawText(x+570, y+10, "SWING ONLY", SMLSIZE)
  else
    lcd.setColor(CUSTOM_COLOR, COL_GRID)
    lcd.drawText(x+570, y+10, "COORDINATED", SMLSIZE)
  end

  --------------------------------------------------
  -- 🔥 TRANSITION DETECTION (SAFE)
  --------------------------------------------------
  local inTransition = getLogicalSwitchValue(12)

  --------------------------------------------------
  -- MODE LABEL (SAFE RENDER)
  --------------------------------------------------
  local sd = getValue("sd")
  local label = "PLOW"

  if sd < 0 then
    label = "TRANSPORT"
  elseif sd > 0 then
    label = "GROOM"
  end

  local flags = SMLSIZE

  local blade_transition = getLogicalSwitchValue(10)
  local tiller_transition = getLogicalSwitchValue(11)
  if blade_transition  or tiller_transition  then
    flags = SMLSIZE + INVERS
  end

  lcd.drawText(x+695, y+10, label, flags)

  local sh =
  (getValue("sh") or 0) > 500

  local homePressed =
    sh and not lastSh

  lastSh =
    sh

  if homePressed then
    homeActive = true
  end

    --------------------------------------------------
  -- HOME INDICATOR
  --------------------------------------------------

  if homeActive then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )

    lcd.drawText(
      x + 650,
      y + 28,
      "HOME",
      SMLSIZE + INVERS
    )

  end
end


--------------------------------------------------
-- MAIN
--------------------------------------------------

local function refresh(wgt, event, touchState)
  local z = wgt.zone

  if wgt.zone.w < 800 or wgt.zone.h < 400 then
      local fsY = wgt.zone.y + wgt.zone.h - 14
      local fsX = wgt.zone.x + 2
      lcd.drawText(
          fsX,
          fsY,
          "Need at least 800x400",
          SMLSIZE + lcd.RGB(255, 255, 255)
      )
      return
  end
  lcd.clear(lcd.RGB(44, 143, 176))

  -- Background panels
  lcd.setColor(CUSTOM_COLOR, COL_PANEL)
  --lcd.drawFilledRectangle(0, 40, 160, 350)
  --lcd.drawFilledRectangle(160, 40, 320, 350)
  --lcd.drawFilledRectangle(480, 40, 320, 350)

  -- Header
  drawHeader(0, 5)

  -- Separators
  lcd.setColor(CUSTOM_COLOR, COL_GRID)
  lcd.drawLine(0, 50, 800, 50, SOLID, FORCE)
  lcd.drawLine(160, 50, 160, 420, SOLID, FORCE)
  lcd.drawLine(480, 50, 480, 380, SOLID, FORCE)
  lcd.drawLine(160,380,800,380, SOLID, FORCE)

  local y = 80

  drawTracks(0, y)
  drawBladePanel(160, y)
  drawTillerPanel(480, y)
end

--------------------------------------------------
local function background(wgt)
end

-- Update function (called when options change)
local function update(wgt, options)
    wgt.options = options
end

return { name = name, options = options, create = create, update = update, refresh = refresh, background = background }
