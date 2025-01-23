#!/usr/bin/env bash
# this script allows to convert .kga files to the machine code

LABELS=()
LABELS_ADDRESSES=()

CONSTANTS=()
CONSTANTS_EVALUATED=()
CONSTANTS_ADDRESSES=()

VARIABLES=()
VARIABLES_ADDRESSES=()
VARIABLES_DECL_ADDRESSES=()

COMPILATION_ERROR_COUNT=0

CUR_FILE=
CUR_LINE_NO=
CUR_LINE=

if [ -z "$DEBUG_INFO" ]; then
    DEBUG_INFO=1
fi

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
    local value="$1"; shift
    local array=("$@")

    for element in "${array[@]}"; do
        if [[ "$element" == "$value" ]]; then
            return 0
        fi
    done
    return 1
}

function find_index() {
    local element="$1"; shift
    local array=("$@")

    for i in "${!array[@]}"; do
        if [[ "${array[i]}" == "$element" ]]; then
            echo "$i"
            return 0
        fi
    done

    echo "-1"
    return 1
}

function eval_constant_lexeme() {
    local LEX="$1"
    local TYPE="${LEX:2:3}"
    local VALUE="${LEX:6}"
    case $TYPE in
    clr|reg|opr)    eval echo "\$$VALUE";;
    num|str)        echo "$VALUE";;
    *)              ;;
    esac
}

if [ -z "$INCLUDE_DIR" ]; then
    INCLUDE_DIR="$(dirname "$0")"/include
fi

source "$INCLUDE_DIR"/operations.sh
source "$INCLUDE_DIR"/other.sh
source "$INCLUDE_DIR"/registers.sh
source "$INCLUDE_DIR"/system.sh

KERNEL_FILE="$GLOBAL_KERNEL_DISK"
SRC_FILES=""
for ARG in "$@"; do
    if [ ! -f "${ARG}" ]; then
        echo "${ARG} is not a valid source file"
        exit 1
    fi
    SRC_FILES="${SRC_FILES} ${ARG}"
done

rm -rf "$GLOBAL_BUILD_DIR"
mkdir -p "$GLOBAL_BUILD_DIR"

NEXT_INSTR_ADDRESS=$KERNEL_START
OBJ_FILES=""

CMDS_ARRAY=("write" "copy" "label" "jump" "jump_if" "cpu_exec" "var" "DEBUG_ON" "DEBUG_OFF")
function is_command() {
    for item in "${CMDS_ARRAY[@]}"; do
        if [[ "$item" == "$1" ]]; then
            return 0
        fi
    done
    return 1
}

function is_constant_lexeme() {
    if [ "$1" != "_" ]; then
        return 1;
    fi
    case $2 in
    num|str|opr|clr)    return 0;;
    *)                  return 1;;
    esac
}

function parse_lexeme() {
    local CUR_LEXEME="$1"
    if [ -z "$CUR_LEXEME" ] || [ "${CUR_LEXEME:0:2}" = "//" ]; then
        echo "comment"
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
        echo "$PREFIX key to"
    elif [ "${CUR_LEXEME:0:4}" = "var:" ]; then
        local CUR_NAME="${CUR_LEXEME#var:}"
        if [[ "${CUR_NAME}" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
            echo "$PREFIX var $CUR_NAME"
        else
            echo "error name_format $CUR_LEXEME"
        fi
    elif [ "${CUR_LEXEME:0:6}" = "label:" ]; then
        local CUR_NAME="${CUR_LEXEME#label:}"
        if [[ "${CUR_NAME}" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
            echo "$PREFIX lbl $CUR_NAME"
        else
            echo "error name_format $CUR_LEXEME"
        fi
    elif [ "${CUR_LEXEME:0:3}" = "OP_" ]; then
        echo "$PREFIX opr $CUR_LEXEME"
    elif [ "${CUR_LEXEME:0:4}" = "REG_" ] || [ "${CUR_LEXEME:0:5}" = "INFO_" ] || [ "$CUR_LEXEME" = "DISPLAY_BUFFER" ] || [ "$CUR_LEXEME" = "DISPLAY_COLOR" ] || [ "$CUR_LEXEME" = "KEYBOARD_BUFFER" ] || [ "${CUR_LEXEME:0:5}" = "FREE_" ]; then
        echo "$PREFIX reg $CUR_LEXEME"
    elif [ "${CUR_LEXEME:0:6}" = "COLOR_" ]; then
        echo "$PREFIX clr $CUR_LEXEME"
    elif is_command "${CUR_LEXEME}"; then
        echo "$PREFIX cmd ${CUR_LEXEME}"
    elif [[ "${CUR_LEXEME}" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        echo "$PREFIX nam $CUR_LEXEME"
    else
        echo "error other $CUR_LEXEME"
    fi
}

NEXT_INSTR_ADDRESS=$KERNEL_START
PARSED_LEXEMES=()
for CUR_FILE in $SRC_FILES; do
    PARSED_LEXEMES+=( "$(echo file ${CUR_FILE})" )
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

        # Let's set expected lexemes count depending on the command
        CUR_CMD="$1"
        case $CUR_CMD in
        write|copy)                     LEXEMES_COUNT=4;;
        label|var|jump|jump_if)         LEXEMES_COUNT=2;;
        cpu_exec|DEBUG_ON|DEBUG_OFF)    LEXEMES_COUNT=1;;
        *)                              LEXEMES_COUNT=0;;
        esac

        CUR_LEXEMES=()
        CUR_ERROR=""
        # parse corresponding count of lexemes:
        for ((i=0;i<=LEXEMES_COUNT;i++)); do
            ARG_IND=$((i+1))
            CUR_LEXEME="${!ARG_IND}"
            # eval command eliminates double quotes from string literals. Let's move them back for the valid case:
            if [ "$i" -eq 1 ] && [[ $(echo "$CUR_LINE" | awk '{print $1" "$2}') == 'write "'* ]]; then
                CUR_LEXEME="\"$CUR_LEXEME\""
            fi

            LEX=$(parse_lexeme "$CUR_LEXEME")
            if [ "${LEX:0:5}" = "error" ]; then
                CUR_ERROR="${LEX}"
                break
            fi
            if ([ "${LEX:0:7}" = "comment" ] && [ $i -lt $LEXEMES_COUNT ]) || ( [ "${LEX:0:7}" != "comment" ] && [ $i -eq $LEXEMES_COUNT ]); then
                CUR_ERROR="Too few arguments. Unrecognized command, comment or empty line is not allowed at position ${i}: $CUR_LEXEME"
                break
            fi
            if [ $i -lt $LEXEMES_COUNT ]; then
                CUR_LEXEMES[$i]=$LEX
            fi
        done

        # Report error if something went wrong during analysis of the line
        if [ -n "$CUR_ERROR" ] || [ $LEXEMES_COUNT -eq 0 ]; then
            compilation_error "" "$CUR_ERROR"
            continue
        fi

        # In case of variables and label declaration we just need to check that they were not defined yet and remember their addresses for further substitution
        if [ "${CUR_CMD}" = "var" ] || [ "${CUR_CMD}" = "label" ]; then
            LEX_TYPE="${CUR_LEXEMES[1]:2:3}"
            CUR_NAME="${CUR_LEXEMES[1]:6}"
            if [ "$LEX_TYPE" != "nam" ]; then
                compilation_error "" "${CUR_CMD} expects a name as a parameter"
                continue
            fi

            if [ "${CUR_CMD}" = "var" ]; then
                if contains_element "$CUR_NAME" "${VARIABLES[@]}"; then
                    compilation_error "Variable should be defined only once" "Variable $CUR_NAME already exists"
                    continue
                fi
                VARIABLES+=("${CUR_NAME}")
                VARIABLES_DECL_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
            else
                if contains_element "$CUR_NAME" "${LABELS[@]}"; then
                    compilation_error "Label should be defined only once" "Label $CUR_NAME already exists"
                    continue
                fi
                LABELS+=("${CUR_NAME}")
                LABELS_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
            fi
            # We don't need to add var and label declarations to PARSED_LEXEMES list as they are not real instructions
            continue
        fi

        # In case of write command we should store constant to the list of constants if such constant was not present there yet
        if [ "$CUR_CMD" = write ]; then
            PREFIX="${CUR_LEXEMES[1]:0:1}"
            LEX_TYPE="${CUR_LEXEMES[1]:2:3}"
            CUR_VALUE="${CUR_LEXEMES[1]:6}"
            if [ "$LEX_TYPE" = str ]; then
                CUR_VALUE="\"${CUR_VALUE}\"" 
            fi
            if ! is_constant_lexeme "$PREFIX" "$LEX_TYPE"; then
                compilation_error "Incorrect instruction" "Write command expects a constant as a parameter"
                continue
            fi

            if ! contains_element "$CUR_VALUE" "${CONSTANTS[@]}"; then
                CONSTANTS+=("${CUR_VALUE}")
                CONSTANTS_EVALUATED+=("$(eval_constant_lexeme "${CUR_LEXEMES[1]}")")
            fi
        fi

        # At this point we have only instructions that can be added to the list of instructions for further compilation
        PARSED_LEXEMES+=( "$(echo line ${CUR_LINE_NO})" )
        PARSED_LEXEMES+=("${CUR_LEXEMES[@]}")
        NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
    done < "$CUR_FILE"
done


# Let's calculate addreses for CONSTANTS as we already know the addresses used for instructions:
for CUR_CONST in "${CONSTANTS[@]}"; do
    CONSTANTS_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
    NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
done

# Let's calculate addresses for VARIABLES - they will be just after constants in memory
for CUR_VAR in "${VARIABLES[@]}"; do
    VARIABLES_ADDRESSES+=("$NEXT_INSTR_ADDRESS")
    NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
done

function get_address_for_lexeme() {
    local LEX="$1"
    local PREFIX="${LEX:0:1}"
    if [ "$PREFIX" = "_" ]; then
        PREFIX=""
    fi
    local TYPE="${LEX:2:3}"
    local VALUE="${LEX:6}"
    FUNC_RESULT=""
    case $TYPE in
    reg)
        FUNC_RESULT=$(eval echo "${PREFIX}\$$VALUE");;
    num)
        FUNC_RESULT="${PREFIX}$VALUE";;
    lbl)
        CUR_INDEX=$(find_index "${VALUE}" "${LABELS[@]}")
        if [ -n "$PREFIX" ]; then
            compilation_error "" "label:$VALUE should not have prefix $PREFIX"
        elif [ "$CUR_INDEX" -eq -1 ]; then
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
    *)  
        ;;
    esac
}

function get_debug_address_for_lexeme() {
    local LEX="$1"
    local VALUE="${LEX:6}"
    local PREFIX="${LEX:0:1}"
    if [ "$PREFIX" = "_" ]; then
        PREFIX=""
    fi
    FUNC_RESULT="$PREFIX$VALUE"
}

rm -rf "${KERNEL_FILE}"
printf "%s\n" "${PARSED_LEXEMES[@]}" > "${KERNEL_FILE}.o"

LEXEME_INDEX=-1
CUR_INSTRUCTION_NO=$((KERNEL_START - 1))

function get_next_lexeme() {
    LEXEME_INDEX=$((LEXEME_INDEX + 1))
    LEXEME=${PARSED_LEXEMES[$LEXEME_INDEX]}
}

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
    CUR_ERROR=""
    CUR_CMD="${LEXEME:6}"
    RES_STR=""
    DEBUG_STR=""
    case "$CUR_CMD" in
    cpu_exec)
        RES_STR="$INSTR_CPU_EXEC"
        DEBUG_STR="cpu_exec" ;;
    DEBUG_ON|DEBUG_OFF)
        RES_STR="$CUR_CMD" ;;
    jump|jump_if)
        get_next_lexeme
        get_address_for_lexeme "${LEXEME}"
        CUR_ADDR_TO="$FUNC_RESULT"
        get_debug_address_for_lexeme "${LEXEME}"
        CUR_DEBUG_TO="$FUNC_RESULT"
        if [ "$CUR_CMD" = jump ]; then
            RES_STR="$INSTR_JUMP ${CUR_ADDR_TO}"
        else
            RES_STR="$INSTR_JUMP_IF ${CUR_ADDR_TO}"
        fi
        DEBUG_STR="$CUR_CMD ${CUR_DEBUG_TO}"
        ;;
    write|copy)
        get_next_lexeme
        if [ $CUR_CMD = write ]; then
            CUR_VALUE="${LEXEME:6}"
            if [ "${LEXEME:2:3}" = str ]; then
                CUR_VALUE="\"${CUR_VALUE}\"" 
            fi
            CUR_INDEX=$(find_index "$CUR_VALUE" "${CONSTANTS[@]}")
            CUR_ADDR_FROM="${CONSTANTS_ADDRESSES[$CUR_INDEX]}"
            CUR_DEBUG_FROM="${CONSTANTS[$CUR_INDEX]}"
        else
            get_address_for_lexeme "${LEXEME}"
            CUR_ADDR_FROM="$FUNC_RESULT"
            get_debug_address_for_lexeme "${LEXEME}"
            CUR_DEBUG_FROM="$FUNC_RESULT"
        fi

        get_next_lexeme
        if [ "${LEXEME}" != "_ key to" ]; then
            CUR_ERROR="Expected $CUR_CMD ... to."
        fi

        get_next_lexeme
        get_address_for_lexeme "${LEXEME}"
        CUR_ADDR_TO="$FUNC_RESULT"
        get_debug_address_for_lexeme "${LEXEME}"
        CUR_DEBUG_TO="$FUNC_RESULT"

        RES_STR="$INSTR_COPY_FROM_TO_ADDRESS ${CUR_ADDR_FROM} ${CUR_ADDR_TO}"
        DEBUG_STR="${CUR_DEBUG_FROM} => ${CUR_DEBUG_TO}"
        ;;
    *)
        CUR_ERROR="Unsupported command $CUR_CMD"
        RES_STR="COMPILATION_ERROR"
        ;;
    esac
    if [ -n "$CUR_ERROR" ]; then
        compilation_error "" "$CUR_ERROR"
        echo "COMPILATION ERROR" >> "$KERNEL_FILE"
    fi
    if [ -n "$RES_STR" ]; then
        if [ -n "$DEBUG_STR" ] && [ "$DEBUG_INFO" -eq 1 ]; then
            DEBUG_STR=" # $DEBUG_STR"
        else
            DEBUG_STR=""
        fi
        echo "$RES_STR$DEBUG_STR" >> "$KERNEL_FILE"
    fi
done

# Let's align all the # comments to the right:
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

# Append constants after instructions
for CUR_CONST in "${CONSTANTS_EVALUATED[@]}"; do
    echo "$CUR_CONST" >> "$KERNEL_FILE"
done

# Append empty line as a placeholder for variables
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