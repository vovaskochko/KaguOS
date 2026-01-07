# KaguOS - Bare Metal Edition

Educational operating system emulator for learning low-level programming.

## Table of Contents

- [Part 1: Introduction \& Philosophy](#part-1-introduction--philosophy)
  - [1.1. What is KaguOS?](#11-what-is-kaguos)
  - [1.2. Quick Start](#12-quick-start)
- [Part 2: Hardware Reference](#part-2-hardware-reference)
  - [2.1. Memory (RAM)](#21-memory-ram)
  - [2.2. CPU Instruction Set \& Operations](#22-cpu-instruction-set--operations)
- [Part 3: Assembly Language \& Programming Patterns](#part-3-assembly-language--programming-patterns)
  - [3.1. Program Memory Layout](#31-program-memory-layout)
  - [3.2. Critical: Code vs. Data Placement](#32-critical-code-vs-data-placement)
  - [3.3. Addressing Modes](#33-addressing-modes)
  - [3.4. Common Programming Patterns](#34-common-programming-patterns)
- [Part 4: The Boot Process](#part-4-the-boot-process-boot-flow)
  - [4.1. The Boot Chain Overview](#41-the-boot-chain-overview)
  - [4.2. Stage 0: Firmware](#42-stage-0-firmware-the-reset-vector)
  - [4.3. Stage 1: MBR](#43-stage-1-mbr-master-boot-record)
  - [4.4. Stage 2: The Bootloader](#44-stage-2-the-bootloader)
  - [4.5. Stage 3: The Kernel](#45-stage-3-the-kernel)
  - [4.6. Building a Bootable Disk](#46-building-a-bootable-disk)
  - [4.7. Quick Boot / Testing](#47-quick-boot--testing)
- [Part 5: Toolchain \& Build System](#part-5-toolchain--build-system)
  - [5.1. The Build Script](#51-the-build-script-build_bootable_disksh)
  - [5.2. Debugging Tools](#52-debugging-tools)
  - [5.3. CMake Build System](#53-cmake-build-system)
- [Part 6: Practical Workshops](#part-6-practical-workshops)
  - [Lab 1: Hello Kagu](#lab-1-hello-kagu-the-ram-snapshot)
  - [Lab 2: The Echo Chamber](#lab-2-the-echo-chamber-inputoutput)
  - [Lab 3: Pixel Art](#lab-3-pixel-art-graphics-kernel)
- [Part 7: KaguOS Cheat Sheet](#part-7-kaguos-cheat-sheet)

---

# Part 1: Introduction & Philosophy

## 1.1. What is KaguOS?

KaguOS is an educational operating system architecture designed to strip away the accidental complexity of modern computing while preserving the essential logical structures.

In a traditional OS, students must immediately grapple with binary arithmetic, endianness (byte ordering), hex dumps, and complex memory management units before they write their first driver. KaguOS replaces these barriers with a radical simplification: **Memory is text.**

### The Core Concept

Imagine a computer where RAM is not an array of bytes, but an array of text strings.

* **No Binary:** Instructions are readable text (e.g., `1 44 7` instead of `0x012C07`).
* **No Endianness:** Data is stored as human-readable strings (e.g., `"Hello"`, `"123.45"`).
* **Von Neumann Architecture:** Code and data share the same memory space, preserving the fundamental behavior of real hardware.

### Why "Bare Metal"?

This edition of KaguOS is the **Bare Metal Edition**.

* **No Protection:** There is no distinction between "User Mode" and "Kernel Mode".
* **Direct Access:** Your code has full access to every hardware component, register, and memory cell.
* **Total Control:** You are not writing software *for* an OS; you are building the system that *runs* the computer.

### High-Level Architecture

1. **The CPU:** Fetches text lines from RAM, decodes numbers, and executes logic.
2. **The RAM:** A linear array of strings indexed starting from 1.
3. **The Disk:** Text files acting as block devices.
4. **The Output:** A terminal emulator that renders text and supports ANSI colors.

---

## 1.2. Quick Start

Get the emulator running and execute your first program.

### Prerequisites

* C++20 compatible compiler (GCC/Clang/MSVC)
* CMake (3.16 or newer)

### Build the Emulator

The emulator (`kagu_boot`) simulates the physical hardware.

```bash
# 0. Switch to tools folder
cd tools
# 1. Configure project
cmake -B build
# 2. Build artefacts. kagu_boot will be installed to the root of the project
cmake --build build
# 3. Go to the root folder of the project
cd ..
```

### Run "Hello World"

KaguOS boots from a disk image that is loaded with reset vector `hw/cpu_firmware.bin`. For simplicity at this stage we will use a pre-made example cpu firmware with custom reset vector. You should consider it as some initial state of RAM.

**Note**: `kagu_boot` requires two parameters - path to cpu firmware aka reset vector and RAM size. You can specify options for debugging as described in the Troubleshooting subsection below.

1. **Run emulator with sample halt system scenario:**
```bash
./kagu_boot examples/cpu_firmware/01_halt.txt 100
```

2. **Run emulator with sample print message and halt system scenario:**
```bash
./kagu_boot examples/cpu_firmware/02_displayln.txt 100
```

### Troubleshooting

* **Debug Mode:** If something goes wrong, you can run the emulator with `-d` flag which allows to dump the entire state of the RAM to `tmp/RAM.txt`. Open this file to inspect registers and memory state at the moment of the crash.
* **Print Jumps:** You can use `-j` flag in addition to `-d` to print current instruction into console.
* **Delay:** You can specify a delay between instructions with `-s N` flag, where N is a count of milliseconds.

#### Task

Open tmp/RAM.txt in a text editor (for example, VSCode) and in parallel run:

```bash
./kagu_boot examples/cpu_firmware/02_displayln.txt 100 -d -j -s 1000
```

---

# Part 2: Hardware Reference

To program for KaguOS, you must understand the hardware it runs on. Since KaguOS is an emulator, this "hardware" is defined by the C++ code in `tools/kagu_boot/src/`. The hardware definitions and constants are exposed to developers via the **`libkagu`** library.

## 2.1. Memory (RAM)

In KaguOS, RAM is a linear array of text strings (lines). Unlike x86 or ARM, there are no bytes, no pages, and no segmentation.

* **Data Type:** Each cell is a `std::string` (aliased as `kagu::RamCell` in `libkagu`). It can hold a number ("42"), a command ("1 44 7"), or text ("Hello").
* **Addressing:** Memory is indexed starting from **1** (aliased as `kagu::FIRST_ADDRESS`). Address 0 is invalid (`kagu::INVALID_ADDRESS`).
* **C++ Interface:** All memory constants and register addresses are defined in the `<kagu/kagu.hpp>` header provided by the `libkagu` library.

### Memory Map

The address space is rigidly divided into four zones as defined in `kagu::Address`:

| Range | Zone Name | Description |
| --- | --- | --- |
| **1 - 11** | **User Space Registers** | General purpose, operation, and result registers. Directly accessible by any code. |
| **12 - 18** | **System Registers** | Privileged registers for I/O, hardware state, and memory management. |
| **19 - 40** | **Firmware Zone** | Reserved for bootstrap microcode. Overwritten by the MBR during the boot process. |
| **41+** | **Code Space** | Free memory for the kernel, bootloader, and user programs. The boot process starts loading the disk at address 41 (`kagu::Address::KernelStart`). |

### Detailed Register Map

Registers in KaguOS are simply memory-mapped addresses at the beginning of RAM. They are defined in `kagu::Address`.

#### User Space Registers (Addresses 1-11)

| Address | C++ Enum (`kagu::Address`) | Name | Purpose |
| --- | --- | --- | --- |
| **1** | `A` | `REG_A` | Operand 1 for operations. |
| **2** | `B` | `REG_B` | Operand 2 for operations. |
| **3** | `C` | `REG_C` | Operand 3 for operations. |
| **4** | `D` | `REG_D` | Operand 4 for operations. |
| **5** | `E` | `REG_E` | Operand 5 for operations. |
| **6** | `F` | `REG_F` | Operand 6 for operations. |
| **7** | `Op` | `REG_OP` | **Operation Code Register**. Stores the numeric code of the operation to execute. |
| **8** | `Res` | `REG_RES` | **Result Register**. Stores the output of math or string operations. |
| **9** | `BoolRes` | `REG_BOOL_RES` | **Boolean Result**. Stores "1" (true) or "0" (false) after comparisons. |
| **10** | `Error` | `REG_ERROR` | **Error Register**. Contains an error message or an empty string if no error occurred. |
| **11** | `LastKey` | `REG_LAST_KEY` | Stores the last key pressed for non-blocking input handling. |

#### System Registers (Addresses 12-18)

| Address | C++ Enum (`kagu::Address`) | Name | Purpose |
| --- | --- | --- | --- |
| **12** | `DisplayBuffer` | `DISPLAY_BUFFER` | Buffer for text output to the terminal. |
| **13** | `DisplayColor` | `DISPLAY_COLOR` | Sets the text color (0-8) for subsequent display operations. |
| **14** | `KeyboardBuffer` | `KEYBOARD_BUFFER` | Buffer for input data or input mode configuration (e.g., `KeyboardReadLine`). |
| **15** | `DisplayBackground` | `DISPLAY_BACKGROUND` | Sets the terminal background color. |
| **16** | `ProgramCounter` | `PROGRAM_COUNTER` | Stores the address of the *current* instruction being executed. |
| **17** | `SysEnergy` | `SYS_ENERGY` | Accumulates the "energy cost" of executed operations (used for profiling). |
| **18** | `FreeMemoryEnd` | `FREE_MEMORY_END` | Stores the last address of available RAM (set to RAM size at boot). |

## 2.2. CPU Instruction Set & Operations

The KaguOS CPU operates on a simple Fetch-Decode-Execute cycle. Unlike traditional architectures with complex instruction sets, KaguOS uses a two-layer approach: **Instructions** (the top-level commands in your code) and **Operations** (the specific logic executed via the `cpu_exec` instruction). All definitions are available in `libkagu/include/kagu/opcodes.hpp`.

### CPU Instructions (Top-Level)

These are the commands that appear directly in your `.disk` files or in RAM. They control the flow of execution and data movement.

| Code | Instruction | Format | Description |
| --- | --- | --- | --- |
| **0** | `CpuExec` | `0` | Executes the operation code currently stored in `REG_OP` (Address 7). |
| **1** | `CopyFromToAddress` | `1 src dest` | Copies a value from `src` to `dest`. **Direct:** `1 44 7` copies value *at* addr 44 to addr 7. **Indirect:** `1 *5 2` reads addr stored *in* addr 5, then copies that value to addr 2. |
| **2** | `Jump` | `2 addr` | Unconditional jump to `addr`. Execution continues from there. |
| **3** | `JumpIf` | `3 addr` | Jumps to `addr` only if `REG_BOOL_RES` (Address 9) contains "1". |
| **4** | `JumpIfNot` | `4 addr` | Jumps to `addr` only if `REG_BOOL_RES` (Address 9) contains "0". |
| **5** | `JumpErr` | `5 addr` | Jumps to `addr` if `REG_ERROR` (Address 10) is not empty. |
| **6** | `Debug` | `6 mode` | Enables (`1`) or disables (`0`) debug mode at runtime. |

### CPU Operations (Micro-operations)

Operations are the actual workhorses for math, logic, and I/O. To perform an operation:

1. Load operands into `REG_A`, `REG_B`, `REG_C`, etc.
2. Load the operation code into `REG_OP`.
3. Execute instruction `0` (`cpu_exec`).

#### Arithmetic Operations

*Writes result to `REG_RES`.*

| Code | Operation | Logic |
| --- | --- | --- |
| **0** | `Add` | `REG_RES = REG_A + REG_B` (Supports integer and float). |
| **1** | `Sub` | `REG_RES = REG_A - REG_B`. |
| **2** | `Incr` | `REG_RES = REG_A + 1`. |
| **3** | `Decr` | `REG_RES = REG_A - 1`. |
| **4** | `Div` | `REG_RES = REG_A / REG_B` (Sets `REG_ERROR` on div by zero). |
| **5** | `Mod` | `REG_RES = REG_A % REG_B` (Integer only). |
| **6** | `Mul` | `REG_RES = REG_A * REG_B`. |

#### Comparison Operations

*Writes "1" (true) or "0" (false) to `REG_BOOL_RES`.*

| Code | Operation | Logic |
| --- | --- | --- |
| **7** | `IsNum` | Checks if `REG_A` is a valid number. |
| **8** | `CmpEq` | Checks if `REG_A == REG_B` (String equality). |
| **9** | `CmpNeq` | Checks if `REG_A != REG_B`. |
| **10** | `CmpLt` | Checks if `REG_A < REG_B` (Numeric comparison supported). |
| **11** | `CmpLe` | Checks if `REG_A <= REG_B`. |

#### String Operations

*Writes result to `REG_RES` and often `REG_BOOL_RES`.*

| Code | Operation | Description |
| --- | --- | --- |
| **12** | `Contains` | Checks if `REG_A` contains `REG_B`. Sets `REG_BOOL_RES` to "1" and `REG_RES` to position (1-based). |
| **13** | `GetLength` | Stores length of string in `REG_A` into `REG_RES`. |
| **14** | `StartsWith` | Checks if `REG_A` starts with `REG_B`. If true, `REG_RES` contains `REG_A` with prefix removed. |
| **15** | `GetColumn` | Extracts a token from `REG_A` at index `REG_B` using delimiter `REG_C`. If `REG_C` is empty, gets character at index. |
| **16** | `ReplaceColumn` | Similar to GetColumn but replaces the token with `REG_D`. |
| **17** | `ConcatWith` | Concatenates `REG_A + REG_C + REG_B` into `REG_RES`. |

#### System & I/O Operations

| Code | Operation | Description |
| --- | --- | --- |
| **18** | `ReadInput` | Reads input into `KEYBOARD_BUFFER` based on the mode already stored in `KEYBOARD_BUFFER` (e.g., "KeyboardReadLine"). |
| **19** | `Display` | Prints `DISPLAY_BUFFER` using `DISPLAY_COLOR`. No newline. |
| **20** | `DisplayLn` | Prints `DISPLAY_BUFFER` using `DISPLAY_COLOR` followed by a newline. |
| **21** | `ReadBlock` | Reads block number `REG_B` from disk named in `REG_A` into `REG_RES`. |
| **22** | `WriteBlock` | Writes data `REG_C` to block `REG_B` of disk `REG_A`. |
| **23** | `SetBackgroundColor` | Sets terminal background color from `REG_A`. |
| **24** | `RenderBitmap` | Renders a bitmap from RAM range [`REG_A`, `REG_B`] at coordinates (`REG_C`, `REG_D`). |
| **29** | `Nop` | No Operation. If `REG_A` is a number, sleeps for that many seconds. |
| **30** | `Halt` | Stops the CPU execution and dumps RAM. |

### Example: Adding Two Numbers

In this architecture, you cannot hardcode literals like `add 5, 3`. You must define your data in memory (usually at the end of your program or in a data block) and reference it.

**Data Layout (Hypothetical):**

* Address 100 contains "5"
* Address 101 contains "10"
* Address 102 contains "0" (The code for OP_ADD)
* Address 50 is our variable `result`

**Assembly Code:**

```bash
1 100 1   # Copy value at addr 100 ("5") to REG_A (Addr 1)
1 101 2   # Copy value at addr 101 ("10") to REG_B (Addr 2)
1 102 7   # Copy value at addr 102 ("0") to REG_OP (Addr 7)
0         # CpuExec: Reads REG_OP (0), performs Add. REG_RES now holds "15"
1 8 50    # Copy value from REG_RES (Addr 8) to target variable at Addr 50
```

### Example: Conditional Logic

**Data Layout:**

* Address 200 contains "8" (The code for OP_CMP_EQ)

**Assembly Code:**

```bash
# ... assume REG_A and REG_B are already loaded ...
1 200 7   # Copy value at addr 200 ("8") to REG_OP
0         # CpuExec: executes CMP_EQ. REG_BOOL_RES is now "1" or "0"
3 100     # JumpIf: if REG_BOOL_RES is "1", jump to instruction at address 100
```

---

# Part 3: Assembly Language & Programming Patterns

Programming in KaguOS Bare Metal Edition involves writing "machine code" directly into text files. Since the system treats memory as text, this serves as a simplified assembly language.

## 3.1. Program Memory Layout

When writing kernel-level programs (like the examples provided), you must understand where your code lives in memory.

* **Kernel Start:** The standard entry point for programs is address **41** (`KERNEL_START`).
* **Sequential Execution:** The CPU executes instructions one by one, starting at 41, then 42, 43, and so on.
* **Absolute Addressing:** There are no labels or relative jumps (e.g., `jump +5`). You must calculate the exact RAM address for your jumps and data references.
* *Tip:* If your data is on the 5th line of your code, and your code starts at 41, the data is at `41 + (5 - 1) = 45`.

## 3.2. Critical: Code vs. Data Placement

The CPU does not distinguish between "instruction" strings and "data" strings. It simply tries to execute whatever text is in the current memory cell.

* **The Crash Scenario:** If you place the text `"Hello"` in the middle of your instructions, the CPU will try to execute it as a command and crash.
* **Comments:**
  * **Instructions:** You can use `#` for comments (e.g., `1 44 7 # Copy op`). The emulator ignores text after `#`.
  * **Data:** You **cannot** use comments on data lines. The `#` will be treated as part of the string.

To manage this, use one of two strategies:

### Strategy 1: Data at the End

Best for simple, linear programs. Place all instructions first, end with a `Halt`, and place data lines after execution stops.

**Example Layout (starting at RAM 41):**

```bash
1 44 12           # [41] Copy "Hello" (from RAM 44) to DisplayBuffer
1 45 7            # [42] Copy OP_DISPLAY_LN (from RAM 45) to REG_OP
0                 # [43] cpu_exec
1 46 7            # [44] Copy OP_HALT (from RAM 46) to REG_OP
0                 # [45] cpu_exec (System stops here)
Hello
20
30
```

### Strategy 2: Jump Over Data

Best for complex programs. Place data at the top so addresses are fixed and easy to calculate, but use a `Jump` instruction to skip over them immediately.

**Example Layout (starting at RAM 41):**

```bash
2 45              # [41] Jump to start of code (RAM 45)
Hello
1
20
1 42 12           # [45] [Code Start] Copy "Hello" to DisplayBuffer
1 43 13           # [46] Copy Color to DisplayColor
1 44 7            # [47] Copy OP code to REG_OP
0                 # [48] cpu_exec
...
```

## 3.3. Addressing Modes

The `copy` instruction (`1`) supports two powerful addressing modes:

| Syntax | Name | Example | Description |
| --- | --- | --- | --- |
| `N` | **Direct** | `1 44 1` | "Go to address 44. Read the text there. Copy it to address 1." |
| `*N` | **Indirect** | `1 *5 1` | "Go to address 5. Read the number stored there (e.g., '100'). Go to address 100. Read the text there. Copy it to address 1." |

**Use Case for Indirect:** Indirect addressing allows you to implement pointers and array traversal. If `REG_E` (Addr 5) holds a "cursor" value, `1 *5 1` reads the memory cell that the cursor points to.

## 3.4. Common Programming Patterns

### 1. Loading Constants

You cannot write literal values in instructions (e.g., you cannot say `copy "Hello" to 1`). You must store the constant in a RAM cell (Data Section) and copy it.

* **Step 1:** Define the constant in your data section (e.g., at RAM 100 put `5`).
* **Step 2:** Use the copy command: `1 100 1` (Copies value "5" from 100 to Register A).

### 2. The Loop Pattern

To create a loop (e.g., "print 5 times"), you need a counter variable in RAM and a conditional jump.

**Algorithm:**

1. **Initialize:** Copy a "0" from data section to a RAM cell (your counter).
2. **Label Start:** (Remember this address).
3. **Compare:** Load counter and limit to registers. Execute `OP_CMP_LT` (Less Than).
4. **Check:** Execute `4 <End_Addr>` (JumpIfNot: if comparison was false, exit loop).
5. **Action:** Perform your task (e.g., print).
6. **Increment:** Load counter to `REG_A`. Execute `OP_INCR`. Save result back to counter.
7. **Loop:** Execute `2 <Start_Addr>` (Jump to start).
8. **Label End:** Continue execution.

### 3. Error Handling

KaguOS provides a dedicated error register (`REG_ERROR`, Addr 10). Critical operations like reading a disk block will write to this register if they fail.

**Pattern:**

```bash
# ... setup and execute OP_READ_BLOCK ...
5 99    # JumpErr: If REG_ERROR is not empty, jump to error handler at address 99
```

---

# Part 4: The Boot Process (Boot Flow)

KaguOS Bare Metal Edition simulates a realistic multi-stage boot process. Understanding this chain is critical because, unlike writing a simple script, your code must "wake up" the machine and pull itself into memory.

**NOTE:** You can use the default boot components(mbr, bootloader and kernel from `hw/samples` folder) to build a `bootable.disk`
```bash
./build_bootable_disk.sh hw/samples/kernel.data
```

## 4.1. The Boot Chain Overview

The system does not magically run your kernel. It follows a strict chain of trust and loading:

1. **Stage 0: Firmware (BIOS/UEFI Equivalent)** - Initial hardware setup and MBR loading.
2. **Stage 1: MBR (Master Boot Record)** - The first 50 lines of the disk. Finds the Bootloader.
3. **Stage 2: Bootloader** - A smarter program that finds, verifies, and loads the Kernel.
4. **Stage 3: Kernel** - The core part of your operating system.

## 4.2. Stage 0: Firmware (The Reset Vector)

When you run `./kagu_boot`, the emulator "powers on" and loads `hw/cpu_firmware.bin` into the **Firmware Zone** (RAM 1-40). Current version of firmware expect `hw/bootable.disk` to exist and follow a special disk format.

* **Reset Vector:** The Program Counter (`PC`) is initialized to **18** (value read from line 16 of the firmware file).
* **Execution Start:** The CPU immediately increments the PC. The first instruction executed is at address **19**.
* **Jump to Routine:** Address 19 contains the instruction `2 23`, which jumps to the **Disk Copy Loop** starting at address 23.

**The Disk Copy Loop (RAM 23-40):**
This is a small utility routine built into the "motherboard". It reads blocks from the disk and writes them to RAM based on specific registers. It uses registers from C to F as the input data:

* **`REG_C`**: Disk Name (e.g., `bootable.disk` which should be placed in `hw` folder).
* **`REG_D`**: Start Block on Disk.
* **`REG_E`**: End Block Number (Allows to determine how many blocks to read/where to stop).
* **`REG_F`**: Target RAM Address.


**Default Boot Behavior:**
By default, the firmware is configured to load the MBR (Master Boot Record) from the disk into `RAM[41]` and then pass control to it.

## 4.3. Stage 1: MBR (Master Boot Record)

* **Location on Disk:** Lines 2 to 51 (Fixed size: 50 lines).
* **Location in RAM:** Loaded at `RAM[41]` (`KERNEL_START`).
* **Role:** The MBR is a small, fixed-size program. Its primary job is to find the Bootloader.

**How MBR Works (`hw/samples/mbr.data`):**

1. **Read Header:** It checks for the "KAGU BOOTLOADER" signature on the disk (Line 52).
2. **Get Size:** It reads the bootloader size from Line 53.
3. **Chain Load:** It calculates the start and end blocks for the bootloader.
4. **Reuse Firmware:** The MBR reuses the firmware's code. It sets up `REG_C` (disk), `REG_D` (start block), `REG_E` (end block), and `REG_F` (RAM destination), then executes `2 23` to jump back into the firmware's Disk Copy Loop. This loads the bootloader into memory immediately after the MBR.

## 4.4. Stage 2: The Bootloader

* **Location on Disk:** Starts at Line 54 (Block 53).
* **Role:** User interface, verification, and kernel loading.

**How Bootloader Works (`hw/samples/bootloader.data`):**

1. **UI:** Displays "Welcome to Kagu bootloader!".
2. **Verify Kernel:** Scans the disk for the "KAGU KERNEL" signature.
3. **Load Kernel:** Reads the kernel size, calculates block ranges, sets up registers (including `REG_F`), and again uses `2 23` to jump to the firmware to load the kernel.
4. **Handover:** Finally, it jumps to the Kernel's entry point.

## 4.5. Stage 3: The Kernel

* **Location:** Loaded into RAM after the Bootloader.
* **Entry Point:** The first line of your kernel code.
* **Execution:** You now have full control of the machine.

## 4.6. Building a Bootable Disk

To create a valid disk image that works with this boot chain, use the provided build scripts.

* **Script:** `./build_bootable_disk.sh` (or `.ps1`).
* **Usage:** `./build_bootable_disk.sh <kernel_path> [bootloader_path] [mbr_path]`.
* **Function:** This script combines your kernel code with a standard MBR and Bootloader (defaulting to `hw/samples/mbr.data` and `hw/samples/bootloader.data` if not specified). It calculates the correct line counts and headers required for the boot process to succeed.

## 4.7. Quick Boot / Testing

For simple experiments or debugging specific code snippets, you do not need to build a full bootable disk or go through the MBR/Bootloader chain.

* **Direct Loading:** You can treat the `cpu_firmware` file as a simple "memory snapshot" loader.
* **Method:** Create a text file that contains your program code directly. When running `./kagu_boot my_program.txt 100`, the emulator loads this file into RAM starting at address 1.
* **Reset Vector Trick:** Since the PC starts at 18 and increments to 19, ensure your test code handles this flow (e.g., by placing your code around these addresses or using the standard firmware structure to jump to your code). This is how `examples/cpu_firmware/01_halt.txt` works—it is a minimal "firmware" that just executes a few instructions.

---

# Part 5: Toolchain & Build System

## 5.1. The Build Script (`build_bootable_disk.sh`)

Building a bootable disk manually (by copy-pasting lines) is error-prone. The project includes a dedicated build script that automates the assembly of the MBR, Bootloader, and Kernel components.

* **Script:** `build_bootable_disk.sh` (or `build_bootable_disk.ps1` for PowerShell).
* **Output:** Creates `hw/bootable.disk` with the strict formatting required by the boot process.

**How it Works:**

1. **Validation:** Ensures the MBR is exactly 50 lines long, which is a hardware/firmware requirement.
2. **Assembly:** Concatenates components in the specific order: Total Line Count -> MBR -> Bootloader Signature & Size -> Bootloader Data -> Kernel Signature & Size -> Kernel Data.
3. **Headers:** Automatically inserts required signatures (like "KAGU BOOTLOADER") and calculates line counts so the MBR logic can successfully find the next stage.

**Usage:**

```bash
# Basic usage (uses default MBR/Bootloader samples)
./build_bootable_disk.sh my_kernel.data

# Custom usage (specify your own bootloader or MBR)
./build_bootable_disk.sh my_kernel.data my_bootloader.data my_mbr.data
```

## 5.2. Debugging Tools

Since KaguOS is a "Bare Metal" emulator, standard debuggers like GDB are not applicable to the guest code. Instead, you use the hardware inspection tools built directly into the emulator.

### Debug Flags (`-d`, `-j`, `-s`)

When launching `kagu_boot`, you can enable flags to trace execution and inspect the machine state:

* **`-d` (Debug Mode):** Dumps the entire state of RAM to `tmp/RAM.txt` after *every* instruction step. This allows you to inspect the memory exactly as it was when execution paused or crashed.
* **`-j` (Jump Trace):** Prints the current instruction being executed to the console. This provides a real-time log of the program flow, which is essential for tracing loops and jumps.
* **`-s <ms>` (Sleep/Step):** Adds a delay (in milliseconds) between instructions. This slows down execution, allowing you to watch the program behavior in "slow motion".

**Example Debug Session:**

```bash
./kagu_boot hw/cpu_firmware.bin 100 -d -j -s 500
```

### Inspecting `tmp/RAM.txt`

If your kernel crashes (or Halts unexpectedly), the `tmp/RAM.txt` file serves as your "core dump".

* **Lines 1-11:** Inspect User Registers (`REG_A`, `REG_OP`, `REG_RES`) to see the inputs and results of the last operation.
* **Lines 12-18:** Check System Registers, specifically `PROGRAM_COUNTER` (to see where execution stopped) and `REG_ERROR` (to see if a system error occurred).
* **Line 41+:** Inspect the Code Space to verify that your kernel code was loaded into memory correctly.

## 5.3. CMake Build System

The emulator itself is built using CMake.

* **Target:** `kagu_boot` (The emulator executable).
* **Library:** `libkagu` (Shared headers for constants and configuration).
* **Installation:** The `install_to_root` target automatically copies the compiled binary from `build/bin/` to the project root directory, ensuring the run commands work as documented.

**Rebuilding the Emulator:**
If you modify the C++ source code (e.g., adding a new CPU operation), you must rebuild the emulator:

```bash
cd tools/build
make
```

---

# Part 6: Practical Workshops

Now that you understand the architecture and tools, it is time to write code. These workshops progress from basic hardware manipulation to full OS development using the build tools.

## Lab 1: "Hello Kagu" (The RAM Snapshot)

**Objective:** Write a minimal program that runs directly on the "bare metal" by creating a custom **Reset Vector**.

**Concept:**
When KaguOS starts, it loads the firmware file into RAM.

* **System Reserved:** Addresses **1-18** are memory-mapped registers. Specifically, `RAM[16]` is the Program Counter, `RAM[17]` is Energy, and `RAM[18]` is Free Memory.
* **Safe Zone:** The first safe place to put custom firmware code is **Address 19**.
* **Reset Vector:** We set `RAM[16]` to **18**. The CPU increments this to **19** and fetches the first instruction from there.

**The Code (`hello_firmware.txt`):**

Create a text file with first 15 empty lines and paste the following content starting from the line 16. Note the placeholders for lines 17 and 18.

```bash
18
0
0
1 25 12  # [19] Copy "Hello_Kagu!" (at line 25) to DISPLAY_BUFFER (12)
1 26 13  # [20] Copy Color Green (at line 26) to DISPLAY_COLOR (13)
1 27 7   # [21] Copy OP_DISPLAY_LN (at line 27) to REG_OP (7)
0        # [22] cpu_exec
1 28 7   # [23] Copy OP_HALT (at line 28) to REG_OP (7)
0        # [24] cpu_exec
Hello_Kagu!
1
20
30
```

**Run It:**

```bash
./kagu_boot hello_firmware.txt 100
```

## Lab 2: The Echo Chamber (Input/Output)

**Objective:** Write a program that asks for user input and then prints it back to the screen (an "echo" program). Like Lab 1, we will run this directly as a custom firmware snapshot.

**Concept:**
We will use the **I/O Registers** defined in the hardware reference:

* **`KEYBOARD_BUFFER` (Address 14):** Used to set the input mode (e.g., "KeyboardReadLine") and to receive the typed text.
* **`DISPLAY_BUFFER` (Address 12):** Where we put text to show on screen.
* **`REG_OP` (Address 7):** Where we put the operation code.

**The Code (`echo_firmware.txt`):**

Create a text file with first 15 empty lines and paste the following content starting from the line 16. We start code execution at **Line 19** to avoid the reserved system registers at 17 and 18.

**Note:** Be careful with the data addresses (28-32). They correspond to the physical line numbers in the file.

```bash
18
0
0
1 28 14  # [19] Setup Input Mode: Copy "KeyboardReadLine" (at line 28) to BUFFER (14)
1 29 7   # [20] Copy OP_READ_INPUT (at line 29) to REG_OP (7)
0        # [21] cpu_exec (System waits for user to type and press Enter)
1 14 12  # [22] Copy result from KEYBOARD_BUFFER (14) to DISPLAY_BUFFER (12)
1 30 13  # [23] Copy Color Cyan (at line 30) to DISPLAY_COLOR (13)
1 31 7   # [24] Copy OP_DISPLAY_LN (at line 31) to REG_OP (7)
0        # [25] cpu_exec (Print the text)
1 32 7   # [26] Copy OP_HALT (at line 32) to REG_OP (7)
0        # [27] cpu_exec (Halt)
1
18
7
20
30
```

**Run It:**

Run the following command, type some text and press Enter:
```bash
./kagu_boot echo_firmware.txt 100
```

## Lab 3: Pixel Art (Graphics Kernel)

**Objective:** Use graphics operations to set background color and draw animated multi-colored graphics on the screen.

**New Operations:**

| Operation | Code | Description |
|-----------|------|-------------|
| `OP_SET_BACKGROUND_COLOR` | 23 | Sets the canvas background color. Reads color code from `REG_A`. The background will be visible when rendering bitmaps or clearing the screen. |
| `OP_RENDER_BITMAP` | 24 | Draws a bitmap on screen. Reads start address from `REG_A`, end address (exclusive) from `REG_B`, X coordinate from `REG_C`, Y coordinate from `REG_D`. Each row of bitmap data is a string of color characters. |
| `OP_NOP` | 29 | No operation / sleep. If `REG_A` contains a number, sleeps for that many seconds. Useful for creating delays and simple animations. |

**Color Codes for Bitmaps:**

| Char | Color |
|------|-------|
| `r` | Red |
| `g` | Green |
| `b` | Blue |
| `y` | Yellow |
| `m` | Magenta |
| `c` | Cyan |
| `w` | White |
| `B` | Black |
| `o` | Orange |
| `n` | No color (transparent) |

**Color Codes for Background (numeric):**

| Code | Color |
|------|-------|
| 0 | Default (no color) |
| 1 | Green |
| 2 | Yellow |
| 3 | Red |
| 4 | Black |
| 5 | Blue |
| 6 | Magenta |
| 7 | Cyan |
| 8 | White |

**Concepts:**

* **Background Color:** The `OP_SET_BACKGROUND_COLOR` operation sets the canvas background from `REG_A`. When followed by bitmap rendering, areas outside the bitmap will be filled with this color.
* **Bitmap Data:** We store rows of color codes (e.g., `rrrr` for red, `gggg` for green) in the data section. Each character represents one pixel.
* **Rendering:** The `OP_RENDER_BITMAP` operation reads bitmap rows from RAM between start and end addresses, then draws them at the specified screen position.
* **Animation:** By using `OP_NOP` with a delay value in `REG_A`, we can pause execution and create simple animations by rendering multiple bitmaps sequentially.
* **Pointers:** Since we cannot put raw numbers like "35" directly into the instruction, we must store the address values (pointers) in the data section and copy them to registers.

**The Code (`art_firmware.txt`):**

Create a text file with first 15 empty lines and paste the following content starting from line 16.

**Logic:** The code sets a blue background, renders the first bitmap, waits 1 second, renders a second bitmap at a different position, then halts.

**Memory Layout:**

| Lines | Content |
|-------|---------|
| 1-15 | Reserved for registers (empty) |
| 16 | Program Counter (18) |
| 17-18 | Empty |
| 19-37 | Instructions |
| 38-41 | Bitmap data (4 rows) |
| 42-55 | Constants |
So copy this code starting from the line 16
```
18


1 43 1   # [19] Copy background color "5" to REG_A
1 44 7   # [20] Copy OP_SET_BACKGROUND_COLOR "23" to REG_OP
0        # [21] cpu_exec: set background to blue
1 45 1   # [22] Copy bitmap1 start addr "39" to REG_A
1 46 2   # [23] Copy bitmap1 end addr "41" to REG_B
1 47 3   # [24] Copy X coord "5" to REG_C
1 48 4   # [25] Copy Y coord "2" to REG_D
1 49 7   # [26] Copy OP_RENDER_BITMAP "24" to REG_OP
0        # [27] cpu_exec: render first bitmap at (5, 2)
1 50 1   # [28] Copy sleep duration "1" to REG_A
1 51 7   # [29] Copy OP_NOP "29" to REG_OP
0        # [30] cpu_exec: sleep for 1 second
1 52 1   # [31] Copy bitmap2 start addr "41" to REG_A
1 53 2   # [32] Copy bitmap2 end addr "43" to REG_B
1 54 3   # [33] Copy X coord "12" to REG_C
1 55 4   # [34] Copy Y coord "12" to REG_D
1 49 7   # [35] Copy OP_RENDER_BITMAP "24" to REG_OP
0        # [36] cpu_exec: render second bitmap at (20, 5)
1 56 7   # [37] Copy OP_HALT "30" to REG_OP
0        # [38] cpu_exec: halt
rrrrggggmmmm
ggggmmmmyyyy
yyyymmmmcccc
mmmmccccwwww
5
23
39
41
5
2
24
1
29
41
43
20
5
30
```

**Data Section Reference (lines 42-55):**

| Line | Value | Used For |
|------|-------|----------|
| 42 | 5 | Background color (blue) |
| 43 | 23 | OP_SET_BACKGROUND_COLOR |
| 44 | 38 | First bitmap start address |
| 45 | 40 | First bitmap end address |
| 46 | 5 | First bitmap X coordinate |
| 47 | 2 | First bitmap Y coordinate |
| 48 | 24 | OP_RENDER_BITMAP |
| 49 | 1 | Sleep duration (seconds) |
| 50 | 29 | OP_NOP |
| 51 | 40 | Second bitmap start address |
| 52 | 42 | Second bitmap end address |
| 53 | 20 | Second bitmap X coordinate |
| 54 | 5 | Second bitmap Y coordinate |
| 55 | 30 | OP_HALT |

**Run It:**
```bash
./kagu_boot art_firmware.txt 100
```

**Expected Result:**

1. Screen fills with blue background
2. First bitmap (red/green/blue pattern) appears at position (5, 2)
3. After 1 second pause...
4. Second bitmap (yellow/magenta/cyan/white pattern) appears at position (20, 5)
5. Program halts

**Experiment Ideas:**

* Change background color code from `5` (blue) to `3` (red) or `2` (yellow)
* Modify bitmap data to create your own pixel art patterns
* Add more sleep/render cycles to create longer animations
* Try overlapping bitmaps by using the same coordinates

---

# Part 7: KaguOS Cheat Sheet

## 7.1. Memory Map

| Address | Name | Purpose |
| --- | --- | --- |
| **1 - 6** | `REG_A` .. `REG_F` | General Purpose Operands |
| **7** | `REG_OP` | Operation Code Register |
| **8** | `REG_RES` | Result Register (Math/String) |
| **9** | `REG_BOOL` | Boolean Result (1=True, 0=False) |
| **10** | `REG_ERR` | Error Message Register |
| **12** | `DISPLAY_BUF` | Output Buffer |
| **13** | `DISPLAY_COL` | Text Color (0-8) |
| **14** | `KEYBOARD_BUF` | Input Buffer / Mode Set |
| **15** | `DISPLAY_BACKGROUND` | Background Color |
| **16** | `PC` | Program Counter |

## 7.2. Instruction List (Control Flow)

| Code | Syntax | Action |
| --- | --- | --- |
| **0** | `0` | **Execute** operation in `REG_OP` |
| **1** | `1 src dest` | **Copy** value from `src` to `dest` |
| **2** | `2 addr` | **Jump** to `addr` |
| **3** | `3 addr` | **Jump if True** (`REG_BOOL` == 1) |
| **4** | `4 addr` | **Jump if False** (`REG_BOOL` == 0) |
| **5** | `5 addr` | **Jump if Error** (`REG_ERR` != "") |
| **6** | `6 mode` | **Debug** mode on/off |

## 7.3. Operation Codes (Load into `REG_OP`)

| ID | Name | Description |
| --- | --- | --- |
| **0** | `Add` | `A + B` -> `RES` |
| **1** | `Sub` | `A - B` -> `RES` |
| **2** | `Incr` | `A + 1` -> `RES` |
| **3** | `Decr` | `A - 1` -> `RES` |
| **8** | `CmpEq` | `A == B` -> `BOOL` |
| **10** | `CmpLt` | `A < B` -> `BOOL` |
| **18** | `ReadInput` | Wait for User Input |
| **20** | `DisplayLn` | Print `DISPLAY_BUF` + Newline |
| **21** | `ReadBlock` | Read Disk `A`, Block `B` -> `RES` |
| **24** | `Render` | Draw Bitmap (A=Start, B=End, C=X, D=Y) |
| **30** | `Halt` | Stop execution |

## 7.4. Colors

### Colors

| Color Name | Code | Bitmap Symbol |
|------------|------|---------------|
| No color   | 0    | n             |
| Green      | 1    | g             |
| Yellow     | 2    | y             |
| Red        | 3    | r             |
| Black      | 4    | B             |
| Blue       | 5    | b             |
| Magenta    | 6    | m             |
| Cyan       | 7    | c             |
| White      | 8    | w             |
| Orange     | -    | o             |

**Note:** Orange is only available in bitmaps (symbol 'o'), not as a text color code.

---

*KaguOS - Educational OS for learning low-level programming*
