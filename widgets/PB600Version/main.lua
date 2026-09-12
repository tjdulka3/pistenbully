local function readVersionInfo()
  if type(loadScript) ~= "function" then
    return "PistenBully 600", "E1: script loader unavailable"
  end

  local versionScript = loadScript("/SCRIPTS/version.lua")

  if type(versionScript) ~= "function" then
    return "PistenBully 600", "E2: version file not loadable"
  end

  local success, versionInfo = pcall(versionScript)

  if not success then
    return "PistenBully 600", "E3: version file execution failed"
  end

  if type(versionInfo) ~= "table" then
    return "PistenBully 600", "E4: version data is invalid"
  end

  local name = versionInfo.name
  local version = versionInfo.version

  if type(name) ~= "string" then
    return "PistenBully 600", "E5: application name missing"
  end

  if type(version) ~= "string" then
    return name, "E6: application version missing"
  end

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