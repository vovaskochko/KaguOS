<#
.SYNOPSIS
    KaguOS Disk Builder - PowerShell Version
    Builds bootable.disk from MBR, bootloader, and kernel components.

.DESCRIPTION
    Structure of output (hw/bootable.disk):
      Line 1:      Total line count
      Lines 2-51:  MBR (50 lines, must be exactly 50)
      Line 52:     "KAGU BOOTLOADER"
      Line 53:     Bootloader size (number of lines, or 0 if empty)
      Lines 54+:   Bootloader data
      Next line:   "KAGU KERNEL"
      Next line:   Kernel size (number of lines, or 0 if empty)
      Remaining:   Kernel data

.EXAMPLE
    .\build_disk.ps1 -KernelPath "hw/kernel.data"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$KernelPath,

    [Parameter(Position=1)]
    [string]$BootloaderPath = "hw/samples/bootloader.data",

    [Parameter(Position=2)]
    [string]$MbrPath = "hw/samples/mbr.data"
)

# Configuration
$OutputFile = "hw/bootable.disk"
$MbrSize = 50

# Set Error Action to Stop to mimic 'set -e'
$ErrorActionPreference = "Stop"

# --- Helper Functions ---

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Write-InfoMsg {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Green
}

function Get-LineCount {
    param([string]$Path)
    if ((Test-Path $Path) -and (Get-Item $Path).Length -gt 0) {
        # Force array @() to handle single line files correctly
        return @(Get-Content $Path).Count
    }
    return 0
}

function Get-FileContent {
    param([string]$Path)
    if ((Test-Path $Path) -and (Get-Item $Path).Length -gt 0) {
        return @(Get-Content $Path)
    }
    return @()
}

# --- Main Logic ---

# Validate Kernel Path
if (-not (Test-Path $KernelPath)) {
    Write-ErrorMsg "Kernel file not found: $KernelPath"
}

# Validate MBR Path
if (-not (Test-Path $MbrPath)) {
    Write-ErrorMsg "MBR file not found: $MbrPath"
}

# Check MBR Size
$MbrLinesTotal = Get-LineCount -Path $MbrPath
if ($MbrLinesTotal -lt $MbrSize) {
    Write-ErrorMsg "MBR file must have at least $MbrSize lines, but has only ${MbrLinesTotal}: $MbrPath"
}

# Check Bootloader
$BootloaderLines = 0
if (Test-Path $BootloaderPath) {
    $BootloaderLines = Get-LineCount -Path $BootloaderPath
    if ($BootloaderLines -eq 0) {
        Write-WarnMsg "Bootloader file is empty: $BootloaderPath"
    }
} else {
    Write-WarnMsg "Bootloader file not found, using empty bootloader: $BootloaderPath"
}

# Count Kernel Lines
$KernelLines = Get-LineCount -Path $KernelPath
if ($KernelLines -eq 0) {
    Write-WarnMsg "Kernel file is empty: $KernelPath"
}

# Calculate Total Lines
# Formula: 1 (Total) + 50 (MBR) + 1 (BL Sig) + 1 (BL Count) + BL_Lines + 1 (Krn Sig) + 1 (Krn Count) + Krn_Lines
$TotalLines = 1 + $MbrSize + 1 + 1 + $BootloaderLines + 1 + 1 + $KernelLines

Write-InfoMsg "Building disk image..."
Write-Host "  MBR lines:        $MbrSize (from source of $MbrLinesTotal)"
Write-Host "  Bootloader lines: $BootloaderLines"
Write-Host "  Kernel lines:     $KernelLines"
Write-Host "  Total lines:      $TotalLines"

# Create output directory if it doesn't exist
$OutputDir = Split-Path -Parent $OutputFile
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

# Build the content in memory to ensure correct order
$OutputContent = New-Object System.Collections.Generic.List[string]

# 1. Total line count
$OutputContent.Add($TotalLines.ToString())

# 2. MBR (Exactly 50 lines)
$MbrData = Get-Content $MbrPath | Select-Object -First $MbrSize
$OutputContent.AddRange([string[]]$MbrData)

# 3. Bootloader Signature
$OutputContent.Add("KAGU BOOTLOADER")

# 4. Bootloader Size
$OutputContent.Add($BootloaderLines.ToString())

# 5. Bootloader Data
if ($BootloaderLines -gt 0) {
    $OutputContent.AddRange([string[]](Get-FileContent $BootloaderPath))
}

# 6. Kernel Signature
$OutputContent.Add("KAGU KERNEL")

# 7. Kernel Size
$OutputContent.Add($KernelLines.ToString())

# 8. Kernel Data
if ($KernelLines -gt 0) {
    $OutputContent.AddRange([string[]](Get-FileContent $KernelPath))
}

# Write to file (Using UTF8 to be safe, or Default)
$OutputContent | Set-Content -Path $OutputFile -Encoding UTF8

# --- Final Verification ---
$ActualLines = Get-LineCount -Path $OutputFile

if ($ActualLines -ne $TotalLines) {
    Write-ErrorMsg "Mismatch! Expected $TotalLines lines, created $ActualLines lines. Check input files for encoding issues."
}

Write-InfoMsg "Successfully built $OutputFile"
Write-Host ""
Write-Host "Disk layout:"
Write-Host "  Lines 1:      Total count ($TotalLines)"
Write-Host "  Lines 2-51:   MBR"
Write-Host "  Line 52:      KAGU BOOTLOADER"
Write-Host "  Line 53:      Bootloader size ($BootloaderLines)"

if ($BootloaderLines -gt 0) {
    $BootEnd = 53 + $BootloaderLines
    Write-Host "  Lines 54-${BootEnd}:  Bootloader data"
    $KernelSig = $BootEnd + 1
} else {
    $KernelSig = 54
}

Write-Host "  Line ${KernelSig}:      KAGU KERNEL"
$KernelSizeLine = $KernelSig + 1
Write-Host "  Line ${KernelSizeLine}:      Kernel size ($KernelLines)"

if ($KernelLines -gt 0) {
    $KernelStart = $KernelSizeLine + 1
    Write-Host "  Lines ${KernelStart}-${TotalLines}: Kernel data"
}
