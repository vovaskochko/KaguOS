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
var original_input_arg1
var original_input_arg2

*VAR_original_input_ADDRESS=*GLOBAL_INPUT_ADDRESS
*GLOBAL_ARG1_ADDRESS="1"
cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_original_input_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
*VAR_original_input_cmd_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

*GLOBAL_ARG1_ADDRESS="2"
cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_original_input_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
*VAR_original_input_arg1_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

*GLOBAL_ARG1_ADDRESS="3"
cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_original_input_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
*VAR_original_input_arg2_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

# check for exit command:
if *VAR_original_input_cmd_ADDRESS=="exit"
    # Display goodbye message:
    *GLOBAL_DISPLAY_ADDRESS="Goodbye!"
    display_success
    jump_to ${GLOBAL_TERMINATE_ADDRESS}
fi

# check for hi command:
if *VAR_original_input_cmd_ADDRESS=="hi"
    call_func print_hello
    jump_to ${LABEL_kernel_loop_start}
fi

# check for cat command:
if *VAR_original_input_cmd_ADDRESS=="cat"
    call_func system_cat ${VAR_original_input_arg1_ADDRESS}
    jump_to ${LABEL_kernel_loop_start}
fi

# check for touch command:
if *VAR_original_input_cmd_ADDRESS=="touch"
    call_func system_touch ${VAR_original_input_arg1_ADDRESS} ${VAR_original_input_arg2_ADDRESS}
    jump_to ${LABEL_kernel_loop_start}
fi

# check for pwd command:
if *VAR_original_input_cmd_ADDRESS=="pwd"
    call_func system_pwd
    jump_to ${LABEL_kernel_loop_start}
fi


*GLOBAL_DISPLAY_ADDRESS="Unknown command or bad args"
display_warning

# go back to the start of the loop:
jump_to ${LABEL_kernel_loop_start}


FUNC:print_hello
    *GLOBAL_DISPLAY_ADDRESS=generate_hello_string()
    display_success
    return "0"

FUNC:generate_hello_string
    return "Hello!!!"

FUNC:system_pwd
    println(*GLOBAL_WORKING_DIR_ADDRESS)
    return "0"

FUNC:system_cat
    var system_cat_temp_var
    var system_cat_file_descriptor
    var system_cat_read_result

    *VAR_system_cat_temp_var_ADDRESS="/"
    cpu_execute "${CPU_STARTS_WITH_CMD}" ${GLOBAL_ARG1_ADDRESS} ${VAR_system_cat_temp_var_ADDRESS}
    jump_if ${LABEL_system_cat_open_file}
    cpu_execute "${CPU_CONCAT_CMD}" ${GLOBAL_WORKING_DIR_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
    *GLOBAL_ARG1_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

  LABEL:system_cat_open_file
    call_func file_open ${GLOBAL_ARG1_ADDRESS}
    *VAR_system_cat_file_descriptor_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    if *VAR_system_cat_file_descriptor_ADDRESS=="-1"
        jump_to ${LABEL_system_cat_error}
    fi

  LABEL:system_cat_loop
    call_func file_read ${VAR_system_cat_file_descriptor_ADDRESS}
    if *GLOBAL_OUTPUT_ADDRESS=="-1"
        jump_to ${LABEL_system_cat_end}
    fi

    *GLOBAL_DISPLAY_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    display_println
    jump_to ${LABEL_system_cat_loop}

  LABEL:system_cat_end
    call_func file_close ${VAR_system_cat_file_descriptor_ADDRESS}
    return "0"

  LABEL:system_cat_error
    *GLOBAL_DISPLAY_ADDRESS="Error opening file"
    display_error
    return "1"

FUNC:system_touch
    var system_touch_temp_var
    var system_touch_file_descriptor
    var system_touch_counter

    # if one of the arguments is empty, return error:
    if *GLOBAL_ARG1_ADDRESS==""
      jump_to ${LABEL_system_touch_error}
    fi
    if *GLOBAL_ARG2_ADDRESS==""
      jump_to ${LABEL_system_touch_error}
    fi

    *VAR_system_touch_temp_var_ADDRESS="1"
    cpu_execute "${CPU_LESS_THAN_CMD}" ${GLOBAL_ARG2_ADDRESS} ${VAR_system_touch_temp_var_ADDRESS}
    jump_if ${LABEL_system_touch_error}  

    # check if path is not absolute then concat it with working dir:
    *VAR_system_touch_temp_var_ADDRESS="/"
    cpu_execute "${CPU_STARTS_WITH_CMD}" ${GLOBAL_ARG1_ADDRESS} ${VAR_system_touch_temp_var_ADDRESS}
    jump_if ${LABEL_system_touch_create_file}
    cpu_execute "${CPU_CONCAT_CMD}" ${GLOBAL_WORKING_DIR_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
    *GLOBAL_ARG1_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

  LABEL:system_touch_create_file
    # call function to create file and check the result:
    call_func file_create ${GLOBAL_ARG1_ADDRESS} ${GLOBAL_ARG2_ADDRESS}
    if *GLOBAL_OUTPUT_ADDRESS=="-1"
        jump_to ${LABEL_system_touch_error}
    fi

    # at this point file was created and we have a valid descriptor
    # now lets query user to fill all the lines in the new file:
    *VAR_system_touch_file_descriptor_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    *GLOBAL_DISPLAY_ADDRESS="Empty file is created. Enter the content of the new file:"
    display_success

    *VAR_system_touch_counter_ADDRESS="0"
  LABEL:system_touch_loop
    read_input
    call_func file_write ${VAR_system_touch_file_descriptor_ADDRESS} ${GLOBAL_INPUT_ADDRESS}

    *VAR_system_touch_counter_ADDRESS++
    cpu_execute "${CPU_LESS_THAN_CMD}" ${VAR_system_touch_counter_ADDRESS} ${GLOBAL_ARG2_ADDRESS}
    jump_if ${LABEL_system_touch_loop}

    call_func file_close ${VAR_system_touch_file_descriptor_ADDRESS}
    return "0"

  LABEL:system_touch_error
    *GLOBAL_DISPLAY_ADDRESS="Error creating file"
    display_error
    return "1"
##########################################
# KERNEL_END                             #
##########################################
