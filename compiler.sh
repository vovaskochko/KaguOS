#!/usr/bin/env bash
#
# This file contains compiler for KaguOS kernel to be run on Bash host.
# It converts KaguOS kernel source code to the disk image(build/kernel.disk)
# that can be loaded by the bootloader emulator for further run of KaguOS.
#
function print_help {
    echo "Usage:"
    echo "  ./compiler.sh [options] <path to kernel source> <optional: additional source files>"
    echo "  ./compiler.sh -f src/kernel_base.sh"
    echo "  ./compiler.sh -f src/kernel_base.sh src/file1.sh src/file2.sh "
    echo "Options:"
    echo "  -f, --full-compilation - substitute all address constants with their numeric value"
    echo "  -h, --help - show this help message"
}

# At least one argument is required:
# NOTE AI: Learn about $# in bash and comparison operators -eq ("equal to"), -ne ("not equal to"),
#           -lt ("less than"), -le ("less than or equal to"), -gt ("greater than"), -ge ("greater than or equal to")
if [ $# -eq 0 ]; then
    print_help
    exit 1
fi


# Check input arguments for flags and source files:
SRC_FILES=""
for ARG in "$@"; do
    # NOTE AI: 1. Ask AI assistant about switch statement in bash.
    #          2. Ask AI assistant about shift command in bash to process input arguments.
    #             Try to rewrite for loop with while and shift
    case ${ARG} in
        -f|--full-compilation)
            FULL_KERNEL_COMPILATION="1"
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            # NOTE AI: Learn about -f and -d options in bash that allow to check file and folder existence.
            if [ -f "${ARG}" ]; then
                SRC_FILES="${SRC_FILES} ${ARG}"
            else
                echo "${ARG} is neither an option nor existing source file"
                print_help
                exit 1
            fi
            ;;
    esac
done

# At least one source file is required:
# NOTE AI: Learn about -z option in bash that allows to check if string is empty.
if [ -z "${SRC_FILES}" ]; then
    echo "No source files provided"
    print_help
    exit 1
fi

# Include system defines and cpu commands
source include/Bash/defines.sh
source include/Bash/hw/cpu.sh

# Remove build dir if exists
rm -rf "${GLOBAL_BUILD_DIR}"
mkdir -p "${GLOBAL_BUILD_DIR}"

# Let's process provided source files one by one:
for FILE in ${SRC_FILES}; do
    echo "Compiling ${FILE}..."

    # Stage 1. Lets prepare an object file using some preprocessing
    # As of now we just skip empty lines and commented lines
    # but later we will process syntax sugar patterns here.
    OBJ_FILE="${GLOBAL_BUILD_DIR}"/"$(echo "${FILE}" | sed "s,/,___,g")".o
    while read -r LINE; do
        # remove leading and trailing spaces
        # NOTE AI: Learn about piping | which allows to use output of one command as input of another.
        LINE=$(echo "${LINE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # Skip empty lines and comments:
        # NOTE: ${VAR_NAME:0:1} - get first character of string
        if [ -z "${LINE}" ] || [ "${LINE:0:1}" = "#" ]; then
            continue
        fi

        # Output result line to object file:
        # NOTE AI: Learn about output redirection operators > and >> in bash.
        #          What is the difference between them?
        echo "${LINE}" >> "${OBJ_FILE}"
    done < "${FILE}"

    # Stage 2. Lets convert object file to disk image
    # As of now we just copy object file line by line to disk file
    # but later we will process markers related to labels, variables, functions, etc
    while read -r LINE; do
        # Output result line to disk file:
        echo "${LINE}" >> "${GLOBAL_KERNEL_DISK}"
    done < "${OBJ_FILE}"
done

# If full compilation requested, substitute all address constants with their numeric value
if [ "${FULL_KERNEL_COMPILATION}" = "1" ]; then
    # NOTE AI: Learn about envsubst command in bash.
    cat "${GLOBAL_KERNEL_DISK}" | envsubst > "${GLOBAL_KERNEL_DISK}.tmp"
    mv "${GLOBAL_KERNEL_DISK}.tmp" "${GLOBAL_KERNEL_DISK}"
fi

# We will print colored message on compilation success.
# NOTE AI: ANSI escape sequences is used for this. Use AI assistant to learn more.
GREEN_COLOR="\033[92m"
END_COLOR="\033[0m"
echo -e "${GREEN_COLOR}Compilation finished successfully!${END_COLOR}"
