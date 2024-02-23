#!/usr/bin/env bash
# KaguOS bootloader

# Helper function to print fatal error and terminate the program
function exit_fatal {
    write-host "FATAL ERROR: $args[1]" -ForegroundColor Red
    exit 1
}


# Parse bootloader arguments to handle debug options if needed:
# Check input arguments for debug flags
$DEBUG_JUMP="0"
$DEBUG_SLEEP="0"

$args_fixed = @()
for ($i=0; $i -lt $args.count;$i++) {
    # Known issue with parsing of arguments with - and . https://github.com/PowerShell/PowerShell/issues/6291
    if ($args[$i] -eq '-s=0') {
        $args_fixed += $args[$i] + [string]$args[$i+1]
        $i = $i + 1
    }
    else {
        $args_fixed += $args[$i]
    }

}
for ($i=0; $i -lt $args_fixed.count; $i++) {
    $IN_ARG=$args_fixed[$i]

    if ( $IN_ARG -in "--debug-jump", "-j") {
        echo "Note: Debug jump enabled"
        $DEBUG_JUMP="1"
        continue
    }
    elseif ($IN_ARG -match "--debug-sleep=*|-s=*") {
        $DEBUG_SLEEP=$("${IN_ARG}" | %{$_.split('=')[1]}) 
        echo "Note: Debug sleep interval set to ${DEBUG_SLEEP}"
    }
    elseif ($IN_ARG -in "--help","-h") {
        echo "KaguOS bootloader for PowerShell"
        echo "Usage: w_bootloader.ps1 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --debug-jump, -j  Debug jump enabled"
        echo "  --debug-sleep=, -s= Debug sleep interval in seconds(e.g. use 0.5 for 500ms), default is 0 - no sleep between command execution"
        echo "  --help, -h        Print this help message"
        exit 0
    }
    else {
        exit_fatal "Unknown argument: ${IN_ARG}."
    }
}

#################################
# BOOTLOADER:                   #
#################################

# Lets include some human readable names for addresses to simplify reading and writing the code
. ./include/PowerShell/defines.ps1
if (Test-Path -Path "${GLOBAL_ENV_FILE}") {
    . "${GLOBAL_ENV_FILE}"
}

###########################
#######  INIT HW  #########
# We use text files to emulate HW and simplify debug
# so lets remove files from previous boot and create an empty one:
if (Test-Path -Path "${GLOBAL_HW_DIR}") {
    Remove-Item "${GLOBAL_HW_DIR}" -Force -Recurse > $null
}
New-Item -ItemType Directory -Path "${GLOBAL_HW_DIR}" -Force > $null


# Init RAM with zero:
# NOTE: Real computer has a memory with some size which is reset to some default values on power off.
$HW_RAM_MEMORY=@()
for ($i=1;$i -le ${GLOBAL_RAM_SIZE};$i++) {
    $HW_RAM_MEMORY += [string]"0"
}

# Init basic functionality of CPU, RAM, display and keyboard.
# NOTE: real computer does it with giving a power to some modules
#       therefore some initial values and states are ready for further usage.
# NOTE AI: Ask AI assistant about command . in PowerShell that is used to include code from other files.
. ./include/PowerShell/hw/cpu.ps1
. ./include/PowerShell/hw/ram.ps1
. ./include/PowerShell/hw/input_output.ps1
####### INIT HW END #######
###########################



###########################
####### LOAD KERNEL #######
# Write debug line to mark kernel start address
write_to_address "${GLOBAL_KERNEL_START_INFO_ADDRESS}" "############ KERNEL START ###########"

# Load data from disk to RAM:
# NOTE: Real computer loads kernel from disk or disk partition
#       so some basic disk driver should be present in bootloader.
# NOTE AI: Ask AI assistant about file reading in loop as below.
$CUR_ADDRESS=[int]"${GLOBAL_KERNEL_START}"
ForEach ($LINE in Get-Content "${GLOBAL_KERNEL_DISK}") {
    write_to_address ${CUR_ADDRESS} "${LINE}"
    $CUR_ADDRESS=[int]$CUR_ADDRESS + 1
}

# Write debug line to mark kernel end address
write_to_address ${CUR_ADDRESS} "############ KERNEL END #############"
####### LOAD KERNEL END ###
###########################


###########################
####### JUMP TO KERNEL ####

# Jump to the address in RAM
# where the kernel was loaded:
. ./include/PowerShell/jump.ps1
. ./include/PowerShell/stack.ps1
. ./include/PowerShell/function.ps1

jump_to ${GLOBAL_KERNEL_START}

# Run kernel main loop.
# NOTE: Real CPU has a control unit to handle switch between instructions
#      while our emulation uses infinite loop and expand function of PowerShell to achieve the same behavior.
# NOTE AI: Ask AI assistant about ExpandString and Invoke-Expression commands and potential security issues of its usage for scripts.
for (;;) {
    # Increment counter of the command to be executed:
    jump_increment_counter

    # If debug flag was set then print the command that will be called
    if ( "${DEBUG_JUMP}" -eq "1") {
        jump_print_debug_info
    }

    # Check whether next command points to termination
    $NEXT_CMD=$(read_from_address ${GLOBAL_NEXT_CMD_ADDRESS})
    if ("${NEXT_CMD}" -eq "${GLOBAL_TERMINATE_ADDRESS}") {
        write_to_address ${GLOBAL_DISPLAY_ADDRESS} "Kernel stopped"
        display_success
        break
    }

    # Read content at the memory to which points number stored under GLOBAL_NEXT_CMD_ADDRESS
    $CMD_TO_EXEC=$(read_from_address ${NEXT_CMD})
    $ExecutionContext.InvokeCommand.ExpandString($CMD_TO_EXEC) | Invoke-Expression

    # dump current content of RAM into text file for debug purposes:
    dump_RAM_to_file
    sleep ${DEBUG_SLEEP}
}

###########################
