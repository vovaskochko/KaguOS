#############################################
#############################################
# Instruction set constants:
#############################################

# To execute a CPU operation, set the operation code in REG_OP and call INSTR_CPU_EXEC.
# The CPU will use REG_A, REG_B, REG_C and REG_D values(depending on the operation).
# The result will be stored in either REG_RES or REG_BOOL_RES.
# Also REG_ERROR can be used to store information about errors.
export INSTR_CPU_EXEC=0

# To copy data from a source address to a destination address.
# Example: 1 100 200 will copy the content of RAM address 100 to address 200.
export INSTR_COPY_FROM_TO_ADDRESS=1

# To read data from a specific memory address, set the address in REG_A.
# Call INSTR_READ_FROM_ADDRESS and the data will be stored in REG_RES.
export INSTR_READ_FROM_ADDRESS=2

# To jump unconditionally to a specific address specify target address a an argument of the instruction.
# Call INSTR_JUMP to transfer control to the target address.
# Example: jump 100 will jump to address 100 and will use 100 as a PROGRAM_COUNTER so all further instruction will be executed started from address 100
export INSTR_JUMP=3

# To jump conditionally, perform conditional check operation(OP_IS_NUM, OP_CMP_EQ and so on) with cpu_exec first.
# Call INSTR_JUMP_IF to transfer control only if the condition is true e.g. REG_BOOL_RES is 1.
# Example: jump_if 100 will jump to address 100 if REG_BOOL_RES is equal to 1 otherwise jump_if instruction will be ignored and the next instruction will be executed.
export INSTR_JUMP_IF=4

# To jump conditionally, perform conditional check operation(OP_IS_NUM, OP_CMP_EQ and so on) with cpu_exec first.
# Call INSTR_JUMP_IF_NOT to transfer control only if the condition is false e.g. REG_BOOL_RES is 0.
# Example: jump_if_not 100 will jump to address 100 if REG_BOOL_RES is equal to 0 otherwise jump_if instruction will be ignored and the next instruction will be executed.
export INSTR_JUMP_IF_NOT=5

# To jump conditionally in case of error happened during the most recent call of INSTR_CPU_EXEC.
# Call INSTR_JUMP_ERR to transfer control only if the error was happened e.g. REG_ERROR is not empty.
# Example: jump_err 100 will jump to address 100 if REG_ERROR is not empty or otherwise jump_err instruction will be ignored and the next instruction will be executed.
export INSTR_JUMP_ERR=6

#############################################
#############################################
# Operations from CPU instruction set.
# For each operation, set the required operands in REG_A, REG_B, REG_C, or REG_D, set REG_OP, and call INSTR_CPU_EXEC.
#############################################

# To perform addition, place the first operand in REG_A and the second operand in REG_B.
# Set REG_OP to OP_ADD and call INSTR_CPU_EXEC.
# After execution, the sum of the values will be present in REG_RES.
export OP_ADD=0

# To perform subtraction, place the minuend in REG_A and the subtrahend in REG_B.
# Set REG_OP to OP_SUB and call INSTR_CPU_EXEC.
# After execution, the difference will be present in REG_RES.
export OP_SUB=1

# To increment a value, place the operand in REG_A.
# Set REG_OP to OP_INCR and call INSTR_CPU_EXEC.
# After execution, the incremented value will be present in REG_RES.
export OP_INCR=2

# To decrement a value, place the operand in REG_A.
# Set REG_OP to OP_DECR and call INSTR_CPU_EXEC.
# After execution, the decremented value will be present in REG_RES.
export OP_DECR=3

# To perform division, place the dividend in REG_A and the divisor in REG_B.
# Set REG_OP to OP_DIV and call INSTR_CPU_EXEC.
# After execution, the quotient will be present in REG_RES.
export OP_DIV=4

# To perform modulo operation, place the dividend in REG_A and the divisor in REG_B.
# Set REG_OP to OP_MOD and call INSTR_CPU_EXEC.
# After execution, the remainder will be present in REG_RES.
export OP_MOD=5

# To perform multiplication, place the first operand in REG_A and the second operand in REG_B.
# Set REG_OP to OP_MUL and call INSTR_CPU_EXEC.
# After execution, the product will be present in REG_RES.
export OP_MUL=6

# To check if a value is a number, place the value in REG_A.
# Set REG_OP to OP_IS_NUM and call INSTR_CPU_EXEC.
# After execution, the result (true or false) will be present in REG_BOOL_RES.
export OP_IS_NUM=7

# To compare equality, place the first value in REG_A and the second value in REG_B.
# Set REG_OP to OP_CMP_EQ and call INSTR_CPU_EXEC.
# After execution, the result (true if equal, false otherwise) will be present in REG_BOOL_RES.
export OP_CMP_EQ=8

# To compare inequality, place the first value in REG_A and the second value in REG_B.
# Set REG_OP to OP_CMP_NEQ and call INSTR_CPU_EXEC.
# After execution, the result (true if not equal, false otherwise) will be present in REG_BOOL_RES.
export OP_CMP_NEQ=9

# To check if one value is less than another, place the first value in REG_A and the second value in REG_B.
# Set REG_OP to OP_CMP_LT and call INSTR_CPU_EXEC.
# After execution, the result (true if REG_A < REG_B) will be present in REG_BOOL_RES.
export OP_CMP_LT=10

# To check if one value is less than or equal to another, place the first value in REG_A and the second value in REG_B.
# Set REG_OP to OP_CMP_LE and call INSTR_CPU_EXEC.
# After execution, the result (true if REG_A <= REG_B) will be present in REG_BOOL_RES.
export OP_CMP_LE=11

# To check if one value contains another, place the container in REG_A and the contained value in REG_B.
# Set REG_OP to OP_CONTAINS and call INSTR_CPU_EXEC.
# After execution, the result (true or false) will be present in REG_BOOL_RES.
export OP_CONTAINS=12

# To get the length of a string, place the string in REG_A.
# Set REG_OP to OP_GET_LENGTH and call INSTR_CPU_EXEC.
# After execution, the length will be present in REG_RES.
export OP_GET_LENGTH=13

# To check if a string starts with a given prefix, place the string in REG_A and the prefix in REG_B.
# Set REG_OP to OP_STARTS_WITH and call INSTR_CPU_EXEC.
# After execution, the result (true or false) will be present in REG_BOOL_RES, tail of the string will be in REG_RES.
export OP_STARTS_WITH=14

# To extract a specific column from a string, place the string in REG_A, the column number in REG_B, and the delimiter in REG_C.
# Set REG_OP to OP_GET_COLUMN and call INSTR_CPU_EXEC.
# After execution, the extracted column will be present in REG_RES.
export OP_GET_COLUMN=15

# To replace a specific column in a string, place the string in REG_A, the column number in REG_B, the delimiter in REG_C,  and the new value in REG_D.
# Set REG_OP to OP_REPLACE_COLUMN and call INSTR_CPU_EXEC.
# After execution, the modified string will be present in REG_RES.
export OP_REPLACE_COLUMN=16

# To concatenate two strings with a delimiter, place the first string in REG_A, the second string in REG_B, and the delimiter in REG_C.
# Set REG_OP to OP_CONCAT_WITH and call INSTR_CPU_EXEC.
# After execution, the concatenated string will be present in REG_RES.
export OP_CONCAT_WITH=17

# To read input from the keyboard, set REG_OP to OP_READ_INPUT and call INSTR_CPU_EXEC.
# For advanced processing set REG_A with one of the modes:
#   KEYBOARD_READ_LINE, KEYBOARD_READ_LINE_SILENTLY, KEYBOARD_READ_CHAR, KEYBOARD_READ_CHAR_SILENTLY.
# After execution, the input will be stored in the KEYBOARD_BUFFER.
export OP_READ_INPUT=18

# To display a string without a newline, place the string in DISPLAY_BUFFER and set the color in DISPLAY_COLOR.
# Set REG_OP to OP_DISPLAY and call INSTR_CPU_EXEC.
export OP_DISPLAY=19

# To display a string with a newline, place the string in DISPLAY_BUFFER and set the color in DISPLAY_COLOR.
# Set REG_OP to OP_DISPLAY_LN and call INSTR_CPU_EXEC.
export OP_DISPLAY_LN=20

# To read a block of data from a disk, set the disk name in REG_A and the block number in REG_B.
# Set REG_OP to OP_READ_BLOCK and call INSTR_CPU_EXEC.
# After execution, the data will be stored in REG_RES but in case of incorrect arguments REG_ERROR will be set to handle it if needed.
export OP_READ_BLOCK=21

# To write a string to a disk block, set the disk name in REG_A, the block number in REG_B, and the string in REG_C.
# Set REG_OP to OP_WRITE_BLOCK and call INSTR_CPU_EXEC.
# The result (success or failure) will be indicated by presence of error message in REG_ERROR buffer.
export OP_WRITE_BLOCK=22

# To change background color set COLOR_* constant to DISPLAY_BACKGROUND,
# set OP_SET_BACKGROUND_COLOR to REG_OP and call INSTR_CPU_EXEC
export OP_SET_BACKGROUND_COLOR=23

# To draw bitmap specify address of first line with bitmap representation to REG_A,
# first address after the last line of bitmap to REG_B, and OP_RENDER_BITMAP to REG_OP.
# Call INSTR_CPU_EXEC to render the bitmap.
# Each line should contain letters B(black), g(green), y(yellow), r(red), b(blue), m(magenta), c(cyan), w(white), o(orange), n(no color)
# For example string ggyyrr will display a line with 2 green cells, 2 yellow cells and 2 red cells
export OP_RENDER_BITMAP=24

# To perform a system call from user space:
# - Place arguments in REG_A, REG_B, and REG_C.
# - Set the system call number in REG_D.
# - Write OP_SYS_CALL to REG_OP.
# - Execute INSTR_CPU_EXEC.
# After the system call returns:
# - The result will be stored in REG_RES.
# - Any error information will be stored in REG_ERROR.
export OP_SYS_CALL=25

# To return from a system call in kernel mode:
# - Set REG_RES with the return value.
# - Set REG_ERROR with any error information.
# - Write OP_SYS_RETURN to REG_OP.
# - Execute INSTR_CPU_EXEC.
export OP_SYS_RETURN=26

# To encrypt the data place it to REG_A, write OP_ENCRYPT_DATA to REG_OP.
# Call INSTR_CPU_EXEC to encrypt the data.
# The encrypted data will be stored in REG_RES.
export OP_ENCRYPT_DATA=27

# To decrypt the data place it to REG_A, write OP_DECRYPT_DATA to REG_OP.
# Call INSTR_CPU_EXEC to decrypt the data.
# The decrypted data will be stored in REG_RES.
export OP_DECRYPT_DATA=28

# To perform no operation with sleep, set REG_OP to OP_NOP, sleep delay in seconds to REG_A and call INSTR_CPU_EXEC.
# This will have no effect and is useful for delays or placeholders.
export OP_NOP=29

# To halt the CPU and stop the system, set REG_OP to OP_HALT and call INSTR_CPU_EXEC.
# This will terminate all operations.
export OP_HALT=30

# To reset the operation code for safety, set REG_OP to OP_UNKNOWN and call INSTR_CPU_EXEC.
# This ensures that the operation code must be explicitly set before the next execution.
export OP_UNKNOWN=31
