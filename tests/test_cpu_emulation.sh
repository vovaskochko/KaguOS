#!/usr/bin/env bash

BASE_DIR="$(dirname "$0")"
if [ ! -f "${BASE_DIR}"/../asm.sh ]; then
    echo "asm.sh does not exist."
    exit 1
fi

for FILE in $(ls "${BASE_DIR}"/cpu/*.kga); do
    echo "Testing $FILE"
    (DEBUG_INFO=0 "${BASE_DIR}"/../asm.sh tests/kagu_test.kga $FILE && ./bootloader.sh build/kernel.disk) | grep "Total tests\|Successful tests\|Failed tests"
done
