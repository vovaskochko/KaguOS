#!/usr/bin/env bash
#
# This file contains compiler for KaguOS kernel.
# It converts KaguOS kernel source code to the disk image(build/kernel.disk)
# that can be loaded by the bootloader emulator for further run of KaguOS.
#
# Usage
#   ./compiler.sh [options] src/kernel_base.sh <src/some_other_source.sh>
# Options:
#   -f, --full-compilation - substitute all address constants with their numeric value
#   -h, --help - show this help message
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
source include/defines.sh
source include/hw/cpu.sh

# Remove build dir if exists
rm -rf "${GLOBAL_BUILD_DIR}"
mkdir -p "${GLOBAL_BUILD_DIR}"

# Let's process provided source files one by one:
for FILE in ${SRC_FILES}; do
    echo "Compiling ${FILE}..."

    # Stage 1. Lets prepare an object file using some preprocessing
    # We will process syntax sugar patterns in this loop.
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

        # Lets add a possibility to use the following patterns in source code:
        #       1. println("Some string") as a short form of
        #               write_to_address ${GLOBAL_DISPLAY_ADDRESS} "Some string"
        #               display_println
        #       2. println(*SOME_ADDRESS) as a short form of
        #               copy_from_to_address ${SOME_ADDRESS} ${GLOBAL_DISPLAY_ADDRESS}
        #               display_println
        # NOTE AI: What is "syntax sugar"? Why do we need it? How it impacts source code quality?
        # TODO:
        #       1. Implement parsing of print(*SOME_ADDRESS) and print("Some string")
        #       2. Implement parsing of println(*SOME_ADDRESS, SUCCESS), println(*SOME_ADDRESS, WARNING), println(*SOME_ADDRESS, ERROR)
        #       3. Implement parsing of println("Some string", SUCCESS), println("Some string", WARNING), println("Some string", ERROR)
        # TODO_END
        if [ "${LINE:0:8}" = "println(" ]; then
            SUBLINE=$(echo "${LINE#println(}")
            if [ "${SUBLINE:0:1}" = '"' ]; then
                echo "write_to_address \${GLOBAL_DISPLAY_ADDRESS} \"${SUBLINE:1:-2}\"" >> "${OBJ_FILE}"
            elif [ "${SUBLINE:0:1}" = '*' ]; then
                echo "copy_from_to_address \${${SUBLINE:1:-1}} \${GLOBAL_DISPLAY_ADDRESS}" >> "${OBJ_FILE}"
            else
                echo "Compilation failed at  ${FILE}:${LINE_NO} ${LINE}"
                exit 1
            fi
            echo "display_println" >>  "${OBJ_FILE}"
            continue
        fi

        if [ "${LINE:0:1}" = "*" ]; then
            # search for *ADDR_VAR1=... pattern
            LEFT_SIDE=$(echo "${LINE}" | awk -F'=' ' {print $1}')
            RIGHT_SIDE=$(echo "${LINE#${LEFT_SIDE}=}")
            # search for *ADDR_VAR1=*ADDR_VAR2 pattern
            if [ "${RIGHT_SIDE:0:1}" = '*' ]; then
                # NOTE AI: Learn about symbol escaping in bash.
                #          Here we escape $ while for TODO task below you may need to escape " as well
                echo "copy_from_to_address \${${RIGHT_SIDE:1}} \${${LEFT_SIDE:1}}" >> "${OBJ_FILE}"
                continue
            fi
            # search for *ADDR_VAR1="..." pattern
            if [ "${RIGHT_SIDE:0:1}" = '"' ] && [ "${RIGHT_SIDE: -1}" = '"' ]; then
                echo "write_to_address \${${LEFT_SIDE:1}} \"${RIGHT_SIDE:1:-1}\"" >> "${OBJ_FILE}"
                continue
            fi
            # TODO
            #     1. Add support of short version for increment *ADDR_VAR++ should be converted to :
            #           cpu_execute "${CPU_INCREMENT_CMD}" ${ADDR_VAR_NAME}
            #           copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} ${ADDR_VAR_NAME}
            #     2. Add support of short version for decrement *ADDR_VAR--.
        fi

        # Output result line to object file:
        # NOTE AI: Learn about output redirection operators > and >> in bash.
        #          What is the difference between them?
        echo "${LINE}" >> "${OBJ_FILE}"
    done < "${FILE}"

    # Stage 2. Lets convert object file to disk image
    # We are processing address related markers like labels, variables, functions, etc
    CUR_ADDRESS=${GLOBAL_KERNEL_START}
    while read -r LINE; do
        # Check for label definition and store its name to a list of unassigned labels:
        # NOTE: we are interested in the address of the first instruction that will be stored to the CUR_ADDRESS
        #       so we will get it automatically from CURRENT_ADDRESS with will be used when the next instruction will be find.
        if [ "${LINE:0:6}" = "LABEL:" ]; then
            LABEL=$(echo "${LINE#LABEL:}")
            echo "export LABEL_${LABEL}=${CUR_ADDRESS}" >> "${GLOBAL_ENV_FILE}"
            continue
        fi

        # Output result line to disk file:
        echo "${LINE}" >> "${GLOBAL_KERNEL_DISK}"

        CUR_ADDRESS=$((CUR_ADDRESS + 1))
    done < "${OBJ_FILE}"
done

# If full compilation requested, substitute all address constants with their numeric value
if [ "${FULL_KERNEL_COMPILATION}" = "1" ]; then
    # Source environment file from the first stage of compilation to substitute all variables correctly
    source "${GLOBAL_ENV_FILE}"

    # Replace all addresses constants with their numeric value
    # NOTE AI: Learn about envsubst command in bash.
    cat "${GLOBAL_KERNEL_DISK}" | envsubst > "${GLOBAL_KERNEL_DISK}.tmp"
    mv "${GLOBAL_KERNEL_DISK}.tmp" "${GLOBAL_KERNEL_DISK}"
fi

# We will print colored message on compilation success.
# NOTE AI: ANSI escape sequences is used for this. Use AI assistant to learn more.
GREEN_COLOR="\033[92m"
END_COLOR="\033[0m"
echo -e "${GREEN_COLOR}Compilation finished successfully!${END_COLOR}"
