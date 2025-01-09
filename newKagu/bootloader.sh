#!/usr/bin/env bash
# KaguOS bootloader

# Helper function to print fatal error and terminate the program
function exit_fatal {
    echo "FATAL ERROR: $1"
    exit 1
}
export -f exit_fatal


# Parse bootloader arguments to handle debug options if needed:
# Check input arguments for debug flags
export DEBUG_JUMP="0"
export DEBUG_SLEEP="0"
for IN_ARG in "$@"; do
    case "${IN_ARG}" in
        --debug-jump|-j)
            echo "Note: Debug jump enabled"
            export DEBUG_JUMP="1"
            ;;
        --debug-sleep=|-s=*)
            export DEBUG_SLEEP="${IN_ARG#*=}"
            if [[ ! ${DEBUG_SLEEP} =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
                echo "Incorrect format for debug sleep parameter. It will be reset to 0."
                export DEBUG_SLEEP="0"
            fi
            echo "Note: Debug sleep interval set to ${DEBUG_SLEEP}"
            ;;
        --help|-h)
            echo "KaguOS bootloader"
            echo "KaguOS bootloader"
            echo "Usage: bootloader.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug-jump, -j  Debug jump enabled"
            echo "  --debug-sleep=, -s= Debug sleep interval in seconds(e.g. use 0.5 for 500ms), default is 0 - no sleep between command execution"
            echo "  --help, -h        Print this help message"
            exit 0
            ;;
        *)
            exit_fatal "Unknown argument: ${IN_ARG}."
            ;;
    esac
done

#################################
# BOOTLOADER:                   #
#################################


###########################
#######  INIT HW  #########

# Lets include some human readable names for addresses to simplify reading and writing the code
# and also implementation of instruction set
source include/defines.sh
source include/hw.sh

# We use text files to emulate HW and simplify debug
# so lets remove files from previous boot:
rm -rf "${GLOBAL_HW_DIR}"
mkdir -p "${GLOBAL_HW_DIR}"

# Init RAM with zero:
# NOTE: Real computer has a memory with some size which is reset to some default values on power off.
for ((i=1;i<=${GLOBAL_RAM_SIZE};i++)); do
    write_to_address $i "0"
done
####### INIT HW END #######
###########################



###########################
####### LOAD KERNEL #######
# Write debug line to mark kernel start address
write_to_address ${KERNEL_START_INFO} "############ KERNEL START ###########"

# Load data from disk to RAM:
# NOTE: Real computer loads kernel from disk or disk partition
#       so some basic disk driver should be present in bootloader.
CUR_ADDRESS="${KERNEL_START}"
while IFS= read -r LINE; do
    write_to_address ${CUR_ADDRESS} "${LINE}"
    CUR_ADDRESS=$((CUR_ADDRESS + 1))
done < "${GLOBAL_KERNEL_DISK}"

# Write debug line to mark kernel end address
write_to_address ${CUR_ADDRESS} "############ KERNEL END #############"
####### LOAD KERNEL END ###
###########################



###########################
####### JUMP TO KERNEL ####
# Jump to the address in RAM
# where the kernel was loaded:
jump ${KERNEL_START}
# Let's skip the first line of kernel which contains debug info:
jump_next

# Run kernel main loop.
# NOTE: Real CPU has a control unit to handle switch between instructions
#      while our emulation uses eval function of bash to achieve similar behavior.
# NOTE AI: Ask AI assistant about eval command and potential security issues of its usage for scripts.
while [ 1 = 1 ]
do
    # Go to the next command:
    jump_next
    if [ "${DEBUG_JUMP}" = "1" ]; then
        jump_print_debug_info
    fi

    # Check whether next command points to termination
    NEXT_CMD=$(read_from_address ${PROGRAM_COUNTER})

    # TODO check supported instructions
    # TODO change all to be used with copy_from_to
    CUR_INSTRUCTION=$(read_from_address ${NEXT_CMD})
    INSTR_CODE=$(echo "${CUR_INSTRUCTION}" | cut -d ' ' -f 1)
    case ${INSTR_CODE:1} in
        INSTR_CPU_EXEC)
            INSTR_FUNC=cpu_exec
            ;;
        INSTR_COPY_FROM_TO_ADDRESS)
            INSTR_FUNC=copy_from_to_address
            ;;
        INSTR_READ_FROM_ADDRESS)
            INSTR_FUNC=read_from_address
            ;;
        INSTR_JUMP)
            INSTR_FUNC=jump
            ;;
        INSTR_JUMP_IF)
            INSTR_FUNC=jump_if
            ;;
        *)
            exit_fatal "Unknown instruction: ${CUR_INSTRUCTION}"
        ;;
    esac
    eval $INSTR_FUNC ${CUR_INSTRUCTION#* }
    dump_RAM_to_file
    sleep ${DEBUG_SLEEP}
done

###### END JUMP TO KERNEL #
###########################
