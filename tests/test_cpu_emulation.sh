#!/usr/bin/env bash

BASE_DIR="$(dirname "$0")"
ASM=$(realpath "${BASE_DIR}/../asm.sh")
if [ "$CPP_BOOTLOADER" = 1 ]; then
    BOOTLOADER=$(realpath "${BASE_DIR}/../bootloader")
    FLAGS="500"
else
    BOOTLOADER=$(realpath "${BASE_DIR}/../bootloader.sh")
    FLAGS=""
fi

if [ ! -f "${ASM}" ]; then
    echo "${ASM} does not exist."
    exit 1
fi
if [ ! -f "${BOOTLOADER}" ]; then
    echo "${BOOTLOADER} does not exist."
    exit 1
fi

for FILE in $(ls "${BASE_DIR}"/cpu/test_is_*.kga); do
    echo "Testing $FILE"
    (DEBUG_INFO=0 "${ASM}" tests/kagu_test.kga $FILE && "${BOOTLOADER}" build/kernel.disk $FLAGS) | grep "Total tests\|Successful tests\|Failed tests" | ( (grep -B 2 "Failed tests" && echo -e "\e[41mFAILED\e[0m") || echo -e "\e[42mPASSED\e[0m")
    echo "---------------------------------------------"
done
