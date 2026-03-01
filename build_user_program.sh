#!/bin/bash

# KaguOS User Program Builder
# Compiles a user-space .kga source file with kagu_asm -u
# Output goes to build/user.disk
#
# Usage: ./build_user_program.sh <source.kga>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

cd "$(dirname "$0")"

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}"
}

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <source.kga>"
    echo "  Compiles a user-space program for KaguOS."
    echo "  Output: build/user.disk"
    exit 1
fi

SRC="$1"

if [[ ! -f "$SRC" ]]; then
    error "Source file not found: $SRC"
fi

if [[ ! -x ./kagu_asm ]]; then
    error "kagu_asm not found. Build it first with: cmake --build build/"
fi

info "Compiling user program: $SRC"
./kagu_asm -u "$SRC"

info "Done! User program compiled to: build/user.disk"
info "Copy it to a disk with: ./copy_file_to_disk.sh build/user.disk main.disk <start> <end>"
