#!/usr/bin/env bash

BASE_DIR="$(dirname "$0")"
if [ ! -f "${BASE_DIR}"/../asm.sh ]; then
    echo "asm.sh does not exist."
    exit 1
fi

for FILE in $(ls "${BASE_DIR}"/compiler/*.kga); do
    echo "Testing $FILE"
    DEBUG_INFO=0 "${BASE_DIR}"/../asm.sh $FILE > /dev/null
    diff build/kernel.disk ${FILE:0:-4}.disk > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "\033[92mTest passed\033[0m"
    else
        echo -e "\033[91mTest failed\033[0m"
    fi
done
