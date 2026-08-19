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

local function fmtSA(v)
  if v == -1024 then return "HORN"
  elseif v == 0 then return "OFF"
  else return "BEEP" end
end

local function fmtSB(v)
  if v == -1024 then return "MAN"
  elseif v == 0 then return "SWG"
  else return "FUL" end
end

local function fmtSH(v)
  if v == 1024 then return "LFT"
  else return "-"
  end
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

  if getValue("ch19") == 1024 then
    lcd.drawText(x+420,y,"LOCK",SMLSIZE+BLINK+INVERS+COL_ALERT)
  end

    if getValue("ch19") == 0 then
    lcd.drawText(x+420,y,"TRAN",SMLSIZE+BLINK+INVERS+COL_WARN)
  end

  if getValue("ch17") > 0 then
    lcd.drawText(x+520,y,"BLADE",SMLSIZE+BLINK+INVERS+COL_MOTION)
  end

  if getValue("ch18") > 0 then
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

  lcd.drawText(X2, r, "SD", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSD(getValue("sd")), SMLSIZE); r=r+ROW
  lcd.drawText(X2, r, "SC", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSC(getValue("sc")), SMLSIZE); r=r+ROW
  lcd.drawText(X2, r, "SB", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSB(getValue("sb")), SMLSIZE); r=r+ROW
  lcd.drawText(X2, r, "SH", SMLSIZE); lcd.drawText(X2+VALUE_OFFSET, r, fmtSH(getValue("sh")), SMLSIZE)

  -- =========================
  -- LOGIC
  -- =========================

  lcd.drawLine(145, r + ROW*3 -5,600, r + ROW*3 -5, SOLID)

  r = r + ROW*3
  lcd.drawText(X2, r, "LOGIC", SMLSIZE); r=r+ROW

  for i=1,9 do
    if i ~= 2 then
      lcd.drawText(X2, r, "L0"..i, SMLSIZE)
      lcd.drawText(X2+VALUE_OFFSET, r, onoff(getValue("ls"..i)), SMLSIZE)
      r = r + ROW
    end
  end

  -- =========================
  -- SYSTEM
  -- =========================
  r = y + 30
  lcd.drawText(X3, r, "SYSTEM", SMLSIZE); r=r+ROW

  lcd.drawText(X3, r, "BLD", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, onoff(getValue("ch17")), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "TIL", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, onoff(getValue("ch18")), SMLSIZE)

  -- =========================
  -- BLADE
  -- =========================
  r = r + ROW*5
  lcd.drawText(X3, r, "BLADE", SMLSIZE); r=r+ROW

  lcd.drawText(X3, r, "Lift", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(getValue("ch23")), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "Tilt", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(getValue("ch24")), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "Angle", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(getValue("ch25")), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "Slew", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(getValue("ch26")), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "LW", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(getValue("ch27")), SMLSIZE); r=r+ROW
  lcd.drawText(X3, r, "RW", SMLSIZE); lcd.drawText(X3+VALUE_OFFSET, r, fmt(getValue("ch28")), SMLSIZE)

  -- =========================
  -- TRACKS
  -- =========================
  r = y + 30
  lcd.drawText(X4, r, "TRACKS", SMLSIZE); r=r+ROW

  lcd.drawText(X4, r, "L", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch1")/1024*(-100.0)).."%", SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "R", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch3")/1024*100.0).."%", SMLSIZE)

  -- =========================
  -- TILLER
  -- =========================
   r = r + ROW*5
  lcd.drawText(X4, r, "TILLER", SMLSIZE); r=r+ROW

  lcd.drawText(X4, r, "Lift", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch29")), SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "Angle", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch30")), SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "FinL", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch31")), SMLSIZE); r=r+ROW
  lcd.drawText(X4, r, "FinR", SMLSIZE); lcd.drawText(X4+VALUE_OFFSET, r, fmt(getValue("ch32")), SMLSIZE); r=r+ROW*2
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
    {0,"wg","%"},{1,"ag","%"},{2,"sg","%"},{3,"tg","%"},{4,"cst","%"},
    {5,"osc","%"},{6,"mvs","%"},{7,"dbd","%"},{8,"trt","s"},{9,"ban","%"},
    {10,"ldt","s"},{11,"lut","s"},{12,"tan","s"},{13,"bld","s"},{14,"fdt","s"}
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