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

# Let's process provided source files one by one:
foreach ($FILE in ${SRC_FILES}) {
    echo "Compiling ${FILE}..."

    # Stage 1. Lets prepare an object file using some preprocessing
    # As of now we just skip empty lines and commented lines
    # but later we will process syntax sugar patterns here.
    $OBJ_FILE = Join-Path `
        $GLOBAL_BUILD_DIR `
        ($FILE -replace "/", "___")
    New-Item -ItemType File -Path $OBJ_FILE > $null
    $LINES = Get-Content "${FILE}"

    ForEach ($LINE in Get-Content "${FILE}") {
        # remove leading and trailing spaces
        $LINE=${LINE}.Trim()

        # Skip empty lines and comments:
        if (( "${LINE}" -eq "") -or ($LINE.Substring(0,1) -eq "#" )) {
            continue
        }

        # Output result line to object file:
        # NOTE AI: Learn about pipe operator | in PowerShell.
        "${LINE}" | Out-File "${OBJ_FILE}" -Append
    }

    # Stage 2. Lets convert object file to disk image
    # As of now we just copy object file line by line to disk file
    # but later we will process markers related to labels, variables, functions, etc
    $LINES = Get-Content "${OBJ_FILE}"
    ForEach ($LINE in Get-Content "${OBJ_FILE}") {
        # Output result line to disk file:
        "${LINE}" | Out-File "${GLOBAL_KERNEL_DISK}" -Append
    }
}

# If full compilation requested, substitute all address constants with their numeric value
if  ("${FULL_KERNEL_COMPILATION}" -eq "1" ) {
    # Let's create a temp file to store expanded strings
    New-Item -ItemType File -Path "${GLOBAL_KERNEL_DISK}.tmp" > $null

    # Expand variables to their values and append the result to the temp file
    ForEach ($LINE in Get-Content "${GLOBAL_KERNEL_DISK}") {
        $ExecutionContext.InvokeCommand.ExpandString($LINE) | Out-File "${GLOBAL_KERNEL_DISK}.tmp" -Append
    }

    # Replace original file with fully compiled:
    Move-Item -Path "${GLOBAL_KERNEL_DISK}.tmp" -Destination "${GLOBAL_KERNEL_DISK}" -Force
}

# We will print colored message on compilation success.
write-host "Compilation finished successfully!" -ForegroundColor Green
