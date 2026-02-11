/**
 * @file colors.hpp
 * @brief KaguOS - Terminal colors and ANSI escape codes
 * 
 * Provides color definitions and ANSI escape sequences for
 * terminal display operations.
 * 
 * Usage:
 * @code
 *   std::cout << ansi::FG_GREEN << "Success!" << ansi::RESET;
 *   std::cout << colorize("Error", Color::Red);
 * @endcode
 */

#pragma once

#include "types.hpp"
#include <string>
#include <string_view>

namespace kagu
{

// ============================================================================
// Color Enumeration
// ============================================================================

/**
 * @brief Terminal color codes
 * 
 * These values are stored in DisplayColor register and
 * used by Display/DisplayLn operations.
 */
enum class Color : int
{
    /// Default/no color (reset)
    No = 0,
    
    /// Green text
    Green = 1,
    
    /// Yellow text
    Yellow = 2,
    
    /// Red text
    Red = 3,
    
    /// Black text
    Black = 4,
    
    /// Blue text
    Blue = 5,
    
    /// Magenta text
    Magenta = 6,
    
    /// Cyan text
    Cyan = 7,
    
    /// White text
    White = 8,

    /// Pink text
    Pink = 9
};

// ============================================================================
// ANSI Escape Codes
// ============================================================================

/**
 * @brief ANSI escape sequence constants
 */
namespace ansi
{
    /// Reset all attributes
    constexpr std::string_view RESET = "\033[0m";
    
    // Foreground colors (text)
    constexpr std::string_view FG_BLACK   = "\033[30m";
    constexpr std::string_view FG_RED     = "\033[91m";
    constexpr std::string_view FG_GREEN   = "\033[92m";
    constexpr std::string_view FG_YELLOW  = "\033[93m";
    constexpr std::string_view FG_BLUE    = "\033[94m";
    constexpr std::string_view FG_MAGENTA = "\033[95m";
    constexpr std::string_view FG_CYAN    = "\033[96m";
    constexpr std::string_view FG_WHITE   = "\033[97m";
    constexpr std::string_view FG_PINK  = "\033[38;5;205m";
    
    // Background colors
    constexpr std::string_view BG_BLACK   = "\033[40m";
    constexpr std::string_view BG_RED     = "\033[48;5;1m";
    constexpr std::string_view BG_GREEN   = "\033[48;5;2m";
    constexpr std::string_view BG_YELLOW  = "\033[48;5;226m";
    constexpr std::string_view BG_BLUE    = "\033[48;5;4m";
    constexpr std::string_view BG_MAGENTA = "\033[48;5;5m";
    constexpr std::string_view BG_CYAN    = "\033[48;5;6m";
    constexpr std::string_view BG_WHITE   = "\033[47m";
    constexpr std::string_view BG_PINK    = "\033[48;5;205m";
    constexpr std::string_view BG_ORANGE  = "\033[48;5;214m";
    constexpr std::string_view BG_DEFAULT = "\033[49m";
    
    /// Clear screen and move cursor to home
    constexpr std::string_view CLEAR = "\033[2J\033[H";
    
} // namespace ansi

// ============================================================================
// Canvas Color Characters
// ============================================================================

/**
 * @brief Canvas color character codes for bitmap rendering
 * 
 * Single character codes used in canvas/bitmap representation:
 * - 'n' = no color (default/transparent)
 * - 'g' = green
 * - 'y' = yellow
 * - 'r' = red
 * - 'B' = black (capital to avoid conflict with blue)
 * - 'b' = blue
 * - 'm' = magenta
 * - 'c' = cyan
 * - 'w' = white
 * - 'o' = orange
 */
namespace canvas
{
    constexpr char NO_COLOR = 'n';
    constexpr char GREEN    = 'g';
    constexpr char YELLOW   = 'y';
    constexpr char RED      = 'r';
    constexpr char BLACK    = 'B';
    constexpr char BLUE     = 'b';
    constexpr char MAGENTA  = 'm';
    constexpr char CYAN     = 'c';
    constexpr char WHITE    = 'w';
    constexpr char ORANGE   = 'o';
    constexpr char PINK     = 'p';
} // namespace canvas

// ============================================================================
// Color Conversion Functions
// ============================================================================

/**
 * @brief Get ANSI foreground color code for text display
 * @param color KaguOS color enum
 * @return ANSI escape sequence string view
 */
[[nodiscard]] constexpr std::string_view getForegroundColor(Color color) noexcept
{
    switch (color)
    {
        case Color::Green:   return ansi::FG_GREEN;
        case Color::Yellow:  return ansi::FG_YELLOW;
        case Color::Red:     return ansi::FG_RED;
        case Color::Black:   return ansi::FG_BLACK;
        case Color::Blue:    return ansi::FG_BLUE;
        case Color::Magenta: return ansi::FG_MAGENTA;
        case Color::Cyan:    return ansi::FG_CYAN;
        case Color::White:   return ansi::FG_WHITE;
        case Color::Pink:    return ansi::FG_PINK;
        case Color::No:
        default:             return ansi::RESET;
    }
}

/**
 * @brief Get ANSI background color code
 * @param color KaguOS color enum
 * @return ANSI escape sequence string view
 */
[[nodiscard]] constexpr std::string_view getBackgroundColor(Color color) noexcept
{
    switch (color)
    {
        case Color::Green:   return ansi::BG_GREEN;
        case Color::Yellow:  return ansi::BG_YELLOW;
        case Color::Red:     return ansi::BG_RED;
        case Color::Black:   return ansi::BG_BLACK;
        case Color::Blue:    return ansi::BG_BLUE;
        case Color::Magenta: return ansi::BG_MAGENTA;
        case Color::Cyan:    return ansi::BG_CYAN;
        case Color::White:   return ansi::BG_WHITE;
        case Color::Pink:    return ansi::BG_PINK;
        case Color::No:
        default:             return ansi::BG_DEFAULT;
    }
}

/**
 * @brief Get background color from single character code (for bitmaps)
 * @param c Character code (g=green, r=red, b=blue, etc.)
 * @return ANSI escape sequence string view
 */
[[nodiscard]] constexpr std::string_view getBackgroundColorChar(char c) noexcept
{
    switch (c)
    {
        case canvas::GREEN:    return ansi::BG_GREEN;
        case canvas::YELLOW:   return ansi::BG_YELLOW;
        case canvas::RED:      return ansi::BG_RED;
        case canvas::BLACK:    return ansi::BG_BLACK;
        case canvas::BLUE:     return ansi::BG_BLUE;
        case canvas::MAGENTA:  return ansi::BG_MAGENTA;
        case canvas::CYAN:     return ansi::BG_CYAN;
        case canvas::WHITE:    return ansi::BG_WHITE;
        case canvas::PINK:     return ansi::BG_PINK;
        case canvas::ORANGE:   return ansi::BG_ORANGE;
        case canvas::NO_COLOR: return ansi::BG_DEFAULT;
        default:               return ansi::BG_DEFAULT;
    }
}

/**
 * @brief Convert Color enum to canvas character code
 * @param color KaguOS color enum
 * @return Canvas character code
 */
[[nodiscard]] constexpr char colorToCanvasChar(Color color) noexcept
{
    switch (color)
    {
        case Color::Green:   return canvas::GREEN;
        case Color::Yellow:  return canvas::YELLOW;
        case Color::Red:     return canvas::RED;
        case Color::Black:   return canvas::BLACK;
        case Color::Blue:    return canvas::BLUE;
        case Color::Magenta: return canvas::MAGENTA;
        case Color::Cyan:    return canvas::CYAN;
        case Color::White:   return canvas::WHITE;
        case Color::Pink:    return canvas::PINK;
        case Color::No:
        default:             return canvas::NO_COLOR;
    }
}

/**
 * @brief Convert canvas character to Color enum
 * @param c Canvas character code
 * @return KaguOS color enum
 */
[[nodiscard]] constexpr Color canvasCharToColor(char c) noexcept
{
    switch (c)
    {
        case canvas::GREEN:   return Color::Green;
        case canvas::YELLOW:  return Color::Yellow;
        case canvas::RED:     return Color::Red;
        case canvas::BLACK:   return Color::Black;
        case canvas::BLUE:    return Color::Blue;
        case canvas::MAGENTA: return Color::Magenta;
        case canvas::CYAN:    return Color::Cyan;
        case canvas::WHITE:   return Color::White;
        case canvas::PINK:    return Color::Pink;
        default:              return Color::No;
    }
}

/**
 * @brief Convert color code string to canvas character
 * @param colorStr Color as string (numeric "0"-"8" or char "g", "r", etc.)
 * @return Canvas character code
 */
[[nodiscard]] inline char colorStrToCanvasChar(std::string_view colorStr) noexcept
{
    if (colorStr.empty())
    {
        return canvas::NO_COLOR;
    }
    
    // Single character - could be digit or color char
    if (colorStr.size() == 1)
    {
        char c = colorStr[0];
        
        // Numeric code 0-9
        if (c >= '0' && c <= '9')
        {
            return colorToCanvasChar(fromInt<Color>(c - '0'));
        }
        
        // Already a canvas char
        return c;
    }
    
    // Multi-digit number
    int val = 0;
    for (char c : colorStr)
    {
        if (c < '0' || c > '9')
        {
            return canvas::NO_COLOR;
        }
        val = val * 10 + (c - '0');
    }
    
    if (val >= 0 && val <= 9)
    {
        return colorToCanvasChar(fromInt<Color>(val));
    }
    
    return canvas::NO_COLOR;
}

/**
 * @brief Get background color from string (numeric or character)
 * @param colorStr Color as string (e.g., "1" for green, "g" for green)
 * @return ANSI escape sequence string view
 */
[[nodiscard]] inline std::string_view getBackgroundColorStr(std::string_view colorStr) noexcept
{
    if (colorStr.empty())
    {
        return ansi::BG_DEFAULT;
    }
    
    // Single character code
    if (colorStr.size() == 1)
    {
        char c = colorStr[0];
        if (c >= '0' && c <= '9')
        {
            return getBackgroundColor(fromInt<Color>(c - '0'));
        }
        return getBackgroundColorChar(c);
    }
    
    // Try numeric parsing
    int val = 0;
    for (char c : colorStr)
    {
        if (c < '0' || c > '9')
        {
            return ansi::BG_DEFAULT;
        }
        val = val * 10 + (c - '0');
    }
    
    if (val >= 0 && val <= 9)
    {
        return getBackgroundColor(fromInt<Color>(val));
    }
    
    return ansi::BG_DEFAULT;
}

// ============================================================================
// Text Formatting Helpers
// ============================================================================

/**
 * @brief Wrap text in color codes
 * @param text Text to colorize
 * @param color Color to apply
 * @return Colorized string with reset at the end
 */
[[nodiscard]] inline std::string colorize(std::string_view text, Color color)
{
    std::string result;
    result.reserve(text.size() + 16);
    result += getForegroundColor(color);
    result += text;
    result += ansi::RESET;
    return result;
}

/**
 * @brief Format error message (red text)
 * @param text Error message
 * @return Colorized string
 */
[[nodiscard]] inline std::string errorText(std::string_view text)
{
    return colorize(text, Color::Red);
}

/**
 * @brief Format success message (green text)
 * @param text Success message
 * @return Colorized string
 */
[[nodiscard]] inline std::string successText(std::string_view text)
{
    return colorize(text, Color::Green);
}

/**
 * @brief Format warning message (yellow text)
 * @param text Warning message
 * @return Colorized string
 */
[[nodiscard]] inline std::string warningText(std::string_view text)
{
    return colorize(text, Color::Yellow);
}

/**
 * @brief Format debug message (cyan text)
 * @param text Debug message
 * @return Colorized string
 */
[[nodiscard]] inline std::string debugText(std::string_view text)
{
    return colorize(text, Color::Cyan);
}

} // namespace kagu
