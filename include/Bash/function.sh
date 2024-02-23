# This file contains helper functions to support function calls inside kernel

# Our implementation of function call supports up to 2 input arguments which are copied by value. Usage:
#      call_func <function name> <optional: argument1 address> <optional: argument2 address>
#
# We should perform the following steps to call a function:
# 1. Copy content from input args addresses to avoid case when they will be erased by push_frame operation
#
# 2. Push current main frame to stack.
#
# 3. Copy actual arguments to the main frame.
#
# 4. Jump to the function.
#
function call_func {
    # Copy values to temporary storage from the addresses provided as funciton arguments:
    if [ ! -z "${2}" ]; then local ARG1="$(read_from_address ${2})"; else local ARG1=""; fi
    if [ ! -z "${3}" ]; then local ARG2="$(read_from_address ${3})"; else local ARG2=""; fi

    # Push current main frame to stack. This will clear the main frame memory:
    push_frame

    # Copy function arguments to main frame:
    write_to_address ${GLOBAL_ARG1_ADDRESS} "${ARG1}"
    write_to_address ${GLOBAL_ARG2_ADDRESS} "${ARG2}"

    # Jump to the function:
    eval "jump_to \${FUNC_${1}}"
}

# Calls function only when GLOBAL_COMPARE_RES_ADDRESS memory contains "1"
#       call_func_if <function name> <optional: argument1 address> <optional: argument2 address>
function call_func_if {
    if [ "$(read_from_address ${GLOBAL_COMPARE_RES_ADDRESS})" = "1" ]; then
        call_func "${1}" "${2}" "${3}"
    fi
}


# On function return we should restore frame that was before the function call
# with the only modification - output should be overwritten with the function result
function func_return {
    # Backup function result to temporary storage
    local CURRENT_OUTPUT="$(read_from_address ${GLOBAL_OUTPUT_ADDRESS})"

    # Restore frame from the stack
    pop_frame

    # Write function result to the output address
    write_to_address ${GLOBAL_OUTPUT_ADDRESS} "${CURRENT_OUTPUT}"
}


export -f call_func
export -f call_func_if
export -f func_return
