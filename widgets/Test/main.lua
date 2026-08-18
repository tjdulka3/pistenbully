local widget = {}

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

-- =========================
-- LAYOUT
-- =========================
local ROW = 18
local X1 = 15
local X2 = 155
local X3 = 295
local X4 = 435
local X5 = 610

local VALUE_OFFSET = 70

-- =========================
-- HELPERS
-- =========================
local function fmt(v) return string.format("%4d", v or 0) end
local function onoff(v) return ((v or 0) > 0) and "1" or "0" end

local function fmtSD(v)
  if v == -1024 then return "TRN"
  elseif v == 0 then return "PLW"
  else return "GRM" end
end

local function fmtSC(v)
  if v == -1024 then return "B1"
  elseif v == 0 then return "B2"
  else return "TIL" end
end

local function fmtSB(v)
  if v == -1024 then return "MAN"
  elseif v == 0 then return "SWG"
  else return "FUL" end
end

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

local function fmtSF(v)
  if v == 1024 then return "E-STOP"
  else return ""
  end
end

local function getGV(idx)
  return model.getGlobalVariable(idx, 0) or 0
end

-- =========================
-- MAIN DRAW
-- =========================
local function draw(zone)

  local x = zone.x
  local y = zone.y

  lcd.clear(lcd.RGB(44,143,176))

  -- =========================
  -- HEADER
  -- =========================
  lcd.drawText(x+5,y,"PB600 DEBUG",SMLSIZE+INVERS)

  lcd.drawText(x+120,y,"SD "..fmtSD(getValue("sd")),SMLSIZE)
  lcd.drawText(x+200,y,"SC "..fmtSC(getValue("sc")),SMLSIZE)
  lcd.drawText(x+280,y,"SB "..fmtSB(getValue("sb")),SMLSIZE)

  local revRequest = (getValue("sd") or 0) > 500 and (getValue("thr") or 0) < -50
  local bladeTran = luaValue(SYSTEM_SLOT, 4) > 0
  local tillerTran = luaValue(SYSTEM_SLOT, 5) > 0
  local trackL = luaValue(SYSTEM_SLOT, 1)
  local trackR = luaValue(SYSTEM_SLOT, 2)

  if revRequest then
    if bladeTran or tillerTran then
      lcd.drawText(x+420,y,"REV LIFT",SMLSIZE+BLINK+INVERS+COL_WARN)
    elseif math.abs(trackL) < 25 and math.abs(trackR) < 25 then
      lcd.drawText(x+420,y,"REV HOLD",SMLSIZE+BLINK+INVERS+COL_WARN)
    else
      lcd.drawText(x+420,y,"REVERSE",SMLSIZE+INVERS+COL_REV)
    end
  elseif bladeTran then
    lcd.drawText(x+520,y,"BLADE",SMLSIZE+BLINK+INVERS+COL_MOTION)
  elseif tillerTran then
    lcd.drawText(x+620,y,"TILLER",SMLSIZE+BLINK+INVERS+COL_MOTION)
  end

  lcd.drawText(x+720,y,fmtSF(getValue("sf")),SMLSIZE+COL_ALERT)


  lcd.drawLine(0, y+25, 800, y+25, SOLID)

  -- =========================
  -- COLUMN SEPARATORS
  -- =========================
  local top = y + 25
  local bottom = y + 320

  lcd.drawLine(145, top, 145, bottom, SOLID)
  lcd.drawLine(285, top, 285, bottom, SOLID)
  lcd.drawLine(425, top, 425, bottom, SOLID)
  lcd.drawLine(600, top, 600, bottom, SOLID)

  -- =========================
  -- INPUTS (FULL)
  -- =========================
  local r = y + 30
  lcd.drawText(X1, r, "INPUTS", SMLSIZE); r=r+ROW

  lcd.drawText(X1, r, "Thr", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("thr")), SMLSIZE); r=r+ROW
  lcd.drawText(X1, r, "Rud", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("rud")), SMLSIZE); r=r+ROW
  lcd.drawText(X1, r, "Ele", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("ele")), SMLSIZE); r=r+ROW
  lcd.drawText(X1, r, "Ail", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("ail")), SMLSIZE); r=r+ROW

  r = r + 6
  lcd.drawText(X1, r, "LS", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("ls")), SMLSIZE); r=r+ROW
  lcd.drawText(X1, r, "RS", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("rs")), SMLSIZE); r=r+ROW

  r = r + 6
  lcd.drawText(X1, r, "SE", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("se")), SMLSIZE); r=r+ROW
  lcd.drawText(X1, r, "SG", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("sg")), SMLSIZE); r=r+ROW

  r = r + 6
  lcd.drawText(X1, r, "S1", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("s1")), SMLSIZE); r=r+ROW
  lcd.drawText(X1, r, "S2", SMLSIZE); lcd.drawText(X1+VALUE_OFFSET, r, fmt(getValue("s2")), SMLSIZE)

  -- =========================
  -- SWITCHES
  -- =========================
  r = y + 30
  lcd.drawText(X2, r, "SWITCHES", SMLSIZE); r=r+ROW

  lcd.drawText(X2, r, "SA", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmt(getValue("sa")), SMLSIZE); r=r+ROW
  lcd.drawText(X2, r, "SB", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSB(getValue("sb")), SMLSIZE); r=r+ROW
  lcd.drawText(X2, r, "SC", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSC(getValue("sc")), SMLSIZE); r=r+ROW
  lcd.drawText(X2, r, "SD", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSD(getValue("sd")), SMLSIZE); r=r+ROW
  lcd.drawText(X2, r, "SF", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSF(getValue("sf")), SMLSIZE)

  -- =========================
  -- LOGIC
  -- =========================

  lcd.drawLine(145, r + ROW*2 -5,600, r + ROW*2 -5, SOLID)

  r = r + ROW*2
  lcd.drawText(X2, r, "LOGIC", SMLSIZE); r=r+ROW

  for _,i in ipairs({8,9,11,12}) do
    lcd.drawText(X2, r, "L"..string.format("%02d", i), SMLSIZE)
    lcd.drawText(X2+VALUE_OFFSET, r, onoff(getValue("ls"..i)), SMLSIZE)
    r = r + ROW
  end

  -- =========================
  -- SYSTEM
  -- =========================
  r = y + 30
  lcd.drawText(X3, r, "SYSTEM", SMLSIZE); r=r+ROW

  local sysNames = {"TrackL","TrackR","TMotor","TranB","TranT","Engine"}
  for i=1,6 do
    lcd.drawText(X3, r, sysNames[i], SMLSIZE)
    lcd.drawText(X3+VALUE_OFFSET, r, fmt(luaValue(SYSTEM_SLOT,i)), SMLSIZE)
    r=r+ROW
  end

  -- =========================
  -- BLADE
  -- =========================
  r = r + ROW
  lcd.drawText(X3, r, "BLADE", SMLSIZE); r=r+ROW

  lcd.drawText(X3, r, "Lift", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(luaValue(BLADE_SLOT,1)), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "Tilt", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(luaValue(BLADE_SLOT,2)), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "Angle", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(luaValue(BLADE_SLOT,3)), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "Slew", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(luaValue(BLADE_SLOT,4)), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "LW", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(luaValue(BLADE_SLOT,5)), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "RW", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(luaValue(BLADE_SLOT,6)), SMLSIZE)

  -- =========================
  -- TRACKS
  -- =========================
  r = y + 30
  lcd.drawText(X4, r, "TRACKS", SMLSIZE); r=r+ROW

  lcd.drawText(X4, r, "L", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(luaValue(SYSTEM_SLOT,1)/1024*(-100.0)).."%", SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "R", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(luaValue(SYSTEM_SLOT,2)/1024*100.0).."%", SMLSIZE)

  -- =========================
  -- TILLER
  -- =========================
   r = r + ROW*5
  lcd.drawText(X4, r, "TILLER", SMLSIZE); r=r+ROW

  lcd.drawText(X4, r, "Lift", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(luaValue(TILLER_SLOT,2)), SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "Angle", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(luaValue(TILLER_SLOT,1)), SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "FinL", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(luaValue(TILLER_SLOT,3)), SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "FinR", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(luaValue(TILLER_SLOT,4)), SMLSIZE); r=r+ROW*2
  lcd.drawText(X4, r, "Swing", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch9")), SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "Rotor", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch14")), SMLSIZE)

  -- =========================
  -- CHANNELS
  -- =========================
  r = y + 30
  lcd.drawText(X5, r, "CHANNELS", SMLSIZE); r=r+ROW

  for i=1,18 do
    lcd.drawText(X5, r, "C"..i, SMLSIZE)
    lcd.drawText(X5+45, r, fmt(getValue("ch"..i)), SMLSIZE)
    r = r + 14
  end

  -- =========================
  -- GV SECTION
  -- =========================
  lcd.drawLine(0, y+320, 800, y+320, SOLID)
  lcd.drawText(10, y+325, "GLOBAL VARIABLES", SMLSIZE)

  local gy = y + 345
  local colW = 155

  local gvs = {
    {0,"Coord Gain","%"},
    {1,"Blade Depth","%"},
    {2,"Tiller Depth","%"},
    {3,"Reverse Lift","%"},
    {4,"Tiller Angle","%"}
  }

  local gx = 10
  local gy_row = gy

  for i=1,#gvs do
    local idx, name, unit = gvs[i][1], gvs[i][2], gvs[i][3]
    local val = getGV(idx)

    local label = string.format("[%d] %s", idx+1, name)
    local value = (unit == "%") and (val.."%" ) or string.format("%0.1fs", val/10)

    lcd.drawText(gx, gy_row, label, SMLSIZE)
    lcd.drawText(gx+80, gy_row, value, SMLSIZE)

    gx = gx + colW
    if (i % 5) == 0 then
      gx = 10
      gy_row = gy_row + ROW
    end
  end

end

function widget.create(zone, options)
  return { zone = zone }
end

function widget.update(widget, options) end

function widget.refresh(widget)
  draw(widget.zone)
end

return {
  name = "PB600 DEBUG FINAL",
  options = {},
  create = widget.create,
  update = widget.update,
  refresh = widget.refresh
}