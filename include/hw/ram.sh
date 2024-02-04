# This file contains source code for RAM read/write functions.
# You should initialize RAM at the early boot stage.


# Read value from RAM
# INPUT: RAM line number
function read_from_address {
    local LINE_NO="${1}"
    # Check if line number is valid e.g. is not outside the range [1, GLOBAL_RAM_SIZE] :
    if [ "${LINE_NO}" -lt 1 ] || [ "${LINE_NO}" -gt ${GLOBAL_RAM_SIZE} ]; then
        exit_fatal "Access to invalid address ${1}. System halt!"
    fi

    echo "${HW_RAM_MEMORY[${LINE_NO}]}"
}


# Write value to RAM
# INPUT: RAM line number, value to write
function write_to_address {
    local LINE_NO="${1}"
    local VALUE="${2}"

    # Check if line number is valid e.g. is not outside the range [1, GLOBAL_RAM_SIZE].
    if [ "${LINE_NO}" -lt 1 ] || [ "${LINE_NO}" -gt ${GLOBAL_RAM_SIZE} ]; then
        exit_fatal "Access to invalid address ${1}. System halt!"
    fi

    HW_RAM_MEMORY[${LINE_NO}]="$VALUE"
}


# Copy value from one address to another in RAM
# INPUT: source address, destination address
function copy_from_to_address {
    write_to_address $2 "$(read_from_address ${1})"
}

# Copy value from one address to another in RAM
# INPUT: source address, destination address, number of lines to copy
function copy_from_to_n_address {
    local SOURCE_ADDRESS="$1"
    local DESTINATION_ADDRESS="$2"
    local NUMBER_OF_LINES="$3"
    for (( i = 0; i < $NUMBER_OF_LINES; i++ )); do
        write_to_address $(($DESTINATION_ADDRESS + i)) "$(read_from_address $(($SOURCE_ADDRESS + i)))"
    done
}

function dump_RAM_to_file {
    printf "%s\n" "${HW_RAM_MEMORY[@]}" > "${GLOBAL_RAM_FILE}"
}

export -f read_from_address
export -f write_to_address
export -f copy_from_to_address
export -f dump_RAM_to_file
