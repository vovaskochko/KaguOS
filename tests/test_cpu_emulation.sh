#!/usr/bin/env bash

BASE_DIR="$(dirname "$0")"
ASM=$(realpath "${BASE_DIR}/../asm.sh")
BOOTLOADER=$(realpath "${BASE_DIR}/../bootloader.sh")

if [ ! -f "${ASM}" ]; then
    echo "${ASM} does not exist."
    exit 1
fi
if [ ! -f "${BOOTLOADER}" ]; then
    echo "${BOOTLOADER} does not exist."
    exit 1
fi

for FILE in $(ls "${BASE_DIR}"/cpu/*.kga); do
    echo "Testing $FILE"
    (DEBUG_INFO=0 "${ASM}" tests/kagu_test.kga $FILE && "${BOOTLOADER}" build/kernel.disk) | grep "Total tests\|Successful tests\|Failed tests"
done
