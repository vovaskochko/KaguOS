
# increment jump counter
function jump_increment_counter {
    write_to_address ${GLOBAL_NEXT_CMD_ADDRESS} "$(($(read_from_address ${GLOBAL_NEXT_CMD_ADDRESS}) + 1))"
}


# jump to the provided address.
# INPUT: address to jump to
function jump_to {
    local PREADDRESS=$((${1} - 1))
    write_to_address ${GLOBAL_NEXT_CMD_ADDRESS} "${PREADDRESS}"
}


# jump_if is a conditional jump to provided address e.g. it will jump only if GLOBAL_COMPARE_RES_ADDRESS contains "1"
# INPUT: address to jump to
function jump_if {
    if [ "$(read_from_address ${GLOBAL_COMPARE_RES_ADDRESS})" = "1" ]; then
        jump_to ${1}
    fi
}

# Debug output for current instruction
function jump_print_debug_info {
    local NEXT_CMD_ADDRESS=$(read_from_address ${GLOBAL_NEXT_CMD_ADDRESS})
    local NEXT_CMD=$(read_from_address ${NEXT_CMD_ADDRESS})
    echo -e "[DEBUG] Command ${NEXT_CMD_ADDRESS}:\033[34m ${NEXT_CMD}\033[0m"
    if [ "${FULL_KERNEL_COMPILATION}" != "1" ]; then
        echo -e "[DEBUG] Command ${NEXT_CMD_ADDRESS}:\033[35m $(echo "${NEXT_CMD}" | envsubst)\033[0m"
    fi
}

export -f jump_increment_counter
export -f jump_to
export -f jump_if
export -f jump_print_debug_info
