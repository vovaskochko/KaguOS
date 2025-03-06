# Welcome!
Welcome to KaguOS - learning framework for operating system design.

The main idea of this project is to emulate work of CPU and its interaction with RAM to build our own simple operating system. Note that this emulation is using string as a unit of RAM instead of byte. This allows monitoring of RAM state easily by checking the `tmp/RAM.txt` file.

We are using Bash functions to emulate basic operations like CPU instructions and the fetch-decode-execute loop. Also C++ version of hardware emulation and bootloader is available.

# Table of Contents

1. [Environment](#1-environment)
   - 1.1 [Requirements](#11-requirements)
   - 1.2 [Installation](#12-installation)
2. [General Approach](#2-general-approach)
   - 2.1 [Core Principles](#21-core-principles)
   - 2.2 [C++ Hardware Emulation](#22-c-hardware-emulation)
3. [How to Work with KaguOS](#3-how-to-work-with-kaguos)
   - 3.1 [Running a Simple Kernel](#31-running-a-simple-kernel)
   - 3.2 [Displaying Messages](#32-displaying-messages)
   - 3.3 [Reading User Input](#33-reading-user-input)
   - 3.4 [Conditional Execution](#34-conditional-execution)
4. [KaguAsm Language](#4-kaguasm-language)
   - 4.1 [Syntax](#41-syntax)
   - 4.2 [Compilation and Execution](#42-compilation-and-execution)
   - 4.3 [VSCode Extension](#43-vscode-extension)
   - 4.4 [Examples](#44-examples)
5. [`asm.sh` Implementation](#5-asmsh-implementation)
6. [System Calls and User Space](#6-system-calls-and-user-space-in-kaguos)
   - 6.1 [System Call Mechanism](#61-system-call-mechanism)
   - 6.2 [System Call Table](#62-system-call-table)
   - 6.3 [User Space Memory Management](#63-user-space-memory-management)
   - 6.4 [User Space Restrictions](#64-user-space-restrictions)
   - 6.5 [Executing User Programs](#65-executing-user-programs)
   - 6.6 [Error Handling in User Space](#66-error-handling-in-user-space)
7. [Compiling and Loading User Programs](#7-compiling-and-loading-user-programs-in-kaguos)
   - 7.1 [Overview](#71-overview)
   - 7.2 [Compiling User Programs](#72-compiling-user-programs)
   - 7.3 [Loading a User Program onto Disk](#73-loading-a-user-program-onto-disk)
   - 7.4 [Writing User Programs](#74-writing-user-programs)
   - 7.5 [User-Space Restrictions](#75-user-space-restrictions)
   - 7.6 [Running a User Program](#76-running-a-user-program)
8. [KaguFS Filesystem and Disk Structure](#8-kagufs-filesystem-and-disk-structure)
   - 8.1 [Overview of the Filesystem](#81-overview-of-the-filesystem)
   - 8.2 [Disk Structure](#82-disk-structure)
   - 8.3 [Partition Mounting Mechanism](#83-partition-mounting-mechanism)
   - 8.4 [Organization of the Filesystem in Partitions](#84-organization-of-the-filesystem-in-partitions)
   - 8.5 [Interaction with Files in KaguFS](#85-interaction-with-files-in-kagufs)
   - 8.6 [Conclusion](#86-conclusion)

## 1. Environment

Bash shell of version 5.2+ is required to run the KaguOS emulation.

The preferred way is to use an Ubuntu Multipass virtual machine. KaguOS can be run directly on Linux and macOS without Multipass. For Windows, `git-bash` can be used for compilation, and C++ emulation can be used to run KaguOS in PowerShell.

### 1.1 Requirements

- **Bash 5.2+** is required.
- **Multipass** is recommended for an isolated environment.
- **C++ Compiler** to build C++ version of hardware emulation and bootloader.

### 1.2 Installation

#### Installation for Linux, macOS, and Windows (with Multipass)

1. Go to [Multipass Installation](https://multipass.run/install) and follow the instructions.
2. Open Terminal or PowerShell and create a new VM (you can use any name instead of `noble`):
   ```bash
   multipass launch 24.04 --name noble
   ```
3. Start your VM if needed:
   ```bash
   multipass start noble
   ```
4. Open a shell inside the virtual machine:
   ```bash
   multipass shell noble
   ```
5. Stop a virtual machine if needed:
   ```bash
   multipass stop noble
   ```

#### Ubuntu (without Multipass)

On Ubuntu Linux, all required dependencies should be available out of the box.

#### macOS (without Multipass)

By default, macOS ships with an outdated version of Bash. To update it, follow these steps:

1. Open Terminal and check the Bash version:
   ```bash
   bash -v
   ```
2. Install Homebrew by executing the following command (see [brew.sh](https://brew.sh) for details):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Install Bash:
   ```bash
   brew install bash
   ```
4. Edit the shell configuration file:
   ```bash
   sudo nano /etc/shells
   ```
   Add the following line before other paths:
   ```
   /usr/local/bin/bash
   ```
5. Save changes by pressing **Ctrl+O** and **Enter**, then exit with **Ctrl+X**.
6. Reopen Terminal and check the Bash version:
   ```bash
   bash -v
   ```

#### Windows (without Multipass)

1. Install `git-bash` to run `asm.sh`.
2. Compile the C++ version of emulation from `bootloader.cpp`.

## 2. General Approach

For educational purposes, KaguOS has a simplified computation scheme to make debugging and monitoring easy. Some core principles we use:

### 2.1 Core Principles

1. **String-based computation**: The computation unit of the KaguOS CPU is a string instead of a byte or machine word in a real CPU. As a result, our RAM is just an array of strings, which can be dumped to a file and easily monitored. This avoids binary conversion and keeps the data readable. Most of the time, we use short strings (≤16 bytes), making the model easily adaptable to a **128-bit CPU** (16-byte machine word).

2. **Addressable RAM**: Each string in RAM has its own address starting from `1`. These addresses are used for computations. For example, data can be copied from address `42` to address `16`. This operation is one of the most frequently used.

3. **Data and instructions in RAM**: Each string in RAM may represent an instruction, data, or free space available for dynamic memory management.

4. **Memory-mapped I/O**: CPU registers, display, and keyboard buffers are mapped to the start of RAM. This ensures consistency and simplifies monitoring of both RAM and registers.

5. **CPU operations**: The CPU has a defined set of supported operations. The typical execution flow involves:
   - Copying data from RAM addresses to registers (`REG_A`, `REG_B`, `REG_C`, `REG_D`).
   - Copying the operation code (`OP_*`) to `REG_OP`.
   - Executing the instruction via `cpu_exec`.
   - Storing the result in `REG_RES` or `REG_BOOL_RES`, depending on the operation type.
   - For more details, refer to the next section **[How to Work with KaguOS](#3-how-to-work-with-kaguos)**.

6. **Instruction execution sequence**: By default, the system executes instructions sequentially. If execution starts from address `41`, the corresponding string in RAM is parsed and executed if possible (otherwise, a fatal error occurs). The program counter is then incremented, and address `42` is treated as the next instruction, and so on.

7. **Control flow via jumps**: To change the execution order, KaguOS supports:
   - **Unconditional jumps (`jump`)**: Directly set the program counter to a new address.
   - **Conditional jumps (`jump_if`, `jump_if_not`, `jump_err`)**: Change execution flow based on conditions.
   - The new address becomes the next instruction to be executed.

8. **Kernel execution**: The kernel should be run using the `bootloader.sh` script or `bootloader` binary compiled from `bootloader.cpp`. Debugging options like `-j -s` are available. Additionally, special instructions `DEBUG_ON` and `DEBUG_OFF` can enable or disable debugging functionality and RAM dumping into `tmp/RAM.txt`.

### 2.2 C++ Hardware Emulation

An alternative version of hardware emulation is implemented in C++ (`bootloader.cpp`).

#### Compilation  
For **macOS, Windows, and Linux**, compile it using:
```sh
clang++ bootloader.cpp -o bootloader -std=c++17
```
or
```sh
g++ bootloader.cpp -o bootloader -std=c++17
```
or (Windows only, using MSVC):
```ps1
cl.exe bootloader.cpp -o bootloader.exe /std:c++17 /EHsc
```

#### Running the Bootloader
To execute the bootloader, use:
```sh
./bootloader build/kernel.disk 1500
```
where `1500` is the amount of RAM allocated.

After compilation, run unit tests for CPU emulation with:
```sh
CPP_BOOTLOADER=1 tests/test_cpu_emulation.sh
```


## 3. How to Work with KaguOS

The simplest way to run KaguOS is by using the command:
```sh
./bootloader <path to kernel disk> <RAM size>
```
The kernel disk contains a list of machine code instructions and constant data required for execution.

To write an instruction, it is necessary to understand the format and machine codes. Basic instructions and CPU operations are listed in *include/operations.sh*. Register addresses are defined in `include/registers.sh`, with all registers mapped to the beginning of RAM for simplicity.

By default, the kernel loads at an address defined by `KERNEL_START` in *include/system.sh* (default: 41). This means the first line of the kernel disk corresponds to address 41 in RAM.

### 3.1 Running a Simple Kernel

A minimal kernel that halts execution immediately can be implemented as follows:

1. Copy `OP_HALT` (code 30) to `REG_OP` (mapped to address 2 in RAM) using `INSTR_COPY_FROM_TO_ADDRESS` (code 1).
2. Execute `INSTR_CPU_EXEC` (code 0) to process the operation.

Since `OP_HALT` must be stored somewhere in RAM, we append it at the end of the kernel disk:
```
1 ? 2       # INSTR_COPY_FROM_TO_ADDRESS ?(unknown address) REG_OP
0           # INSTR_CPU_EXEC
30          # OP_HALT code - the address of this memory should be substituted in 1 ? 2 instead of ?
```

The last instruction is at line 3 of the kernel disk, which loads at address 43 in RAM. Substituting `?`:
```bash
1 43 2
0
30
```
Save this to `kernels/simple`, then run:
```sh
./bootloader kernels/simple 200
```
This should output `CPU halt`. Running it with `-j` enables debugging:
```sh
./bootloader kernels/simple 200 -j
```

RAM state changes are logged in `tmp/RAM.txt`. Debugging can be enabled/disabled using `DEBUG_ON` and `DEBUG_OFF`.

### 3.2 Displaying Messages

To print a message before halting, use `DISPLAY_BUFFER` (address 18), `DISPLAY_COLOR` (address 20), and `OP_DISPLAY_LN` (code 20). Supported colors are in `include/others.sh`. Example:
```bash
1 ? 18  # Copy text to DISPLAY_BUFFER
1 ? 20  # Copy COLOR_GREEN (1) to DISPLAY_COLOR
1 ? 2   # Copy OP_DISPLAY_LN (20) to REG_OP
0       # Execute operation
1 ? 2   # Copy OP_HALT (30) to REG_OP
0       # Execute operation
Green hello!
1
20
30
```

Now we can resolve ? with the addresses were constants will be present in RAM. Text *Green hello!* is at line 7 at kernel disk therefore it will be at address 47 in RAM. Other constants will be calculated in the same way.
```bash
1 47 18
1 48 20
1 49 2
0
1 50 2
0
Green hello!
1
20
30
```
Save this to `kernels/hello` and run it.

To display a second message in `COLOR_RED` (3):
```bash
1 51 18
1 52 20
1 53 2
0
1 54 18
1 55 20
1 56 2
0
1 57 2
0
Green hello!
1
20
Red hello!
3
20
30
```
Save this as `kernels/helloRed`.

**TASK**: Optimize memory usage in this kernel.

### 3.3 Reading User Input

Use `OP_READ_INPUT` (18) to store input in `KEYBOARD_BUFFER` (address 22):
```bash
1 ? 2   # Copy OP_READ_INPUT to REG_OP
0       # Execute operation
1 22 18 # Copy from KEYBOARD_BUFFER to DISPLAY_BUFFER
1 ? 20  # Copy COLOR_GREEN to DISPLAY_COLOR
1 ? 2   # Copy OP_DISPLAY_LN to REG_OP
0       # Execute operation
1 ? 18  # Copy Red hello! to DISPLAY_BUFFER
1 ? 20  # Copy COLOR_RED to DISPLAY_COLOR
1 ? 2   # Copy OP_DISPLAY_LN to REG_OP
0       # Execute operation
1 ? 2   # Copy OP_HALT to REG_OP
0       # Execute operation
18
1
20
Red hello!
3
20
30
```
After resolving addresses:
```bash
1 53 2
0
1 22 18
1 54 20
1 55 2
0
1 56 18
1 57 20
1 58 2
0
1 59 2
0
18
1
20
Red hello!
3
20
30
```
Save this as `kernels/readInput`.

**TASK**: Display a prompt before reading input.

### 3.4 Conditional Execution

For conditional execution, use `INSTR_JUMP` (3) and `INSTR_JUMP_IF` (4). Conditional jumps occur if `REG_BOOL_RES` (address 14) contains `1`. Example:

- Use `OP_CMP_EQ` (8) to compare `REG_A` and `REG_B`.
- If equal, skip displaying user input.
```bash
1 ? 2   # Copy OP_READ_INPUT to REG_OP
0       # Execute operation
1 22 4  # Copy input to REG_A
1 ? 6   # Copy "red" to REG_B
1 ? 2   # Copy OP_CMP_EQ to REG_OP
0       # Execute operation
4 ??    # JUMP_IF to Red hello! if input is "red"
1 22 18 # Copy from KEYBOARD_BUFFER to DISPLAY_BUFFER
1 ? 20  # Copy COLOR_GREEN to DISPLAY_COLOR
1 ? 2   # Copy OP_DISPLAY_LN to REG_OP
0       # Execute operation
1 ? 18  # Copy Red hello! to DISPLAY_BUFFER
1 ? 20  # Copy COLOR_RED to DISPLAY_COLOR
1 ? 2   # Copy OP_DISPLAY_LN to REG_OP
0       # Execute operation
1 ? 2   # Copy OP_HALT to REG_OP
0       # Execute operation
18
red
8
1
20
Red hello!
3
20
30
```
After resolving addresses (`??` → `52` since the jump is to line 12):
```bash
1 58 2
0
1 22 4
1 59 6
1 60 2
0
4 52
1 22 18
1 61 20
1 62 2
0
1 63 18
1 64 20
1 65 2
0
1 66 2
0
18
red
8
1
20
Red hello!
3
20
30
```
Save as `kernels/condition`. Enter text *red* and ensure that it will not be printed with green color. Restart kernel and enter any other text and ensure that logic is working fine.

**TASK**: Modify the kernel to loop until `exit` is entered.

**TASK**: Implement a calculator that parses expression like `15 + 2`, computes the sum, and outputs the result. Use `OP_GET_COLUMN` and `OP_IS_NUM`.


## 4. KaguAsm Language

Manually writing machine code requires significant attention and is prone to errors due to the many manual calculations involved.

To address these challenges, we developed a simple assembler language that makes writing code for KaguOS much easier. The key features of this language include support for labels, jumps, variables, and the `write` function. The language also allows direct use of constants such as `REG_OP`, `OP_READ_INPUT`, and `COLOR_RED`. The `asm.sh` compiler handles address calculations and automatically generates the kernel.

### 4.1 Syntax

Key aspects of KaguAsm syntax:
- Each command should be placed on its own line.
- Supported commands: `write`, `copy`, `jump`, `jump_if`, `jump_if_not`, `jump_err`, `cpu_exec`, `DEBUG_ON`, `DEBUG_OFF`.
- The keyword `to` can be used with `write` and `copy`.
- Declare variables with `var someName` and labels with `label otherName`. Reference them as `var:someName` and `label:otherName`.
- Label and variable names must start with a letter and contain only letters, digits, and `_`.
- Comments start with `//` (both inline and separate lines are allowed).
- Constants from *include/registers.sh*, *include/operations.sh*, and *include/other.sh* can be used (e.g., `copy REG_RES to DISPLAY_BUFFER`).
- Use `*` before an address to reference its stored value (e.g., `copy *REG_RES to REG_A`).
- Use `@` to copy a variable's address (e.g., `copy @var:someVar to REG_A`).

### 4.2 Compilation and Execution

Compile source files with:
```sh
./asm.sh path/to/file.kga path/to/otherFile.kga
```
This merges input files into **build/kernel.disk**. Execute the compiled kernel with:
```sh
./bootloader build/kernel.disk 500
```

### 4.3 VSCode Extension

A VSCode extension provides syntax highlighting for KaguOS assembler.

1. Download the `.vsix` file from [VSCodeKaguLangSupport](https://github.com/vovaskochko/VSCodeKaguLangSupport/releases).
2. In VSCode, go to Extensions → `...` → `Install from VSIX...` and select the downloaded file.
3. Enjoy syntax highlighting!

### 4.4 Examples

#### Simple Kernel
Create `simple.kga` to display text and exit:
```sh
write "Hello!" to DISPLAY_BUFFER
write COLOR_GREEN to DISPLAY_COLOR
write OP_DISPLAY_LN to REG_OP
cpu_exec
write OP_HALT to REG_OP
cpu_exec
```
Compile and run:
```sh
./asm.sh simple.kga
./bootloader build/kernel.disk 200 -j
```

#### Infinite Loop with Label
```sh
label startKernel // Kernel start
    write "Hello! How are you?" to DISPLAY_BUFFER
    write COLOR_GREEN to DISPLAY_COLOR
    write OP_DISPLAY_LN to REG_OP
    cpu_exec
    write OP_READ_INPUT to REG_OP
    cpu_exec
    jump label:startKernel

label exit // Jump here to exit
    write OP_HALT to REG_OP
    cpu_exec
```
**TASK**: Modify the code to allow exiting the loop.

#### Conditional Execution (`if-else`)
**TASK**: Implement conditional logic based on user input.

#### Do-While Loop
**TASK**: Print user input 5 times using a loop.

#### Variable Handling
**TASK**: Declare a variable with `var someName`, store keyboard input in it (`copy KEYBOARD_BUFFER to var:someName`), and display its contents.


---

## 5. `asm.sh` Implementation

1. The assembler processes all `.kga` files provided by the user, analyzing each line sequentially. Empty lines and comments are ignored immediately.

2. For all other lines, the first word is read and analyzed. This word must be one of the supported commands (`write`, `copy`, `jump`, `jump_if`, `jump_if_not`, `jump_err`, `cpu_exec`, `DEBUG_ON`, `DEBUG_OFF`) or declarations (`var` in `var name` for variables or `label` in `label name` for labels). Based on this first word, the expected number of lexemes is determined. For example, the `write` command requires 4 lexemes, plus the possibility of a comment at the end of the line, so a total of 5 lexemes is checked. Valid patterns for these lexemes are predefined and will be explained later.

3. Each lexeme undergoes analysis via the `parse_lexeme` function. This function determines the lexeme's data type and whether it has an additional prefix (`*` or `@`). If there is no prefix, the default `_` is added. Consequently, every lexeme is converted into a string format where:
   - The first character represents the prefix.
   - A space follows the prefix.
   - The next three characters represent the lexeme type.
   - Another space separates the type from the lexeme's value.

   **Examples:**
   ```
   _ cmd write      // corresponds to the word `write`
   * var name       // corresponds to `*var:name`
   _ lbl labelName  // corresponds to `label:labelname`
   ```
   The first five characters of the formatted lexeme (prefix + type) are crucial for pattern validation.

4. Example valid patterns for `jump` or `jump_if`:
   ```
   ^(_ cmd)(_ num|\* num|\* reg|_ lbl|\* var)(_ cmt)$
   ```
   This pattern ensures:
   - The first lexeme is the command itself (`_ cmd`).
   - The second lexeme can be: a number (`_ num`), a pointer (`* num`, `* reg`, `* var`), or a label (`_ lbl`).
   - The optional third lexeme is a comment (`_ cmt`).

5. Each line is validated against predefined regex patterns, catching most errors early. Remaining errors (e.g., undeclared variables, missing labels) are checked in later passes.

6. The assembler maintains auxiliary arrays for variables, labels, and constants, ensuring proper memory allocation and label resolution.

7. Valid instructions are added to the `PARSED_LEXEMES` list. Debug information, such as `line $CUR_LINE_NO`, helps track errors.

8. After parsing, memory addresses for constants and variables are calculated, and a structured lexeme dump is saved for visualization.

9. The assembler processes `PARSED_LEXEMES` to generate machine code. Debugging information is generated for each lexeme.

10. The final machine code is written to **build/kernel.disk**. Comments are formatted, and memory spaces for variables are allocated at the end.

11. Compilation completes, and the assembler provides feedback to the user.


## 6. System Calls and User Space in KaguOS

### 6.1 System Call Mechanism
KaguOS supports user-space programs that operate within restricted memory regions and rely on system calls to interact with the kernel. System calls allow user-space programs to execute predefined operations by passing arguments via registers.

#### How System Calls Work
1. **Arguments** are stored in `REG_A`, `REG_B`, and `REG_C`.
2. **System call number** is stored in `REG_D`.
3. **Execution is triggered** by setting `REG_OP` to `OP_SYS_CALL` and invoking `cpu_exec`.
4. **Result** is returned in `REG_RES` and `REG_ERROR`.

##### Example: Printing a String
```assembly
   copy REG_RES to REG_A      // Move result to argument register
   write COLOR_NO to REG_B    // Set color argument
   write SYS_CALL_PRINTLN to REG_D // System call number
   write OP_SYS_CALL to REG_OP // Trigger system call
   cpu_exec                    // Execute the call
```

### 6.2 System Call Table

| Call Number | System Call Name     | REG_A               | REG_B             | REG_C        | REG_RES            | REG_ERROR  |
|------------|---------------------|---------------------|------------------|-------------|------------------|------------|
| 0          | SYS_CALL_EXIT        | Exit code          | -                | -           | -                | -          |
| 1          | SYS_CALL_PRINTLN     | Text               | Color code       | -           | -                | -          |
| 2          | SYS_CALL_PRINT       | Text               | Color code       | -           | -                | -          |
| 3          | SYS_CALL_READ_INPUT  | Keyboard mode      | -                | -           | Input string     | -          |
| 4          | SYS_CALL_OPEN        | File path          | -                | -           | File descriptor  | Error      |
| 5          | SYS_CALL_DESCRIPTOR_INFO | File descriptor | -                | -           | File info        | Error      |
| 6          | SYS_CALL_CLOSE       | File descriptor    | -                | -           | -                | Error      |
| 7          | SYS_CALL_READ        | File descriptor    | Line number      | -           | Read line        | EOF/Error  |
| 8          | SYS_CALL_WRITE       | File descriptor    | Line number      | New value   | -                | Error      |
| 9          | SYS_CALL_SET_BACKGROUND | Background color | -                | -           | -                | -          |
| 10         | SYS_CALL_RENDER_BITMAP | Start address    | End address      | -           | -                | -          |
| 11         | SYS_CALL_SLEEP       | Sleep in seconds   | -                | -           | -                | -          |

### 6.3 User Space Memory Management
User-space programs execute within predefined memory regions. Process-related information is stored in:
- `REG_PROC_START_ADDRESS` (Start of user-space memory)
- `REG_PROC_END_ADDRESS` (End of user-space memory)

#### Memory Limitations
- Memory is allocated at process load time.
- If `config.txt` on `main.disk` is missing or invalid, a default size of `200` is used.
- Processes **cannot** access memory beyond their allocated space except for system-permitted registers.

### 6.4 User Space Restrictions
User-space programs have limited access to registers and CPU instructions.

#### Accessible Registers:
- `REG_OP`, `REG_A`, `REG_B`, `REG_C`, `REG_D`, `REG_RES`, `REG_BOOL_RES`, `REG_ERROR`

#### Allowed Operations:
- **Arithmetic:** `OP_ADD`, `OP_SUB`, `OP_INCR`, `OP_DECR`, `OP_DIV`, `OP_MOD`, `OP_MUL`
- **Comparisons:** `OP_IS_NUM`, `OP_CMP_EQ`, `OP_CMP_NEQ`, `OP_CMP_LT`, `OP_CMP_LE`
- **String Operations:** `OP_CONTAINS`, `OP_GET_LENGTH`, `OP_STARTS_WITH`, `OP_GET_COLUMN`, `OP_REPLACE_COLUMN`, `OP_CONCAT_WITH`
- **System Call Invocation:** `OP_SYS_CALL`

### 6.5 Executing User Programs
User-space programs rely on system calls to interact with the OS.

#### Example: Exiting a Program
```assembly
   write 0 to REG_A            // Set exit code
   write SYS_CALL_EXIT to REG_D // System call number
   write OP_SYS_CALL to REG_OP  // Trigger system call
   cpu_exec                     // Execute the call
```

### **6.6 Error Handling in User Space**
- Running `mario` without arguments → **Error** (Process terminates, system remains stable).
- Running `mario 10` → **Successful execution**.

> **Errors in user space do not crash the system – they only terminate the affected process.**

## 7. Compiling and Loading User Programs in KaguOS

### 7.1 Overview
User-space programs in KaguOS are compiled separately from the kernel and must be loaded onto the system disk before execution. This section explains how to use the tools `user_asm.sh` and `copy_file_to_disk.sh` to compile and install user programs.

### 7.2 Compiling User Programs
KaguOS provides the script `user_asm.sh` for assembling user-space programs written in KaguASM. This script is just a wrapper on top of `asm.sh` as instead of `KERNEL_START` shift we should rely on user space program layout.

#### Usage
```sh
./user_asm.sh path/to/user_program.kga
```
- This generates a compiled disk file `build/user.disk`.

#### Example
```sh
./user_asm.sh src/debug.kga
```
- Output: `build/user.disk`, ready to be copied onto `main.disk`.

#### Important Notes
- User programs **must** adhere to **user-space restrictions** (see below).
- System calls must be used for **I/O operations**, **memory management**, and **file access**.

### 7.3 Loading a User Program onto Disk
Once compiled, the user program must be added to `main.disk` so it can be executed by the kernel.

#### Usage
Create a file with a name `dbg` by adding it to the file system header. Let's suppose that available blocks for that file are bleong to the range 321 360. Check [KaguFs Filesystem and Disk Structure](#8-kagufs-filesystem-and-disk-structure) for more details.
```sh
./copy_file_to_disk.sh source_file target_disk start_block_1 end_block_1 start_block_2 end_block_2 start_block_3 end_block_3
```
- `source_file` – The compiled user program (`build/user.disk`).
- `target_disk` – The system disk where the program will be stored (`main.disk`).
- `start_block_*`, `end_block_*` – Defines a list of block intervals for file to be stored on the disk.

#### Example
```sh
./copy_file_to_disk.sh build/user.disk main.disk 321 360
```
- This writes `build/user.disk` to blocks `321-360` of `main.disk`.

#### Verifying the Copy
- Open `hw/main.disk` and check the filesystem header (`BLOCKS`) for the added program.
- Ensure the program name appears in the filesystem metadata.

### 7.4 Writing User Programs
User programs must:
1. **Respect user-space limitations** (restricted memory and operations).
2. **Use system calls** for any privileged operation (e.g., printing, file access).
3. **Follow register conventions** when making system calls.

#### Example: Printing a String
```assembly
   write "Hello, KaguOS!" to REG_A  // Set text
   write COLOR_NO to REG_B          // Set color
   write SYS_CALL_PRINTLN to REG_D  // System call ID
   write OP_SYS_CALL to REG_OP      // Trigger system call
   cpu_exec                         // Execute the call
```

#### Example: Exiting a Program
```assembly
   write 0 to REG_A                 // Exit code
   write SYS_CALL_EXIT to REG_D      // System call ID
   write OP_SYS_CALL to REG_OP       // Trigger system call
   cpu_exec                          // Execute the call
```

### 7.5 User-Space Restrictions
User programs **cannot**:
- Directly modify memory outside of their allocated space.
- Perform privileged CPU operations.
- Access kernel-only registers.

#### Allowed Instructions
| **Category**    | **Allowed Operations**                                |
|---------------|------------------------------------------------------|
| **Arithmetic** | `OP_ADD`, `OP_SUB`, `OP_INCR`, `OP_DECR`, `OP_DIV`, `OP_MOD`, `OP_MUL` |
| **Comparisons** | `OP_IS_NUM`, `OP_CMP_EQ`, `OP_CMP_NEQ`, `OP_CMP_LT`, `OP_CMP_LE` |
| **Strings**    | `OP_CONTAINS`, `OP_GET_LENGTH`, `OP_STARTS_WITH`, `OP_GET_COLUMN`, `OP_REPLACE_COLUMN`, `OP_CONCAT_WITH` |
| **System Calls** | `OP_SYS_CALL` |

### 7.6 Running a User Program
Once the program is compiled and loaded onto `main.disk`, it can be executed by the bootloader.

#### Steps:
1. **Boot the system**:
   ```sh
   ./bootloader build/kernel.disk 2048
   ```
2. **Run the user program**:
   ```sh
   dbg
   ```

#### Debugging
- Running `debug on` enables **tracing system calls** and **memory access**.
- Errors in user space **do not crash the system**—only the affected process is terminated.


### 8. KaguFS Filesystem and Disk Structure

#### 8.1 Overview of the Filesystem

The **KaguFS** filesystem provides fundamental file operations in **KaguOS**, such as opening, reading, writing, and closing files. It operates at the **block level**, where **one block corresponds to one line** in the disk file.

Key features of **KaguFS**:
- **File metadata is stored in the initial blocks of the partition**.
- **Files are allocated in a set of contiguous blocks**, and their headers contain location information.
- **Supports mounting partitions**, allowing files to be stored in different disk sections.
- **Structured file headers** include access permissions, ownership details, and block mappings.

---

#### 8.2 Disk Structure

A disk in **KaguOS** consists of separate blocks, each storing **one line of data**. The first block contains the **total disk size**, followed by the partition table, and then the mounted filesystems.

##### **Example of Initial Disk Structure:**
```
2048
START_PARTITION_TABLE
PARTITION_ENTRIES 4
NAME part1 START_BLOCK 10 END_BLOCK 1000
NAME part2 START_BLOCK 1001 END_BLOCK 1500
NAME part3 START_BLOCK 1501 END_BLOCK 1800
NAME part4 START_BLOCK 1801 END_BLOCK 2048
END_PARTITION_TABLE
```
- The first block (`2048`) – total size of the disk.
- Blocks `2-8` – partition table:
  - Defines partition names (`part1`, `part2`, etc.).
  - Specifies **block ranges** for each partition.
  - All file operations are **restricted** to these ranges.

---

#### 8.3 Partition Mounting Mechanism

The filesystem supports **mounting partitions**, enabling files to be accessed across different sections of the disk.

##### **Mount Configuration Disk (`mount.info`):**
```
6
MOUNT dummy.disk dummyPart /dummy
MOUNT main.disk part2 /home
MOUNT main.disk part3 /usr
MOUNT main.disk part4 /test
MOUNT main.disk part1 /
```
- Specifies the **disk name** (`main.disk`) and **partition name** (`part1`, `part2`, etc.).
- The **last argument** (`/`, `/home`) represents the **mount point**.
- If there are **nested mount points** (e.g., `/dir1`, `/dir1/dir2`), they must be **listed in descending order of length**.

##### **Algorithm for Finding a Partition for a File:**
1. The file path is analyzed.
2. The **longest matching mount point** from `mount.info` is found.
3. The corresponding **partition** is determined.

---

#### 8.4 Organization of the Filesystem in Partitions

Each partition contains an **filesystem header**, defining the range of usable blocks where files are stored.

##### **Example of a Filesystem Header (partition `part1`):**
```
FS_HEADER kagu_fs FIRST_USABLE_BLOCK 31 LAST_USABLE_BLOCK 1000
config.txt 6 4 4 user user BLOCKS 31 40
cat 7 7 7 user user BLOCKS 41 100
1.txt 6 4 0 user user BLOCKS 101 110 321 330
mario 7 5 5 user user BLOCKS 111 261
clear 7 5 5 user user BLOCKS 262 275
debug 7 5 5 user user BLOCKS 276 320
FS_HEADER_END
```
- **FS_HEADER** – Identifier of the filesystem header start. It contains meta information about filesystem parameters.
- **FIRST_USABLE_BLOCK / LAST_USABLE_BLOCK** – Defines the range of blocks where file data can be stored.
- **File list**:
  - **Format**: `filename <permissions:owner> <permissions:group> <permissions:others> owner group BLOCKS start end`
  - **`BLOCKS`** – Indicates the **allocated blocks for the file**.

##### **File Header Structure:**
```
1.txt 7 6 4 user user BLOCKS 101 110 321 330
```
- `1.txt` – File name.
- `7` – File permissions(read/write/execute) for owner of the file.
- `6` – File permissions(read/write/execute) for group.
- `4` - File permissions(read/write/execute) for other users.
- `user user` – Owner and group.
- `BLOCKS 101 110 321 330` – Blocks occupied by the file. It may include multiple pairs if file is fragmented. In this example the first 10 blocks of the file are stored from the line 101 to the line 110; other part of the file is stored from the line 321 to the line 330.

---

#### 8.5 Interaction with Files in KaguFS

File operations in **KaguFS** are performed through **system calls**, which interact with file headers and block mappings.

##### **File Descriptor Format**
A file descriptor contains:
```
filename disk_name file_header_block file_size
```
Example descriptor for `config.txt`:
```
config.txt main.disk 11 10
```

##### **Opening a File (`SYS_CALL_OPEN`)**
```assembly
   write "config.txt" to REG_A  // File name
   write SYS_CALL_OPEN to REG_D  // Open file system call
   write OP_SYS_CALL to REG_OP  
   cpu_exec
```
- **If successful** → The descriptor is stored in `REG_RES`.
- **If an error occurs** → The error code is placed in `REG_ERROR`.

##### **Reading a File (`SYS_CALL_READ`)**
```assembly
   write 1 to REG_B             // Line number to read(starting from 1)
   write SYS_CALL_READ to REG_D
   write OP_SYS_CALL to REG_OP
   cpu_exec
```
- **The read line** is stored in `REG_RES`.

##### **Writing to a File (`SYS_CALL_WRITE`)**
```assembly
   write 2 to REG_B             // Line number to overwrite
   write "Hello World!" to REG_C // Data to write
   write SYS_CALL_WRITE to REG_D 
   write OP_SYS_CALL to REG_OP  
   cpu_exec
```
- If the **line exists**, it will be **overwritten**.
- If the **line does not exist**, an **error is returned**.

##### **Closing a File (`SYS_CALL_CLOSE`)**
```assembly
   write SYS_CALL_CLOSE to REG_D 
   write OP_SYS_CALL to REG_OP  
   cpu_exec
```
