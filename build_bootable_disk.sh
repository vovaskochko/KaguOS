#!/bin/bash

# KaguOS Disk Builder
# Builds bootable.disk from MBR, bootloader, and kernel components
#
# Usage: ./build_disk.sh <kernel_path> [bootloader_path] [mbr_path]
#
# Structure of output (hw/bootable.disk):
#   Line 1:      Total line count
#   Lines 2-51:  MBR (50 lines, must be exactly 50)
#   Line 52:     "KAGU BOOTLOADER"
#   Line 53:     Bootloader size (number of lines, or 0 if empty)
#   Lines 54+:   Bootloader data
#   Next line:   "KAGU KERNEL"
#   Next line:   Kernel size (number of lines, or 0 if empty)
#   Remaining:   Kernel data

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default paths
DEFAULT_MBR="hw/samples/mbr.data"
DEFAULT_BOOTLOADER="hw/samples/bootloader.data"
OUTPUT_FILE="hw/bootable.disk"

# MBR must be exactly this many lines
MBR_SIZE=50

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

info() {
    echo -e "${GREEN}$1${NC}"
}

usage() {
    echo "Usage: $0 <kernel_path> [bootloader_path] [mbr_path]"
    echo ""
    echo "Arguments:"
    echo "  kernel_path      Path to kernel data file (required)"
    echo "  bootloader_path  Path to bootloader data file (optional, default: $DEFAULT_BOOTLOADER)"
    echo "  mbr_path         Path to MBR data file (optional, default: $DEFAULT_MBR)"
    echo ""
    echo "Output: $OUTPUT_FILE"
    echo ""
    echo "Disk structure:"
    echo "  Line 1:      Total line count"
    echo "  Lines 2-51:  MBR (exactly 50 lines required)"
    echo "  Line 52:     'KAGU BOOTLOADER' signature"
    echo "  Line 53:     Bootloader line count"
    echo "  Lines 54+:   Bootloader data"
    echo "  Next:        'KAGU KERNEL' signature"
    echo "  Next:        Kernel line count"
    echo "  Remaining:   Kernel data"
    exit 1
}

count_lines() {
    local file="$1"
    if [[ -f "$file" && -s "$file" ]]; then
        awk 'END {print NR}' "$file"
    else
        echo "0"
    fi
}

safe_cat() {
    local file="$1"
    if [[ -f "$file" && -s "$file" ]]; then
        awk '{print}' "$file"
    fi
}

# Check arguments
if [[ $# -lt 1 ]]; then
    usage
fi

KERNEL_PATH="$1"
BOOTLOADER_PATH="${2:-$DEFAULT_BOOTLOADER}"
MBR_PATH="${3:-$DEFAULT_MBR}"

# Validate kernel path (required)
if [[ ! -f "$KERNEL_PATH" ]]; then
    error "Kernel file not found: $KERNEL_PATH"
fi

# Validate MBR path
if [[ ! -f "$MBR_PATH" ]]; then
    error "MBR file not found: $MBR_PATH"
fi

# Check MBR has at least 50 lines
MBR_LINES=$(count_lines "$MBR_PATH")
if [[ "$MBR_LINES" -lt "$MBR_SIZE" ]]; then
    error "MBR file must have at least $MBR_SIZE lines, but has only $MBR_LINES: $MBR_PATH"
fi

# Check bootloader (optional - can be missing or empty)
BOOTLOADER_EXISTS=false
BOOTLOADER_LINES=0
if [[ -f "$BOOTLOADER_PATH" ]]; then
    BOOTLOADER_EXISTS=true
    BOOTLOADER_LINES=$(count_lines "$BOOTLOADER_PATH")
    if [[ "$BOOTLOADER_LINES" -eq 0 ]]; then
        warn "Bootloader file is empty: $BOOTLOADER_PATH"
    fi
else
    warn "Bootloader file not found, using empty bootloader: $BOOTLOADER_PATH"
fi

# Count kernel lines
KERNEL_LINES=$(count_lines "$KERNEL_PATH")
if [[ "$KERNEL_LINES" -eq 0 ]]; then
    warn "Kernel file is empty: $KERNEL_PATH"
fi

# Calculate total lines:
# 1 (count) + 50 (MBR) + 1 (BOOTLOADER sig) + 1 (bootloader size) + bootloader_lines 
# + 1 (KERNEL sig) + 1 (kernel size) + kernel_lines
TOTAL_LINES=$((1 + MBR_SIZE + 1 + 1 + BOOTLOADER_LINES + 1 + 1 + KERNEL_LINES))

info "Building disk image..."
echo "  MBR lines:        $MBR_SIZE (from source of $MBR_LINES)"
echo "  Bootloader lines: $BOOTLOADER_LINES"
echo "  Kernel lines:     $KERNEL_LINES"
echo "  Total lines:      $TOTAL_LINES"

mkdir -p "$(dirname "$OUTPUT_FILE")"

# Build the disk image
{
    # Line 1: Total line count
    echo "$TOTAL_LINES"
    
    # Lines 2-51: MBR (exactly 50 lines)
    head -n "$MBR_SIZE" "$MBR_PATH"
    
    # Line 52: Bootloader signature
    echo "KAGU BOOTLOADER"
    
    # Line 53: Bootloader size
    echo "$BOOTLOADER_LINES"
    
    # Lines 54+: Bootloader Data
    if [[ "$BOOTLOADER_LINES" -gt 0 ]]; then
        safe_cat "$BOOTLOADER_PATH"
    fi
    
    # Kernel Signature
    echo "KAGU KERNEL"
    
    # Kernel Size
    echo "$KERNEL_LINES"
    
    # Kernel Data
    if [[ "$KERNEL_LINES" -gt 0 ]]; then
        safe_cat "$KERNEL_PATH"
    fi

} > "$OUTPUT_FILE"

# --- Final Verification ---
ACTUAL_LINES=$(count_lines "$OUTPUT_FILE")

if [[ "$ACTUAL_LINES" -ne "$TOTAL_LINES" ]]; then
    error "Mismatch! Expected $TOTAL_LINES lines, created $ACTUAL_LINES lines. Check input files for weird characters."
fi

info "Successfully built $OUTPUT_FILE"
echo ""
echo "Disk layout:"
echo "  Lines 1:      Total count ($TOTAL_LINES)"
echo "  Lines 2-51:   MBR"
echo "  Line 52:      KAGU BOOTLOADER"
echo "  Line 53:      Bootloader size ($BOOTLOADER_LINES)"
if [[ "$BOOTLOADER_LINES" -gt 0 ]]; then
    BOOT_END=$((53 + BOOTLOADER_LINES))
    echo "  Lines 54-$BOOT_END:  Bootloader data"
    KERNEL_SIG=$((BOOT_END + 1))
else
    KERNEL_SIG=54
fi
echo "  Line $KERNEL_SIG:      KAGU KERNEL"
echo "  Line $((KERNEL_SIG + 1)):      Kernel size ($KERNEL_LINES)"
if [[ "$KERNEL_LINES" -gt 0 ]]; then
    echo "  Lines $((KERNEL_SIG + 2))-$TOTAL_LINES: Kernel data"
fi
