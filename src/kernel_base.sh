# KaguOS kernel main code

##########################################
# INITRAMFS_START                        #
##########################################
# Write help info to RAM to simplify debugging.
*GLOBAL_DISPLAY_INFO_ADDRESS="${GLOBAL_DISPLAY_INFO}"
*GLOBAL_INPUT_INFO_ADDRESS="${GLOBAL_INPUT_INFO}"
*GLOBAL_ARGS_INFO_ADDRESS="${GLOBAL_ARGS_INFO}"
*GLOBAL_OUTPUT_INFO_ADDRESS="${GLOBAL_OUTPUT_INFO}"
*GLOBAL_COMPARE_RESULT_INFO_ADDRESS="${GLOBAL_COMPARE_RESULT_INFO}"
*GLOBAL_NEXT_CMD_INFO_ADDRESS="${GLOBAL_NEXT_CMD_INFO}"
*GLOBAL_CURRENT_FRAME_COUNT_INFO_ADDRESS="${GLOBAL_CURRENT_FRAME_COUNT_INFO}"
*GLOBAL_MOUNT_INFO_DISK_ADDRESS="${GLOBAL_MOUNT_INFO_DISK}"

*GLOBAL_WORKING_DIR_ADDRESS="/"

*GLOBAL_DISPLAY_ADDRESS="RAMFS init - done."
display_success
##########################################
# INITRAMFS_END                          #
##########################################


##########################################
# KERNEL_START                           #
##########################################

# Display welcome message:
*GLOBAL_DISPLAY_ADDRESS="Welcome to KaguOS"
display_success

# NOTE AI: Ask AI assistant about labels and goto instruction in C language.
LABEL:kernel_loop_start


# Display prompt to enter the value:
*GLOBAL_DISPLAY_ADDRESS=*GLOBAL_WORKING_DIR_ADDRESS
display_print
*GLOBAL_DISPLAY_ADDRESS=" :) "
display_print

# read cmd from keyboard and split into command and arguments:
read_input

var original_input
var original_input_cmd

*VAR_original_input_ADDRESS=*GLOBAL_INPUT_ADDRESS
*GLOBAL_ARG1_ADDRESS="1"
cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_original_input_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
*VAR_original_input_cmd_ADDRESS=*GLOBAL_OUTPUT_ADDRESS



# check for exit command:
if *VAR_original_input_cmd_ADDRESS=="exit"
    # Display goodbye message:
    *GLOBAL_DISPLAY_ADDRESS="Goodbye!"
    display_success
    jump_to ${GLOBAL_TERMINATE_ADDRESS}
fi

# go back to the start of the loop:
jump_to ${LABEL_kernel_loop_start}

##########################################
# KERNEL_END                             #
##########################################
