-- ============================================================
-- PB600 DEBUG DASHBOARD
-- Clean diagnostic panel matching original PB600 panel styling
-- 800x400 color LCD
--
-- Displays:
--   * Top bar: right-stick mode, coordination, machine mode
--   * Current inputs / switches
--   * All Lua mixer outputs for System / Blade / Tiller
--   * Logical switches actually in use: L08, L09, L11, L12
--   * Global variables actually in use: GV1-GV5
--
-- Lua mixer sources are flattened by EdgeTX as lua1, lua2, ...
-- Set the three 0-based script slots below to match the
-- Model -> Custom Scripts order.
-- ============================================================

local name = "PB600DBG"
local options = {}

local function create(zone, options)
  return { zone = zone, options = options }
end

local function update(wgt, options)
  wgt.options = options
end

local function background(wgt)
end

-- ============================================================
-- CUSTOM SCRIPT SLOT ORDER
-- ============================================================

local SYSTEM_SLOT = 0
local BLADE_SLOT  = 1
local TILLER_SLOT = 2
local OUTPUTS_PER_SCRIPT = 6

local function luaSource(slot, outputNumber)
  return "lua" .. tostring(slot * OUTPUTS_PER_SCRIPT + outputNumber)
end

local function luaValue(slot, outputNumber)
  return getValue(luaSource(slot, outputNumber)) or 0
end

-- ============================================================
-- ORIGINAL PB600 COLOR PALETTE
-- ============================================================

local COL_BG     = lcd.RGB(44,143,176)

local COL_PANEL  = lcd.RGB(25,25,30)
local COL_GRID   = lcd.RGB(70,70,75)
local COL_TEXT   = lcd.RGB(200,200,200)

local COL_ACTIVE = lcd.RGB(0,160,120)
local COL_WARN   = lcd.RGB(220,140,0)
local COL_ALERT  = lcd.RGB(200,40,40)
local COL_HYD    = lcd.RGB(0,110,180)
local COL_MOTION = lcd.RGB(160,160,160)

local COL_FWD    = lcd.RGB(16,179,57)
local COL_REV    = lcd.RGB(242,206,13)

-- ============================================================
-- HELPERS
-- ============================================================

local function pct(v)
  if type(v) ~= "number" then
    return "---"
  end

  return string.format("%4.0f%%", (v / 1024) * 100)
end

local function raw(v)
  if type(v) ~= "number" then
    return "---"
  end

  return string.format("%5d", v)
end

local function gv(n)
  return getValue("gvar" .. tostring(n)) or 0
end

local function switchText(v)
  if v < -500 then
    return "UP"
  elseif v > 500 then
    return "DN"
  else
    return "MID"
  end
end

local function boolText(v)
  return v and "ON" or "OFF"
end


local function drawPanel(x, y, w, h, title)

  -- Match the older panel style:
  -- no large dark card backgrounds, just thin separators.
  lcd.setColor(CUSTOM_COLOR, COL_GRID)
  lcd.drawRectangle(x, y, w, h)

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(
    x + 6,
    y + 4,
    title,
    SMLSIZE
  )

  lcd.setColor(CUSTOM_COLOR, COL_GRID)
  lcd.drawLine(
    x + 4,
    y + 22,
    x + w - 4,
    y + 22,
    SOLID,
    FORCE
  )
end


local function drawKV(x, y, label, value, active)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x,
    y,
    label,
    SMLSIZE
  )

  if active then
    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )
  else
    lcd.setColor(
      CUSTOM_COLOR,
      COL_TEXT
    )
  end

  lcd.drawText(
    x + 54,
    y,
    value,
    SMLSIZE
  )
end


local function drawLuaKV(x, y, label, value)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x,
    y,
    label,
    SMLSIZE
  )

  if math.abs(value) < 20 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_GRID
    )

  elseif math.abs(value) < 700 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )

  else

    lcd.setColor(
      CUSTOM_COLOR,
      COL_WARN
    )

  end

  lcd.drawText(
    x + 50,
    y,
    raw(value),
    SMLSIZE
  )
end

-- ============================================================
-- HEADER
-- ============================================================

local function drawHeader(x, y)

  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x,
    y,
    "Pisten Bully 600 DEBUG",
    MIDSIZE
  )


  -- Right-stick mode from SC.
  local sc =
    getValue("sc") or 0

  local stickMode =
    "BLADE SLEW/ANGLE"

  if sc < -500 then

    stickMode =
      "BLADE LIFT/TILT"

  elseif sc > 500 then

    stickMode =
      "TILLER LIFT/ANGLE"

  end


  lcd.drawText(
    x + 260,
    y + 10,
    "STICK MODE: " .. stickMode,
    SMLSIZE
  )


  -- Coordination from SB.
  local sb =
    getValue("sb") or 0

  if sb > 500 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ACTIVE
    )

    lcd.drawText(
      x + 575,
      y + 10,
      "COORDINATED",
      SMLSIZE
    )

  else

    lcd.setColor(
      CUSTOM_COLOR,
      COL_GRID
    )

    lcd.drawText(
      x + 575,
      y + 10,
      "MANUAL",
      SMLSIZE
    )

  end


  -- Machine mode from SD.
  local sd =
    getValue("sd") or 0

  local label =
    "PLOW"

  if sd < -500 then

    label =
      "TRANSPORT"

  elseif sd > 500 then

    label =
      "GROOM"

  end


  local flags =
    SMLSIZE

  local bladeTransition =
    getLogicalSwitchValue(10)

  local tillerTransition =
    getLogicalSwitchValue(11)

  if bladeTransition
    or tillerTransition
  then

    flags =
      SMLSIZE + INVERS

  end


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    x + 705,
    y + 10,
    label,
    flags
  )


  -- E-stop indicator.
  local sf =
    getValue("sf") or 0

  if sf > 0 then

    lcd.setColor(
      CUSTOM_COLOR,
      COL_ALERT
    )

    lcd.drawText(
      x + 705,
      y + 28,
      "E-STOP",
      SMLSIZE + INVERS + BLINK
    )

  end
end

-- ============================================================
-- INPUTS / SWITCHES
-- ============================================================

local function drawInputs(x, y, w, h)

  drawPanel(
    x,
    y,
    w,
    h,
    "INPUTS / SWITCHES"
  )

  local lx =
    x + 7

  local rx =
    x + 105

  local y0 =
    y + 28

  local dy =
    17


  -- Analog / sticks.
  drawKV(
    lx,
    y0 + 0*dy,
    "Thr",
    pct(getValue("thr") or 0)
  )

  drawKV(
    lx,
    y0 + 1*dy,
    "Rud",
    pct(getValue("rud") or 0)
  )

  drawKV(
    lx,
    y0 + 2*dy,
    "AIL",
    pct(getValue("ail") or 0)
  )

  drawKV(
    lx,
    y0 + 3*dy,
    "ELE",
    pct(getValue("ele") or 0)
  )

  drawKV(
    lx,
    y0 + 4*dy,
    "LS",
    pct(getValue("ls") or 0)
  )

  drawKV(
    lx,
    y0 + 5*dy,
    "RS",
    pct(getValue("rs") or 0)
  )

  drawKV(
    lx,
    y0 + 6*dy,
    "S1",
    pct(getValue("s1") or 0)
  )

  drawKV(
    lx,
    y0 + 7*dy,
    "S2",
    pct(getValue("s2") or 0)
  )


  -- Switches currently relevant.
  local sa = getValue("sa") or 0
  local sb = getValue("sb") or 0
  local sc = getValue("sc") or 0
  local sd = getValue("sd") or 0
  local se = getValue("se") or 0
  local sf = getValue("sf") or 0
  local sg = getValue("sg") or 0


  drawKV(
    rx,
    y0 + 0*dy,
    "SA",
    switchText(sa)
  )

  drawKV(
    rx,
    y0 + 1*dy,
    "SB",
    switchText(sb),
    sb > 500
  )

  drawKV(
    rx,
    y0 + 2*dy,
    "SC",
    switchText(sc)
  )

  drawKV(
    rx,
    y0 + 3*dy,
    "SD",
    switchText(sd)
  )

  drawKV(
    rx,
    y0 + 4*dy,
    "SE",
    switchText(se)
  )

  drawKV(
    rx,
    y0 + 5*dy,
    "SF",
    switchText(sf),
    sf > 0
  )

  drawKV(
    rx,
    y0 + 6*dy,
    "SG",
    switchText(sg)
  )
end

-- ============================================================
-- LUA MIXER OUTPUTS
-- ============================================================

local function drawLuaOutputs(x, y, w, h)

  drawPanel(
    x,
    y,
    w,
    h,
    "LUA MIXER OUTPUTS"
  )

  local y0 =
    y + 28

  local dy =
    17

  local sx =
    x + 7

  local bx =
    x + 183

  local tx =
    x + 359


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    sx,
    y0,
    "SYSTEM",
    SMLSIZE
  )

  lcd.drawText(
    bx,
    y0,
    "BLADE",
    SMLSIZE
  )

  lcd.drawText(
    tx,
    y0,
    "TILLER",
    SMLSIZE
  )


  -- system.lua
  drawLuaKV(
    sx,
    y0 + 1*dy,
    "TrackL",
    luaValue(SYSTEM_SLOT, 1)
  )

  drawLuaKV(
    sx,
    y0 + 2*dy,
    "TrackR",
    luaValue(SYSTEM_SLOT, 2)
  )

  drawLuaKV(
    sx,
    y0 + 3*dy,
    "TMotor",
    luaValue(SYSTEM_SLOT, 3)
  )

  drawLuaKV(
    sx,
    y0 + 4*dy,
    "TranB",
    luaValue(SYSTEM_SLOT, 4)
  )

  drawLuaKV(
    sx,
    y0 + 5*dy,
    "TranT",
    luaValue(SYSTEM_SLOT, 5)
  )

  drawLuaKV(
    sx,
    y0 + 6*dy,
    "EngOut",
    luaValue(SYSTEM_SLOT, 6)
  )


  -- blade.lua
  drawLuaKV(
    bx,
    y0 + 1*dy,
    "Lift",
    luaValue(BLADE_SLOT, 1)
  )

  drawLuaKV(
    bx,
    y0 + 2*dy,
    "Tilt",
    luaValue(BLADE_SLOT, 2)
  )

  drawLuaKV(
    bx,
    y0 + 3*dy,
    "Angle",
    luaValue(BLADE_SLOT, 3)
  )

  drawLuaKV(
    bx,
    y0 + 4*dy,
    "Slew",
    luaValue(BLADE_SLOT, 4)
  )

  drawLuaKV(
    bx,
    y0 + 5*dy,
    "LW",
    luaValue(BLADE_SLOT, 5)
  )

  drawLuaKV(
    bx,
    y0 + 6*dy,
    "RW",
    luaValue(BLADE_SLOT, 6)
  )


  -- tiller.lua
  drawLuaKV(
    tx,
    y0 + 1*dy,
    "TAng",
    luaValue(TILLER_SLOT, 1)
  )

  drawLuaKV(
    tx,
    y0 + 2*dy,
    "TLift",
    luaValue(TILLER_SLOT, 2)
  )

  drawLuaKV(
    tx,
    y0 + 3*dy,
    "FinL",
    luaValue(TILLER_SLOT, 3)
  )

  drawLuaKV(
    tx,
    y0 + 4*dy,
    "FinR",
    luaValue(TILLER_SLOT, 4)
  )
end

-- ============================================================
-- USED LOGICAL SWITCHES / USED GLOBAL VARIABLES
-- ============================================================

local function drawLogicGV(x, y, w, h)

  drawPanel(
    x,
    y,
    w,
    h,
    "LOGICAL SWITCHES / GLOBAL VARIABLES"
  )

  local y0 =
    y + 28

  local dy =
    17

  local lx =
    x + 7

  local gx =
    x + 220


  lcd.setColor(
    CUSTOM_COLOR,
    COL_TEXT
  )

  lcd.drawText(
    lx,
    y0,
    "LOGICAL",
    SMLSIZE
  )

  lcd.drawText(
    gx,
    y0,
    "GLOBAL VARIABLES",
    SMLSIZE
  )


  -- Only logical switches currently used.
  local l08 =
    getLogicalSwitchValue(7)

  local l09 =
    getLogicalSwitchValue(8)

  local l11 =
    getLogicalSwitchValue(10)

  local l12 =
    getLogicalSwitchValue(11)


  drawKV(
    lx,
    y0 + 1*dy,
    "L08 REV",
    boolText(l08),
    l08
  )

  drawKV(
    lx,
    y0 + 2*dy,
    "L09 BEEP",
    boolText(l09),
    l09
  )

  drawKV(
    lx,
    y0 + 3*dy,
    "L11 BTR",
    boolText(l11),
    l11
  )

  drawKV(
    lx,
    y0 + 4*dy,
    "L12 TTR",
    boolText(l12),
    l12
  )


  -- Only GVs currently used.
  drawKV(
    gx,
    y0 + 1*dy,
    "GV1 Coord",
    string.format("%3d", gv(1))
  )

  drawKV(
    gx,
    y0 + 2*dy,
    "GV2 Blade",
    string.format("%3d", gv(2))
  )

  drawKV(
    gx,
    y0 + 3*dy,
    "GV3 Tiller",
    string.format("%3d", gv(3))
  )

  drawKV(
    gx,
    y0 + 4*dy,
    "GV4 Rev",
    string.format("%3d", gv(4))
  )

  drawKV(
    gx,
    y0 + 5*dy,
    "GV5 TAng",
    string.format("%3d", gv(5))
  )
end

-- ============================================================
-- REFRESH
-- ============================================================

local function refresh(wgt, event, touchState)

  local z =
    wgt.zone


  if z.w < 800
    or z.h < 400
  then

    lcd.clear(
      COL_BG
    )

    lcd.setColor(
      CUSTOM_COLOR,
      COL_TEXT
    )

    lcd.drawText(
      z.x + 2,
      z.y + z.h - 14,
      "Need at least 800x400",
      SMLSIZE
    )

    return

  end


  -- Match original panel background.
  lcd.clear(
    COL_BG
  )


  drawHeader(
    0,
    5
  )


  -- Original-style separator below header.
  lcd.setColor(
    CUSTOM_COLOR,
    COL_GRID
  )

  lcd.drawLine(
    0,
    50,
    800,
    50,
    SOLID,
    FORCE
  )


  -- Compact, information-dense layout.
  drawInputs(
    5,
    57,
    205,
    338
  )

  drawLuaOutputs(
    216,
    57,
    579,
    165
  )

  drawLogicGV(
    216,
    228,
    579,
    167
  )
end


return {
  name = name,
  options = options,
  create = create,
  update = update,
  refresh = refresh,
  background = background
}
