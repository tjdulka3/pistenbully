local function readVersionInfo()
  local file = io.open("/RADIO/version.lua", "r")

  if not file then
    return "PistenBully 600", "Version unavailable"
  end

  local content = file:read("*a")
  file:close()

  local name = string.match(content, 'APP_NAME%s*=%s*"([^"]+)"')
  local version = string.match(content, 'APP_VERSION%s*=%s*"([^"]+)"')

  return name or "PistenBully 600", version and ("v" .. version) or "Version unavailable"
end

local function create(zone, options)
  local name, version = readVersionInfo()

  return {
    zone = zone,
    name = name,
    version = version
  }
end

local function refresh(widget)
  lcd.drawText(widget.zone.x, widget.zone.y, widget.name, SMLSIZE)
  lcd.drawText(widget.zone.x, widget.zone.y + 16, widget.version, SMLSIZE)
end

return {
  name = "PB600Version",
  options = {},
  create = create,
  refresh = refresh
}