# This file contains source code for keyboard input and output to display
# You should initialize corresponding parts at the early boot stage.

# Read input line to input register of RAM
function read_input() {
    $INPUT_LINE = read-host
    write_to_address ${GLOBAL_INPUT_ADDRESS} "${INPUT_LINE}"
}


# print regular logs
function display_println {
    write-host "$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})"
}


# print regular logs without new line
function display_print {
    write-host -NoNewline "$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})"
}


# print with a green color
function display_success {
    write-host "$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})" -ForegroundColor Green
}


# print warning messages using yellow color
function display_warning {
    write-host "$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})" -ForegroundColor Yellow
}


# print error messages using red color
function display_error {
    write-host "$(read_from_address ${GLOBAL_DISPLAY_ADDRESS})" -ForegroundColor Red
}
