# This file contains basic CPU commands together with cpu_execute function

# CPU COMMAND #
export CPU_EQUAL_CMD="is_equal"
export CPU_NOT_EQUAL_CMD="is_not_equal"
export CPU_ADD_CMD="add"
export CPU_INCREMENT_CMD="increment"
export CPU_DECREMENT_CMD="decrement"
export CPU_SUBTRACT_CMD="subtract"
export CPU_MULTIPLY_CMD="multiply"
export CPU_DIVIDE_CMD="divide"
export CPU_CONCAT_CMD="concat"
export CPU_CONCAT_SPACES_CMD="concat_spaces"
export CPU_GET_COLUMN_CMD="get_column"
export CPU_REPLACE_COLUMN_CMD="replace_column"
export CPU_REMOVE_COLUMN_CMD="remove_column"
export CPU_LESS_THAN_CMD="less_than"
export CPU_LESS_THAN_EQUAL_CMD="less_than_equal"
export CPU_STARTS_WITH_CMD="starts_with"
export CPU_ENCRYPT_CMD="encrypt"
export CPU_DECRYPT_CMD="decrypt"

# CPU execution function

# function to execute CPU command provided as the first argument of the function
# Input arguments(if needed) should be stored to RAM
# and corresponding addresses should be provided as the second and the third arguments of the function
# Result is stored into GLOBAL_OUTPUT_ADDRESS for all commands except comparison which stored into GLOBAL_COMPARE_RES_ADDRESS
function cpu_execute {
    local CPU_REGISTER_CMD="${1}"
    local CPU_REGISTER1=""
    local CPU_REGISTER2=""
    local CPU_REGISTER3=""
    local CPU_REGISTER_OUT=""

    if [ ! -z "$2" ]; then
        CPU_REGISTER1="$(read_from_address ${2})"
    fi
    if [ ! -z "$3" ]; then
        CPU_REGISTER2="$(read_from_address ${3})"
    fi
    if [ ! -z "$4" ]; then
        CPU_REGISTER3="$(read_from_address ${4})"
    fi

    case "${CPU_REGISTER_CMD}" in
        "${CPU_EQUAL_CMD}")
            if [ "${CPU_REGISTER1}" = "${CPU_REGISTER2}" ]; then
                CPU_REGISTER_OUT="1"
            else
                CPU_REGISTER_OUT="0"
            fi
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} "${CPU_REGISTER_OUT}"
            return 0
            ;;
        "${CPU_NOT_EQUAL_CMD}")
            if [ "${CPU_REGISTER1}" != "${CPU_REGISTER2}" ]; then
                CPU_REGISTER_OUT="1"
            else
                CPU_REGISTER_OUT="0"
            fi
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} ${CPU_REGISTER_OUT}
            return 0
            ;;
        "${CPU_LESS_THAN_CMD}")
            if [ "${CPU_REGISTER1}" -lt "${CPU_REGISTER2}" ]; then
                CPU_REGISTER_OUT="1"
            else
                CPU_REGISTER_OUT="0"
            fi
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} ${CPU_REGISTER_OUT}
            return 0
            ;;
         "${CPU_LESS_THAN_EQUAL_CMD}")
            if [ "${CPU_REGISTER1}" -le "${CPU_REGISTER2}" ]; then
                CPU_REGISTER_OUT="1"
            else
                CPU_REGISTER_OUT="0"
            fi
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} ${CPU_REGISTER_OUT}
            return 0
            ;;
        "${CPU_ADD_CMD}")
            CPU_REGISTER_OUT="$((${CPU_REGISTER1}+${CPU_REGISTER2}))"
            ;;
        "${CPU_SUBTRACT_CMD}")
            CPU_REGISTER_OUT="$((${CPU_REGISTER1}-${CPU_REGISTER2}))"
            ;;
        "${CPU_DIVIDE_CMD}")
            CPU_REGISTER_OUT="$((${CPU_REGISTER1}/${CPU_REGISTER2}))"
            ;;
        "${CPU_MULTIPLY_CMD}")
            CPU_REGISTER_OUT="$((${CPU_REGISTER1}-${CPU_REGISTER2}))"
            ;;
        "${CPU_INCREMENT_CMD}")
            CPU_REGISTER_OUT="$((${CPU_REGISTER1}+1))"
            ;;
        "${CPU_DECREMENT_CMD}")
            CPU_REGISTER_OUT="$((${CPU_REGISTER1}-1))"
            ;;
        "${CPU_CONCAT_CMD}")
            CPU_REGISTER_OUT="${CPU_REGISTER1}${CPU_REGISTER2}"
            ;;
        "${CPU_CONCAT_SPACES_CMD}")
            if [ -z "${CPU_REGISTER2}" ]; then
                CPU_REGISTER_OUT="${CPU_REGISTER1}"
            elif [ -z "${CPU_REGISTER1}" ]; then
                CPU_REGISTER_OUT="${CPU_REGISTER2}"
            else
                CPU_REGISTER_OUT="${CPU_REGISTER1} ${CPU_REGISTER2}"
            fi
            ;;
        "${CPU_GET_COLUMN_CMD}")
            CPU_REGISTER_OUT=$(echo "${CPU_REGISTER1}" | awk -F' ' ' {print $'${CPU_REGISTER2}'}')
            ;;
        "${CPU_REPLACE_COLUMN_CMD}")
            CPU_REGISTER_OUT=$(echo "${CPU_REGISTER1}" | awk -F' ' '{$'${CPU_REGISTER2}'="'${CPU_REGISTER3}'"}1' )
            ;;
        "${CPU_REMOVE_COLUMN_CMD}")
            CPU_REGISTER_OUT=$(echo "${CPU_REGISTER1}" | awk -F' ' '{$'${CPU_REGISTER2}'=""}1' )
            ;;
        "${CPU_STARTS_WITH_CMD}")
            if [[ "${CPU_REGISTER1}" == "${CPU_REGISTER2}"* ]]; then
                CPU_REGISTER_OUT="1"
            else
                CPU_REGISTER_OUT="0"
            fi
            write_to_address ${GLOBAL_COMPARE_RES_ADDRESS} "${CPU_REGISTER_OUT}"
            if [ "${CPU_REGISTER_OUT}" == "1" ]; then
                CPU_REGISTER_OUT=${CPU_REGISTER1#${CPU_REGISTER2}}
                write_to_address ${GLOBAL_OUTPUT_ADDRESS} "${CPU_REGISTER_OUT}"
            fi
            return 0
            ;;
        "${CPU_ENCRYPT_CMD}")
            CPU_REGISTER_OUT="${CPU_REGISTER1}"
            ;;
        "${CPU_DECRYPT_CMD}")
            CPU_REGISTER_OUT="${CPU_REGISTER1}"
            ;;
        *)
            exit_fatal "Unknown cpu instruction: ${CPU_REGISTER_CMD}"
            ;;
    esac
    write_to_address ${GLOBAL_OUTPUT_ADDRESS} "${CPU_REGISTER_OUT}"
}

export -f cpu_execute
