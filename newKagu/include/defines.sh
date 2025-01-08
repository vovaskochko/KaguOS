# This file contains a list of constants for KaguOS.
# It includes memory addresses that are used by the kernel and the instruction set of out CPU.

#################################################################
# We will store hw emulation files under tmp dir
export GLOBAL_HW_DIR="tmp"

# RAM constants:
export GLOBAL_RAM_FILE="${GLOBAL_HW_DIR}/RAM.txt"
export GLOBAL_RAM_SIZE="100"

# Kernel constants:
export GLOBAL_BUILD_DIR="build"
export GLOBAL_KERNEL_DISK="${GLOBAL_BUILD_DIR}/kernel.disk"
export KERNEL_START_INFO=35
export KERNEL_START=36

export REG_OP_INFO=1
export REG_OP=2

export REG_A_INFO=3
export REG_A=4
export REG_B_INFO=5
export REG_B=6
export REG_C_INFO=7
export REG_C=8
export REG_D_INFO=9
export REG_D=10

export REG_RES_INFO=11
export REG_RES=12
export REG_BOOL_RES_INFO=13
export REG_BOOL_RES=14

export REG_ERROR_INFO=15
export REG_ERROR=16

export DISPLAY_BUFFER_INFO=17
export DISPLAY_BUFFER=18
export DISPLAY_COLOR_INFO=19
export DISPLAY_COLOR=20
export KEYBOARD_BUFFER_INFO=21
export KEYBOARD_BUFFER=22
export PROGRAM_COUNTER_INFO=23
export PROGRAM_COUNTER=24
export REG_STACK_PTR_INFO=25
export REG_STACK_PTR=26
export REG_STACK_PREV_PTR_INFO=27
export REG_STACK_PREV_PTR=28


# REG_A + REG_B => REG_RES
export OP_ADD=0

# REG_A - REG_B => REG_RES
export OP_SUB=1

# REG_A++ => REG_RES
export OP_INCR=2

# REG_A-- => REG_RES
export OP_DECR=3

# is REG_A a number? => REG_BOOL_RES
export OP_IS_NUM=4

# REG_A == REG_B => REG_BOOL_RES
export OP_CMP_EQ=5

# REG_A != REG_B => REG_BOOL_RES
export OP_CMP_NEQ=6

# REG_A < REG_B => REG_BOOL_RES
export OP_CMP_LT=7

# REG_A <= REG_B => REG_BOOL_RES
export OP_CMP_LE=8

# Does REG_A contain REG_B? => REG_BOOL_RES
export OP_CONTAINS=9

# REG_A - string, REG_B - column number, REG_C - delimiter => REG_RES - column
export OP_GET_COLUMN=10

# read result => KEYBOARD_BUFFER
export OP_READ_INPUT=11

# DISPLAY_BUFFER will be printed with DISPLAY_COLOR without endline
export OP_DISPLAY=12

# DISPLAY_BUFFER will be printed with DISPLAY_COLOR with endline
export OP_DISPLAY_LN=13

# REG_A - disk name, REG_B - block number => REG_RES
export OP_READ_BLOCK=14

# REG_A - disk name, REG_B - block number, REG_C - string to write => REG_BOOL_RES - contains result, REG_ERROR - error if needed
export OP_WRITE_BLOCK=15

#####
# OP codes from 16 to 28 are reserved for future use
#####

# OP_NOP - do nothing
export OP_NOP=29

# OP_HALT is used to stop the system
export OP_HALT=30

# OP_UNKNOWN can be used for safe programming by resetting to it after any cpu_exec to ensure that REG_OP was set explicitely
export OP_UNKNOWN=31

# Color support constants for display functions
export COLOR_NO=0
export COLOR_GREEN=1
export COLOR_YELLOW=2
export COLOR_RED=3
