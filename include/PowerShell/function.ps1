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
    param(
        [Parameter(Mandatory=$true)][string]$func_name,
        [Parameter(Mandatory=$false)][string]$arg1,
        [Parameter(Mandatory=$false)][string]$arg2
    )
    # Copy values to temporary storage from the addresses provided as funciton arguments:
    if ($arg1) {
        $ARG1=$(read_from_address $arg1)
    }
    else {
        $ARG1=""
    }

    if ($arg2) {
        $ARG2=$(read_from_address $arg2)
    }
    else {
        $ARG2=""
    }

    # Push current main frame to stack. This will clear the main frame memory:
    push_frame

    # Copy function arguments to main frame:
    write_to_address ${GLOBAL_ARG1_ADDRESS} "${ARG1}"
    write_to_address ${GLOBAL_ARG2_ADDRESS} "${ARG2}"

    # Jump to the function:
    $ExecutionContext.InvokeCommand.ExpandString("jump_to `${FUNC_${func_name}}")  | Invoke-Expression
}

# Calls function only when GLOBAL_COMPARE_RES_ADDRESS memory contains "1"
#       call_func_if <function name> <optional: argument1 address> <optional: argument2 address>
function call_func_if() {
    param(
        [Parameter(Mandatory=$true)][string]$func_name,
        [Parameter(Mandatory=$false)][string]$arg1,
        [Parameter(Mandatory=$false)][string]$arg2
    )
    if ("$(read_from_address ${GLOBAL_COMPARE_RES_ADDRESS})" -eq "1" ) {
        call_func "$func_name" "$arg1" "$arg2"
    }
}


# On function return we should restore frame that was before the function call
# with the only modification - output should be overwritten with the function result
function func_return {
    # Backup function result to temporary storage
    $CURRENT_OUTPUT="$(read_from_address ${GLOBAL_OUTPUT_ADDRESS})"

    # Restore frame from the stack
    pop_frame

    # Write function result to the output address
    write_to_address ${GLOBAL_OUTPUT_ADDRESS} "${CURRENT_OUTPUT}"
}
