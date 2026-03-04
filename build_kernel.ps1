<#
.SYNOPSIS
    KaguOS Kernel Builder - PowerShell Version
    Compiles kernel .kga files with kagu_asm and builds bootable disk.

.EXAMPLE
    .\build_kernel.ps1
#>

$ErrorActionPreference = "Stop"

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Write-InfoMsg {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Green
}

Set-Location $PSScriptRoot

$KernelSrcDir = "src/kernel"
$KernelData   = "build/kernel.data"

# Find assembler (with or without .exe)
$AsmExe = $null
if     (Test-Path ".\kagu_asm.exe") { $AsmExe = ".\kagu_asm.exe" }
elseif (Test-Path ".\kagu_asm")     { $AsmExe = ".\kagu_asm" }

if (-not $AsmExe) {
    Write-ErrorMsg "kagu_asm not found. Build it first with: cmake --build build/"
}

# Check kernel source directory
if (-not (Test-Path $KernelSrcDir)) {
    Write-ErrorMsg "Kernel source directory not found: $KernelSrcDir"
}

# Collect kernel .kga files in sorted order
$KernelFiles = @(
    Get-ChildItem -Path $KernelSrcDir -Filter "*.kga" -Recurse |
    Sort-Object FullName |
    Select-Object -ExpandProperty FullName
)

if ($KernelFiles.Count -eq 0) {
    Write-ErrorMsg "No .kga files found in $KernelSrcDir"
}

# Step 1: Compile with kagu_asm
Write-InfoMsg "Step 1: Compiling kernel..."
Write-Host "  Files:"
foreach ($f in $KernelFiles) {
    Write-Host "    - $(Split-Path $f -Leaf)"
}

& $AsmExe @KernelFiles
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "kagu_asm failed with exit code $LASTEXITCODE"
}

# Step 2: Build bootable disk
Write-InfoMsg "Step 2: Building bootable disk..."
& "$PSScriptRoot\build_bootable_disk.ps1" -KernelPath $KernelData
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "build_bootable_disk.ps1 failed with exit code $LASTEXITCODE"
}

Write-InfoMsg "Done! Run with: .\kagu_boot.exe hw\cpu_firmware.bin <ram_size>"
