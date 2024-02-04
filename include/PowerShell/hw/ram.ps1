# This file contains source code for RAM read/write functions.
# You should initialize RAM at the early boot stage.


# Read value from RAM
# INPUT: RAM line number
function read_from_address([String]$arg1) {
    $LINE_NO=[int]$arg1
    # Check if line number is valid e.g. is not outside the range [1, GLOBAL_RAM_SIZE] :
    if ( (${LINE_NO} -lt 1) -or (${LINE_NO} -gt ${GLOBAL_RAM_SIZE})) {
        exit_fatal "Read access to invalid address $LINE_NO. System halt!"
    }

    $HW_RAM_MEMORY[${LINE_NO}-1]
}


# Write value to RAM
# INPUT: RAM line number, value to write
function write_to_address([string]$arg1, [string]$arg2) {
    $LINE_NO=[int]$arg1
    $VALUE=$arg2

    # Check if line number is valid e.g. is not outside the range [1, GLOBAL_RAM_SIZE].
    if ((${LINE_NO} -lt 1) -or (${LINE_NO} -gt ${GLOBAL_RAM_SIZE})) {
        exit_fatal "Write access to invalid address $arg1. System halt!"
    }

    $HW_RAM_MEMORY[[int]$LINE_NO-1]="$VALUE"
}


# Copy value from one address to another in RAM
# INPUT: source address, destination address
function copy_from_to_address([string]$arg1, [string]$arg2) {
    $SRC_LINE_NO=[int]$arg1
    $DEST_LINE_NO=[int]$arg2
    $HW_RAM_MEMORY[$DEST_LINE_NO-1]=$HW_RAM_MEMORY[$SRC_LINE_NO-1]
}

# Copy value from one address to another in RAM
# INPUT: source address, destination address, number of lines to copy
function copy_from_to_n_address([string]$arg1, [string]$arg2, [string]$arg3) {
    $SOURCE_ADDRESS="$arg1"
    $DESTINATION_ADDRESS="$arg2"
    $NUMBER_OF_LINES="$arg3"
    for ( $i = 0; $i -le $NUMBER_OF_LINES; $i++ ) {
        $CurSrc=[int]$SOURCE_ADDRESS + $i
        $CurDest=[int]$DESTINATION_ADDRESS + $i
        $HW_RAM_MEMORY[$CurDest - 1]=$HW_RAM_MEMORY[$CurSrc-1]
    }
}

function dump_RAM_to_file {
    ${HW_RAM_MEMORY} | Out-File "${GLOBAL_RAM_FILE}"
}
