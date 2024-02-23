# This file contains compiler for KaguOS kernel to be run on PowerShell host.
# It converts KaguOS kernel source code to the disk image(build/kernel.disk)
# that can be loaded by the bootloader emulator for further run of KaguOS.

function print_help {
    echo "Usage:"
    echo "  ./w_compiler.ps1 [options] <path to kernel source> <optional: additional source files>"
    echo "  ./w_compiler.ps1 -f src/kernel_base.sh"
    echo "  ./w_compiler.ps1 -f src/kernel_base.sh src/file1.sh src/file2.sh "
    echo "Options:"
    echo "  -f, --full-compilation - substitute all address constants with their numeric value"
    echo "  -h, --help - show this help message"
}

# At least one argument is required:
# NOTE AI: Learn about PowerShell comparison operators -eq ("equal to"), -ne ("not equal to"),
#           -lt ("less than"), -le ("less than or equal to"), -gt ("greater than"), -ge ("greater than or equal to")
if ($args.count -eq 0) {
    print_help
    exit 1
}

$VerbosePreference = "SilentlyContinue"

# Check input arguments for flags and source files:
$SRC_FILES = @()
foreach ($ARG in $args) {
    if ((${ARG} -eq "-f") -or (${ARG} -eq "--full-compilation")) {
        $FULL_KERNEL_COMPILATION = "1"
    }
    elseif ((${ARG} -eq "-h") -or (${ARG} -eq "--help")) {
        print_help
        exit 0
    }
    else {
        if (Test-Path -Path "${ARG}") {
            $SRC_FILES += "${ARG}"
        }
        else {
            echo "${ARG} is neither an option nor existing source file"
            print_help
            exit 1
        }
    }
}

# At least one source file is required:
if ( $SRC_FILES.empty ) {
    echo "No source files provided"
    print_help
    exit 1
}


# Include system defines and cpu commands
. ./include/PowerShell/defines.ps1
. ./include/PowerShell/hw/cpu.ps1

# Remove build dir if exists
if (Test-Path -Path "${GLOBAL_BUILD_DIR}") {
    Remove-Item "${GLOBAL_BUILD_DIR}" -Force -Recurse > $null
}

New-Item -ItemType Directory -Path "${GLOBAL_BUILD_DIR}" -Force > $null
New-Item -ItemType File -Path "${GLOBAL_KERNEL_DISK}" > $null
New-Item -ItemType File -Path "${GLOBAL_ENV_FILE}" > $null

# Let's process provided source files one by one:
foreach ($FILE in ${SRC_FILES}) {
    echo "Compiling ${FILE}..."

    # Stage 1. Lets prepare an object file using some preprocessing
    # We will process syntax sugar patterns in this loop.
    $OBJ_FILE = Join-Path `
        $GLOBAL_BUILD_DIR `
        ($FILE -replace "/", "___")
    New-Item -ItemType File -Path $OBJ_FILE > $null

    $LINE_NO=0
    ForEach ($LINE in Get-Content "${FILE}") {
        # remove leading and trailing spaces
        $LINE=${LINE}.Trim()
        $LINE_NO++

        # Skip empty lines and comments:
        if (( "${LINE}" -eq "") -or ($LINE.Substring(0,1) -eq "#" )) {
            continue
        }

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
        if ($LINE.Substring(0, 8) -eq "println(" ) {
            $SUBLINE=$LINE.Substring(8)
            if ($SUBLINE.Substring(0, 1) -eq '"' ) {
                $STR_VALUE=$SUBLINE.Substring(1, $SUBLINE.Length - 3)
                "write_to_address `${GLOBAL_DISPLAY_ADDRESS} `"${STR_VALUE}`"" | Out-File "${OBJ_FILE}" -Append
            }
            elseif ($SUBLINE.Substring(0, 1) -eq "*") {
                $SRC_ADDRESS=$SUBLINE.Substring(1, $SUBLINE.Length - 2)
                "copy_from_to_address `${$SRC_ADDRESS} `${GLOBAL_DISPLAY_ADDRESS}" | Out-File "${OBJ_FILE}" -Append
            }
            else {
                write-host "Compilation failed at  ${FILE}:${LINE_NO} ${LINE}" -ForegroundColor Red
                exit 1
            }
            "display_println" | Out-File "${OBJ_FILE}" -Append
            continue
        }

        # Output result line to object file:
        # NOTE AI: Learn about pipe operator | in PowerShell.
        "${LINE}" | Out-File "${OBJ_FILE}" -Append
    }

    # Stage 2. Lets convert object file to disk image
    # We are processing address related markers like labels, variables, functions, etc
    $CUR_ADDRESS=${GLOBAL_KERNEL_START}
    ForEach ($LINE in Get-Content "${OBJ_FILE}") {
        # Check for label definition and store its name to a list of unassigned labels:
        # NOTE: we are interested in the address of the first instruction that will be stored to the CUR_ADDRESS
        #       so we will get it automatically from CURRENT_ADDRESS with will be used when the next instruction will be find.
        if ($LINE.Substring(0, 6) -eq "LABEL:") {
            $LABEL=$LINE.Substring(6)
            "`$LABEL_${LABEL}=${CUR_ADDRESS}" | Out-File "${GLOBAL_ENV_FILE}" -Append
            continue
        }

        # Output result line to disk file:
        "${LINE}" | Out-File "${GLOBAL_KERNEL_DISK}" -Append

        $CUR_ADDRESS=[int]$CUR_ADDRESS + 1
    }
}

# If full compilation requested, substitute all address constants with their numeric value
if  ("${FULL_KERNEL_COMPILATION}" -eq "1" ) {
    # Let's create a temp file to store expanded strings
    New-Item -ItemType File -Path "${GLOBAL_KERNEL_DISK}.tmp" > $null

    # Source environment file from the first stage of compilation to substitute all variables correctly
    . "${GLOBAL_ENV_FILE}"

    # Expand variables to their values and append the result to the temp file
    ForEach ($LINE in Get-Content "${GLOBAL_KERNEL_DISK}") {
        $ExecutionContext.InvokeCommand.ExpandString($LINE) | Out-File "${GLOBAL_KERNEL_DISK}.tmp" -Append
    }

    # Replace original file with fully compiled:
    Move-Item -Path "${GLOBAL_KERNEL_DISK}.tmp" -Destination "${GLOBAL_KERNEL_DISK}" -Force
}

# We will print colored message on compilation success.
write-host "Compilation finished successfully!" -ForegroundColor Green
