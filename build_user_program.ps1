<#
.SYNOPSIS
    KaguOS User Program Builder - PowerShell Version
    Compiles a user-space .kga source file with kagu_asm -u.

.DESCRIPTION
    Output goes to build/user.disk.

.EXAMPLE
    .\build_user_program.ps1 src/hello.kga
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Source
)

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

if (-not (Test-Path $Source)) {
    Write-ErrorMsg "Source file not found: $Source"
}

# Find assembler (with or without .exe)
$AsmExe = $null
if     (Test-Path ".\kagu_asm.exe") { $AsmExe = ".\kagu_asm.exe" }
elseif (Test-Path ".\kagu_asm")     { $AsmExe = ".\kagu_asm" }

if (-not $AsmExe) {
    Write-ErrorMsg "kagu_asm not found. Build it first with: cmake --build build/"
}

Write-InfoMsg "Compiling user program: $Source"
& $AsmExe -u $Source
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "kagu_asm failed with exit code $LASTEXITCODE"
}

Write-InfoMsg "Done! User program compiled to: build/user.disk"
Write-InfoMsg "Copy it to a disk with: .\copy_file_to_disk.ps1 build/user.disk main.disk <start> <end>"
