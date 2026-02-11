/**
 * @file kagu.hpp
 * @brief KaguOS - Main include header for libkagu
 * 
 * Include this single header to get access to all KaguOS constants,
 * types, and utilities.
 * 
 * Library Structure:
 * - types.hpp     : Fundamental type aliases (RamAddress, RamCell, etc.)
 * - registers.hpp : Memory-mapped register addresses (Address enum)
 * - opcodes.hpp   : CPU instructions and operations (Instruction, Operation)
 * - syscalls.hpp  : System call definitions (SysCall enum)
 * - colors.hpp    : Terminal colors and ANSI codes (Color enum)
 * - keyboard.hpp  : Keyboard input modes (KeyboardMode enum)
 * - config.hpp    : System configuration constants
 * 
 * Example usage:
 * @code
 *   #include <kagu/kagu.hpp>
 *   
 *   using namespace kagu;
 *   
 *   // Get register address (new compact layout)
 *   int opAddr = toInt(Address::Op);  // Returns 1
 *   int regA = toInt(Address::A);     // Returns 2
 *   
 *   // Check operation privileges
 *   bool priv = isPrivileged(Operation::Display);  // Returns true
 *   
 *   // Format colored output
 *   std::cout << colorize("Success!", Color::Green);
 *   
 *   // Get register name for debugging
 *   const char* name = getRegisterName(Address::LastKey);  // "REG_LAST_KEY"
 * @endcode
 */

#pragma once

// Core types and utilities
#include "types.hpp"

// Memory-mapped registers
#include "registers.hpp"

// CPU instructions and operations
#include "opcodes.hpp"

// System calls
#include "syscalls.hpp"

// Terminal colors
#include "colors.hpp"

// Keyboard input modes
#include "keyboard.hpp"

// System configuration
#include "config.hpp"

namespace kagu
{

/**
 * @brief Library version information
 */
struct Version
{
    int major = 1;
    int minor = 1;
    int patch = 0;
    
    /**
     * @brief Check if current version is at least the specified version
     * @param maj Major version
     * @param min Minor version (default 0)
     * @param pat Patch version (default 0)
     * @return true if current version >= specified version
     */
    [[nodiscard]] constexpr bool isAtLeast(int maj, int min = 0, int pat = 0) const noexcept
    {
        if (major != maj) return major > maj;
        if (minor != min) return minor > min;
        return patch >= pat;
    }
    
    /**
     * @brief Get version string
     * @return Version as "major.minor.patch"
     */
    [[nodiscard]] std::string toString() const
    {
        return std::to_string(major) + "." + 
               std::to_string(minor) + "." + 
               std::to_string(patch);
    }
};

/// Global library version constant
constexpr Version VERSION = {};

} // namespace kagu
