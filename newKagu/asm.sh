# this script allows to convert .kgasm files to the machine code

source include/defines.sh
source include/hw.sh

SRC_FILE="$1"

if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

declare -a labels

mkdir -p "$GLOBAL_BUILD_DIR"
OBJ_FILE="${GLOBAL_BUILD_DIR}"/"$(echo "${SRC_FILE}" | sed "s,/,___,g")".o
rm -rf "${OBJ_FILE}"
touch "${OBJ_FILE}"

NEXT_INTRUCTION_ADDRESS=0
while read -r LINE; do
    # remove leading and trailing spaces
    LINE=$(echo "${LINE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Skip empty lines and comments:
    # NOTE: ${VAR_NAME:0:1} - get first character of string
    if [ -z "${LINE}" ] || [ "${LINE:0:2}" = "//" ]; then
        continue
    fi

    if [[ "$LINE" = *"label:" ]]; then
        labels["$LINE"]=$((KERNEL_START + NEXT_INTRUCTION_ADDRESS))
        continue
    fi

    # split LINE to lexer components with awk
    LEX1=$(echo "${LINE}" | awk '{print $1}')
    LEX2=$(echo "${LINE}" | awk '{print $2}')
    LEX3=$(echo "${LINE}" | awk '{print $3}')
    LEX4=$(echo "${LINE}" | awk '{print $4}')

    if [ "$LEX1" = write ] && [ "$LEX3" = to ]; then
        if [ ${LEX2:0:1} = '"' ]; then
            RES_LINE="write_to_address \$${LEX4} $LEX2"
        else
            RES_LINE="write_to_address \$${LEX4} \"\$$LEX2\""
        fi
    else
        RES_LINE="$LINE"
    fi

    # Output result line to object file:
    # NOTE AI: Learn about output redirection operators > and >> in bash.
    #          What is the difference between them?

    echo "${RES_LINE}" >> "${OBJ_FILE}"
    NEXT_INTRUCTION_ADDRESS=$((NEXT_INTRUCTION_ADDRESS + 1))
done < "${SRC_FILE}"