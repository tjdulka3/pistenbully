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


Write-Host ""
Write-Host "============================================"
Write-Host " PistenBully Deployment"
Write-Host "============================================"
Write-Host ""
Write-Host " Environment : $Environment"
Write-Host " Target      : $TargetRoot"
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