# File descriptor is a line that points to disk partition and file header location
# Example:
# DISK primary.disk PARTITION part1 HEADER_LINE 7 FILE_LINE 1 FILE_LINE_ON_DISK 12

# Check mount points to match input filename
# INPUT: file path
# OUTPUT: string of form "disk_file partition partition_info_line_on_disk relative_file_path"
#        or -1 if mount point doesn't exist
FUNC:file_found_disk
        var file_found_disk_counter
        var file_found_disk_temp_var
        var file_found_disk_cur_line

        var file_found_disk_name
        var file_found_disk_partition
        var file_found_disk_part_line
        var file_found_disk_filename

        *VAR_file_found_disk_counter_ADDRESS="1"
    LABEL:file_found_disk_mount_loop
        read_device_buffer ${GLOBAL_MOUNT_INFO_DISK_ADDRESS} ${VAR_file_found_disk_counter_ADDRESS}
        *VAR_file_found_disk_cur_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        *VAR_file_found_disk_temp_var_ADDRESS=""
        cpu_execute "${CPU_EQUAL_CMD}" ${VAR_file_found_disk_cur_line_ADDRESS} ${VAR_file_found_disk_temp_var_ADDRESS}
        jump_if ${LABEL_file_found_disk_error}

        *VAR_file_found_disk_temp_var_ADDRESS="2"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_found_disk_cur_line_ADDRESS} ${VAR_file_found_disk_temp_var_ADDRESS}
        *VAR_file_found_disk_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS 

        *VAR_file_found_disk_temp_var_ADDRESS="3"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_found_disk_cur_line_ADDRESS} ${VAR_file_found_disk_temp_var_ADDRESS}
        *VAR_file_found_disk_partition_ADDRESS=*GLOBAL_OUTPUT_ADDRESS      

        *VAR_file_found_disk_temp_var_ADDRESS="1"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_found_disk_cur_line_ADDRESS} ${VAR_file_found_disk_temp_var_ADDRESS}
        cpu_execute "${CPU_STARTS_WITH_CMD}" ${GLOBAL_ARG1_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
        *VAR_file_found_disk_filename_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        jump_if ${LABEL_file_found_disk_found}

        *VAR_file_found_disk_counter_ADDRESS++
        jump_to ${LABEL_file_found_disk_mount_loop}

    LABEL:file_found_disk_error
        *GLOBAL_OUTPUT_ADDRESS="-1"
        func_return

    LABEL:file_found_disk_found
        call_func file_found_disk_partition_line ${VAR_file_found_disk_name_ADDRESS} ${VAR_file_found_disk_partition_ADDRESS}
        *VAR_file_found_disk_temp_var_ADDRESS="-1"
        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_found_disk_temp_var_ADDRESS}
        jump_if ${LABEL_file_found_disk_error}
        *VAR_file_found_disk_part_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        *GLOBAL_OUTPUT_ADDRESS=*VAR_file_found_disk_name_ADDRESS
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_found_disk_partition_ADDRESS}
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_found_disk_part_line_ADDRESS}
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_found_disk_filename_ADDRESS}
        func_return

# Check for partition to exist on disk
# INPUT: disk name, partition name
# OUTPUT: line number of partition header or -1 if not found
FUNC:file_found_disk_partition_line
        var file_found_disk_partition_line_counter
        var file_found_disk_partition_line_temp_var
        var file_found_disk_partition_line_cur_line

        # Check for PARTITION_TABLE header start.
        # If the first line of the disk is not PARTITION_TABLE then partition table is broken and we should report an error
        *VAR_file_found_disk_partition_line_counter_ADDRESS="1"
        read_device_buffer ${GLOBAL_ARG1_ADDRESS} ${VAR_file_found_disk_partition_line_counter_ADDRESS}
        *VAR_file_found_disk_partition_line_temp_var_ADDRESS="PARTITION_TABLE"
        cpu_execute "${CPU_NOT_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_found_disk_partition_line_temp_var_ADDRESS}
        jump_if ${LABEL_found_disk_partition_line_error}

        # Start a loop to find the parition:
        *VAR_file_found_disk_partition_line_counter_ADDRESS++
    LABEL:file_found_disk_partition_line_loop
        read_device_buffer ${GLOBAL_ARG1_ADDRESS} ${VAR_file_found_disk_partition_line_counter_ADDRESS}
        *VAR_file_found_disk_partition_line_cur_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # check whether we reached end of partition table
        *VAR_file_found_disk_partition_line_temp_var_ADDRESS="PARTITION_TABLE_END"
        cpu_execute "${CPU_EQUAL_CMD}" ${VAR_file_found_disk_partition_line_cur_line_ADDRESS} ${VAR_file_found_disk_partition_line_temp_var_ADDRESS}
        jump_if ${LABEL_found_disk_partition_line_error}

        *VAR_file_found_disk_partition_line_temp_var_ADDRESS="1"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_found_disk_partition_line_cur_line_ADDRESS} ${VAR_file_found_disk_partition_line_temp_var_ADDRESS}

        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_ARG2_ADDRESS}
        jump_if ${LABEL_found_disk_partition_line_ok}

        *VAR_file_found_disk_partition_line_counter_ADDRESS++
        jump_to ${LABEL_file_found_disk_partition_line_loop}

    LABEL:found_disk_partition_line_error
        *GLOBAL_OUTPUT_ADDRESS="-1"
        func_return

    LABEL:found_disk_partition_line_ok
        *GLOBAL_OUTPUT_ADDRESS=*VAR_file_found_disk_partition_line_counter_ADDRESS
        func_return

# function returns the address in RAM as file descriptor e.g. writes it to GLOBAL_OUTPUT_ADDRESS
# or -1 if file doesn't exist
# INPUT: file path
FUNC:file_open
        var file_open_counter
        var file_open_temp_var
        var file_open_cur_line
        var file_open_filename
        var file_open_disk_info
        var file_open_disk_name
        var file_open_partition_name
        var file_open_partition_start
        var file_open_partition_end


        # Check for mount point and partition existence for a given filename
        call_func file_found_disk ${GLOBAL_ARG1_ADDRESS}
        *VAR_file_open_disk_info_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} "-1"
        jump_if ${LABEL_file_open_file_not_found}

        # Parse disk info:
        *VAR_file_open_temp_var_ADDRESS="1"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_disk_info_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_disk_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        *VAR_file_open_temp_var_ADDRESS="2"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_disk_info_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_partition_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        *VAR_file_open_temp_var_ADDRESS="4"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_disk_info_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_filename_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        # Read partition info:
        *VAR_file_open_temp_var_ADDRESS="3"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_disk_info_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_counter_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        read_device_buffer ${VAR_file_open_disk_name_ADDRESS} ${VAR_file_open_counter_ADDRESS}
        *VAR_file_open_cur_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # Parse partition info:
        *VAR_file_open_temp_var_ADDRESS="4"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_cur_line_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_partition_start_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        *VAR_file_open_temp_var_ADDRESS="5"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_cur_line_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_partition_end_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # check whether file exists:
        *VAR_file_open_counter_ADDRESS=*VAR_file_open_partition_start_ADDRESS
        read_device_buffer ${VAR_file_open_disk_name_ADDRESS} ${VAR_file_open_counter_ADDRESS}

        *VAR_file_open_temp_var_ADDRESS="DUMMY_FS"
        cpu_execute "${CPU_NOT_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        jump_if ${LABEL_file_open_file_not_found}

        *VAR_file_open_counter_ADDRESS++
    LABEL:file_open_file_loop
        read_device_buffer ${VAR_file_open_disk_name_ADDRESS} ${VAR_file_open_counter_ADDRESS}
        *VAR_file_open_cur_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # check whether we reached end of partition table
        *VAR_file_open_temp_var_ADDRESS="DUMMY_FS_END"
        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        jump_if ${LABEL_file_open_file_not_found}

        *VAR_file_open_temp_var_ADDRESS="1"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_cur_line_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_filename_ADDRESS}
        jump_if ${LABEL_file_open_file_found}

        *VAR_file_open_counter_ADDRESS++
        jump_to ${LABEL_file_open_file_loop}

    LABEL:file_open_file_found
        var file_open_file_desc
        var file_open_file_header
        *VAR_file_open_file_header_ADDRESS=*VAR_file_open_counter_ADDRESS

        *VAR_file_open_temp_var_ADDRESS="DISK"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${VAR_file_open_temp_var_ADDRESS} ${VAR_file_open_disk_name_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS="PARTITION"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS=*VAR_file_open_partition_name_ADDRESS
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS="FILE_HEADER_LINE"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS=*VAR_file_open_file_header_ADDRESS
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS="NEXT_LINE_IN_FILE"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS="0"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS="CHUNKS:"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_file_desc_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # Lets read info about chunks related to file
        var file_open_file_start
        var file_open_file_end
        *VAR_file_open_counter_ADDRESS="8"
    LABEL:file_open_chunks_loop
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_cur_line_ADDRESS} ${VAR_file_open_counter_ADDRESS}
        *VAR_file_open_file_start_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        *VAR_file_open_counter_ADDRESS++

        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_open_cur_line_ADDRESS} ${VAR_file_open_counter_ADDRESS}
        *VAR_file_open_file_end_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        *VAR_file_open_counter_ADDRESS++

        *VAR_file_open_temp_var_ADDRESS=""
        cpu_execute "${CPU_EQUAL_CMD}" ${VAR_file_open_file_start_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        jump_if ${LABEL_file_open_chunks_loop_end}
        cpu_execute "${CPU_EQUAL_CMD}" ${VAR_file_open_file_end_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        jump_if ${LABEL_file_open_chunks_loop_end}

        *VAR_file_open_temp_var_ADDRESS=*VAR_file_open_file_start_ADDRESS
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${VAR_file_open_file_desc_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_temp_var_ADDRESS=*VAR_file_open_file_end_ADDRESS
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_open_temp_var_ADDRESS}
        *VAR_file_open_file_desc_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        jump_to ${LABEL_file_open_chunks_loop}

    LABEL:file_open_chunks_loop_end
        *VAR_file_open_counter_ADDRESS="${GLOBAL_FILE_DESCRIPTORS_START_ADDRESS}"

    LABEL:file_open_find_mem_for_desc_loop
        *VAR_file_open_temp_var_ADDRESS="${GLOBAL_FILE_DESCRIPTORS_END_ADDRESS}"
        cpu_execute "${CPU_LESS_THAN_CMD}" ${VAR_file_open_temp_var_ADDRESS} ${VAR_file_open_counter_ADDRESS}
        jump_if ${LABEL_file_open_file_not_found}

        *VAR_file_open_temp_var_ADDRESS="0"
        cpu_execute "${CPU_EQUAL_CMD}" $(read_from_address ${VAR_file_open_counter_ADDRESS}) ${VAR_file_open_temp_var_ADDRESS}
        jump_if ${LABEL_file_open_find_mem_for_desc_loop_end}

        *VAR_file_open_counter_ADDRESS++
        jump_to ${LABEL_file_open_find_mem_for_desc_loop}

    LABEL:file_open_find_mem_for_desc_loop_end
        copy_from_to_address ${VAR_file_open_file_desc_ADDRESS} "$(read_from_address ${VAR_file_open_counter_ADDRESS})"
        *GLOBAL_OUTPUT_ADDRESS="$(read_from_address ${VAR_file_open_counter_ADDRESS})"
        func_return

    LABEL:file_open_file_not_found
        *GLOBAL_OUTPUT_ADDRESS="-1"
        func_return

# Get file information based on provided file descriptor
# INPUT: file descriptor
# OUTPUT: file information on success
FUNC:file_info
    copy_from_to_address "$(read_from_address ${GLOBAL_ARG1_ADDRESS})" ${GLOBAL_OUTPUT_ADDRESS}
    func_return

# function deletes file descriptor if any
# INPUT: file descriptor address
# OUTPUT: 0 on success, -1 otherwise
FUNC:file_close
    write_to_address $(read_from_address ${GLOBAL_ARG1_ADDRESS}) "0"
    *GLOBAL_OUTPUT_ADDRESS="0"
    func_return

# function reads one line from the file with provided file descriptor
# and then decrypts it
# INPUT: file descriptor, address to write result line
# OUTPUT: next line from the file on success, decrypted, -1 otherwise
FUNC:file_read
    var file_read_disk_name
    var file_read_info
    var file_read_temp_var

    call_func file_info ${GLOBAL_ARG1_ADDRESS}
    *VAR_file_read_info_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_file_read_temp_var_ADDRESS="2"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_read_info_ADDRESS} ${VAR_file_read_temp_var_ADDRESS}
    *VAR_file_read_disk_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    call_func file_cursor_to_line ${GLOBAL_ARG1_ADDRESS}
    *VAR_file_read_temp_var_ADDRESS="-1"
    cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_read_temp_var_ADDRESS}
    jump_if ${LABEL_file_read_not_found}

    read_device_buffer ${VAR_file_read_disk_name_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_file_read_temp_var_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    # Decrypt the line after reading from the disk
    cpu_execute "${CPU_DECRYPT_CMD}" ${VAR_file_read_temp_var_ADDRESS}
    *GLOBAL_OUTPUT_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    func_return
  LABEL:file_read_not_found
    *GLOBAL_OUTPUT_ADDRESS="-1"
    func_return

# function writes one line to the file with provided file descriptor
# after encrypting it
# INPUT: file descriptor, address with line that should be added to file
# OUTPUT: 0 on success, encrypted, -1 otherwise
FUNC:file_write
    var file_write_disk_name
    var file_write_info
    var file_write_temp_var
    var line_number

    call_func file_info ${GLOBAL_ARG1_ADDRESS}
    *VAR_file_write_info_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_file_write_temp_var_ADDRESS="2"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_write_info_ADDRESS} ${VAR_file_write_temp_var_ADDRESS}
    *VAR_file_write_disk_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    call_func file_cursor_to_line ${GLOBAL_ARG1_ADDRESS}
    *VAR_file_write_temp_var_ADDRESS="-1"
    cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_write_temp_var_ADDRESS}
    jump_if ${LABEL_file_write_not_found}

    *VAR_line_number_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    echo "DEBUG: Line number value: ${VAR_line_number_ADDRESS}"

    *VAR_file_write_temp_var_ADDRESS=*GLOBAL_ARG2_ADDRESS
    cpu_execute "${CPU_ENCRYPT_CMD}" ${VAR_file_write_temp_var_ADDRESS}

    write_device_buffer ${VAR_file_write_disk_name_ADDRESS} ${VAR_line_number_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
    *VAR_file_write_temp_var_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *GLOBAL_OUTPUT_ADDRESS=*VAR_file_write_temp_var_ADDRESS
    func_return

  LABEL:file_write_not_found
    *GLOBAL_OUTPUT_ADDRESS="-1"
    func_return

# function sets cursor to file descriptor
FUNC:file_set_cursor
    var file_set_cursor_current
    var file_set_cursor_temp_var

    copy_from_to_address $(read_from_address ${GLOBAL_ARG1_ADDRESS}) ${VAR_file_set_cursor_current_ADDRESS}
    *VAR_file_set_cursor_temp_var_ADDRESS="8"
    cpu_execute "${CPU_REPLACE_COLUMN_CMD}" ${VAR_file_set_cursor_current_ADDRESS} ${VAR_file_set_cursor_temp_var_ADDRESS} ${GLOBAL_ARG2_ADDRESS}
    copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} $(read_from_address ${GLOBAL_ARG1_ADDRESS})
    *GLOBAL_OUTPUT_ADDRESS="0"
    func_return

# function calculates the real line on the disk based on the file descriptor cursor
FUNC:file_cursor_to_line
    var file_cursor_to_line_info
    var file_cursor_to_line_file_line
    var file_cursor_to_line_counter
    var file_cursor_to_line_temp_var

    call_func file_info ${GLOBAL_ARG1_ADDRESS}
    *VAR_file_cursor_to_line_info_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_file_cursor_to_line_temp_var_ADDRESS="8"
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_cursor_to_line_info_ADDRESS} ${VAR_file_cursor_to_line_temp_var_ADDRESS}
    *VAR_file_cursor_to_line_file_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    *VAR_file_cursor_to_line_file_line_ADDRESS++
    # Lets update cursor position
    call_func file_set_cursor ${GLOBAL_ARG1_ADDRESS} ${VAR_file_cursor_to_line_file_line_ADDRESS}

    var file_cursor_to_line_chunk_start
    var file_cursor_to_line_chunk_end
    var file_cursor_to_line_chunk_size
    var file_cursor_to_line_chunk_adjusted_index
    *VAR_file_cursor_to_line_chunk_adjusted_index_ADDRESS=*VAR_file_cursor_to_line_file_line_ADDRESS

    *VAR_file_cursor_to_line_counter_ADDRESS="10"
  LABEL:file_cursor_to_line_chunk_loop
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_cursor_to_line_info_ADDRESS} ${VAR_file_cursor_to_line_counter_ADDRESS}
    *VAR_file_cursor_to_line_chunk_start_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_file_cursor_to_line_counter_ADDRESS++
    cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_cursor_to_line_info_ADDRESS} ${VAR_file_cursor_to_line_counter_ADDRESS}
    *VAR_file_cursor_to_line_chunk_end_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    *VAR_file_cursor_to_line_temp_var_ADDRESS=""
    cpu_execute "${CPU_EQUAL_CMD}" ${VAR_file_cursor_to_line_chunk_start_ADDRESS} ${VAR_file_cursor_to_line_temp_var_ADDRESS}
    jump_if ${LABEL_file_cursor_to_line_not_found}
    cpu_execute "${CPU_EQUAL_CMD}" ${VAR_file_cursor_to_line_chunk_end_ADDRESS} ${VAR_file_cursor_to_line_temp_var_ADDRESS}
    jump_if ${LABEL_file_cursor_to_line_not_found}

    cpu_execute "${CPU_SUBTRACT_CMD}" ${VAR_file_cursor_to_line_chunk_end_ADDRESS} ${VAR_file_cursor_to_line_chunk_start_ADDRESS}
    *VAR_file_cursor_to_line_chunk_size_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
    *VAR_file_cursor_to_line_chunk_size_ADDRESS++

    cpu_execute "${CPU_LESS_THAN_EQUAL_CMD}"  ${VAR_file_cursor_to_line_chunk_adjusted_index_ADDRESS} ${VAR_file_cursor_to_line_chunk_size_ADDRESS}
    jump_if ${LABEL_file_cursor_to_line_chunk_loop_end}

    cpu_execute "${CPU_SUBTRACT_CMD}" ${VAR_file_cursor_to_line_chunk_adjusted_index_ADDRESS} ${VAR_file_cursor_to_line_chunk_size_ADDRESS}
    *VAR_file_cursor_to_line_chunk_adjusted_index_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

    *VAR_file_cursor_to_line_counter_ADDRESS++
    jump_to ${LABEL_file_cursor_to_line_chunk_loop}

  LABEL:file_cursor_to_line_chunk_loop_end

    cpu_execute "${CPU_ADD_CMD}" ${VAR_file_cursor_to_line_chunk_start_ADDRESS} ${VAR_file_cursor_to_line_chunk_adjusted_index_ADDRESS}
    *GLOBAL_OUTPUT_ADDRESS--
    func_return
LABEL:file_cursor_to_line_not_found
    *GLOBAL_OUTPUT_ADDRESS="-1"
    func_return

# Create a new file
# INPUT: file name, line count
# OUTPUT: file descriptor on success, -1 otherwise
FUNC:file_create
        var file_create_counter
        var file_create_temp_var
        var file_create_cur_line
        var file_create_filename
        var file_create_disk_info
        var file_create_disk_name
        var file_create_partition_name
        var file_create_partition_start
        var file_create_partition_end
        var file_create_line_for_header
        var file_create_partition_header

        # Check for mount point and partition existence for a given file path to create
        call_func file_found_disk ${GLOBAL_ARG1_ADDRESS}
        *VAR_file_create_disk_info_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} "-1"
        jump_if ${LABEL_file_create_error}

        # Parse disk info:
        *VAR_file_create_temp_var_ADDRESS="1"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_disk_info_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_disk_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        *VAR_file_create_temp_var_ADDRESS="2"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_disk_info_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_partition_name_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        *VAR_file_create_temp_var_ADDRESS="4"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_disk_info_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_filename_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        # Read partition info:
        *VAR_file_create_temp_var_ADDRESS="3"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_disk_info_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_counter_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        *VAR_file_create_partition_header_ADDRESS=*VAR_file_create_counter_ADDRESS
        read_device_buffer ${VAR_file_create_disk_name_ADDRESS} ${VAR_file_create_counter_ADDRESS}
        *VAR_file_create_cur_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # Parse partition info:
        *VAR_file_create_temp_var_ADDRESS="4"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_cur_line_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_partition_start_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        *VAR_file_create_temp_var_ADDRESS="5"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_cur_line_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_partition_end_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # check whether file exists:
        *VAR_file_create_counter_ADDRESS=*VAR_file_create_partition_start_ADDRESS
        read_device_buffer ${VAR_file_create_disk_name_ADDRESS} ${VAR_file_create_counter_ADDRESS}

        *VAR_file_create_temp_var_ADDRESS="DUMMY_FS"
        cpu_execute "${CPU_NOT_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        jump_if ${LABEL_file_create_file_error}

        *VAR_file_create_counter_ADDRESS++
        *VAR_file_create_line_for_header_ADDRESS=""
    LABEL:file_create_file_loop
        read_device_buffer ${VAR_file_create_disk_name_ADDRESS} ${VAR_file_create_counter_ADDRESS}
        *VAR_file_create_cur_line_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        *VAR_file_create_temp_var_ADDRESS=""
        cpu_execute "${CPU_NOT_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        jump_if ${LABEL_file_create_non_empty_record}
        # if the record in filesystem header is empty and we didn't find such line before then we can use it for file creation
        cpu_execute "${CPU_NOT_EQUAL_CMD}" ${VAR_file_create_line_for_header_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        jump_if ${LABEL_file_create_non_empty_record}
        *VAR_file_create_line_for_header_ADDRESS=*VAR_file_create_counter_ADDRESS

      LABEL:file_create_non_empty_record
        # check whether we reached end of partition table
        *VAR_file_create_temp_var_ADDRESS="DUMMY_FS_END"
        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        jump_if ${LABEL_file_create_file_not_found}

        # if file already exists then we can not create it
        *VAR_file_create_temp_var_ADDRESS="1"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_cur_line_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_create_filename_ADDRESS}
        jump_if ${LABEL_file_create_error}

        *VAR_file_create_counter_ADDRESS++
        jump_to ${LABEL_file_create_file_loop}

    LABEL:file_create_file_not_found
        *VAR_file_create_temp_var_ADDRESS=""
        # if no free record in header was found then we can not create new file
        cpu_execute "${CPU_EQUAL_CMD}" ${VAR_file_create_line_for_header_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        jump_if ${LABEL_file_create_error}

        var file_create_start_index
        var file_create_end_index
        var file_create_cur_part_header
        read_device_buffer ${VAR_file_create_disk_name_ADDRESS} ${VAR_file_create_partition_header_ADDRESS}
        *VAR_file_create_cur_part_header_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # Let's get free range for current partition:
        *VAR_file_create_temp_var_ADDRESS="7"
        cpu_execute "${CPU_GET_COLUMN_CMD}" ${VAR_file_create_cur_part_header_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_start_index_ADDRESS=*GLOBAL_OUTPUT_ADDRESS

        # Not let's use input argument with file size to calculate end index and check whether it will be inside partition:
        cpu_execute "${CPU_ADD_CMD}" ${VAR_file_create_start_index_ADDRESS} ${GLOBAL_ARG2_ADDRESS}
        *GLOBAL_OUTPUT_ADDRESS--
        *VAR_file_create_end_index_ADDRESS=*GLOBAL_OUTPUT_ADDRESS
        cpu_execute "${CPU_LESS_THAN_CMD}" ${VAR_file_create_partition_end_ADDRESS} ${VAR_file_create_end_index_ADDRESS}
        jump_if ${LABEL_file_create_error}

        # Now we should update partition header to decrease free space:
        var file_create_new_part_free_start
        *VAR_file_create_new_part_free_start_ADDRESS=*VAR_file_create_end_index_ADDRESS
        *VAR_file_create_new_part_free_start_ADDRESS++
        *VAR_file_create_temp_var_ADDRESS="7"
        cpu_execute "${CPU_REPLACE_COLUMN_CMD}" ${VAR_file_create_cur_part_header_ADDRESS} ${VAR_file_create_temp_var_ADDRESS} ${VAR_file_create_new_part_free_start_ADDRESS}
        write_device_buffer ${VAR_file_create_disk_name_ADDRESS} ${VAR_file_create_partition_header_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}
        # create new file by adding new record to header
        *VAR_file_create_temp_var_ADDRESS="file 7 7 7 root root"
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${VAR_file_create_filename_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_create_start_index_ADDRESS}
        cpu_execute "${CPU_CONCAT_SPACES_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${VAR_file_create_end_index_ADDRESS}
        write_device_buffer ${VAR_file_create_disk_name_ADDRESS} ${VAR_file_create_line_for_header_ADDRESS} ${GLOBAL_OUTPUT_ADDRESS}

        # Now we should zero out all lines of the newly created file:
        *VAR_file_create_counter_ADDRESS=*VAR_file_create_start_index_ADDRESS
        *VAR_file_create_temp_var_ADDRESS=""
    LABEL:file_create_zeroing_loop
        write_device_buffer ${VAR_file_create_disk_name_ADDRESS} ${VAR_file_create_counter_ADDRESS} ${VAR_file_create_temp_var_ADDRESS}
        *VAR_file_create_counter_ADDRESS++
        cpu_execute "${CPU_LESS_THAN_EQUAL_CMD}" ${VAR_file_create_counter_ADDRESS} ${VAR_file_create_end_index_ADDRESS}
        jump_if ${LABEL_file_create_zeroing_loop}

        call_func file_open ${GLOBAL_ARG1_ADDRESS}
        func_return

    LABEL:file_create_error
        *GLOBAL_OUTPUT_ADDRESS="-1"
        func_return
