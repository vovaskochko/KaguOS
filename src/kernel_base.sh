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

if *VAR_original_input_cmd_ADDRESS=="ls"
    call_func system_ls ${VAR_original_input_arg1_ADDRESS} ${VAR_original_input_arg2_ADDRESS}
    jump_to ${LABEL_kernel_loop_start}
fi

# check for pwd command:
if *VAR_original_input_cmd_ADDRESS=="pwd"
    call_func system_pwd
    jump_to ${LABEL_kernel_loop_start}
fi

if *VAR_original_input_cmd_ADDRESS=="load"
    call_func system_load ${VAR_original_input_ADDRESS}
    jump_to ${LABEL_kernel_loop_start}
fi

if *VAR_original_input_cmd_ADDRESS=="sched"
    call_func system_sched ${VAR_original_input_ADDRESS}
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

FUNC:system_get_absolute_path
    var system_get_absolute_path_temp_var

    *VAR_system_get_absolute_path_temp_var_ADDRESS="/"
    cpu_execute "${CPU_STARTS_WITH_CMD}" ${GLOBAL_ARG1_ADDRESS} ${VAR_system_get_absolute_path_temp_var_ADDRESS}
    jump_if ${LABEL_system_get_absolute}

    cpu_execute "${CPU_CONCAT_CMD}" ${GLOBAL_WORKING_DIR_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
    *GLOBAL_ARG1_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
  LABEL:system_get_absolute
    return *GLOBAL_ARG1_ADDRESS

FUNC:system_cat
    var system_cat_temp_var
    var system_cat_file_descriptor
    var system_cat_read_result

    call_func system_get_absolute_path ${GLOBAL_ARG1_ADDRESS}
    *GLOBAL_ARG1_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

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

    call_func system_get_absolute_path ${GLOBAL_ARG1_ADDRESS}
    *GLOBAL_ARG1_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

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

FUNC:system_ls
    var system_ls_file_descriptor
    var system_ls_temp_var
    var system_ls_file_info
    var system_ls_disk
    var system_ls_file_header_line
    var system_ls_file_header
    var system_ls_res

    if *GLOBAL_ARG1_ADDRESS!="-la"
        *GLOBAL_DISPLAY_ADDRESS="Unknown args. Usage: ls -la <filename>"
        display_error
        return "1"
    fi

    if *GLOBAL_ARG2_ADDRESS==""
        *GLOBAL_DISPLAY_ADDRESS="Unknown args. Usage: ls -la <filename>"
        display_error
        return "1"
    fi

    call_func system_get_absolute_path ${GLOBAL_ARG2_ADDRESS}
    *GLOBAL_ARG2_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    call_func file_open ${GLOBAL_ARG2_ADDRESS}
    if *GLOBAL_OUTPUT_ADDRESS=="-1"
        *GLOBAL_DISPLAY_ADDRESS="No such file"
        return "1"
    else
        *VAR_system_ls_file_descriptor_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    fi

    call_func file_info ${VAR_system_ls_file_descriptor_ADDRESS}
    *VAR_system_ls_file_info_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    call_func file_close ${VAR_system_ls_file_descriptor_ADDRESS}

    *VAR_system_ls_temp_var_ADDRESS="2"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_info_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    *VAR_system_ls_disk_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_system_ls_temp_var_ADDRESS="6"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_info_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    *VAR_system_ls_file_header_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    read_device_buffer ${VAR_system_ls_disk_ADDRESS} ${VAR_system_ls_file_header_line_ADDRESS}
    *VAR_system_ls_file_header_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_system_ls_temp_var_ADDRESS="2"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_header_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    if *GLOBAL_OUTPUT_ADDRESS=="file"
        *VAR_system_ls_res_ADDRESS="-"
    fi
    if *GLOBAL_OUTPUT_ADDRESS=="dir"
        *VAR_system_ls_res_ADDRESS="d"
    fi

    *VAR_system_ls_temp_var_ADDRESS="3"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_header_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    call_func system_permission_int_to_string ${GLOBAL_OUTPUT_ADDRESS}
    cpu_execute "${CPU_CONCAT_CMD}" ${VAR_system_ls_res_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_system_ls_res_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_system_ls_temp_var_ADDRESS="4"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_header_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    call_func system_permission_int_to_string ${GLOBAL_OUTPUT_ADDRESS}
    cpu_execute "${CPU_CONCAT_CMD}" ${VAR_system_ls_res_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_system_ls_res_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_system_ls_temp_var_ADDRESS="5"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_header_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    call_func system_permission_int_to_string ${GLOBAL_OUTPUT_ADDRESS}
    cpu_execute "${CPU_CONCAT_CMD}" ${VAR_system_ls_res_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_system_ls_res_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_system_ls_temp_var_ADDRESS="6"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_header_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${VAR_system_ls_res_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_system_ls_res_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_system_ls_temp_var_ADDRESS="7"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_header_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${VAR_system_ls_res_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_system_ls_res_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_system_ls_temp_var_ADDRESS="1"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_ls_file_header_ADDRESS} ${VAR_system_ls_temp_var_ADDRESS}
    cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${VAR_system_ls_res_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_system_ls_res_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    println(*VAR_system_ls_res_ADDRESS)
    return "0"

FUNC:get_free_RAM_start
    return "$(read_from_address ${GLOBAL_KERNEL_END_INFO_ADDRESS})"

FUNC:system_load
    var system_load_file_name
    var system_load_file_descriptor
    var system_load_counter
    var system_load_cur_mem_to_write
    var system_load_cur_line
    var system_load_current_proc_offset
    var system_load_temp_var

    var system_load_pid_info_line
    var system_load_pid
    var system_load_priority

    # Let's remember the first line for process info
    *VAR_system_load_pid_info_line_ADDRESS="${GLOBAL_SCHED_PID_INFO_START_ADDRESS}"

    # We should assign unique process id to every loaded program
    *VAR_system_load_pid_ADDRESS="1"


    # Let's assign priority to every loaded program(the less value the bigger priority)
    *VAR_system_load_priority_ADDRESS="100"

    # Let's get free memory range to load the programs into it:
    call_func get_free_RAM_start
    *VAR_system_load_cur_mem_to_write_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

# LOAD PROGRAMS:
    # GLOBAL_ARG1_ADDRESS contains the whole command input e.g.
    # load file1 file2 file3 file4
    *VAR_system_load_counter_ADDRESS="1"
    LABEL:system_load_loop
        *VAR_system_load_counter_ADDRESS++

        # Let's get file name from argument:
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${GLOBAL_ARG1_ADDRESS} ${VAR_system_load_counter_ADDRESS}
        *VAR_system_load_file_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        if *VAR_system_load_file_name_ADDRESS==""
            jump_to ${LABEL_system_load_loop_end}
        fi

        # Print info about file that will be loaded:
        *GLOBAL_DISPLAY_ADDRESS="Loading file "
        display_print
        *GLOBAL_DISPLAY_ADDRESS=*VAR_system_load_file_name_ADDRESS
        display_println

    # FREE PROCESS INFO LINE:
        # Let's check whether we have space to store process info for current program:
        if *VAR_system_load_pid_info_line_ADDRESS<="${GLOBAL_SCHED_PID_INFO_END_ADDRESS}"
            *GLOBAL_DISPLAY_ADDRESS="Process info table is full. Skip other inputs."
            display_warning
            jump_to ${LABEL_system_load_loop_end}
        fi
    # END: FREE PROCESS INFO LINE


    LABEL:system_load_load_program
        # Now we can open the file
        call_func system_get_absolute_path ${VAR_system_load_file_name_ADDRESS}
        *VAR_system_load_file_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        call_func file_open ${VAR_system_load_file_name_ADDRESS}
        *VAR_system_load_file_descriptor_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        if *VAR_system_load_file_descriptor_ADDRESS=="-1"
            *GLOBAL_DISPLAY_ADDRESS="No such file"
            display_error
            jump_to ${LABEL_system_load_loop}
        fi


        # TODO process priority should be prompted here instead of hardcode in case of more sophisticated scheduling algorithms:
        # read_input
        #*VAR_system_load_priority_ADDRESS=${GLOBAL_INPUT_ADDRESS}
        # TODO_END

        # Let's memorize the first address of text segment
        *VAR_system_load_current_proc_offset_ADDRESS=*VAR_system_load_cur_mem_to_write_ADDRESS

    # LOAD PROGRAM:
        # Now we can read the file line by line and copy it to .text segment of the process in RAM:
        LABEL:system_load_read_loop
            call_func file_read ${VAR_system_load_file_descriptor_ADDRESS}
            *VAR_system_load_cur_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
            if *VAR_system_load_cur_line_ADDRESS=="-1"
                jump_to ${LABEL_system_load_read_loop_end}
            fi

            # Copy instruction to the .text segment
            copy_from_to_address ${VAR_system_load_cur_line_ADDRESS} $(read_from_address ${VAR_system_load_cur_mem_to_write_ADDRESS})
            *VAR_system_load_cur_mem_to_write_ADDRESS++

            jump_to ${LABEL_system_load_read_loop}
        LABEL:system_load_read_loop_end
    # END: LOAD PROGRAM

        # Let's close the file:
        call_func file_close ${VAR_system_load_file_descriptor_ADDRESS}

    # PROCESS INFO:
        # PID <pid> :
        *VAR_system_load_temp_var_ADDRESS="PID"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${VAR_system_load_temp_var_ADDRESS} ${VAR_system_load_pid_ADDRESS}

        # PRIORITY <priority> :
        *VAR_system_load_temp_var_ADDRESS="PRIORITY"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_system_load_temp_var_ADDRESS}
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_system_load_priority_ADDRESS}

        # MEM_OFFSET <mem_offset> :
        *VAR_system_load_temp_var_ADDRESS="MEM_OFFSET"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_system_load_temp_var_ADDRESS}
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_system_load_current_proc_offset_ADDRESS}

        # STATUS <status> :
        *VAR_system_load_temp_var_ADDRESS="STATUS ready"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_system_load_temp_var_ADDRESS}

        # FILE <file> :
        *VAR_system_load_temp_var_ADDRESS="FILE"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_system_load_temp_var_ADDRESS}
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_system_load_file_name_ADDRESS}

        copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} $(read_from_address ${VAR_system_load_pid_info_line_ADDRESS})

        # Now let's increase counter and hepler variables to be used for the next process
        *VAR_system_load_pid_info_line_ADDRESS++
        *VAR_system_load_pid_ADDRESS++
        *VAR_system_load_temp_var_ADDRESS="${LOCAL_TOTAL_SIZE}"
        cpu_execute "${CPU_ADD_CMD}" ${VAR_system_load_current_proc_offset_ADDRESS} ${VAR_system_load_temp_var_ADDRESS}
        *VAR_system_load_cur_mem_to_write_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    # END: PROCESS INFO

        jump_to ${LABEL_system_load_loop}
    LABEL:system_load_loop_end
# END: LOAD PROGRAMS


    # Print total loaded programs
    *GLOBAL_DISPLAY_ADDRESS="There are "
    display_print
    *VAR_system_load_pid_ADDRESS--
    *GLOBAL_DISPLAY_ADDRESS=*VAR_system_load_pid_ADDRESS
    display_print
    *GLOBAL_DISPLAY_ADDRESS=" program(s) loaded to RAM:"
    display_println

# PRINT PROC INFO TABLE:
    var system_load_process_counter
    var system_load_process_tmp_column
    *VAR_system_load_process_tmp_column_ADDRESS="1"

    *VAR_system_load_process_counter_ADDRESS="${GLOBAL_SCHED_PID_INFO_START_ADDRESS}"
    LABEL:system_load_process_loop
        copy_from_to_address "$(read_from_address ${VAR_system_load_process_counter_ADDRESS})" ${VAR_system_load_temp_var_ADDRESS}
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_load_temp_var_ADDRESS} ${VAR_system_load_process_tmp_column_ADDRESS}
        if *GLOBAL_OUTPUT_ADDRESS!="PID"
            return "0"
        fi

        *GLOBAL_DISPLAY_ADDRESS=*VAR_system_load_temp_var_ADDRESS
        display_println
        if *VAR_system_load_process_counter_ADDRESS=="${GLOBAL_SCHED_PID_INFO_END_ADDRESS}"
            *GLOBAL_DISPLAY_ADDRESS=*VAR_system_load_process_counter_ADDRESS
            display_println
            return "0"
        fi

    *VAR_system_load_process_counter_ADDRESS++
    jump_to ${LABEL_system_load_process_loop}
    LABEL:system_load_process_loop_end

# END PRINT PROC INFO TABLE

    return "0"


# Let's go through the loaded programs and execute them
FUNC:system_sched
    var system_sched_process_pid_info_column
    *VAR_system_sched_process_pid_info_column_ADDRESS="1"

    var system_sched_process_pid_column
    *VAR_system_sched_process_pid_column_ADDRESS="2"

    var system_sched_process_status_column
    *VAR_system_sched_process_status_column_ADDRESS="8"

    var system_sched_cur_proc_info
    var system_sched_cur_pid
    var system_sched_cur_status
    var system_sched_process_counter

    var system_sched_active_process_count

# SCHEDULER:

    # TODO scheduler logic should be placed here
    LABEL:system_sched_main_loop

        *VAR_system_sched_active_process_count_ADDRESS="0"
        *VAR_system_sched_process_counter_ADDRESS="${GLOBAL_SCHED_PID_INFO_START_ADDRESS}"
        LABEL:system_sched_process_loop

            copy_from_to_address "$(read_from_address ${VAR_system_sched_process_counter_ADDRESS})" ${VAR_system_sched_cur_proc_info_ADDRESS}

            cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_sched_cur_proc_info_ADDRESS} ${VAR_system_sched_process_pid_info_column_ADDRESS}
            if *GLOBAL_OUTPUT_ADDRESS!="PID"
                # Skip empty or invalid process info lines
                jump_to ${LABEL_system_sched_process_loop_continue}
            fi

            cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_sched_cur_proc_info_ADDRESS} ${VAR_system_sched_process_status_column_ADDRESS}
            *VAR_system_sched_cur_status_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

            # Skip terminated processes and reset corresponding process info memory
            if *VAR_system_sched_cur_status_ADDRESS=="terminated"
                jump_to ${LABEL_system_sched_process_loop_continue}
            fi
            # Skip processes that are not ready:
            if *VAR_system_sched_cur_status_ADDRESS!="ready"
                jump_to ${LABEL_system_sched_process_loop_continue}
            fi

            *VAR_system_sched_active_process_count_ADDRESS++
            *GLOBAL_CURRENT_PID_INFO_ADDRESS=*VAR_system_sched_process_counter_ADDRESS
            *GLOBAL_SCHED_COUNTER_ADDRESS="5"
            cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_system_sched_cur_proc_info_ADDRESS} ${VAR_system_sched_process_pid_column_ADDRESS}
            *GLOBAL_SCHED_PID_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        LABEL:system_sched_process_loop_continue
            if *VAR_system_sched_process_counter_ADDRESS=="${GLOBAL_SCHED_PID_INFO_END_ADDRESS}"
                jump_to ${LABEL_system_sched_process_loop_end}
            fi

        *VAR_system_sched_process_counter_ADDRESS++
        jump_to ${LABEL_system_sched_process_loop}
        LABEL:system_sched_process_loop_end

        if *VAR_system_sched_active_process_count_ADDRESS=="0"
            *GLOBAL_DISPLAY_ADDRESS="No active processes: stopping scheduler."
            display_success
            jump_to ${LABEL_system_sched_main_loop_end}
        fi
        jump_to ${LABEL_system_sched_main_loop}
    LABEL:system_sched_main_loop_end
    # TODO_END

# END: SCHEDULER

# DEBUG restart all the processes.
# To avoid programs reloading every time you can reset already loaded programs and assign custom priority
# Fill free to extend it for your purpose:
        # *VAR_system_sched_process_counter_ADDRESS="${GLOBAL_SCHED_PID_INFO_START_ADDRESS}"
        # LABEL:system_sched_process_loop_debug
        #     # restart_process_from_pid ${VAR_system_sched_process_counter_ADDRESS}
        #     # or with new priority:
        #     var system_sched_some_tmp_var
        #     *VAR_system_sched_some_tmp_var_ADDRESS="5"
        #     restart_process_from_pid ${VAR_system_sched_process_counter_ADDRESS} ${VAR_system_sched_some_tmp_var_ADDRESS}
        # LABEL:system_sched_process_loop_debug_continue
        #     if *VAR_system_sched_process_counter_ADDRESS=="${GLOBAL_SCHED_PID_INFO_END_ADDRESS}"
        #         jump_to ${LABEL_system_sched_process_loop_debug_end}
        #     fi
            
        #     *VAR_system_sched_process_counter_ADDRESS++
        #     jump_to ${LABEL_system_sched_process_loop_debug}
        # LABEL:system_sched_process_loop_debug_end
# END DEBUG

    return "0"

##########################################
# KERNEL_END                             #
##########################################
