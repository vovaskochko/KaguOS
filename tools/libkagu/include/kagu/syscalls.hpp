/**
 * @file syscalls.hpp
 * @brief KaguOS - System call definitions
 * 
 * System calls are the interface between user programs and the kernel.
 * 
 * Usage from user space:
 * 1. Set arguments in registers A, B, C
 * 2. Set syscall number in register D
 * 3. Execute Operation::SysCall
 * 4. Result in Res register, error in Error register
 * 
 * Example (print "Hello"):
 * @code
 *   write "Hello" to REG_A
 *   write COLOR_GREEN to REG_B
 *   write SYS_CALL_PRINTLN to REG_D
 *   write OP_SYS_CALL to REG_OP
 *   cpu_exec
 * @endcode
 */

#pragma once

#include "types.hpp"

namespace kagu
{

// ============================================================================
// System Call Numbers
// ============================================================================

/**
 * @brief System call numbers
 * 
 * System call table:
 * 
 * | Call | Name            | REG_A          | REG_B        | REG_C     | REG_RES        | REG_ERROR |
 * |------|-----------------|----------------|--------------|-----------|----------------|-----------|
 * | 0    | exit            | exit code      | -            | -         | -              | -         |
 * | 1    | println         | text           | color code   | -         | -              | -         |
 * | 2    | print           | text           | color code   | -         | -              | -         |
 * | 3    | read_input      | keyboard mode  | -            | -         | input string   | -         |
 * | 4    | open            | file path      | -            | -         | file descriptor| error     |
 * | 5    | descriptor_info | file descriptor| -            | -         | file info      | error     |
 * | 6    | close           | file descriptor| -            | -         | -              | error     |
 * | 7    | read            | file descriptor| line number  | -         | read line      | EOF/error |
 * | 8    | write           | file descriptor| line number  | new value | -              | error     |
 * | 9    | set_background  | background clr | -            | -         | -              | -         |
 * | 10   | render_bitmap   | start address  | end address  | -         | -              | -         |
 * | 11   | sleep           | seconds        | -            | -         | -              | -         |
 * | 12   | get_file_attr   | file descriptor| -            | -         | "7 7 7 u g"    | error     |
 * | 13   | set_file_attr   | file descriptor| "4 4 0 u g"  | -         | -              | error     |
 * | 14   | sched_program   | command line   | priority     | -         | process ID     | error     |
 * | 15   | is_process_active| pid           | -            | -         | process info   | error     |
 * | 16   | kill_process    | pid to kill    | -            | -         | -              | error     |
 * | 17   | skip_sched      | -              | -            | -         | -              | error     |
 * | 18   | wait_sched      | -              | -            | -         | -              | error     |
 */
enum class SysCall : int
{
    // ========================================================================
    // Process Control (0)
    // ========================================================================
    
    /// Exit current process
    /// A = exit code (0 = success)
    Exit = 0,
    
    // ========================================================================
    // I/O Operations (1-3)
    // ========================================================================
    
    /// Print text with newline
    /// A = text to print, B = color code
    PrintLn = 1,
    
    /// Print text without newline
    /// A = text to print, B = color code
    Print = 2,
    
    /// Read input from keyboard
    /// A = keyboard mode (ReadLine, ReadChar, etc.)
    /// Result: Res = input string
    ReadInput = 3,
    
    // ========================================================================
    // File Operations (4-8)
    // ========================================================================
    
    /// Open file
    /// A = file path (absolute or relative)
    /// Result: Res = file descriptor
    Open = 4,
    
    /// Get file descriptor info
    /// A = file descriptor
    /// Result: Res = "path disk headerBlock size"
    DescriptorInfo = 5,
    
    /// Close file
    /// A = file descriptor
    Close = 6,
    
    /// Read line from file
    /// A = file descriptor, B = line number (1-based)
    /// Result: Res = line content
    Read = 7,
    
    /// Write line to file
    /// A = file descriptor, B = line number, C = new value
    Write = 8,
    
    // ========================================================================
    // Display Operations (9-10)
    // ========================================================================
    
    /// Set terminal background color
    /// A = color code
    SetBackground = 9,
    
    /// Render bitmap from memory region
    /// A = start address, B = end address
    /// Addresses are relative to process memory
    RenderBitmap = 10,
    
    // ========================================================================
    // Timing (11)
    // ========================================================================
    
    /// Sleep for specified duration
    /// A = seconds (can be decimal, e.g., "0.5")
    Sleep = 11,
    
    // ========================================================================
    // File Attributes (12-13)
    // ========================================================================
    
    /// Get file attributes/permissions
    /// A = file descriptor
    /// Result: Res = "owner_r owner_w owner_x group_r ... user group"
    GetFileAttr = 12,
    
    /// Set file attributes/permissions
    /// A = file descriptor, B = new attributes
    SetFileAttr = 13,
    
    // ========================================================================
    // Process Scheduling (14-18)
    // ========================================================================
    
    /// Schedule new program for execution
    /// A = command line (program and args)
    /// B = priority (higher = more CPU time)
    /// Result: Res = process ID
    SchedProgram = 14,
    
    /// Check if process is active
    /// A = process ID
    /// Result: Res = process control block info
    IsProcessActive = 15,
    
    /// Kill process
    /// A = process ID to terminate
    KillProcess = 16,
    
    /// Skip current scheduling quantum
    /// Forces immediate context switch
    SkipSched = 17,
    
    /// Wait/pause until other processes complete
    /// Current process enters "pause" state
    WaitSched = 18
};

// ============================================================================
// System Call Utility Functions
// ============================================================================

/**
 * @brief Get the total number of implemented system calls
 * @return Number of system calls
 */
[[nodiscard]] constexpr int getSysCallCount() noexcept
{
    return 19;  // 0-18
}

/**
 * @brief Check if syscall number is valid
 * @param num Syscall number to check
 * @return true if valid syscall number
 */
[[nodiscard]] constexpr bool isValidSysCall(int num) noexcept
{
    return num >= 0 && num < getSysCallCount();
}

/**
 * @brief Check if syscall is a file operation
 * @param sc System call to check
 * @return true if file-related syscall
 */
[[nodiscard]] constexpr bool isFileSysCall(SysCall sc) noexcept
{
    return sc >= SysCall::Open && sc <= SysCall::Write;
}

/**
 * @brief Check if syscall is a process control operation
 * @param sc System call to check
 * @return true if process-related syscall
 */
[[nodiscard]] constexpr bool isProcessSysCall(SysCall sc) noexcept
{
    return sc >= SysCall::SchedProgram && sc <= SysCall::WaitSched;
}

} // namespace kagu
