/**
 * @file keyboard.hpp
 * @brief KaguOS - Keyboard input modes
 * 
 * Defines keyboard input modes that can be written to KEYBOARD_BUFFER
 * register before executing OP_READ_INPUT operation.
 */

#pragma once

#include "types.hpp"
#include <string_view>

namespace kagu
{

// ============================================================================
// Keyboard Input Modes
// ============================================================================

/**
 * @brief Keyboard input mode for OP_READ_INPUT operation
 * 
 * Set the mode in KEYBOARD_BUFFER register before executing OP_READ_INPUT.
 * The result will be stored back in KEYBOARD_BUFFER.
 * 
 * Usage:
 * @code
 *   write KEYBOARD_READ_LINE to KEYBOARD_BUFFER
 *   write OP_READ_INPUT to REG_OP
 *   cpu_exec
 *   // Result now in KEYBOARD_BUFFER
 * @endcode
 */
enum class KeyboardMode : int
{
    /// Read a full line (with echo) - blocks until Enter
    ReadLine = 0,
    
    /// Read a full line without echo (for passwords)
    ReadLineSilently = 1,
    
    /// Read a single character (with echo)
    ReadChar = 2,
    
    /// Read a single character without echo
    ReadCharSilently = 3
};

// ============================================================================
// Keyboard Mode Utility Functions
// ============================================================================

/**
 * @brief Get string value for keyboard mode (used in KEYBOARD_BUFFER)
 * @param mode Keyboard mode
 * @return String identifier for the mode
 */
[[nodiscard]] constexpr std::string_view keyboardModeValue(KeyboardMode mode) noexcept
{
    switch (mode)
    {
        case KeyboardMode::ReadLine:
            return "KeyboardReadLine";
        case KeyboardMode::ReadLineSilently:
            return "KeyboardReadLineSilently";
        case KeyboardMode::ReadChar:
            return "KeyboardReadChar";
        case KeyboardMode::ReadCharSilently:
            return "KeyboardReadCharSilently";
        default:
            return "KeyboardReadLine";
    }
}

/**
 * @brief Parse keyboard mode from string value
 * @param value String value from KEYBOARD_BUFFER
 * @return Corresponding keyboard mode (defaults to ReadLine)
 */
[[nodiscard]] inline KeyboardMode parseKeyboardMode(std::string_view value) noexcept
{
    if (value == "KeyboardReadLine" || value == "KEYBOARD_READ_LINE")
        return KeyboardMode::ReadLine;
    if (value == "KeyboardReadLineSilently" || value == "KEYBOARD_READ_LINE_SILENTLY")
        return KeyboardMode::ReadLineSilently;
    if (value == "KeyboardReadChar" || value == "KEYBOARD_READ_CHAR")
        return KeyboardMode::ReadChar;
    if (value == "KeyboardReadCharSilently" || value == "KEYBOARD_READ_CHAR_SILENTLY")
        return KeyboardMode::ReadCharSilently;
    return KeyboardMode::ReadLine;
}

} // namespace kagu
