# This file contains defines and helper function for processes.

# Let's define layout of virtual memory for the process:
#          --------- 1
#         |  .text  |
#         |_________|30
#         |         |31
#         |  .data  |
#          --------- 45
#
export LOCAL_TEXT_SEGMENT_SIZE=30
export LOCAL_DATA_SEGMENT_SIZE=20
export LOCAL_TOTAL_SIZE=$(($LOCAL_TEXT_SEGMENT_SIZE + $LOCAL_DATA_SEGMENT_SIZE))
export LOCAL_TEXT_SEGMENT_START_ADDRESS=1
export LOCAL_TEXT_SEGMENT_END_ADDRESS="${LOCAL_TEXT_SEGMENT_SIZE}"

export LOCAL_DATA_SEGMENT_START_ADDRESS=$(($LOCAL_TEXT_SEGMENT_SIZE + 1))

export LOCAL_DISPLAY_INFO_ADDRESS=$LOCAL_DATA_SEGMENT_START_ADDRESS
export LOCAL_DISPLAY_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 1))
export LOCAL_INPUT_INFO_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 2))
export LOCAL_INPUT_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 3))
export LOCAL_OUTPUT_INFO_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 4))
export LOCAL_OUTPUT_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 5))
export LOCAL_COMPARE_RES_INFO_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 6))
export LOCAL_COMPARE_RES_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 7))
export LOCAL_NEXT_CMD_INFO_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 8))
export LOCAL_NEXT_CMD_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 9))
export LOCAL_VARS_INFO_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 10))
export LOCAL_VAR1_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 11))
export LOCAL_VAR2_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 12))
export LOCAL_VAR3_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 13))
export LOCAL_VAR4_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 14))
export LOCAL_VAR5_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 15))
export LOCAL_VAR6_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 16))
export LOCAL_VAR7_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 17))
export LOCAL_VAR8_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 18))
export LOCAL_VAR9_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 19))
export LOCAL_VAR10_ADDRESS=$(($LOCAL_DATA_SEGMENT_START_ADDRESS + 20))
export LOCAL_DATA_SEGMENT_END_ADDRESS="${LOCAL_TOTAL_SIZE}"

# process info looks as follows:
# PID 1 PRIORITY 1 MEM_OFFSET 1000 STATUS <terminated, active, ready>
#
# Returns the process id based on provided process info
function get_process_id() {
    local PID_INFO="$(read_from_address ${1})"
    cut -d " " -f 2 <<< "${PID_INFO}"
}

# Returns the priority based on provided process info
function get_process_priority() {
    local PID_INFO="$(read_from_address ${1})"
    cut -d " " -f 4 <<< "${PID_INFO}"
}

# Returns the memory offset based on provided process info
function get_process_mem_offset() {
    if [ -z "${1}" ]; then
        local PID_INFO_ADDRESS="$(read_from_address ${GLOBAL_CURRENT_PID_INFO_ADDRESS})"
        local PID_INFO="$(read_from_address ${PID_INFO_ADDRESS})"
    else
        local PID_INFO="$(read_from_address ${1})"
    fi
    cut -d " " -f 6 <<< "${PID_INFO}"
}

# Returns process status:
function get_process_status() {
    local PID_INFO="$(read_from_address ${1})"
    cut -d " " -f 8 <<< "${PID_INFO}" 
}

function set_process_status() {
    local PID_INFO_ADDRESS=$(read_from_address ${1})
    local PID_INFO=$(read_from_address ${PID_INFO_ADDRESS})
    local NEW_VALUE=$(echo "${PID_INFO}" | awk -F' ' '{$8="'${2}'"}1')
    write_to_address ${PID_INFO_ADDRESS} "${NEW_VALUE}"
}

function print_process_id() {
    # Some debug info to know what the process is active at the moment
    local PID_INFO_ADDRESS="$(read_from_address ${GLOBAL_CURRENT_PID_INFO_ADDRESS})"
    echo -e -n "\033[92m[$(read_from_address ${PID_INFO_ADDRESS} | cut -d ' ' -f2)]\033[0m"
}

# Returns the memory offset based on provided process info
function virtual_address_to_real() {
    if [ "$1" -lt "$LOCAL_TEXT_SEGMENT_START_ADDRESS" ] || [ "$1" -gt "$LOCAL_DATA_SEGMENT_END_ADDRESS" ]; then
        echo "Segmentation fault: virtual address "
        v_exit
    fi
    local PID_INFO_ADDRESS="$(read_from_address ${GLOBAL_CURRENT_PID_INFO_ADDRESS})"
    OFFSET=$(get_process_mem_offset ${PID_INFO_ADDRESS})
    echo "$(($OFFSET + $1))"
}

function v_read_from_address() {
    read_from_address "$(virtual_address_to_real ${1})"
}
function v_write_to_address() {
    write_to_address "$(virtual_address_to_real ${1})" "${2}"
}

function v_copy_from_to_address() {
    copy_from_to_address "$(virtual_address_to_real ${1})" "$(virtual_address_to_real ${2})"
}

# increment jump counter
function v_jump_increment_counter {
    write_to_address "$(virtual_address_to_real ${LOCAL_NEXT_CMD_ADDRESS})" "$(($(v_read_from_address ${LOCAL_NEXT_CMD_ADDRESS}) + 1))"
}


# jump to the provided address.
# INPUT: address to jump to
function v_jump_to {
    local PREADDRESS=$((${1} - 1))
    v_write_to_address ${LOCAL_NEXT_CMD_ADDRESS} "${PREADDRESS}"
}


# jump_if is a conditional jump to provided address e.g. it will jump only if GLOBAL_COMPARE_RES_ADDRESS contains "1"
# INPUT: address to jump to
function v_jump_if {
    if [ "$(v_read_from_address ${LOCAL_COMPARE_RES_ADDRESS})" = "1" ]; then
        v_jump_to ${1}
    fi
}

function v_read_input() {
    # Backup current input:
    local INPUT_BACKUP=$(read_from_address ${GLOBAL_INPUT_ADDRESS})

    print_process_id
    # Wait for input:
    read_input

    # Get input result and move to local variables, resotre previous input:
    copy_from_to_address ${GLOBAL_INPUT_ADDRESS} $(virtual_address_to_real ${LOCAL_INPUT_ADDRESS})
    write_to_address ${GLOBAL_INPUT_ADDRESS} "${INPUT_BACKUP}"

}

function v_display_println() {
    # Backup current display buffer:
    local DISPLAY_BACKUP=$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})
    copy_from_to_address $(virtual_address_to_real ${LOCAL_DISPLAY_ADDRESS}) ${GLOBAL_DISPLAY_ADDRESS}

    print_process_id
    # Display current display buffer:
    display_println

    # Restore previous display buffer:
    write_to_address ${GLOBAL_DISPLAY_ADDRESS} "${DISPLAY_BACKUP}"
}

function v_cpu_execute() {
    # backup current output & compare res and use copy local versions to corresponding memory:
    local OUTPUT_BACKUP=$(read_from_address ${GLOBAL_OUTPUT_ADDRESS})
    local CMP_RES_BACKUP=$(read_from_address ${GLOBAL_COMPARE_RES_ADDRESS})
    copy_from_to_address $(virtual_address_to_real ${LOCAL_OUTPUT_ADDRESS}) ${GLOBAL_OUTPUT_ADDRESS}
    copy_from_to_address $(virtual_address_to_real ${LOCAL_COMPARE_RES_ADDRESS}) ${GLOBAL_COMPARE_RES_ADDRESS}

    # calculate real addresses and call cpu_execute on them
    if [ ! -z "$4" ]; then
        cpu_execute "${1}" "$(virtual_address_to_real ${2})" "$(virtual_address_to_real ${3})" "$(virtual_address_to_real ${4})"
    elif [ ! -z "$3" ]; then
        cpu_execute "${1}" "$(virtual_address_to_real ${2})" "$(virtual_address_to_real ${3})"
    elif [ ! -z "$2" ]; then
        cpu_execute "${1}" "$(virtual_address_to_real ${2})"
    elif [ ! -z "$1" ]; then
        cpu_execute "${1}"
    else
        echo "Illegal instruction"
        v_exit
    fi

    # copy results from GLOBAL variables to LOCAL and restore previous values:
    copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS}  $(virtual_address_to_real ${LOCAL_OUTPUT_ADDRESS})
    copy_from_to_address ${GLOBAL_COMPARE_RES_ADDRESS} $(virtual_address_to_real ${LOCAL_COMPARE_RES_ADDRESS})
    write_to_address ${GLOBAL_OUTPUT_ADDRESS} "${OUTPUT_BACKUP}"
    write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} "${CMP_RES_BACKUP}"
}

# if we reached the end of the program, we need to signal scheduler about it:
function v_exit() {
    write_to_address ${GLOBAL_SCHED_COUNTER_ADDRESS} "0"
    write_to_address ${GLOBAL_SCHED_PID_ADDRESS} "0"
    set_process_status ${GLOBAL_CURRENT_PID_INFO_ADDRESS} "terminated"
}

# Restart process from provided PID for debug purposes:
# $1 - line with process info
# $2 - new value for priority
function restart_process_from_pid() {
    local PROC_INFO_ADDRESS=$(read_from_address ${1})
    # Let's update status to ready:
    local NEW_VALUE=$(read_from_address ${PROC_INFO_ADDRESS} | awk -F' ' '{$8="ready"}1')
    # If priority provided let's adjust it:
    if [ ! -z "$2" ]; then
        local PRIORITY=$(read_from_address ${2})
        NEW_VALUE=$(echo "${NEW_VALUE}" | awk -F' ' '{$4="'${PRIORITY}'"}1')
    fi

    # Let's reset program counter:
    local OFFSET=$(get_process_mem_offset ${PROC_INFO_ADDRESS})
    write_to_address $(($OFFSET + $LOCAL_NEXT_CMD_ADDRESS)) "0"
    write_to_address ${PROC_INFO_ADDRESS} "${NEW_VALUE}"
}

export -f get_process_id
export -f get_process_priority
export -f get_process_mem_offset
export -f get_process_status
export -f set_process_status
export -f print_process_id
export -f virtual_address_to_real
export -f v_write_to_address
export -f v_copy_from_to_address
export -f v_jump_increment_counter
export -f v_jump_to
export -f v_jump_if
export -f v_read_input
export -f v_display_println
export -f v_cpu_execute
export -f v_exit
export -f restart_process_from_pid
