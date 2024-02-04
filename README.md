# Welcome! #
Welcome to KaguOS - learning framework for operating system design.

# Environment #
Bash shell is required to run the KaguOS emulation.

## Multipass for Linux, MacOS and Windows ##
The preffered way is to use Ubuntu multipass for container creation. It should work fine for Windows, Linux and MacOS:
* Go to https://multipass.run/install and follow the instructions.
* Open Terminal or PowerShell and create new container. You can use any name you like instead of **jammy**.
```bash
multipass launch 22.04 --name jammy
```
* Mount KaguOS to container. Below we mount it to ~/KaguOS:
```bash
multipass mount <your path to sources>/KaguOS jammy:/home/ubuntu/KaguOS
```
* List your containers and their status:
```bash
multipass list
```
* Start your container if needed:
```bash
multipass start jammy
```
* Stop a container:
```bash
multipass stop jammy
```
* Open a shell inside container:
```bash
multipass shell jammy
```
* As an alternative you can use VSCode together with the extension https://marketplace.visualstudio.com/items?itemName=levalleyjack.multipass-manager . It will allow you to manage multipass containers from VSCode side panel.

## Docker ##
* Follow the instructions from https://docs.docker.com/engine/install/ to install docker.
* Use docker file from docker subfolder.
* Build docker image:
```bash
docker build -t kagu  ./docker
```
* Run docker from KaguOS folder and mount your source folder to /KaguOS in container:
```bash
docker run -v `pwd`:/KaguOS -it --rm kagu bash
```
* Use VSCode or other IDE with docker remote extension.

* Change working dir to /KaguOS inside container:
```
cd /KaguOS
```

## Ubuntu ##
On Ubuntu linux you should get all you need from the box.

## MacOS ##
By default MacOS is delivered with an outdated version of bash. To update it you can use the following steps.
* Open Terminal and check bash version with command **bash -v** .
* Install brew by executing of the following command(see brew.sh for details ):
    **/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"**
* Install bash
    **brew install bash**
* Edit config file for shells with command **sudo nano /etc/shells** by adding the line **/usr/local/bin/bash** before other paths.
* Press **Ctrl+O** and **Enter** to write your changes. Exit from editor with **Ctrl+X**.
* Reopen Terminal and check version of bash **bash -v** .

# How to work with KaguOS #

## Code review ##
Read the code of components and comments inside each files. Here is proposed sequence of review:
* Start from `bootloader.sh`.
* Review `include` folder starting from `defines.sh` and then `jump.sh` and `hw` subfolder content.
* Go to `src/kernel_base.sh`.
* Take a look at `compiler.sh` file.

## Compile and run ##
You should compile kernel first. It can be done with `./compiler.sh src/kernel_base.sh` or `./compiler.sh -f src/kernel_base.sh` if you want to replace all the constants with real values.
Run bootloader with command `./bootloader.sh`. Alternatively you can use debug flags:
*  `./bootloader.sh -j` to show each command that was executed
* `./bootloader.sh -s=0.5` to have a delay between command execution. 0.5 means 0.5 second, you can adjust it. View changes in `tmp/RAM.txt` in parallel to track changes made in memory with each command execution.
* `./bootloader.sh -j -s=0.5` combination of both debug tools from above.

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
KaguOS is written on bash shell scripting language.
Basic functionality of CPU, RAM, display and other is written as bash functions which are exported to be visible from any place from bootloader script execution.
As a result machine code is a sequence of calls of such functions.
All the constants are also exported as bash global variables. While the command `compiler.sh -f` allows to substitute all of them with a numeric value. Therefore it behaves very similar as the real machine code does.

In real computers string constants used in code should be stored under some address in static storage and we should manipulate with this address instead of plain string.
But in our implementation we can use string literals in code and compiled instructions to increase readability.
At the same time it may be a good task to adjust `compiler.sh` to handle write_to_address strings in code and substitute them with hardcoding of that value to some address and using copy_from_to_address instead of write_to_address instruction.

Execution of machine code instruction is a call of bash `eval` which interprets a line at the RAM file and executes it as a bash call.

# General structure #

## 1. include ##
Folder contains defines for constants, hw functionality and jump instruction

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



## 2. src ##
Folder with source code for kernel and user programs

### 2.1 kernel_base.sh ###
Example of kernel source code


## 3. bootloader.sh ##
Bootloader script inits a hardware and loads the kernel. After that the main kernel loop is started.
You can use the following options:
```
-j      print each executed instruction to the console
-s=     add delay(in seconds) between sequential commands, for example `./bootloader.sh -s=0.5` gives 0.5 second delay.
```

## 4. compiler.sh ##
Compiler script transforms kernel source code to a set of instruction that can be run with the simulator.
```
-f      fully compile code e.g. substitute human readable names of address constants with their numeric values.
```

## 5. build ##
Folder for build artifacts. In case of kernel compilation `./compiler.sh src/kernel_base.sh` you will get `kernel.disk` file with compiled kernel and `env.sh` with extra constants if needed.

## 6. tmp ##
After starting `./bootloader.sh` you can monitor state of RAM using `tmp/RAM.txt` file. For step by step review use delay between commands, for example `./bootloader.sh -s=0.5` gives 0.5 second delay.

## 7. docker ##
Docker file for container setup.
