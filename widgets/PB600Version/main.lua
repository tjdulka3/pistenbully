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

  local updated = versionInfo.updated

  return name or "PistenBully 600", version and ("v" .. version) or "Version unavailable",
    "Updated: " .. (type(updated) == "string" and updated or "unknown")
end

local function create(zone, options)
  local name, version, updated = readVersionInfo()

  return {
    zone = zone,
    name = name,
    version = version,
    updated = updated
  }
end

local function refresh(widget)
  lcd.drawText(widget.zone.x, widget.zone.y, widget.name, SMLSIZE)
  lcd.drawText(widget.zone.x, widget.zone.y + 16, widget.version, SMLSIZE)
  if widget.updated then
    lcd.drawText(widget.zone.x, widget.zone.y + 32, widget.updated, SMLSIZE)
  end
end

return {
  name = "PB600Version",
  options = {},
  create = create,
  refresh = refresh
}