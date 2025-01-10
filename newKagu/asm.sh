#!/usr/bin/env bash
# this script allows to convert .kgasm files to the machine code

LABELS=()
LABELS_COUNT=0

CONSTANTS=()
CONSTANTS_ADDRESSES=()
CONSTANTS_COUNT=0

VARIABLES=()
VARIABLES_ADDRESSES=()
VARIABLES_COUNT=0

COMPILATION_ERROR_COUNT=0

CUR_FILE=
CUR_LINE_NO=
LINE=

function compilation_error() {
    local EXPECTED_SYNTAX="$1"
    echo -e "\033[93mCompilation error\033[0m at ${CUR_FILE}:${CUR_LINE_NO}"
    echo -e "\033[91m$LINE\033[0m"
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

function handle_cpu_exec() {
    local LEX2=$(echo "$LINE" | awk '{print $2}')
    if [ $(empty_or_comment "$LEX2") = false ]; then
        compilation_error "cpu_exec"
        return 1
    fi

    RES_LINE="$INSTR_CPU_EXEC # cpu_exec"
}

# Expected format:
# var some1_name // comment if needed
function handle_variable() {
    local LEX1=$(echo "$LINE" | awk '{print $1}')
    local LEX2=$(echo "$LINE" | awk '{print $2}')
    local LEX3=$(echo "$LINE" | awk '{print $3}')
    if [ $(empty_or_comment "$LEX3") = false ]; then
        compilation_error "var SOME_NAME"
        return 1
    fi

    if [[ ! "$LEX2" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        compilation_error "variable should start with letter and contain only letters, digits and _"
        return 1
    fi

    GREP_KEY=$(printf "%s\n" "${VARIABLES[@]}" | grep "^$LEX2")
    if [ -n "${GREP_KEY}" ]; then
        compilation_error "Each variable should be defined only once"
        return 1
    fi

    VARIABLES[$VARIABLES_COUNT]="$LEX2"
    VARIABLES_COUNT=$((VARIABLES_COUNT + 1))
}

function handle_label() {
    local LEX1=$(echo "$LINE" | awk '{print $1}')
    local LEX2=$(echo "$LINE" | awk '{print $2}')

    if [ $(empty_or_comment "$LEX2") = false ]; then
        compilation_error "label:some_value"
        return 1
    fi

    CUR_KEY="${LEX1#label:}"
    if [[ ! "$CUR_KEY" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        compilation_error "label should start with letter and contain only letters, digits and _"
        return 1
    fi

    GREP_KEY=$(printf "%s\n" "${LABELS[@]}" | grep "^$CUR_KEY ")
    if [ -n "${GREP_KEY}" ]; then
        compilation_error "Each label should be defined only once"
        return 1
    fi

    LABELS[$LABELS_COUNT]="$CUR_KEY $NEXT_INSTR_ADDRESS"
    LABELS_COUNT=$((LABELS_COUNT + 1))
}

function handle_copy() {
    eval set -- "$LINE"
    local LEX1="$1"
    local LEX2="$2"
    local LEX3="$3"
    local LEX4="$4"
    local LEX5="$5"
    if [ "$LEX3" != to ] || [ -z "$LEX4" ] || [ $(empty_or_comment "$LEX5") = false ]; then
        compilation_error "copy SOME_ADDRESS to OTHER_ADDRESS"
        return 1
    fi

    RES_LINE="$INSTR_COPY_FROM_TO_ADDRESS \$${LEX2} \$${LEX4} # ${LEX2} => ${LEX4}"
}

function handle_write() {
    eval set -- "$LINE"
    local LEX1="$1"
    local LEX2="$2"
    local LEX3="$3"
    local LEX4="$4"
    local LEX5="$5"

    if [ "$LEX3" != to ] || [ -z "$LEX4" ] || [ $(empty_or_comment "$LEX5") = false ]; then
        compilation_error "write SOME to ADDRESS"
        return 1
    fi

    HELP_STR=$(echo ${LINE#"$LEX1"} | sed -e 's/^[[:space:]]'$LEX1'*//' -e 's/[[:space:]]*$//')
    if [ "${HELP_STR:0:1}" = '"' ]; then
        CURRENT_CONSTANT="\"$LEX2\""
    else
        CURRENT_CONSTANT="\$$LEX2"
    fi

    # Lets perform some optimisation: if constant was already added, we can reuse it: 
    CUR_INDEX=$CONSTANTS_COUNT
    for i in "${!CONSTANTS[@]}"; do
        if [ "${CONSTANTS[$i]}" = "${CURRENT_CONSTANT}" ]; then
            CUR_INDEX="$i"
            break
        fi
    done

    # if constant is not present in array, we will need to copy it to the memory
    if [ $CUR_INDEX -eq $CONSTANTS_COUNT ]; then
        CONSTANTS[$CONSTANTS_COUNT]="$CURRENT_CONSTANT"
        CONSTANTS_COUNT=$((CONSTANTS_COUNT + 1))
    fi

    RES_LINE="$INSTR_COPY_FROM_TO_ADDRESS constant:$CUR_INDEX \$${LEX4} # $CURRENT_CONSTANT => ${LEX4}"
}

function handle_jumps() {
    local LEX1=$(echo "$LINE" | awk '{print $1}')
    local LEX2=$(echo "$LINE" | awk '{print $2}')
    local LEX3=$(echo "$LINE" | awk '{print $3}')
    if [ -z "$LEX2" ] || [[ ! "$LEX2" =~ ^([0-9]+|label:.*)$ ]] || [ $(empty_or_comment "$LEX3") = false ]; then
        compilation_error "jump 50\njump label:some\njump_if 100\njump_if label:some"
        return 1
    fi

    if [ $LEX1 = jump_if ]; then
        RES_LINE="$INSTR_JUMP_IF ${LEX2} # jump_if ${LEX2}"
    else
        RES_LINE="$INSTR_JUMP ${LEX2} # jump $LEX2"
    fi
} 

source include/operations.sh
source include/other.sh
source include/registers.sh
source include/system.sh

# TODO More careful checks of errors - no files, permissions and so on
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

for CUR_FILE in ${SRC_FILES}; do
    CUR_LINE_NO=0

    OBJ_FILE="${GLOBAL_BUILD_DIR}"/"$(echo "$CUR_FILE" | sed "s,/,___,g")".o
    rm -rf "${OBJ_FILE}"
    touch "${OBJ_FILE}"
    OBJ_FILES="${OBJ_FILES} ${OBJ_FILE}"

    while read -r LINE; do
        CUR_LINE_NO=$((CUR_LINE_NO + 1))
        # remove leading and trailing spaces
        LINE=$(echo "${LINE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        # Skip empty lines and comments:
        if [ $(empty_or_comment "$LINE") = true ]; then
            continue
        fi

        # let's get the first lexical component of the LINE and analyze whether it matches one of the expected commands
        LEX1=$(echo "$LINE" | awk '{print $1}')

        RES_LINE=
        case "$LEX1" in
            cpu_exec)
                handle_cpu_exec
                ;;
            "var")
                handle_variable
                continue
                ;;
            "label:"*)
                handle_label
                continue
                ;;
            copy)
                handle_copy
                ;;
            write)
                handle_write
                ;;
            jump|jump_if)
                handle_jumps
                ;;
            *)
                compilation_error "write copy label cpu_exec jump jump_if"
                ;;
        esac

        echo "${RES_LINE}" >> "${OBJ_FILE}"
        NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
    done < "$CUR_FILE"
done
echo "======TEXT SEGMENT END======" >> "${OBJ_FILE}"
NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))

# Let's generate object file from constants. Later it will be appended to the end of the kernel.
CONSTANTS_OBJ_FILE="${KERNEL_FILE}".constants.o
CUR_COUNTER=0
echo "======DATA SEGMENT CONSTANTS START======" > "${CONSTANTS_OBJ_FILE}"
NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
for CONSTANT in "${CONSTANTS[@]}"; do
    if [ ${CONSTANT:0:1} = '"' ]; then
        echo "${CONSTANT:1:-1}" >> "${CONSTANTS_OBJ_FILE}"
    else
        eval echo "${CONSTANT}" >> "${CONSTANTS_OBJ_FILE}"
    fi
    CONSTANT_ADDRESSES[CUR_COUNTER]="${NEXT_INSTR_ADDRESS}"
    CUR_COUNTER=$((CUR_COUNTER + 1))
    NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
done
echo "======DATA SEGMENT CONSTANTS END======" >> "${CONSTANTS_OBJ_FILE}"

# Let's generate object file from global variables. Later it will be appended to the end of the kernel.
VARIABLES_OBJ_FILE="${KERNEL_FILE}".variables.o
CUR_COUNTER=0
echo "======DATA SEGMENT GLOBAL VARIABLES START======" > "${VARIABLES_OBJ_FILE}"
NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
for VAR in "${VARIABLES[@]}"; do
    echo "$VAR" >> "${VARIABLES_OBJ_FILE}"
    VARIABLES_ADDRESSES[CUR_COUNTER]="${NEXT_INSTR_ADDRESS}"
    CUR_COUNTER=$((CUR_COUNTER + 1))
    NEXT_INSTR_ADDRESS=$((NEXT_INSTR_ADDRESS + 1))
done
echo "======DATA SEGMENT GLOBAL VARIABLES END======" >> "${VARIABLES_OBJ_FILE}"

# Let's concat generated object files and write them to the kernel file: 
rm -rf "${KERNEL_FILE}"
for OBJ_FILE in ${OBJ_FILES}; do
    while read -r LINE; do
        RES_LINE="$LINE"

        # We should replace all the labels in jump/jump_if commands with corresponding addresses
        if [[ "$LINE" == "$INSTR_JUMP "* ]] || [[ "$LINE" == "$INSTR_JUMP_IF "* ]]; then
            LEX2=$(echo "$LINE" | awk '{print $2}')
            if [[ "$LEX2" == "label:"* ]]; then
                CUR_KEY="${LEX2#label:}"
                ADDRESS=$(printf "%s\n" "${LABELS[@]}" | grep "^$CUR_KEY " | awk '{print $2}')
                if [ -z "$ADDRESS" ]; then
                    compilation_error "" "" "$LINE" "Label $CUR_KEY should be defined"
                else
                    RES_LINE=$(echo "$LINE" | sed 's,label:'$CUR_KEY','$ADDRESS',1')
                fi
            fi
        fi

        # We should replace all the constant:N inside copy instructions with corresponding addresses;
        # otherwise variables like $REG_OP should be evaluated to get addresses as well.
        if [[ "$LINE" == "$INSTR_COPY_FROM_TO_ADDRESS"* ]]; then
            LEX2=$(echo "$LINE" | awk '{print $2}')
            LEX3=$(echo "$LINE" | awk '{print $3}')
            if [[ "$LEX2" == "constant:"* ]]; then
                CUR_INDEX=${LEX2#constant:}
                RES_LINE=$(echo "$LINE" | sed 's,constant:'$CUR_INDEX','${CONSTANT_ADDRESSES[$CUR_INDEX]}',1'| sed 's,'$LEX3','$(eval echo $LEX3)',1')
            else
                RES_LINE=$(echo "$LINE" | sed 's,'$LEX2','$(eval echo $LEX2)',1' | sed 's,'$LEX3','$(eval echo $LEX3)',1')
            fi
        fi
        echo "${RES_LINE}" >> "${KERNEL_FILE}"
    done < "${OBJ_FILE}"
done

# Let's align all the # comments to the right:
awk '{
    # Find the position of the last number before #
    pos = index($0, "#")
    if (pos == 0) {
        # No # found, print line as is
        print
    } else {
        # Calculate spaces needed to align # to column 20
        spaces = 15 - (pos - 1)
        # Print the line up to # with calculated padding
        printf "%s%*s%s\n", substr($0, 1, pos - 1), spaces, "", substr($0, pos)
    }
}' "${KERNEL_FILE}" > "${KERNEL_FILE}".tmp && mv "${KERNEL_FILE}".tmp "${KERNEL_FILE}"

# Let's append constants and global variables reserved memory to the end of the kernel file
cat "${CONSTANTS_OBJ_FILE}" >> "${KERNEL_FILE}"
cat "${VARIABLES_OBJ_FILE}" >> "${KERNEL_FILE}"

# That's it - compilation finished. Let's report status to the user:
if [ $COMPILATION_ERROR_COUNT -ne 0 ]; then
    echo -e "\033[91mCompilation failed: $COMPILATION_ERROR_COUNT error(s).\033[0m"
    exit 1
else
    echo -e "\033[92mCompilation succeeded\033[0m"
fi
