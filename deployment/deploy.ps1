param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Test", "Production")]
    [string]$Environment
)

$ErrorActionPreference = "Stop"

# ============================================================
# Select deployment target
# ============================================================

if ($Environment -eq "Test") {

    $TargetRoot = "C:\radio"

}
elseif ($Environment -eq "Production") {

    $TargetRoot = "D:\"

}

# Repository root is one level above /deployment
$RepoRoot = Split-Path -Parent $PSScriptRoot

# Version file is the source of truth for the application version shown in the debug panel.
# Only production deployments increment the patch number.
$VersionFile = Join-Path $RepoRoot 'radio\version.lua'

if (!(Test-Path $VersionFile)) {
    Set-Content -Path $VersionFile -Value 'APP_VERSION = "1.1.1"' -NoNewline
}

$VersionText = (Get-Content -Path $VersionFile -Raw).Trim()

if ($VersionText -match 'APP_VERSION\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"') {
    $CurrentVersion = $Matches[1]
    $parts = $CurrentVersion.Split('.')
    $Major = [int]$parts[0]
    $Minor = [int]$parts[1]
    $Patch = [int]$parts[2]
}
elseif ($VersionText -match '^([0-9]+)\.([0-9]+)\.([0-9]+)$') {
    $Major = [int]$Matches[1]
    $Minor = [int]$Matches[2]
    $Patch = [int]$Matches[3]
    $CurrentVersion = "$Major.$Minor.$Patch"
}
else {
    throw ('Version file must contain an assignment such as APP_VERSION = "1.1.3": ' + $VersionFile)
}

$NewVersion = $CurrentVersion

if ($Environment -eq "Production") {
    $NewVersion = "$Major.$Minor.$([int]$Patch + 1)"
}

$versionLua = 'APP_VERSION = "' + $NewVersion + '"'
Set-Content -Path $VersionFile -Value $versionLua -NoNewline

Write-Host ""
Write-Host "============================================"
Write-Host " PistenBully Deployment"
Write-Host "============================================"
Write-Host ""
Write-Host " Environment : $Environment"
Write-Host " Target      : $TargetRoot"
Write-Host " Version     : $NewVersion"
Write-Host ""


# ============================================================
# Validate target
# ============================================================

if ($Environment -eq "Test") {

    # Create the test SD structure if necessary

    if (!(Test-Path $TargetRoot)) {

        Write-Host "Creating test radio folder..."

        New-Item `
            -ItemType Directory `
            -Path $TargetRoot `
            -Force | Out-Null
    }

}

if ($Environment -eq "Production") {

    if (!(Test-Path $TargetRoot)) {

        Write-Error "Production drive D:\ was not found."
        exit 1
    }

    $Identifier = Join-Path `
        $TargetRoot `
        "PistenBully-Radio.txt"

    if (!(Test-Path $Identifier)) {

        Write-Error @"
D:\ exists, but it does not appear to be the
PistenBully TX16S SD card.

Missing:

    D:\PistenBully-Radio.txt

PRODUCTION DEPLOYMENT CANCELLED.
"@

        exit 1
    }

}


# ============================================================
# Create required EdgeTX directories
# ============================================================

$TargetMixes = Join-Path `
    $TargetRoot `
    "SCRIPTS\MIXES"

$TargetWidgets = Join-Path `
    $TargetRoot `
    "WIDGETS"

$TargetModels = Join-Path `
    $TargetRoot `
    "MODELS"

$TargetRadio = Join-Path `
    $TargetRoot `
    "RADIO"

New-Item `
    -ItemType Directory `
    -Path $TargetMixes `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $TargetWidgets `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $TargetModels `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $TargetRadio `
    -Force | Out-Null

# ============================================================
# Deploy mixer scripts
# ============================================================

$SourceMixes = Join-Path `
    $RepoRoot `
    "scripts\mixes"

Write-Host "Deploying mixer scripts..."

Copy-Item `
    "$SourceMixes\*" `
    $TargetMixes `
    -Recurse `
    -Force


# ============================================================
# Deploy widgets
# ============================================================

$SourceWidgets = Join-Path `
    $RepoRoot `
    "widgets"

# Clear stale widget folders so the radio sees the freshly deployed version.
$WidgetNames = @("PB600Dbg", "PB600Op")
foreach ($WidgetName in $WidgetNames) {
    $WidgetTarget = Join-Path $TargetWidgets $WidgetName
    if (Test-Path $WidgetTarget) {
        Remove-Item -Path $WidgetTarget -Recurse -Force
    }
}

Write-Host "Deploying widgets..."

Copy-Item `
    "$SourceWidgets\*" `
    $TargetWidgets `
    -Recurse `
    -Force

# ============================================================
# Deploy models
# ============================================================

$SourceModels = Join-Path `
    $RepoRoot `
    "models"

Write-Host "Deploying models..."

Copy-Item `
    "$SourceModels\*" `
    $TargetModels `
    -Recurse `
    -Force

# ============================================================
# Deploy radio
# ============================================================

$SourceRadio = Join-Path `
    $RepoRoot `
    "radio"

Write-Host "Deploying radio..."

Copy-Item `
    "$SourceRadio\*" `
    $TargetRadio `
    -Recurse `
    -Force

# Version file is deployed to the radio root so the debug widget can read it there.
$VersionTarget = Join-Path $TargetRadio "version.lua"
$LegacyVersionTarget = Join-Path $TargetRadio "version.txt"
if (Test-Path $LegacyVersionTarget) {
    Remove-Item -Path $LegacyVersionTarget -Force
}
Copy-Item -Path $VersionFile -Destination $VersionTarget -Force

# ============================================================
# Finished
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " Deployment successful"
Write-Host "============================================"
Write-Host ""
Write-Host " Environment : $Environment"
Write-Host " Target      : $TargetRoot"
Write-Host ""