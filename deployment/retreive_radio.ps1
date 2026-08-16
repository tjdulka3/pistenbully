$ErrorActionPreference = "Stop"

# ============================================================
# Configuration
# ============================================================

$RadioRoot = "D:\"

# Repository root is one level above /deployment
$RepoRoot = Split-Path -Parent $PSScriptRoot

$RadioIdentifier = Join-Path `
    $RadioRoot `
    "PistenBully-Radio.txt"


# ============================================================
# Display
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " Retrieve PistenBully Radio Configuration"
Write-Host "============================================"
Write-Host ""
Write-Host " Source : $RadioRoot"
Write-Host " Repo   : $RepoRoot"
Write-Host ""


# ============================================================
# Verify production radio
# ============================================================

if (!(Test-Path $RadioRoot)) {

    Write-Error @"
Radio drive was not found.

Expected:

    D:\

Connect the TX16S using USB Storage mode and try again.
"@

    exit 1
}


if (!(Test-Path $RadioIdentifier)) {

    Write-Error @"
D:\ exists, but it does not appear to be the
PistenBully TX16S SD card.

Missing identification file:

    D:\PistenBully-Radio.txt

RETRIEVE CANCELLED.
"@

    exit 1
}


Write-Host "Radio verified."
Write-Host ""


# ============================================================
# Source files
# ============================================================

$SourceRadio = Join-Path `
    $RadioRoot `
    "RADIO\radio.yml"

$SourceModel = Join-Path `
    $RadioRoot `
    "MODELS\model5.yml"


# ============================================================
# Destination files
# ============================================================

$DestinationRadioFolder = Join-Path `
    $RepoRoot `
    "RADIO"

$DestinationModelFolder = Join-Path `
    $RepoRoot `
    "MODELS"

$DestinationRadio = Join-Path `
    $DestinationRadioFolder `
    "radio.yml"

$DestinationModel = Join-Path `
    $DestinationModelFolder `
    "model5.yml"


# ============================================================
# Verify source files
# ============================================================

if (!(Test-Path $SourceRadio)) {

    Write-Error @"
EdgeTX radio configuration was not found:

    $SourceRadio

Retrieve cancelled.
"@

    exit 1
}


if (!(Test-Path $SourceModel)) {

    Write-Error @"
PistenBully model configuration was not found:

    $SourceModel

Retrieve cancelled.
"@

    exit 1
}


# ============================================================
# Create repo directories if necessary
# ============================================================

New-Item `
    -ItemType Directory `
    -Path $DestinationRadioFolder `
    -Force | Out-Null

New-Item `
    -ItemType Directory `
    -Path $DestinationModelFolder `
    -Force | Out-Null


# ============================================================
# Retrieve radio configuration
# ============================================================

Write-Host "Retrieving radio configuration..."

Copy-Item `
    -Path $SourceRadio `
    -Destination $DestinationRadio `
    -Force

Write-Host "  RETRIEVED  RADIO\radio.yml"


# ============================================================
# Retrieve model configuration
# ============================================================

Write-Host "Retrieving PistenBully model configuration..."

Copy-Item `
    -Path $SourceModel `
    -Destination $DestinationModel `
    -Force

Write-Host "  RETRIEVED  MODELS\model5.yml"


# ============================================================
# Show Git changes
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " Git changes"
Write-Host "============================================"
Write-Host ""

Push-Location $RepoRoot

try {

    git status --short `
        -- RADIO/radio.yml `
           MODELS/model5.yml

}
finally {

    Pop-Location
}


# ============================================================
# Finished
# ============================================================

Write-Host ""
Write-Host "============================================"
Write-Host " Retrieve successful"
Write-Host "============================================"
Write-Host ""
Write-Host "Review the YAML changes in VS Code before committing."
Write-Host ""