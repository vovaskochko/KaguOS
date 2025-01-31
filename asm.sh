#!/usr/bin/env bash
# this script allows to convert .kga files to the machine code

function compilation_error() {
    local EXPECTED_SYNTAX="$1"
    local ERROR_INFO="$2"
    echo -e "\033[93mCompilation error\033[0m at ${CUR_FILE}:${CUR_LINE_NO}" 1>&2
    echo -e "\033[91m$CUR_LINE\033[0m" 1>&2
    if [ -n "$ERROR_INFO" ]; then
        echo -e "\033[91m$ERROR_INFO\033[0m" 1>&2
    fi
    echo -e "Expected syntax:\n\033[92m$EXPECTED_SYNTAX\033[0m" 1>&2
    echo 1>&2

    COMPILATION_ERROR_COUNT=$((COMPILATION_ERROR_COUNT + 1))
    if [ $COMPILATION_ERROR_COUNT -gt 20 ]; then
        echo "Too many compilation errors, aborting" 1>&2
        exit 1
    fi
}

function contains_element() {
    local VALUE="$1"; shift
    local ARRAY=("$@")

    for ELEMENT in "${ARRAY[@]}"; do
        if [[ "$ELEMENT" == "$VALUE" ]]; then
            return 0
        fi
    done
    return 1
}

function find_index() {
    local ELEMENT="$1"; shift
    local ARRAY=("$@")

    for i in "${!ARRAY[@]}"; do
        if [[ "${ARRAY[i]}" == "$ELEMENT" ]]; then
            echo "$i"
            return 0
        fi
    done

    echo "-1"
    return 1
}

function concatStrings() {
    if [ -n "$1" ] && [ -n "$2" ]; then
        echo "$1 $2"
    else
        echo "$1$2"
    fi
}

CMDS_ARRAY=("write" "copy" "label" "jump" "jump_if" "cpu_exec" "var" "DEBUG_ON" "DEBUG_OFF")
function is_command() {
    for item in "${CMDS_ARRAY[@]}"; do
        if [[ "$item" == "$1" ]]; then
            return 0
        fi
    done
    return 1
}

function parse_lexeme() {
    local CUR_LEXEME="$1"
    if [ -z "$CUR_LEXEME" ] || [ "${CUR_LEXEME:0:2}" = "//" ]; then
        echo "_ cmt"
        return
    fi

    PREFIX="${CUR_LEXEME:0:1}"
    if [ "$PREFIX" = "@" ] || [ "$PREFIX" = "*" ]; then
        CUR_LEXEME="${CUR_LEXEME:1}"
    else
        PREFIX="_"
    fi

    if [ "${CUR_LEXEME:0:1}" = '"' ] && [ "${CUR_LEXEME: -1}" = '"' ]; then
        echo "$PREFIX str ${CUR_LEXEME:1:-1}"
    elif [[ "$CUR_LEXEME" =~ ^[0-9]+$ ]]; then
        echo "$PREFIX num $CUR_LEXEME"
    elif [ "$CUR_LEXEME" = "to" ]; then
        echo "$PREFIX kto =>"
    elif [ "${CUR_LEXEME:0:4}" = "var:" ]; then
        local CUR_NAME="${CUR_LEXEME#var:}"
        if [[ "${CUR_NAME}" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
            echo "$PREFIX var $CUR_NAME"
        else
            echo "$PREFIX err name_format $CUR_LEXEME"
        fi
    elif [ "${CUR_LEXEME:0:6}" = "label:" ]; then
        local CUR_NAME="${CUR_LEXEME#label:}"
        if [[ "${CUR_NAME}" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
            echo "$PREFIX lbl $CUR_NAME"
        else
            echo "$PREFIX err name_format $CUR_LEXEME"
        fi
    elif [ "${CUR_LEXEME:0:3}" = "OP_" ]; then
        echo "$PREFIX opr $CUR_LEXEME"
    elif [ "${CUR_LEXEME:0:4}" = "REG_" ] || [ "${CUR_LEXEME:0:5}" = "INFO_" ] || [ "$CUR_LEXEME" = "DISPLAY_BUFFER" ] || [ "$CUR_LEXEME" = "DISPLAY_COLOR" ] || [ "$CUR_LEXEME" = "DISPLAY_BACKGROUND" ] || [ "$CUR_LEXEME" = "KEYBOARD_BUFFER" ] || [ "$CUR_LEXEME" = "PROGRAM_COUNTER" ] || [ "${CUR_LEXEME:0:5}" = "FREE_" ]; then
        echo "$PREFIX reg $CUR_LEXEME"
    elif [ "${CUR_LEXEME:0:6}" = "COLOR_" ]; then
        echo "$PREFIX clr $CUR_LEXEME"
    elif [ "${CUR_LEXEME}" = "KEYBOARD_READ_LINE" ] || [ "${CUR_LEXEME}" = "KEYBOARD_READ_LINE_SILENTLY" ] || [ "${CUR_LEXEME}" = "KEYBOARD_READ_CHAR" ] || [ "${CUR_LEXEME}" = "KEYBOARD_READ_CHAR_SILENTLY" ]; then
        echo "$PREFIX mod $CUR_LEXEME"
    elif is_command "${CUR_LEXEME}"; then
        echo "$PREFIX cmd ${CUR_LEXEME}"
    elif [[ "${CUR_LEXEME}" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        echo "$PREFIX nam $CUR_LEXEME"
    else
        echo "$PREFIX err other $CUR_LEXEME"
    fi
}

function eval_lexeme() {
    local LEX="$1"
    local POSITION="$2"
    local PREFIX="${LEX:0:1}"
    if [ "$PREFIX" = "_" ]; then PREFIX=""; fi

    local TYPE="${LEX:2:3}"
    local VALUE="${LEX:6}"
    FUNC_RESULT=""
    case $TYPE in
    cmd)
        case $VALUE in
            copy|write) FUNC_RESULT="$INSTR_COPY_FROM_TO_ADDRESS";;
            jump) FUNC_RESULT="$INSTR_JUMP";;
            jump_if) FUNC_RESULT="$INSTR_JUMP_IF";;
            cpu_exec) FUNC_RESULT="$INSTR_CPU_EXEC";;
            DEBUG_ON|DEBUG_OFF) FUNC_RESULT="$VALUE";;
            *) FUNC_RESULT="";;
        esac
        ;;
    kto) FUNC_RESULT="";;
    num|reg|opr|clr|mod)
        if [ "$POSITION" = "write_1" ]; then
            CUR_INDEX=$(find_index "$VALUE" "${CONSTANTS[@]}")
            FUNC_RESULT="${CONSTANTS_ADDRESSES[$CUR_INDEX]}"
        else
            if [ "$TYPE" = "num" ]; then
                FUNC_RESULT="${PREFIX}$VALUE"
            else
                FUNC_RESULT="${PREFIX}$(eval echo "\$$VALUE")"
            fi
        fi
       ;;
    str)
        CUR_INDEX=$(find_index "\"$VALUE\"" "${CONSTANTS[@]}")
        FUNC_RESULT="${CONSTANTS_ADDRESSES[$CUR_INDEX]}"
        ;;
    lbl)
        CUR_INDEX=$(find_index "${VALUE}" "${LABELS[@]}")
        if [ "$CUR_INDEX" -eq -1 ]; then
            compilation_error "" "Label $VALUE is not defined"
        else
            FUNC_RESULT="${LABELS_ADDRESSES[$CUR_INDEX]}"
        fi
        ;;
    var)
        CUR_INDEX=$(find_index "$VALUE" "${VARIABLES[@]}")
        if [ "$CUR_INDEX" -eq -1 ]; then
            compilation_error "Variable should be declared before usage" "Variable $VALUE is not defined"
        else
            DECL_ADDRESS=${VARIABLES_DECL_ADDRESSES[$CUR_INDEX]}
            if [ "$CUR_INSTRUCTION_NO" -lt "$DECL_ADDRESS" ]; then
                compilation_error "Variable should be defined before the first use" "Variable ${VALUE} is used before declaration"
            fi
            FUNC_RESULT="${PREFIX}${VARIABLES_ADDRESSES[$CUR_INDEX]}"
        fi
        ;;
    *) echo "Lexem $LEX was not handled properly";;
    esac
}

function eval_debug_info_for_lexeme() {
    local LEX="$1"
    local POSITION="$2"
    local TYPE="${LEX:2:3}"
    local VALUE="${LEX:6}"

    if [ "$TYPE" = str ] || ([ "$TYPE" = num ] && [ "${POSITION}" = write_1 ]); then
        FUNC_RESULT="\"$VALUE\""
        return
    fi

    if [ "$TYPE" = var ] || [ "$TYPE" = lbl ]; then
        VALUE="$TYPE:$VALUE"
    fi

    local PREFIX="${LEX:0:1}"
    if [ "$PREFIX" = "_" ]; then PREFIX=""; fi
    FUNC_RESULT="$PREFIX$VALUE"
}

# MAIN COMPILER CODE:

# Include files with definitions:
INCLUDE_DIR="$(dirname "$0")"/include
source "$INCLUDE_DIR"/operations.sh
source "$INCLUDE_DIR"/other.sh
source "$INCLUDE_DIR"/registers.sh
source "$INCLUDE_DIR"/system.sh

# Define global variables:
CUR_FILE=""
CUR_LINE_NO=""
CUR_LINE=""

LABELS=()
LABELS_ADDRESSES=()

CONSTANTS=()
CONSTANTS_EVALUATED=()
CONSTANTS_ADDRESSES=()

VARIABLES=()
VARIABLES_ADDRESSES=()
VARIABLES_DECL_ADDRESSES=()

COMPILATION_ERROR_COUNT=0

PARSED_LEXEMES=()

if [ -z "$DEBUG_INFO" ]; then
    DEBUG_INFO=1
fi

# Parse input list of source files:
KERNEL_FILE="$GLOBAL_KERNEL_DISK"
SRC_FILES=""
for ARG in "$@"; do
    if [ ! -f "${ARG}" ]; then
        echo "${ARG} is not a valid source file"
        exit 1
    fi
    SRC_FILES="${SRC_FILES} ${ARG}"
done

# Go through the files and parse each line to the list of lexemes, store constants, variables and labels to calculate there addresses later:
NEXT_INSTR_ADDRESS=$KERNEL_START
for CUR_FILE in $SRC_FILES; do
    PARSED_LEXEMES+=( "file ${CUR_FILE}" )
    CUR_LINE_NO=0

    while read -r CUR_LINE || [ -n "$CUR_LINE" ]; do
        CUR_LINE_NO=$((CUR_LINE_NO + 1))
        # remove leading and trailing spaces
        CUR_LINE=$(echo "${CUR_LINE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [ -z "$CUR_LINE" ] || [ "${CUR_LINE:0:2}" = "//" ]; then
            continue
        fi

        # Parse line to components:
        eval set -- "$CUR_LINE"

        # Let's set expected lexeme count depending on the command
        CUR_CMD="$1"
        case $CUR_CMD in
        write)
            LEXEMES_COUNT=4
            EXPECTED_PATTERN="^(_ cmd)(_ str|_ num|_ opr|_ clr|_ mod)(_ kto)(_ num|\* num|_ reg|\* reg|_ var|\* var)(_ cmt)$"
            EXPECTED_SYNTAX="'write \"some string\" to address' or 'write 100 to address' or 'write OP_* to address' or 'write COLOR_* to address'"
            ;;
        copy)
            LEXEMES_COUNT=4
            EXPECTED_PATTERN="^(_ cmd)(_ num|\* num|_ reg|\* reg|_ var|\* var|@ var)(_ kto)(_ num|\* num|_ reg|\* reg|_ var|\* var)(_ cmt)$"
            EXPECTED_SYNTAX="copy someAddress to otherAddress"
            ;;
        label|var)
            LEXEMES_COUNT=2
            EXPECTED_PATTERN="^(_ cmd)(_ nam)(_ cmt)$"
            EXPECTED_SYNTAX="$CUR_CMD name - name should start from a letter and contain only letters, numbers and _"
            ;;
        jump|jump_if)
            LEXEMES_COUNT=2
            EXPECTED_PATTERN="^(_ cmd)(_ num|\* num|\* reg|_ lbl|\* var)(_ cmt)$"
            EXPECTED_SYNTAX="$CUR_CMD label:someName or $CUR_CMD 100 or $CUR_CMD *100 or $CUR_CMD *var:varName"
            ;;
        cpu_exec|DEBUG_ON|DEBUG_OFF)
            LEXEMES_COUNT=1
            EXPECTED_PATTERN="^(_ cmd)(_ cmt)$"
            EXPECTED_SYNTAX="$CUR_CMD // some optional comment"
            ;;
        *)
            LEXEMES_COUNT=0
            EXPECTED_PATTERN="^(_ cmt)$"
            EXPECTED_SYNTAX="$CUR_CMD is unknown command"
            ;;
        esac

        CUR_LEXEMES=()
        CUR_PATTERN=""
        # parse corresponding count of lexemes:
        for ((i=1;i<=LEXEMES_COUNT+1;i++)); do
            CUR_LEXEME="${!i}"

            # eval command eliminates double quotes from string literals. Let's move them back for the valid case:
            if [ "$i" -eq 2 ] && [[ $(echo "$CUR_LINE" | awk '{print $1" "$2}') == 'write "'* ]]; then
                CUR_LEXEME="\"$CUR_LEXEME\""
            fi

            LEX=$(parse_lexeme "$CUR_LEXEME")
            CUR_PATTERN="${CUR_PATTERN}${LEX:0:5}"
            if [ $i -le $LEXEMES_COUNT ]; then
                CUR_LEXEMES+=( "$LEX" )
            fi
        done

        # Report error if something went wrong during analysis of the line
        if [[ ! "$CUR_PATTERN" =~ $EXPECTED_PATTERN ]]; then
            compilation_error "$EXPECTED_SYNTAX" "Unexpected arguments for command $CUR_CMD"
            continue
        fi

        # For variables declaration we should only check that name is unique and add it to variables list.
        # Also we should store declaration position to report errors when variable is used before declaration.
        if [ "${CUR_CMD}" = "var" ]; then
            CUR_NAME="${CUR_LEXEMES[1]:6}"
            if contains_element "$CUR_NAME" "${VARIABLES[@]}"; then
                compilation_error "Variable should be defined only once" "Variable $CUR_NAME already exists"
                continue
            fi
            VARIABLES+=("${CUR_NAME}")
            VARIABLES_DECL_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
            continue
        fi

        # For labels declaration we should only check that name is unique and add it to labels list.
        # Also we should store the address of the instruction associated with the label for further use.
        if [ "${CUR_CMD}" = "label" ]; then
            CUR_NAME="${CUR_LEXEMES[1]:6}"
            if contains_element "$CUR_NAME" "${LABELS[@]}"; then
                compilation_error "Label should be defined only once" "Label $CUR_NAME already exists"
                continue
            fi
            LABELS+=("${CUR_NAME}")
            LABELS_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
            continue
        fi

        # We are using constants only in case of write command. That constants should be stored to some location in memory.
        # Therefore we store constant to the constants list if it is not present there yet.
        if [ "$CUR_CMD" = write ]; then
            LEX_TYPE="${CUR_LEXEMES[1]:2:3}"
            CUR_VALUE="${CUR_LEXEMES[1]:6}"
            if [ "$LEX_TYPE" = str ]; then
                CUR_VALUE="\"${CUR_VALUE}\""
            fi

            if ! contains_element "$CUR_VALUE" "${CONSTANTS[@]}"; then
                CONSTANTS+=("${CUR_VALUE}")
                case $LEX_TYPE in
                    clr|reg|opr|mod)    EVAL_VALUE=$(eval echo "\$$CUR_VALUE");;
                    num)                EVAL_VALUE="$CUR_VALUE";;
                    str)                EVAL_VALUE="${CUR_VALUE:1:-1}";;
                    *)                  EVAL_VALUE="";;
                esac
                CONSTANTS_EVALUATED+=("${EVAL_VALUE}")
            fi
        fi

        # At this point we have only valid instruction patterns that can be added to the list of instructions for further compilation
        PARSED_LEXEMES+=( "line ${CUR_LINE_NO}" )
        PARSED_LEXEMES+=( "${CUR_LEXEMES[@]}" )
        NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
    done < "$CUR_FILE"
done

# Let's calculate addreses for CONSTANTS as we already know the addresses used for all instructions:
for CUR_CONST in "${CONSTANTS[@]}"; do
    CONSTANTS_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
    NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
done

# Let's calculate addresses for VARIABLES - they will be just after constants in memory
for CUR_VAR in "${VARIABLES[@]}"; do
    VARIABLES_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
    NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
done

# Let's prepare folders and files to store compiled kernel:
mkdir -p $(dirname "${KERNEL_FILE}")
rm -rf "${KERNEL_FILE}"
printf "%s\n" "${PARSED_LEXEMES[@]}" > "${KERNEL_FILE}.o"


function get_next_lexeme() {
    LEXEME_INDEX=$((LEXEME_INDEX + 1))
    LEXEME=${PARSED_LEXEMES[$LEXEME_INDEX]}
}

# Now we can go through the list of the parsed lexemes and substitute all the addresses
LEXEME_INDEX=-1
CUR_INSTRUCTION_NO=$((KERNEL_START - 1))
while true; do
    get_next_lexeme

    if [ -z "$LEXEME" ]; then
        break
    fi

    if [ "${LEXEME:0:4}" = "file" ]; then
        CUR_FILE=${LEXEME:5}
        continue
    fi

    if [ "${LEXEME:0:4}" = "line" ]; then
        CUR_LINE_NO=${LEXEME:5}
        continue
    fi

    CUR_INSTRUCTION_NO=$((CUR_INSTRUCTION_NO + 1))
    CUR_CMD="${LEXEME:6}"
    case "$CUR_CMD" in
        cpu_exec|DEBUG_ON|DEBUG_OFF)    LEXEMES_COUNT=1;;
        jump|jump_if)                   LEXEMES_COUNT=2;;
        write|copy)                     LEXEMES_COUNT=4;;
        *)                              LEXEMES_COUNT=0;;
    esac

    RES_STR=""
    DEBUG_STR="# "
    for((i=0;i<LEXEMES_COUNT;i++)); do
        if [ "$i" -gt 0 ]; then
            get_next_lexeme
        fi
        eval_lexeme "${LEXEME}" "${CUR_CMD}_$i"
        RES_STR=$(concatStrings "${RES_STR}" "${FUNC_RESULT}")
        eval_debug_info_for_lexeme "${LEXEME}" "${CUR_CMD}_$i"
        DEBUG_STR=$(concatStrings "${DEBUG_STR}" "${FUNC_RESULT}")
    done

    if [ "$DEBUG_INFO" -eq 1 ]; then
        echo "$RES_STR $DEBUG_STR" >> "$KERNEL_FILE"
    else
        echo "$RES_STR" >> "$KERNEL_FILE"
    fi
done

# Let's align all the # comments of the instructions to have more readability:
if [ -s "$KERNEL_FILE" ]; then
    awk '{
        pos = index($0, "#")
        if (pos == 0) {
            print
        } else {
            spaces = 15 - (pos - 1)
            printf "%s%*s%s\n", substr($0, 1, pos - 1), spaces, "", substr($0, pos)
        }
    }' "${KERNEL_FILE}" > "${KERNEL_FILE}".tmp && mv "${KERNEL_FILE}".tmp "${KERNEL_FILE}"
else
    compilation_error "" "Empty kernel file: no valid instructions present in the provided source files"
fi

# Append constants just after instructions
for CUR_CONST in "${CONSTANTS_EVALUATED[@]}"; do
    echo "$CUR_CONST" >> "$KERNEL_FILE"
done

# Append empty lines as a default value for memory allocated for variables
for CUR_VAR in "${VARIABLES[@]}"; do
    echo "" >> "$KERNEL_FILE"
done

# That's it - compilation finished. Let's report status to the user:
if [ $COMPILATION_ERROR_COUNT -ne 0 ]; then
    echo -e "\033[91mCompilation failed: $COMPILATION_ERROR_COUNT error(s).\033[0m"
    exit $COMPILATION_ERROR_COUNT
else
    echo -e "\033[92mCompilation succeeded. Kernel image: ${KERNEL_FILE}\033[0m"
fi

if [ "$NEXT_INSTR_ADDRESS" -ge "$GLOBAL_RAM_SIZE" ]; then
    echo -e "\033[93mNot enough RAM to store all the instructions. RAM size is $GLOBAL_RAM_SIZE, last address of the disk is $NEXT_INSTR_ADDRESS"
    echo -e "Either increase RAM size or decrease the size of the program to run the kernel properly.\033[0m"
fi
