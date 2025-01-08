#!/usr/bin/env bash
# this script allows to convert .kgasm files to the machine code

function compilation_error() {
    local CUR_FILE="$1"
    local CUR_LINE_NO="$2"
    local CUR_LINE="$3"
    local EXPECTED_SYNTAX="$4"
    echo -e "\033[93mCompilation error\033[0m at ${CUR_FILE}:${CUR_LINE_NO}"
    echo -e "\033[91m$CUR_LINE\033[0m"
    echo -e "Expected syntax:\n\033[92m$EXPECTED_SYNTAX\033[0m"
    echo

    COMPILATION_ERROR_COUNT=$((COMPILATION_ERROR_COUNT + 1))
}

function empty_or_comment() {
    local CUR_ARG="$1"
    if [ -z "$CUR_ARG" ] || [ "${CUR_ARG:0:2}" = "//" ]; then
        echo true
    else
        echo false
    fi
}

source include/defines.sh
source include/hw.sh

SRC_FILE="$1"
KERNEL_FILE="$GLOBAL_KERNEL_DISK"

if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

mkdir -p "$GLOBAL_BUILD_DIR"
OBJ_FILE="${GLOBAL_BUILD_DIR}"/"$(echo "${SRC_FILE}" | sed "s,/,___,g")".o
rm -rf "${OBJ_FILE}"
touch "${OBJ_FILE}"

COMPILATION_ERROR_COUNT=0
NEXT_INSTRUCTION_ADDRESS=$KERNEL_START
LABELS=()
LABELS_COUNT=0
CONSTANTS=()
CONSTANTS_COUNT=0

# TODO
# for SRC_FILE in $FILES ...
# LINE_NO=0
while read -r LINE; do
    LINE_NO=$((LINE_NO + 1))
    # remove leading and trailing spaces
    LINE=$(echo "${LINE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    # Skip empty lines and comments:
    if [ $(empty_or_comment "$LINE") = true ]; then
        continue
    fi

    # split LINE to lexer components with awk
    eval set -- "$LINE"
    LEX1="$1"
    LEX2="$2"
    LEX3="$3"
    LEX4="$4"
    LEX5="$5"

    RES_LINE=
    case "$LEX1" in
        "label:"*)
            if [ $(empty_or_comment "$LEX2") = true ]; then
                CUR_KEY="${LINE#label:}"
                if [[ "$CUR_KEY" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
                    GREP_KEY=$(printf "%s\n" "${LABELS[@]}" | grep "^$CUR_KEY ")
                    if [ -z "${GREP_KEY}" ]; then
                        LABELS[$LABELS_COUNT]="$CUR_KEY $NEXT_INSTRUCTION_ADDRESS"
                        LABELS_COUNT=$((LABELS_COUNT + 1))
                    else
                        compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "Each label should be defined only once"
                    fi
                else
                    compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "label should start with letter and contain only letters, digit and _"
                fi
            else
                compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "label:some_value"
            fi
            continue
            ;;
        copy)
            if [ "$LEX3" = to ] && [ -n "$LEX4" ] && [ $(empty_or_comment "$LEX5") = true ]; then
                RES_LINE="copy_from_to_address \$${LEX2} \$${LEX4}"
            else
                compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "copy SOME_ADDRESS to OTHER_ADDRESS"
            fi
        ;;
        write)
            if [ "$LEX3" = to ] && [ $(empty_or_comment "$LEX5") = true ]; then
                HELP_STR=$(echo ${LINE#"$LEX1"} | sed -e 's/^[[:space:]]'$LEX1'*//' -e 's/[[:space:]]*$//')
                if [ "${HELP_STR:0:1}" = '"' ]; then
                    RES_LINE="write_to_address \$${LEX4} \"$LEX2\""
                else
                    RES_LINE="write_to_address \$${LEX4} \$$LEX2"
                fi
            else
                compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "write SOME to ADDRESS"
            fi
        ;;
        cpu_exec)
            if [ $(empty_or_comment "$LEX2") = true ]; then
                RES_LINE="cpu_exec"
            else
                compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "cpu_exec"
            fi
        ;;
        jump|jump_if)
            if [ -n "$LEX2" ] && [[ "$LEX2" =~ ^([0-9]+|label:.*)$ ]] && [ $(empty_or_comment "$LEX3") = true ]; then
                RES_LINE="$LEX1 $LEX2"
            else
                compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "jump 50\njump label:some\njump_if 100\njump_if label:some"
            fi
        ;;
        *)
            compilation_error "${SRC_FILE}" "$LINE_NO" "$LINE" "write copy label cpu_exec jump jump_if"
        ;;
    esac

    echo "${RES_LINE}" >> "${OBJ_FILE}"
    NEXT_INSTRUCTION_ADDRESS=$((NEXT_INSTRUCTION_ADDRESS + 1))
done < "${SRC_FILE}"

rm -rf "${KERNEL_FILE}"
while read -r LINE; do
    RES_LINE="$LINE"
    if [[ "$LINE" == jump* ]]; then
        LEX1=$(echo "$LINE" | awk '{print $1}')
        LEX2=$(echo "$LINE" | awk '{print $2}')
        if [[ "$LEX2" == "label:"* ]]; then
            CUR_KEY="${LEX2#label:}"
            ADDRESS=$(printf "%s\n" "${LABELS[@]}" | grep "^$CUR_KEY " | awk '{print $2}')
            if [ -z "$ADDRESS" ]; then
                compilation_error "" "" "$LINE" "Label $CUR_KEY should be defined"
            else
                RES_LINE="$LEX1 $ADDRESS"
            fi
        fi
    fi

    echo "${RES_LINE}" >> "${KERNEL_FILE}"
done < "${OBJ_FILE}"

if [ $COMPILATION_ERROR_COUNT -ne 0 ]; then
    echo -e "\033[91mCompilation failed: $COMPILATION_ERROR_COUNT error(s).\033[0m"
    exit 1
else
    echo -e "\033[92mCompilation succeeded\033[0m"
fi
