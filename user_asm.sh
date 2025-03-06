#!/bin/bash
BASE_DIR=$(dirname "$0")
USER_SPACE="on" "$BASE_DIR/asm.sh" $@

RESULT_FILE="${BASE_DIR}/build/user.disk"
echo "Compiled program $RESULT_FILE contains $(cat "$RESULT_FILE" | wc -l | tr -d ' ') lines"
