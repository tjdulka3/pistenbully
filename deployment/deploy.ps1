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

# The debug widget owns the displayed application version.
$DebugWidgetPath = Join-Path $RepoRoot 'widgets\PB600Dbg\main.lua'

if (!(Test-Path $DebugWidgetPath)) {
    throw ('Missing debug widget script for version tracking: ' + $DebugWidgetPath)
}

$DebugWidgetText = (Get-Content -Path $DebugWidgetPath -Raw).Trim()

if ($DebugWidgetText -match 'APP_VERSION\s*=\s*"([0-9]+\.[0-9]+\.[0-9]+)"') {
    $CurrentVersion = $Matches[1]
    $parts = $CurrentVersion.Split('.')
    $Major = [int]$parts[0]
    $Minor = [int]$parts[1]
    $Patch = [int]$parts[2]
}
else {
    throw ('Version must be defined in the debug widget as APP_VERSION = "1.1.3": ' + $DebugWidgetPath)
}

$CurrentVersionDisplay = $CurrentVersion
$PendingVersion = $CurrentVersion

if ($Environment -eq "Production") {
    $PendingVersion = "$Major.$Minor.$([int]$Patch + 1)"
}

Write-Host ""
Write-Host "============================================"
Write-Host " PistenBully Deployment"
Write-Host "============================================"
Write-Host ""
Write-Host " Environment : $Environment"
Write-Host " Target      : $TargetRoot"
Write-Host " Version     : $CurrentVersionDisplay"
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

# Only increment the version on successful production deployment.
$TargetDebugWidget = Join-Path $TargetWidgets 'PB600Dbg\main.lua'

if ($Environment -eq "Production") {
    $updatedTargetWidget = (Get-Content -Path $TargetDebugWidget -Raw) -replace 'APP_VERSION\s*=\s*"[0-9]+\.[0-9]+\.[0-9]+"', ('APP_VERSION = "' + $PendingVersion + '"')
    Set-Content -Path $TargetDebugWidget -Value $updatedTargetWidget -NoNewline

    $updatedSourceWidget = (Get-Content -Path $DebugWidgetPath -Raw) -replace 'APP_VERSION\s*=\s*"[0-9]+\.[0-9]+\.[0-9]+"', ('APP_VERSION = "' + $PendingVersion + '"')
    Set-Content -Path $DebugWidgetPath -Value $updatedSourceWidget -NoNewline
}

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
Write-Host " Version     : $PendingVersion"
Write-Host ""