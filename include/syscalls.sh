# System call constants for KaguOS

# Terminates the process with the given exit code
export SYS_CALL_EXIT=0

# Prints text with a newline; REG_A contains text, REG_B contains color code
export SYS_CALL_PRINTLN=1

# Prints text without a newline; REG_A contains text, REG_B contains color code
export SYS_CALL_PRINT=2

# Reads input from the keyboard; REG_A specifies the input mode, result stored in REG_RES
export SYS_CALL_READ_INPUT=3

# Opens a file; REG_A contains the file path, returns file descriptor in REG_RES or error in REG_ERROR
export SYS_CALL_OPEN=4

# Retrieves file descriptor information; REG_A contains descriptor, returns file info in REG_RES or error in REG_ERROR
export SYS_CALL_DESCRIPTOR_INFO=5

# Closes a file; REG_A contains descriptor, returns status in REG_ERROR
export SYS_CALL_CLOSE=6

# Reads a line from a file; REG_A contains descriptor, REG_B contains line number, result in REG_RES, EOF or error in REG_ERROR
export SYS_CALL_READ=7

# Writes a line to a file; REG_A contains descriptor, REG_B contains line number, REG_C contains new value, error in REG_ERROR
export SYS_CALL_WRITE=8

# Sets the terminal background color; REG_A contains the color code
export SYS_CALL_SET_BACKGROUND=9

# Renders a bitmap; REG_A contains the start address, REG_B contains the end address
export SYS_CALL_RENDER_BITMAP=10

# Suspends execution for the given time in seconds; REG_A contains sleep duration
export SYS_CALL_SLEEP=11

# Gets the file permissions based on provided descripror;
# REG_A contains file descriptor. REG_RES will contain a string like 7 7 7 someUser someGroup
export SYS_CALL_GET_FILE_ATTR=12

# Sets the file permissions based on provided descripror;
# REG_A contains file descriptor. REG_B contains the new permissions like 4 4 0 otherUser otherGroup
export SYS_CALL_SET_FILE_ATTR=13

# Schedules a program for execution
# REG_A contains command line to execute for example mario 10 or cat 1.txt, REG_B contains priority of the process
export SYS_CALL_SCHED_PROGRAM=14
