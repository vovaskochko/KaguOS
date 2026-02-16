#!/bin/bash

# KaguOS Kernel Builder
# Compiles kernel .kga files with kagu_asm and builds bootable disk
#
# Usage: ./build_kernel.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KERNEL_SRC_DIR="$SCRIPT_DIR/src/kernel"
KERNEL_DATA="$SCRIPT_DIR/build/kernel.data"

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}"
}

# Check that assembler exists
if [[ ! -x "$SCRIPT_DIR/kagu_asm" ]]; then
    error "kagu_asm not found. Build it first with: cmake --build build/"
fi

# Check kernel source directory
if [[ ! -d "$KERNEL_SRC_DIR" ]]; then
    error "Kernel source directory not found: $KERNEL_SRC_DIR"
fi

# Collect kernel .kga files in sorted order
KERNEL_FILES=$(find "$KERNEL_SRC_DIR" -name '*.kga' | sort)

if [[ -z "$KERNEL_FILES" ]]; then
    error "No .kga files found in $KERNEL_SRC_DIR"
fi

# Step 1: Compile with kagu_asm (supports multiple source files)
info "Step 1: Compiling kernel..."
echo "  Files:"
for f in $KERNEL_FILES; do
    echo "    - $(basename "$f")"
done

"$SCRIPT_DIR/kagu_asm" $KERNEL_FILES

# Step 2: Build bootable disk
info "Step 2: Building bootable disk..."
"$SCRIPT_DIR/build_bootable_disk.sh" "$KERNEL_DATA"

info "Done! Run with: ./kagu_boot hw/cpu_firmware.bin <ram_size>"
