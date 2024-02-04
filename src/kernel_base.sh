# KaguOS kernel main code

##########################################
# INITRAMFS_START                        #
##########################################
# Write help info to RAM to simplify debugging.
# TODO 
#      1. Open tmp/RAM.txt in text editor to see the content of RAM.
#      2. Use -s=0.5 option or other while running bootloader script
#         to see the content of RAM with a delay between instructions execution.
#      3. Use -j option to print executed commands to console.
# TODO END
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

# Display prompt to enter the value:
write_to_address ${GLOBAL_DISPLAY_ADDRESS} " :) "
display_print

# read cmd from keyboard and split into command and arguments:
read_input
write_to_address ${GLOBAL_ARG1_ADDRESS} "1"
cpu_execute "${CPU_GET_COLUMN_CMD}" ${GLOBAL_INPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}


# Display a message with first component of input:
write_to_address ${GLOBAL_DISPLAY_ADDRESS} "Parsed command:"
display_println

copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_DISPLAY_ADDRESS}
display_println

# TODO 
#      1. Uncomment the following code.
#      2. Try to adjust jump_if argument to read input in a loop until exit command will be entered.
#      3. Monitor RAM(use -s= option for delay between commands) to see how it changed in different scenarios.
#      4. Use -j option to see executed commands in console.
# TODO END
# write_to_address ${GLOBAL_ARG1_ADDRESS} "exit"
# cpu_execute "${CPU_NOT_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
# jump_if 0

jump_to ${GLOBAL_TERMINATE_ADDRESS}


# TODO
#      1. Write some code to print strings or perform other actions.
#      2. Last instruction of the block should be jump_to some address inside kernel logic. Hint:
#             <some instruction1>
#             <some instruction2>
#             <some instruction3>
#             jump_to <addr>
#      3. Integrate this code block into the kernel logic from above by jump_if call for some case of user's input.
#         !!! Be careful as addresses will shift when you will add any instruction above this code - check tmp/RAM.txt.
#      4. You can write few such blocks and for example help command handling to list supported commands
# TODO END


##########################################
# KERNEL_END                             #
##########################################
