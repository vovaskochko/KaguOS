#############################################
#############################################
# Instruction set constants:
#############################################

# To execute a CPU operation, set the operation code in REG_OP and call INSTR_CPU_EXEC.
# Depending on the operation, the CPU will use REG_A, REG_B, and REG_C, and store the result in REG_RES or REG_BOOL_RES.
export INSTR_CPU_EXEC=0

# To copy data from a source address to a destination address
# 1 100 200 will copy content of RAM address 100 to address 200
export INSTR_COPY_FROM_TO_ADDRESS=1

# To read data from a specific memory address, set the address in REG_A.
# Call INSTR_READ_FROM_ADDRESS and the data will be stored in REG_RES.
export INSTR_READ_FROM_ADDRESS=2

# To jump unconditionally to a specific address, set the target address in REG_A.
# Call INSTR_JUMP to transfer control to the target address.
export INSTR_JUMP=3

# To jump conditionally, set the target address in REG_A and the condition in REG_B.
# Call INSTR_JUMP_IF to transfer control only if the condition is true.
export INSTR_JUMP_IF=4



#############################################
#############################################
## Operations from CPU instruction set.
# For each operation, set the required operands in REG_A, REG_B, or REG_C, set REG_OP, and call INSTR_CPU_EXEC.
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

# TODO add comments
export OP_DIV=4
export OP_MOD=5
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

# TODO comments
export OP_GET_LENGTH=13
export OP_STARTS_WITH=14

# To extract a specific column from a string, place the string in REG_A, the column number in REG_B, and the delimiter in REG_C.
# Set REG_OP to OP_GET_COLUMN and call INSTR_CPU_EXEC.
# After execution, the extracted column will be present in REG_RES.
export OP_GET_COLUMN=15

# REG_A - input string, REG_B - delimiter, REG_C - column no, REG_D - new column value
export OP_REPLACE_COLUMN=16

# TODO CONCAT_WITH
export OP_CONCAT_WITH=17

# To read input from the keyboard, call OP_READ_INPUT.
# After execution, the input will be stored in the KEYBOARD_BUFFER.
export OP_READ_INPUT=18

# To display a string without a newline, place the string in DISPLAY_BUFFER and set the color in DISPLAY_COLOR.
# Call OP_DISPLAY to output the string.
export OP_DISPLAY=19

# To display a string with a newline, place the string in DISPLAY_BUFFER and set the color in DISPLAY_COLOR.
# Call OP_DISPLAY_LN to output the string followed by a newline.
export OP_DISPLAY_LN=20

# To read a block of data from a disk, set the disk name in REG_A and the block number in REG_B.
# Call OP_READ_BLOCK and the data will be stored in REG_RES.
export OP_READ_BLOCK=21

# To write a string to a disk block, set the disk name in REG_A, the block number in REG_B, and the string in REG_C.
# Call OP_WRITE_BLOCK to perform the write operation.
# The result (success or failure) will be present in REG_BOOL_RES, and any error message will be stored in REG_ERROR if needed.
export OP_WRITE_BLOCK=22


#####
# OP codes from 23 to 28 are reserved for future use.
#####

# To perform no operation, set REG_OP to OP_NOP and call INSTR_CPU_EXEC.
# This will have no effect and is useful for delays or placeholders.
export OP_NOP=29

# To halt the CPU and stop the system, set REG_OP to OP_HALT and call INSTR_CPU_EXEC.
# This will terminate all operations.
export OP_HALT=30

# To reset the operation code for safety, set REG_OP to OP_UNKNOWN after any CPU execution.
# This ensures that the operation code must be explicitly set before the next execution.
export OP_UNKNOWN=31
