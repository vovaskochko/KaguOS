/**
 * @file registers.hpp
 * @brief KaguOS - Memory-mapped registers and buffer addresses
 * 
 * Architecture Notes:
 * - Addresses 1-11 are accessible from user space
 * - Addresses 12-18 are system registers (privileged I/O and memory management)
 * - Addresses 19-40 are firmware zone (bootstrap code, overwritten during boot)
 * - Address 41+ is available for kernel/user code
 */

#pragma once

#include "types.hpp"

namespace kagu
{

// ============================================================================
// Memory-Mapped Register Addresses
// ============================================================================

/**
 * @brief Memory-mapped register and buffer addresses
 * 
 * The KaguOS memory map is divided into:
 * - User registers (1-11): General purpose and basic I/O
 * - System registers (12-18): Privileged I/O and memory management
 * - Firmware zone (19-50): CPU microcode (overwritten by MBR during boot). It can be used after boot by kernel for its purpose.
 * - Code space (51+): MBR, bootloader, kernel, and user programs
 */
enum class Address : int
{
    // ========================================================================
    // User Space Registers (1-11)
    // ========================================================================

    /// General purpose register A (first operand)
    A = 1,

    /// General purpose register B (second operand)
    B = 2,

    /// General purpose register C (third operand)
    C = 3,

    /// General purpose register D (fourth operand)
    D = 4,

    /// General purpose register E (fifth operand)
    E = 5,

    /// General purpose register F (sixth operand)
    F = 6,

    /// Operation code for CPU execution
    Op = 7,

    /// Result register (operation output)
    Res = 8,

    /// Boolean result register (comparison output: "0" or "1")
    BoolRes = 9,

    /// Error register (error message or empty string)
    Error = 10,

    /// Last key pressed (non-blocking keyboard input, per-process)
    LastKey = 11,
    
    /// Last user-accessible register address
    UserSpaceEnd = 11,
    
    // ========================================================================
    // System Registers (12-18) - Privileged Access Only
    // ========================================================================

    /// Display buffer for terminal output
    DisplayBuffer = 12,

    /// Current display color code
    DisplayColor = 13,

    /// Keyboard input buffer / mode
    KeyboardBuffer = 14,

    /// Terminal background color
    DisplayBackground = 15,

    /// Current program counter (instruction address)
    ProgramCounter = 16,

    /// Register to accumulate energy consumption
    SysEnergy = 17,

    /// Last address of free memory region (set on power-on = RAM size)
    FreeMemoryEnd = 18,

    // ========================================================================
    // Firmware Zone (19-40) - Bootstrap Code
    // ========================================================================
    // This region contains CPU microcode loaded by emulator at power-on.
    // It includes constants, copy routines, and cleanup code.
    // This zone is overwritten by MBR during boot and can be reused by kernel.

    // After kernel boot this memory will be used as a service memory
    FreeMemoryStart = 19,
    FreeChunks = 20,
    ProcStartAddress = 21,
    ProcEndAddress = 22,
    SysCallHandler = 23,
    SysRetAddress = 24,
    SysInterruptHandler = 25,
    SysInterruptData = 26,
    SysHwTimer = 27,

    // ========================================================================
    // Code Space (41+)
    // ========================================================================

    /// First address of kernel code (MBR/bootloader/kernel starts here)
    KernelStart = 41
};

// ============================================================================
// Address Utility Functions
// ============================================================================

/**
 * @brief Check if address is a user-accessible register
 * @param addr Address to check
 * @return true if address is in user space (1-11)
 */
[[nodiscard]] constexpr bool isUserRegister(Address addr) noexcept
{
    int a = toInt(addr);
    return a >= 1 && a <= toInt(Address::UserSpaceEnd);
}

/**
 * @brief Check if address is a system register
 * @param addr Address to check
 * @return true if this is a system register address (12-18)
 */
[[nodiscard]] constexpr bool isSystemRegister(Address addr) noexcept
{
    int a = toInt(addr);
    return a >= toInt(Address::DisplayBuffer) && a <= toInt(Address::FreeMemoryEnd);
}

/**
 * @brief Check if address is in firmware zone
 * @param addr Address to check
 * @return true if address is in firmware zone (19-40)
 */
[[nodiscard]] constexpr bool isFirmwareZone(Address addr) noexcept
{
    int a = toInt(addr);
    return a >= 19 && a <= 40;
}

/**
 * @brief Check if address is in code space
 * @param addr Address to check
 * @return true if address is in code space (41+)
 */
[[nodiscard]] constexpr bool isCodeSpace(int addr) noexcept
{
    return addr >= toInt(Address::KernelStart);
}

/**
 * @brief Get register name for debugging/display
 * @param addr Address to get name for
 * @return String name of the register or nullptr if not a register
 */
[[nodiscard]] constexpr const char* getRegisterName(Address addr) noexcept
{
    switch (addr)
    {
        case Address::Op: return "REG_OP";
        case Address::A: return "REG_A";
        case Address::B: return "REG_B";
        case Address::C: return "REG_C";
        case Address::D: return "REG_D";
        case Address::E: return "REG_E";
        case Address::F: return "REG_F";
        case Address::Res: return "REG_RES";
        case Address::BoolRes: return "REG_BOOL_RES";
        case Address::Error: return "REG_ERROR";
        case Address::LastKey: return "REG_LAST_KEY";
        case Address::DisplayBuffer: return "DISPLAY_BUFFER";
        case Address::DisplayColor: return "DISPLAY_COLOR";
        case Address::KeyboardBuffer: return "KEYBOARD_BUFFER";
        case Address::DisplayBackground: return "DISPLAY_BACKGROUND";
        case Address::ProgramCounter: return "PROGRAM_COUNTER";
        case Address::SysEnergy: return "SYS_ENERGY";
        case Address::FreeMemoryEnd: return "FREE_MEMORY_END";
        case Address::KernelStart: return "KERNEL_START";
        default: return nullptr;
    }
}

/**
 * @brief Get register name for a raw address
 * @param addr Raw address value
 * @return String name of the register or nullptr if not a register
 */
[[nodiscard]] inline const char* getRegisterName(RamAddress addr) noexcept
{
    if (addr >= 1 && addr <= 27)
    {
        return getRegisterName(fromInt<Address>(addr));
    }
    return nullptr;
}

} // namespace kagu
