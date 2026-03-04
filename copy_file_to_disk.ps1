<#
.SYNOPSIS
    KaguOS Copy File to Disk - PowerShell Version
    Copies a file into specified line intervals of a disk image.

.DESCRIPTION
    Replaces specified line ranges in a disk image with content from a source file.
    Supports fragmented intervals (multiple start-end pairs).
    The disk name is automatically prefixed with "hw/".

.EXAMPLE
    .\copy_file_to_disk.ps1 build/user.disk main.disk 100 200
    .\copy_file_to_disk.ps1 build/user.disk main.disk 100 150 200 250
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$FileToCopy,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$DiskName,

    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [int[]]$Intervals
)

$ErrorActionPreference = "Stop"

if ($Intervals.Count -lt 2 -or ($Intervals.Count % 2) -ne 0) {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <file to copy> <disk name> <start1> <end1> [<start2> <end2> ...]"
    exit 1
}

$DiskPath = "hw/$DiskName"

# Validate intervals
for ($i = 0; $i -lt $Intervals.Count; $i += 2) {
    $Start = $Intervals[$i]
    $End   = $Intervals[$i + 1]
    if ($Start -ge $End) {
        Write-Host "[ERROR] Invalid start-end pair ($Start, $End). Ensure start < end and both are numeric." -ForegroundColor Red
        exit 1
    }
}

# Validate files
if (-not (Test-Path $FileToCopy)) {
    Write-Host "[ERROR] User program file '$FileToCopy' does not exist." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $DiskPath)) {
    Write-Host "[ERROR] Disk file '$DiskPath' does not exist." -ForegroundColor Red
    exit 1
}

# Read source and disk
$SourceLines = @(Get-Content $FileToCopy)
$TotalLines  = $SourceLines.Count

# Calculate available slots
$AvailableSlots = 0
for ($i = 0; $i -lt $Intervals.Count; $i += 2) {
    $AvailableSlots += ($Intervals[$i + 1] - $Intervals[$i] + 1)
}

if ($TotalLines -gt $AvailableSlots) {
    Write-Host "[ERROR] Not enough space in the specified intervals. Need $TotalLines lines, but available slots are only $AvailableSlots." -ForegroundColor Red
    exit 1
}

# Read disk into array (1-indexed positions -> 0-indexed array)
$DiskLines = @(Get-Content $DiskPath)

# Clear all interval slots first
for ($i = 0; $i -lt $Intervals.Count; $i += 2) {
    $Start = $Intervals[$i]
    $End   = $Intervals[$i + 1]
    for ($pos = $Start; $pos -le $End; $pos++) {
        $DiskLines[$pos - 1] = ""
    }
}

# Write source lines into intervals in order
$srcIdx = 0
:outer for ($i = 0; $i -lt $Intervals.Count; $i += 2) {
    $Start = $Intervals[$i]
    $End   = $Intervals[$i + 1]
    for ($pos = $Start; $pos -le $End; $pos++) {
        if ($srcIdx -ge $TotalLines) { break outer }
        $DiskLines[$pos - 1] = $SourceLines[$srcIdx]
        $srcIdx++
    }
}

# Write back
$DiskLines | Set-Content -Path $DiskPath -Encoding UTF8

Write-Host "[INFO] Successfully copied $srcIdx lines from $FileToCopy to $DiskPath using fragmented intervals." -ForegroundColor Green
