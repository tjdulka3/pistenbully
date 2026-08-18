-- ============================================================
-- PB600 DEBUG DASHBOARD
-- Current-system quick diagnostics for 800x400 color LCD
--
-- Displays:
--   * Top bar: right-stick mode, machine mode, coordination, E-stop
--   * Current operator inputs / switches
--   * ALL Lua mixer outputs for System / Blade / Tiller
--   * Logical switches currently in use
--   * GV1-GV9
--
-- IMPORTANT:
-- EdgeTX exposes Lua mixer outputs as flattened sources lua1, lua2, ...
-- Set the three 0-based script slots below to match Model -> Custom Scripts.
-- ============================================================

local name = "PB600TST"
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
-- COLORS
-- ============================================================

local COL_BG      = lcd.RGB(15, 15, 18)
local COL_PANEL   = lcd.RGB(25, 25, 30)
local COL_HEADER  = lcd.RGB(35, 35, 42)
local COL_GRID    = lcd.RGB(70, 70, 78)
local COL_TEXT    = lcd.RGB(215, 215, 220)
local COL_DIM     = lcd.RGB(135, 135, 145)
local COL_ACTIVE  = lcd.RGB(0, 170, 120)
local COL_VALUE   = lcd.RGB(120, 190, 235)
local COL_ALERT   = lcd.RGB(210, 45, 45)

-- ============================================================
-- HELPERS
-- ============================================================

local function pct(v)
  if type(v) ~= "number" then return "---" end
  return string.format("%4.0f%%", (v / 1024) * 100)
end

local function raw(v)
  if type(v) ~= "number" then return "---" end
  return string.format("%5d", v)
end

local function gv(n)
  return getValue("gvar" .. tostring(n)) or 0
end

local function switchText(v)
  if v < -500 then return "UP" end
  if v > 500 then return "DN" end
  return "MID"
end

local function boolText(v)
  return v and "ON" or "OFF"
end

local function drawPanel(x, y, w, h, title)
  lcd.setColor(CUSTOM_COLOR, COL_PANEL)
  lcd.drawFilledRectangle(x, y, w, h, CUSTOM_COLOR)

  lcd.setColor(CUSTOM_COLOR, COL_GRID)
  lcd.drawRectangle(x, y, w, h, CUSTOM_COLOR)

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(x + 7, y + 4, title, SMLSIZE + BOLD)

  lcd.setColor(CUSTOM_COLOR, COL_GRID)
  lcd.drawLine(x + 5, y + 23, x + w - 5, y + 23, SOLID, FORCE)
end

local function drawKV(x, y, label, value, active)
  lcd.setColor(CUSTOM_COLOR, COL_DIM)
  lcd.drawText(x, y, label, SMLSIZE)

  lcd.setColor(CUSTOM_COLOR, active and COL_ACTIVE or COL_VALUE)
  lcd.drawText(x + 62, y, value, SMLSIZE)
end

local function drawLuaKV(x, y, label, value)
  lcd.setColor(CUSTOM_COLOR, COL_DIM)
  lcd.drawText(x, y, label, SMLSIZE)

  if math.abs(value) > 20 then
    lcd.setColor(CUSTOM_COLOR, COL_ACTIVE)
  else
    lcd.setColor(CUSTOM_COLOR, COL_VALUE)
  end

  lcd.drawText(x + 57, y, raw(value), SMLSIZE)
end

-- ============================================================
-- HEADER
-- ============================================================

local function drawHeader()
  lcd.setColor(CUSTOM_COLOR, COL_HEADER)
  lcd.drawFilledRectangle(0, 0, 800, 46, CUSTOM_COLOR)

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(8, 7, "PB600 DEBUG", MIDSIZE)

  -- Preserve the right-stick mode display you liked.
  local sc = getValue("sc") or 0
  local stickMode = "SLEW / ANGLE"

  if sc < -500 then
    stickMode = "LIFT / TILT"
  elseif sc > 500 then
    stickMode = "TILLER ANG / LIFT"
  end

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(176, 11, "RIGHT STICK:", SMLSIZE)

  lcd.setColor(CUSTOM_COLOR, COL_VALUE)
  lcd.drawText(276, 11, stickMode, SMLSIZE + BOLD)

  -- Preserve Transport / Plow / Groom on the top bar.
  local sd = getValue("sd") or 0
  local machineMode = "PLOW"

  if sd < -500 then
    machineMode = "TRANSPORT"
  elseif sd > 500 then
    machineMode = "GROOM"
  end

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(470, 11, "MODE:", SMLSIZE)

  lcd.setColor(CUSTOM_COLOR, COL_ACTIVE)
  lcd.drawText(520, 11, machineMode, SMLSIZE + BOLD)

  local sb = getValue("sb") or 0
  local coord = sb > 500

  lcd.setColor(CUSTOM_COLOR, coord and COL_ACTIVE or COL_DIM)
  lcd.drawText(625, 11, coord and "COORD" or "MANUAL", SMLSIZE + BOLD)

  local sf = getValue("sf") or 0

  if sf > 0 then
    lcd.setColor(CUSTOM_COLOR, COL_ALERT)
    lcd.drawText(730, 11, "E-STOP", SMLSIZE + INVERS + BLINK)
  else
    lcd.setColor(CUSTOM_COLOR, COL_DIM)
    lcd.drawText(740, 11, "RUN", SMLSIZE)
  end
end

-- ============================================================
-- INPUTS / SWITCHES
-- ============================================================

local function drawInputs(x, y, w, h)
  drawPanel(x, y, w, h, "INPUTS / SWITCHES")

  local lx = x + 8
  local rx = x + 116
  local y0 = y + 29
  local dy = 18

  drawKV(lx, y0 + 0*dy, "Thr", pct(getValue("thr") or 0))
  drawKV(lx, y0 + 1*dy, "Rud", pct(getValue("rud") or 0))
  drawKV(lx, y0 + 2*dy, "AIL", pct(getValue("ail") or 0))
  drawKV(lx, y0 + 3*dy, "ELE", pct(getValue("ele") or 0))
  drawKV(lx, y0 + 4*dy, "LS",  pct(getValue("ls")  or 0))
  drawKV(lx, y0 + 5*dy, "RS",  pct(getValue("rs")  or 0))
  drawKV(lx, y0 + 6*dy, "S1",  pct(getValue("s1")  or 0))
  drawKV(lx, y0 + 7*dy, "S2",  pct(getValue("s2")  or 0))

  drawKV(rx, y0 + 0*dy, "SA", switchText(getValue("sa") or 0))
  drawKV(rx, y0 + 1*dy, "SB", switchText(getValue("sb") or 0), (getValue("sb") or 0) > 500)
  drawKV(rx, y0 + 2*dy, "SC", switchText(getValue("sc") or 0))
  drawKV(rx, y0 + 3*dy, "SD", switchText(getValue("sd") or 0))
  drawKV(rx, y0 + 4*dy, "SE", switchText(getValue("se") or 0))
  drawKV(rx, y0 + 5*dy, "SF", switchText(getValue("sf") or 0), (getValue("sf") or 0) > 0)
  drawKV(rx, y0 + 6*dy, "SG", switchText(getValue("sg") or 0))
end

-- ============================================================
-- LUA OUTPUTS
-- ============================================================

local function drawLuaOutputs(x, y, w, h)
  drawPanel(x, y, w, h, "LUA MIXER OUTPUTS")

  local y0 = y + 29
  local dy = 18

  local sx = x + 8
  local bx = x + 151
  local tx = x + 294

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(sx, y0, "SYSTEM", SMLSIZE + BOLD)
  lcd.drawText(bx, y0, "BLADE",  SMLSIZE + BOLD)
  lcd.drawText(tx, y0, "TILLER", SMLSIZE + BOLD)

  drawLuaKV(sx, y0 + 1*dy, "TrackL", luaValue(SYSTEM_SLOT, 1))
  drawLuaKV(sx, y0 + 2*dy, "TrackR", luaValue(SYSTEM_SLOT, 2))
  drawLuaKV(sx, y0 + 3*dy, "TMotor", luaValue(SYSTEM_SLOT, 3))
  drawLuaKV(sx, y0 + 4*dy, "TranB",  luaValue(SYSTEM_SLOT, 4))
  drawLuaKV(sx, y0 + 5*dy, "TranT",  luaValue(SYSTEM_SLOT, 5))
  drawLuaKV(sx, y0 + 6*dy, "EngOut", luaValue(SYSTEM_SLOT, 6))

  drawLuaKV(bx, y0 + 1*dy, "Lift",  luaValue(BLADE_SLOT, 1))
  drawLuaKV(bx, y0 + 2*dy, "Tilt",  luaValue(BLADE_SLOT, 2))
  drawLuaKV(bx, y0 + 3*dy, "Angle", luaValue(BLADE_SLOT, 3))
  drawLuaKV(bx, y0 + 4*dy, "Slew",  luaValue(BLADE_SLOT, 4))
  drawLuaKV(bx, y0 + 5*dy, "LW",    luaValue(BLADE_SLOT, 5))
  drawLuaKV(bx, y0 + 6*dy, "RW",    luaValue(BLADE_SLOT, 6))

  drawLuaKV(tx, y0 + 1*dy, "TAng",  luaValue(TILLER_SLOT, 1))
  drawLuaKV(tx, y0 + 2*dy, "TLift", luaValue(TILLER_SLOT, 2))
  drawLuaKV(tx, y0 + 3*dy, "FinL",  luaValue(TILLER_SLOT, 3))
  drawLuaKV(tx, y0 + 4*dy, "FinR",  luaValue(TILLER_SLOT, 4))
  drawLuaKV(tx, y0 + 5*dy, "Out5",  luaValue(TILLER_SLOT, 5))
  drawLuaKV(tx, y0 + 6*dy, "Out6",  luaValue(TILLER_SLOT, 6))
end

-- ============================================================
-- LOGICAL SWITCHES / GLOBAL VARIABLES
-- ============================================================

local function drawLogicAndGV(x, y, w, h)
  drawPanel(x, y, w, h, "LOGIC / GLOBAL VARIABLES")

  local y0 = y + 29
  local dy = 18

  local lx  = x + 8
  local gx1 = x + 148
  local gx2 = x + 270

  lcd.setColor(CUSTOM_COLOR, COL_TEXT)
  lcd.drawText(lx,  y0, "LOGICAL", SMLSIZE + BOLD)
  lcd.drawText(gx1, y0, "GV1-GV5", SMLSIZE + BOLD)
  lcd.drawText(gx2, y0, "GV6-GV9", SMLSIZE + BOLD)

  local l08 = getLogicalSwitchValue(7)
  local l09 = getLogicalSwitchValue(8)
  local l11 = getLogicalSwitchValue(10)
  local l12 = getLogicalSwitchValue(11)

  drawKV(lx, y0 + 1*dy, "L08 Rev",  boolText(l08), l08)
  drawKV(lx, y0 + 2*dy, "L09 Beep", boolText(l09), l09)
  drawKV(lx, y0 + 3*dy, "L11 BTr",  boolText(l11), l11)
  drawKV(lx, y0 + 4*dy, "L12 TTr",  boolText(l12), l12)

  drawKV(gx1, y0 + 1*dy, "GV1", string.format("%3d", gv(1)))
  drawKV(gx1, y0 + 2*dy, "GV2", string.format("%3d", gv(2)))
  drawKV(gx1, y0 + 3*dy, "GV3", string.format("%3d", gv(3)))
  drawKV(gx1, y0 + 4*dy, "GV4", string.format("%3d", gv(4)))
  drawKV(gx1, y0 + 5*dy, "GV5", string.format("%3d", gv(5)))

  drawKV(gx2, y0 + 1*dy, "GV6", string.format("%3d", gv(6)))
  drawKV(gx2, y0 + 2*dy, "GV7", string.format("%3d", gv(7)))
  drawKV(gx2, y0 + 3*dy, "GV8", string.format("%3d", gv(8)))
  drawKV(gx2, y0 + 4*dy, "GV9", string.format("%3d", gv(9)))
end

-- ============================================================
-- REFRESH
-- ============================================================

local function refresh(wgt, event, touchState)
  local z = wgt.zone

  if z.w < 800 or z.h < 400 then
    lcd.clear(COL_BG)
    lcd.setColor(CUSTOM_COLOR, COL_TEXT)
    lcd.drawText(z.x + 4, z.y + z.h - 18, "PB600DBG requires 800x400", SMLSIZE)
    return
  end

  lcd.clear(COL_BG)

  drawHeader()
  drawInputs(5, 51, 230, 344)
  drawLuaOutputs(240, 51, 555, 175)
  drawLogicAndGV(240, 231, 555, 164)
end

return {
  name = name,
  options = options,
  create = create,
  update = update,
  refresh = refresh,
  background = background
}
