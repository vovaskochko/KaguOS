# KaguOS kernel main code

##########################################
# INITRAMFS_START                        #
##########################################
# Write help info to RAM to simplify debugging.
write_to_address ${GLOBAL_DISPLAY_INFO_ADDRESS} "${GLOBAL_DISPLAY_INFO}"
write_to_address ${GLOBAL_INPUT_INFO_ADDRESS} "${GLOBAL_INPUT_INFO}"
write_to_address ${GLOBAL_ARGS_INFO_ADDRESS} "${GLOBAL_ARGS_INFO}"
write_to_address ${GLOBAL_OUTPUT_INFO_ADDRESS} "${GLOBAL_OUTPUT_INFO}"
write_to_address ${GLOBAL_COMPARE_RESULT_INFO_ADDRESS} "${GLOBAL_COMPARE_RESULT_INFO}"
write_to_address ${GLOBAL_NEXT_CMD_INFO_ADDRESS} "${GLOBAL_NEXT_CMD_INFO}"

write_to_address ${GLOBAL_DISPLAY_ADDRESS} "RAMFS init - done."
display_success
##########################################
# INITRAMFS_END                          #
##########################################


##########################################
# KERNEL_START                           #
##########################################

# Display welcome message:
write_to_address ${GLOBAL_DISPLAY_ADDRESS} "Welcome to KaguOS"
display_success

# NOTE AI: Ask AI assistant about labels and goto instruction in C language.
LABEL:kernel_loop_start


# Display prompt to enter the value:
write_to_address ${GLOBAL_DISPLAY_ADDRESS} " :) "
display_print

# read cmd from keyboard and split into command and arguments:
read_input
write_to_address ${GLOBAL_ARG1_ADDRESS} "1"
cpu_execute "${CPU_GET_COLUMN_CMD}" ${GLOBAL_INPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}


# Display a message with first component of input:
println("Parsed command:")
println(*GLOBAL_OUTPUT_ADDRESS)


# check for exit command:
write_to_address ${GLOBAL_ARG1_ADDRESS} "exit"
cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
jump_if ${LABEL_kernel_terminate}

# TODO
#     1. Migrate your functions from Lesson 1.1 to labels approach instead of hardcoded values.
#     2. Add support for more commands.
#     3. Add command that will use the second argument for some logic(use lines 37-39 as a reference)


# go back to the start of the loop:
jump_to ${LABEL_kernel_loop_start}


# termination code
LABEL:kernel_terminate
# Display goodbye message:
write_to_address ${GLOBAL_DISPLAY_ADDRESS} "Goodbye!"
display_success
jump_to ${GLOBAL_TERMINATE_ADDRESS}


##########################################
# KERNEL_END                             #
##########################################
