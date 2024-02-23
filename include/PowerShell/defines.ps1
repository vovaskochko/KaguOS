# This file contains a list of constants for KaguOS.
# It includes memory addresses that are used by the kernel.

# NOTE: We are using *_INFO_ADDRESS variables to store debug information in RAM
# so you can open tmp/RAM.txt and quickly understand what is the data stored at some line.
# For example, we have GLOBAL_INPUT_ADDRESS and it is used to store real data from keyboard after corresponding call.
# We will print helper message "Keyboard buffer:" to the previous memory address GLOBAL_INPUT_INFO_ADDRESS.
# As a result, you can see the data stored at GLOBAL_INPUT_ADDRESS and its description in tmp/RAM.txt, for example:
#   line3: Keyboard buffer:
#   line4: <some text you have entered recently>

#################################################################
# We will store hw emulation files under tmp dir
$GLOBAL_HW_DIR="tmp"

# RAM constants:
$GLOBAL_RAM_FILE="${GLOBAL_HW_DIR}/RAM.txt"
$GLOBAL_RAM_SIZE="128"
$GLOBAL_TERMINATE_ADDRESS="${GLOBAL_RAM_SIZE}"

# Kernel constants:
$GLOBAL_BUILD_DIR="build"
$GLOBAL_KERNEL_DISK="${GLOBAL_BUILD_DIR}/kernel.disk"
$GLOBAL_ENV_FILE="${GLOBAL_BUILD_DIR}/env.ps1"
$GLOBAL_KERNEL_START_INFO_ADDRESS="19"
$GLOBAL_KERNEL_START="20"

# Display memory.
# You should write data to GLOBAL_DISPLAY_ADDRESS
# and call one of display_* functions to trigger printing of the data in console
$GLOBAL_DISPLAY_INFO="Display buffer:"
$GLOBAL_DISPLAY_INFO_ADDRESS="1"
$GLOBAL_DISPLAY_ADDRESS="2"

# Memory to store data read from keyboard.
# You should call read_input function wait for input
# and then you can use GLOBAL_INPUT_ADDRESS for further processing.
$GLOBAL_INPUT_INFO="Keyboard buffer:"
$GLOBAL_INPUT_INFO_ADDRESS="3"
$GLOBAL_INPUT_ADDRESS="4"

# Memory to store arguments of the commands.
# You can use those two addreses as a temporary storage for some calls.
$GLOBAL_ARGS_INFO="Arguments 1-2:"
$GLOBAL_ARGS_INFO_ADDRESS="5"
$GLOBAL_ARG1_ADDRESS="6"
$GLOBAL_ARG2_ADDRESS="7"

# Memory to store output of the previous command if needed
$GLOBAL_OUTPUT_INFO="Output buffer:"
$GLOBAL_OUTPUT_INFO_ADDRESS="8"
$GLOBAL_OUTPUT_ADDRESS="9"

# Memory to store result of comparison done with cpu_execute
# For example, if you want to compare previous ouput with some string "test", you can use cpu_execute
#     write_to_address ${GLOBAL_ARG1_ADDRESS} "test"
#     cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_ARG1_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
# as a result GLOBAL_COMPARE_RES_ADDRESS will contain 1 or 0 based on comparison result.
# You can use this result later by backing it up to some othe memory address
# or you can perform conditional jump instruction aka jump_if
$GLOBAL_COMPARE_RESULT_INFO="Compare result:"
$GLOBAL_COMPARE_RESULT_INFO_ADDRESS="10"
$GLOBAL_COMPARE_RES_ADDRESS="11"

# Memory to store address to define the next command to be executed.
$GLOBAL_NEXT_CMD_INFO="Next command pre-address:"
$GLOBAL_NEXT_CMD_INFO_ADDRESS="12"
$GLOBAL_NEXT_CMD_ADDRESS="13"

$GLOBAL_MAIN_FRAME_START_ADDRESS="1"
$GLOBAL_CURRENT_FRAME_COUNT_INFO="Current frame count:"
$GLOBAL_CURRENT_FRAME_COUNT_INFO_ADDRESS="$([int]$GLOBAL_RAM_SIZE - 1)"
$GLOBAL_CURRENT_FRAME_COUNT_ADDRESS="${GLOBAL_RAM_SIZE}"
$GLOBAL_FRAME_SIZE="${GLOBAL_NEXT_CMD_ADDRESS}"
