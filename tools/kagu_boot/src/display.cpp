/**
 * @file display.cpp
 * @brief KaguOS Emulator - Display Output Module (Implementation)
 */

#include "display.hpp"
#include <iostream>

namespace kagu_boot
{

Display::Display()
    : currentBackground_(kagu::Color::No)
    , currentColor_(kagu::Color::No)
{
}

// ============================================================================
// Text Output
// ============================================================================

void Display::print(std::string_view text, kagu::Color color)
{
    if (color != kagu::Color::No)
    {
        std::cout << kagu::getForegroundColor(color);
    }
    
    std::cout << text;
    
    if (color != kagu::Color::No)
    {
        std::cout << kagu::ansi::RESET;
    }
}

void Display::println(std::string_view text, kagu::Color color)
{
    print(text, color);
    std::cout << std::endl;
}

void Display::printWithColorStr(
    std::string_view text, 
    const std::string& colorStr, 
    bool newline
)
{
    kagu::Color color = kagu::Color::No;
    
    if (!colorStr.empty() && colorStr != "0")
    {
        try
        {
            int colorCode = std::stoi(colorStr);
            if (colorCode >= 0 && colorCode <= 8)
            {
                color = kagu::fromInt<kagu::Color>(colorCode);
            }
        }
        catch (...)
        {
            // Invalid color code, use default
        }
    }
    
    if (newline)
    {
        println(text, color);
    }
    else
    {
        print(text, color);
    }
}

// ============================================================================
// Background Control
// ============================================================================

void Display::setBackground(kagu::Color color)
{
    currentBackground_ = color;
    std::cout << kagu::getBackgroundColor(color);
}

std::string Display::setBackgroundStr(const std::string& colorStr)
{
    auto bgCode = kagu::getBackgroundColorStr(colorStr);
    std::cout << bgCode;
    return std::string(bgCode);
}

void Display::resetBackground()
{
    setBackground(kagu::Color::No);
}

kagu::Color Display::getBackground() const noexcept
{
    return currentBackground_;
}

// ============================================================================
// Screen Control
// ============================================================================

void Display::clear()
{
    std::cout << kagu::ansi::CLEAR;
}

void Display::reset()
{
    std::cout << kagu::ansi::RESET;
    currentBackground_ = kagu::Color::No;
    currentColor_ = kagu::Color::No;
}

// ============================================================================
// Bitmap Rendering
// ============================================================================

void Display::renderBitmapLine(std::string_view line)
{
    for (char c : line)
    {
        std::cout << kagu::getBackgroundColorChar(c) << " ";
    }
    std::cout << kagu::ansi::RESET << std::endl;
}

void Display::moveCursor(int x, int y)
{
    // ANSI escape: \033[row;colH (1-based)
    std::cout << "\033[" << (y + 1) << ";" << (x + 1) << "H";
}

// ============================================================================
// Debug Output
// ============================================================================

void Display::debug(std::string_view message, bool isKernel, int pid)
{
    if (isKernel)
    {
        std::cout << "\033[34m[KERNEL]";
    }
    else
    {
        std::cout << "\033[32m[PID " << pid << "]";
    }
    
    std::cout << "[DEBUG] " << message << "\033[0m" << std::endl;
}

void Display::error(std::string_view message)
{
    std::cerr << kagu::errorText(std::string(message)) << std::endl;
}

void Display::info(std::string_view message)
{
    std::cout << "[INFO] " << message << std::endl;
}

} // namespace kagu_boot
