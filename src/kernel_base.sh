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
*GLOBAL_DISPLAY_ADDRESS=" :) "
display_print

# read cmd from keyboard and split into command and arguments:
read_input
*GLOBAL_ARG1_ADDRESS="1"
cpu_execute "${CPU_GET_COLUMN_CMD}" ${GLOBAL_INPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}


# Display a message with first component of input:
println("Parsed command:")
println(*GLOBAL_OUTPUT_ADDRESS)


# check for exit command:
*GLOBAL_ARG1_ADDRESS="exit"
cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
jump_if ${LABEL_kernel_terminate}

# check for hi command:
*GLOBAL_ARG1_ADDRESS="hi"
cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
call_func_if print_hello

# TODO
#     1. Migrate your code from the previous lessons from labels and jumps to function calls call_func_if.
#     2. The main loop should look like this
#   LABEL:kernel_loop_start
#           <code to read input>
#           check cmd name1
#           call_func_if func1 ...
#           check cmd name2
#           call_func_if func2 ...
#           ...
#           jump_to ${LABEL_kernel_loop_start}
#     3. Add command that will use argument for some logic(use lines 37-39 to get second parameter)


# go back to the start of the loop:
jump_to ${LABEL_kernel_loop_start}


# termination code
LABEL:kernel_terminate
# Display goodbye message:
*GLOBAL_DISPLAY_ADDRESS="Goodbye!"
display_success
jump_to ${GLOBAL_TERMINATE_ADDRESS}

FUNC:print_hello
    *GLOBAL_DISPLAY_ADDRESS=generate_hello_string()
    display_success
# TODO
#     1. Uncomment the following recursive call of print_hello function.
#     2. Run OS with sleep between commands -s=0.5 or longer.
#     3. Enter hi command and review the growth of the stack from the end of file tmp/RAM.txt to the start.
#    call_func print_hello
    func_return

FUNC:generate_hello_string
    *GLOBAL_OUTPUT_ADDRESS="Hello!!!"
    func_return
# TODO
#     1. Patch compiler to add some syntax sugar which allows you to write:
#           FUNC:generate_hello_string
#               func_return "Hello!!!"
#     2. Check that generated build/kernel.disk is the same as it was before.

##########################################
# KERNEL_END                             #
##########################################
