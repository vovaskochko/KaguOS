# This file contains source code for keyboard input and output to display
# You should initialize corresponding parts at the early boot stage.

# Read input line to input register of RAM
function read_input() {
    local INPUT_LINE
    read -r INPUT_LINE
    write_to_address ${GLOBAL_INPUT_ADDRESS} "${INPUT_LINE}"
}

function read_device_buffer {
    local DEVICE_TO_READ=$(read_from_address ${1})
    local DEVICE_INPUT_ARG=$(read_from_address ${2})

    if [ ! -f "${DEVICE_TO_READ}" ]; then
        exit_fatal "Device ${DEVICE_TO_READ} does not exist"
    fi

    RES=$(sed -n "${DEVICE_INPUT_ARG}p" "${DEVICE_TO_READ}")
    write_to_address ${GLOBAL_OUTPUT_ADDRESS} "${RES}"
}

function write_device_buffer {
    local DEVICE_TO_WRITE=$(read_from_address ${1})
    local DEVICE_OUTPUT_LINE=$(read_from_address ${2})
    local DEVICE_OUTPUT_CONTENT=$(read_from_address ${3})
    if [ ! -f "${DEVICE_TO_WRITE}" ]; then
        exit_fatal "Device ${DEVICE_TO_WRITE} does not exist"
    fi

    DEVICE_OUTPUT_CONTENT_ESC=$(sed 's/[\*\.&\/]/\\&/g' <<<"$DEVICE_OUTPUT_CONTENT")
    if [ "$(uname -s)" = "Darwin" ]; then
        RES=$(sed -i '' "${DEVICE_OUTPUT_LINE}s/.*/${DEVICE_OUTPUT_CONTENT_ESC}/" "${DEVICE_TO_WRITE}")
    else
        RES=$(sed -i "${DEVICE_OUTPUT_LINE}s/.*/${DEVICE_OUTPUT_CONTENT_ESC}/" "${DEVICE_TO_WRITE}")
    fi
}



# print regular logs
function display_println {
    echo -e "$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})"
}


# print regular logs without new line
function display_print {
    echo -e -n "$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})"
}


# print with a green color
function display_success {
    local END_COLOR="\033[0m"
    local GREEN_COLOR="\033[92m"
    echo -e "${GREEN_COLOR}$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})${END_COLOR}"
}


# print warning messages using yellow color
function display_warning {
    local END_COLOR="\033[0m"
    local YELLOW_COLOR="\033[93m"
    echo -e "${YELLOW_COLOR}$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})${END_COLOR}"
}


# print error messages using red color
function display_error {
    local RED_COLOR="\033[91m"
    local END_COLOR="\033[0m"
    echo -e "${RED_COLOR}$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})${END_COLOR}"
}


# export functions to be used everywhere
export -f read_input
export -f display_success
export -f display_print
export -f display_println
export -f display_warning
export -f display_error
