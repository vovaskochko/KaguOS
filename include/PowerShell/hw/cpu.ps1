# This file contains basic CPU commands list together with cpu_execute function

# CPU COMMAND #
$CPU_EQUAL_CMD="is_equal"
$CPU_NOT_EQUAL_CMD="is_not_equal"
$CPU_ADD_CMD="add"
$CPU_INCREMENT_CMD="increment"
$CPU_DECREMENT_CMD="decrement"
$CPU_SUBTRACT_CMD="subtract"
$CPU_MULTIPLY_CMD="multiply"
$CPU_DIVIDE_CMD="divide"
$CPU_CONCAT_CMD="concat"
$CPU_CONCAT_SPACES_CMD="concat_spaces"
$CPU_GET_COLUMN_CMD="get_column"
$CPU_LESS_THAN_CMD="less_than"
$CPU_LESS_THAN_EQUAL_CMD="less_than_equal"

# CPU execution function

# function to execute CPU command provided as the first argument of the function
# Input arguments(if needed) should be stored in RAM
# and corresponding addresses should be provided as the second and the third arguments of the function
# Result is stored into GLOBAL_OUTPUT_ADDRESS for all commands except comparison which stored into GLOBAL_COMPARE_RES_ADDRESS
function cpu_execute([string]$arg1, [string]$arg2, [string]$arg3) {
    $CPU_REGISTER_CMD=$arg1
    $CPU_REGISTER1=""
    $CPU_REGISTER2=""
    $CPU_REGISTER_OUT=""

    if ( "$arg2" -ne "" ) {
        $CPU_REGISTER1="$(read_from_address $arg2)"
    }

    if ( "$arg3" -ne "") {
        $CPU_REGISTER2="$(read_from_address $arg3)"
    }

    Switch ("${CPU_REGISTER_CMD}") {
        "${CPU_EQUAL_CMD}" {
            if ("${CPU_REGISTER1}" -eq "${CPU_REGISTER2}") {
                $CPU_REGISTER_OUT="1"
            }
            else {
                $CPU_REGISTER_OUT="0"
            }
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} "${CPU_REGISTER_OUT}"
            return
        }
        "${CPU_NOT_EQUAL_CMD}" {
            if ("${CPU_REGISTER1}" -ne "${CPU_REGISTER2}") {
                $CPU_REGISTER_OUT="1"
            }
            else {
                $CPU_REGISTER_OUT="0"
            }
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} "${CPU_REGISTER_OUT}"
            return
        }
        "${CPU_LESS_THAN_CMD}" {
            if ("${CPU_REGISTER1}" -lt "${CPU_REGISTER2}") {
                $CPU_REGISTER_OUT="1"
            }
            else {
                $CPU_REGISTER_OUT="0"
            }
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} "${CPU_REGISTER_OUT}"
            return
        }
         "${CPU_LESS_THAN_EQUAL_CMD}" {
            if ("${CPU_REGISTER1}" -le "${CPU_REGISTER2}") {
                $CPU_REGISTER_OUT="1"
            }
            else {
                $CPU_REGISTER_OUT="0"
            }
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} "${CPU_REGISTER_OUT}"
            return
        }
        "${CPU_ADD_CMD}" {
            $CPU_REGISTER_OUT="$([int]${CPU_REGISTER1} + [int]${CPU_REGISTER2})"
            }
        "${CPU_SUBTRACT_CMD}" {
            $CPU_REGISTER_OUT="$([int]${CPU_REGISTER1} - [int]${CPU_REGISTER2})"
        }
        "${CPU_INCREMENT_CMD}" {
            $CPU_REGISTER_OUT="$([int]${CPU_REGISTER1} + 1)"
        }
        "${CPU_DECREMENT_CMD}" {
            $CPU_REGISTER_OUT="$([int]${CPU_REGISTER1} - 1)"
        }
        "${CPU_CONCAT_CMD}" {
            $CPU_REGISTER_OUT="${CPU_REGISTER1}${CPU_REGISTER2}"
        }
        "${CPU_CONCAT_SPACES_CMD}" {
            if ("${CPU_REGISTER2}" -eq "") {
                $CPU_REGISTER_OUT="${CPU_REGISTER1}"
            }
            elseif ("${CPU_REGISTER1}" -eq "") {
                $CPU_REGISTER_OUT="${CPU_REGISTER2}"
            }
            else {
                $CPU_REGISTER_OUT="${CPU_REGISTER1} ${CPU_REGISTER2}"
            }
        }
        "${CPU_GET_COLUMN_CMD}" {
            $COLUMN_INDEX=[int]${CPU_REGISTER2} - 1
            $CPU_REGISTER_OUT=$("${CPU_REGISTER1}" | %{$_.split(' ')[$COLUMN_INDEX]})
        }
        Default {
            exit_fatal "Unknown cpu instruction: ${CPU_REGISTER_CMD}"
        }
    }

    write_to_address ${GLOBAL_OUTPUT_ADDRESS} "${CPU_REGISTER_OUT}"
}

