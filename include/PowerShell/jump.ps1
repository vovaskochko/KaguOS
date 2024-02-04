
# increment jump counter
function jump_increment_counter {
    $NEW_COUNTER=[int]$(read_from_address "${GLOBAL_NEXT_CMD_ADDRESS}") + 1
    write_to_address "${GLOBAL_NEXT_CMD_ADDRESS}" "$NEW_COUNTER"
}


# jump to the provided address.
# INPUT: address to jump to
function jump_to([string]$arg1) {
    $PREADDRESS=[int]$arg1 - 1
    write_to_address "${GLOBAL_NEXT_CMD_ADDRESS}" "${PREADDRESS}"
}


# jump_if is a conditional jump to provided address e.g. it will jump only if GLOBAL_COMPARE_RES_ADDRESS contains "1"
# INPUT: address to jump to
function jump_if([string]$arg1) {
    if ("$(read_from_address ${GLOBAL_COMPARE_RES_ADDRESS})" -eq "1" ) {
        jump_to $arg1
    }
}

# Debug output for current instruction
function jump_print_debug_info {
    $NEXT_CMD_ADDRESS=$(read_from_address ${GLOBAL_NEXT_CMD_ADDRESS})
    $NEXT_CMD=$(read_from_address ${NEXT_CMD_ADDRESS})
    write-host -NoNewline "[DEBUG] Command ${NEXT_CMD_ADDRESS}: "
    write-host "${NEXT_CMD}" -ForegroundColor Blue
}

