local function readVersionInfo()
  local versionScript = loadScript("/RADIO/version.lua")

  if not versionScript then
    return "PistenBully 600", "Version unavailable"
  end

  local versionInfo = versionScript()

  if type(versionInfo) ~= "table" then
    return "PistenBully 600", "Version unavailable"
  end

  local name = versionInfo.name
  local version = versionInfo.version

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