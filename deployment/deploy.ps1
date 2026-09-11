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
# It increments the patch number on every deployment.
$VersionFile = Join-Path $RepoRoot "radio\version.txt"

if (!(Test-Path $VersionFile)) {
    "1.1.1" | Set-Content -Path $VersionFile -NoNewline
}

$VersionText = (Get-Content -Path $VersionFile -Raw).Trim()

if ($VersionText -notmatch '^(\d+)\.(\d+)\.(\d+)$') {
    throw "Version file must contain a semantic version in the form X.Y.Z: $VersionFile"
}

$Major = [int]$Matches[1]
$Minor = [int]$Matches[2]
$Patch = [int]$Matches[3] + 1
$NewVersion = "$Major.$Minor.$Patch"
$NewVersion | Set-Content -Path $VersionFile -NoNewline

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
$VersionTarget = Join-Path $TargetRadio "version.txt"
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