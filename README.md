# Welcome! #
Welcome to KaguOS - learning framework for operating system design.

# Environment Setup #
Bash shell or PowerShell is required to run the KaguOS emulation.
You can find the instruction on the environment setup for your operating system in corresponding folder inside `setup`.
Preffered configuration is Multipass containers + VSCode with AWS Toolkit extension. While for situation with failed multipass setup on Windows we have backup solution using PowerShell implementation instead of Bash.

# How to work with KaguOS #

## Compile and run ##
Use ONLY ONE of the options below based on your setup.

### Bash version ###
You should compile kernel first. It can be done with `./compiler.sh src/kernel_base.sh` or `./compiler.sh -f src/kernel_base.sh` if you want to replace all the constants with real values.
Run bootloader with command `./bootloader.sh`. Alternatively you can use debug flags:
*  `./bootloader.sh -j` to show each command that was executed
* `./bootloader.sh -s=0.5` to have a delay between command execution. 0.5 means 0.5 second, you can adjust it. View changes in `tmp/RAM.txt` in parallel to track changes made in memory with each command execution.
* `./bootloader.sh -j -s=0.5` combination of both debug tools from above.

### PowerShell version ###
You should compile kernel first. It can be done with `./w_compiler.ps1 src/kernel_base.sh` or `./w_compiler.ps1 -f src/kernel_base.sh` if you want to replace all the constants with real values.
Run bootloader with command `./w_bootloader.ps1`. Alternatively you can use debug flags:
*  `./w_bootloader.ps1 -j` to show each command that was executed
* `./w_bootloader.ps1 -s=0.5` to have a delay between command execution. 0.5 means 0.5 second, you can adjust it. View changes in `tmp/RAM.txt` in parallel to track changes made in memory with each command execution.
* `./w_bootloader.ps1 -j -s=0.5` combination of both debug tools from above.

## TODO tasks ##
Search for the TODO words across the source code. Follow the instructions to experiment with the code.
Write your own code and compile&run the kernel to check the behavior and debug RAM change and jumps.

## NOTE and NOTE AI ##
NOTE points to some usefull information about code below..
NOTE AI usually marks some questions for AI assistant tool.

## Hints ##
* For coding in KaguOS you should use only basic operations defined in files from include folder to manipulate strings in tmp/RAM.txt.
* Usually you can reuse lines from src/kernel_base.sh. Also it is reasonable to copy that file with a new name to use it for experiments, compilation and running and have some basic reference with original file.
* Here are some examples of usage:
``` bash
# Message display:

# To display some message write the message string to GLOBAL_DISPLAY_INFO_ADDRESS memory and call some display_* function:
write_to_address ${GLOBAL_DISPLAY_INFO_ADDRESS} "Some text to display"
display_success

# Or you can copy data from other address to display memory address and then call a display_* function:
copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_DISPLAY_INFO_ADDRESS}
display_println


# Read input from keyboard:

# Call read_input function. After Enter press string will be stored to GLOBAL_INPUT_ADDRESS and can be used in the program:
read_input
copy_from_to_address ${GLOBAL_INPUT_ADDRESS} ${GLOBAL_DISPLAY_INFO_ADDRESS}
display_warning

# CPU instructions (see include/hw/cpu.sh)

# Call cpu_execute to compare strings stored at 2 addresses.
# Note CPU_EQUAL_CMD and CPU_NOT_EQUAL_CMD store the result of comparison to GLOBAL_COMPARE_RES_ADDRESS. Other CPU instructions write their result to GLOBAL_OUTPUT_ADDRESS:
cpu_execute "${CPU_EQUAL_CMD}" ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_ARG1_ADDRESS}
copy_from_to_address ${GLOBAL_COMPARE_RES_ADDRESS} ${GLOBAL_DISPLAY_INFO_ADDRESS}
display_warning

# Call cpu_execute to increment numeric value stored at some address. Result is stored in GLOBAL_OUTPUT_ADDRESS:
cpu_execute "${CPU_INCREMENT_CMD}" ${GLOBAL_ARG1_ADDRESS}
copy_from_to_address ${GLOBAL_OUTPUT_ADDRESS} ${GLOBAL_DISPLAY_INFO_ADDRESS}
display_print

```

# Implementation #
KaguOS has 2 implementations: on Bash shell scripting language and using PowerShell.
Basic functionality of CPU, RAM, display and other is written as functions which are exported to be visible from any place from bootloader script execution.
As a result machine code is a sequence of calls of such functions.
All the constants are also exported as bash or ppowershell global variables. While the command `compiler.sh -f` (`w_compiler.ps1 -f` for PowerShell version) allows you to substitute all of them with a numeric value. Therefore it behaves very similar as the real machine code does.

In real computers string constants used in code should be stored under some address in static storage and we should manipulate with this address instead of plain string.
But in our implementation we can use string literals in code and compiled instructions to increase readability.
At the same time it may be a good task to adjust `compiler.sh` or `w_compiler.ps1` to handle write_to_address strings in code and substitute them with hardcoding of that value to some address and using copy_from_to_address instead of write_to_address instruction.

Execution of machine code instruction is a call of bash `eval` (for PowerShell `Invoke-Expression` is used)  which interprets a line at the RAM file and executes it as a shell script function call.

# General structure #

## 1A. include/Bash ##
Folder contains defines for constants, hw functionality and jump instruction for Bash implementation

### 1.1 defines.sh ###
File contains constants for RAM size, emulation files location, addresses for different memory and so on.

### 1.2 jump.sh ###
**jump_to** and **jump_if** instructions to manage address of next instruction to be excuted.

### 1.3 hw ###
Folder with includes related to basic HW functionality

#### 1.3.1 cpu.sh ####
**cpu_execute** functionality and constants for supported cpu instructions

#### 1.3.2 ram.sh ####
Functions to work with RAM: **write_to_address**, **copy_from_to_address**, **copy_from_to_n_address**.
Also we have **read_from_address** but it is mostly used as a helper for implementation of other basic HW functions. You should not use it in your kernel code - use **copy_from_to_address** instead.

#### 1.3.3 input_output.sh ####
Functions to work with input(**read_input**) and display (**display_print**, **display_println**, **display_success**, **display_warning**, **display_error**) 

## 1B. include/PowerShell ##
Folder has the same structure as Bash version while all files have ps1 extension instead of sh. That part of code is written on PowerShell language.

## 2. src ##
Folder with source code for kernel and user programs

### 2.1 kernel_base.sh ###
Example of kernel source code


## 3. bootloader.sh, w_bootloader.ps1 ##
Bootloader script inits a hardware and loads the kernel. After that the main kernel loop is started.
You can use the following options:
```
-j      print each executed instruction to the console
-s=     add delay(in seconds) between sequential commands, for example `./bootloader.sh -s=0.5` gives 0.5 second delay.
```

## 4. compiler.sh, w_compiler.ps1 ##
Compiler script transforms kernel source code to a set of instruction that can be run with the simulator.
```
-f      fully compile code e.g. substitute human readable names of address constants with their numeric values.
```

## 5. build ##
Folder for build artifacts. In case of kernel compilation `./compiler.sh src/kernel_base.sh` you will get `kernel.disk` file with compiled kernel and `env.sh` with extra constants if needed.

## 6. tmp ##
After starting `./bootloader.sh` or `./w_bootloader.ps1` you can monitor state of RAM using `tmp/RAM.txt` file. For step by step review use delay between commands, for example `./bootloader.sh -s=0.5` (`./w_bootloader.ps1 -s=0.5`) gives 0.5 second delay.

## 7. docker ##
Docker file for container setup.
