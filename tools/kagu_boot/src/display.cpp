/**
 * @file display.cpp
 * @brief KaguOS Emulator - Display Output Module (Implementation)
 * 
 * Implements off-screen canvas for bitmap compositing.
 */

#include "display.hpp"
#include <iostream>
#include <algorithm>

namespace kagu_boot
{

// ============================================================================
// Canvas Implementation
// ============================================================================

bool Canvas::empty() const noexcept
{
    return width == 0 || height == 0;
}

void Canvas::reset()
{
    pixels.clear();
    width = 0;
    height = 0;
    dirty = false;
}

void Canvas::fill()
{
    for (auto& row : pixels)
    {
        row.assign(width, backgroundColor);
    }
    dirty = true;
}

void Canvas::resize(int newWidth, int newHeight)
{
    if (newWidth <= width && newHeight <= height)
    {
        return; // No expansion needed
    }
    
    int oldWidth = width;
    int oldHeight = height;
    
    // Expand width of existing rows
    if (newWidth > oldWidth)
    {
        for (auto& row : pixels)
        {
            row.append(newWidth - oldWidth, backgroundColor);
        }
    }
    
    // Add new rows
    if (newHeight > oldHeight)
    {
        std::string emptyRow(newWidth, backgroundColor);
        pixels.resize(newHeight, emptyRow);
    }
    
    width = newWidth;
    height = newHeight;
    dirty = true;
}

void Canvas::initialize(int w, int h, char bgColor)
{
    backgroundColor = bgColor;
    width = w;
    height = h;
    pixels.clear();
    pixels.resize(h, std::string(w, backgroundColor));
    dirty = true;
}

void Canvas::setPixel(int x, int y, char color)
{
    if (x >= 0 && x < width && y >= 0 && y < height)
    {
        pixels[y][x] = color;
        dirty = true;
    }
}

char Canvas::getPixel(int x, int y) const
{
    if (x >= 0 && x < width && y >= 0 && y < height)
    {
        return pixels[y][x];
    }
    return backgroundColor;
}

// ============================================================================
// Display Constructor
// ============================================================================

Display::Display()
    : canvas_()
    , screenWidth_(80)
    , screenHeight_(24)
    , currentBackground_(kagu::Color::No)
    , currentColor_(kagu::Color::No)
{
}

// ============================================================================
// Text Output (immediate, bypasses canvas)
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
// Terminal Background Control
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
    
    // Also update canvas background color
    canvas_.backgroundColor = kagu::colorStrToCanvasChar(colorStr);
    
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
    // Reset canvas state
    canvas_.reset();
    
    // Initialize canvas to full screen size with background color
    canvas_.initialize(screenWidth_, screenHeight_, canvas_.backgroundColor);
    
    // Clear terminal and fill screen with background color
    hideCursor();
    moveCursor(0, 0);
    fillScreen();
    moveCursor(0, 0);
    
    std::cout.flush();
}

void Display::reset()
{
    std::cout << kagu::ansi::RESET;
    currentBackground_ = kagu::Color::No;
    currentColor_ = kagu::Color::No;
}

void Display::moveCursor(int x, int y)
{
    // ANSI escape: \033[row;colH (1-based)
    std::cout << "\033[" << (y + 1) << ";" << (x + 1) << "H";
}

void Display::hideCursor()
{
    std::cout << "\033[?25l";
}

void Display::showCursor()
{
    std::cout << "\033[?25h";
}

void Display::fillScreen()
{
    // Get background ANSI code
    auto bgCode = kagu::getBackgroundColorChar(canvas_.backgroundColor);
    
    // Fill each row with background color
    std::string row(screenWidth_, ' ');
    
    for (int y = 0; y < screenHeight_; ++y)
    {
        moveCursor(0, y);
        std::cout << bgCode << row;
    }
    
    std::cout << kagu::ansi::RESET;
}

// ============================================================================
// Canvas Operations
// ============================================================================

void Display::setCanvasBackground(char color)
{
    canvas_.backgroundColor = color;
}

char Display::getCanvasBackground() const noexcept
{
    return canvas_.backgroundColor;
}

void Display::setCanvasSize(int width, int height)
{
    screenWidth_ = width;
    screenHeight_ = height;
    
    // Resize canvas if it exists
    if (!canvas_.empty())
    {
        canvas_.resize(width, height);
    }
}

void Display::drawBitmap(int x, int y, const std::vector<std::string>& bitmap)
{
    if (bitmap.empty())
    {
        return;
    }
    
    // Calculate bitmap dimensions
    int bitmapHeight = static_cast<int>(bitmap.size());
    int bitmapWidth = 0;
    for (const auto& row : bitmap)
    {
        bitmapWidth = std::max(bitmapWidth, static_cast<int>(row.size()));
    }
    
    if (bitmapWidth == 0)
    {
        return;
    }
    
    // Calculate required canvas size
    int requiredWidth = x + bitmapWidth;
    int requiredHeight = y + bitmapHeight;
    
    // Initialize or expand canvas as needed
    if (canvas_.empty())
    {
        // First bitmap: initialize canvas to screen size or required size
        int initWidth = std::max(screenWidth_, requiredWidth);
        int initHeight = std::max(screenHeight_, requiredHeight);
        canvas_.initialize(initWidth, initHeight, canvas_.backgroundColor);
    }
    else
    {
        // Expand canvas if bitmap extends beyond current bounds
        if (requiredWidth > canvas_.width || requiredHeight > canvas_.height)
        {
            canvas_.resize(
                std::max(canvas_.width, requiredWidth),
                std::max(canvas_.height, requiredHeight)
            );
        }
    }
    
    // Draw bitmap onto canvas (overlay)
    for (int row = 0; row < bitmapHeight; ++row)
    {
        const std::string& bitmapRow = bitmap[row];
        int canvasY = y + row;
        
        for (int col = 0; col < static_cast<int>(bitmapRow.size()); ++col)
        {
            int canvasX = x + col;
            char pixel = bitmapRow[col];
            
            // Draw all pixels (including 'n' for explicit transparency control)
            canvas_.setPixel(canvasX, canvasY, pixel);
        }
    }
    
    canvas_.dirty = true;
}

void Display::render()
{
    render(0, 0);
}

void Display::render(int screenX, int screenY)
{
    if (canvas_.empty())
    {
        return;
    }
    
    hideCursor();
    
    // Render each row
    for (int row = 0; row < canvas_.height; ++row)
    {
        renderCanvasRow(row, screenX, screenY);
    }
    
    // Reset terminal attributes after rendering
    std::cout << kagu::ansi::RESET;
    std::cout.flush();
    
    canvas_.dirty = false;
}

void Display::renderCanvasRow(int row, int screenX, int screenY)
{
    // Move cursor to row position
    moveCursor(screenX, screenY + row);
    
    const std::string& pixelRow = canvas_.pixels[row];
    
    // Optimized rendering: group consecutive pixels of same color
    char currentColor = '\0';
    
    for (int col = 0; col < canvas_.width; ++col)
    {
        char pixel = (col < static_cast<int>(pixelRow.size())) 
                   ? pixelRow[col] 
                   : canvas_.backgroundColor;
        
        // Change color only if different from current
        if (pixel != currentColor)
        {
            std::cout << kagu::getBackgroundColorChar(pixel);
            currentColor = pixel;
        }
        
        // Output space (each pixel is one character wide in terminal)
        std::cout << ' ';
    }
}

bool Display::isDirty() const noexcept
{
    return canvas_.dirty;
}

int Display::canvasWidth() const noexcept
{
    return canvas_.width;
}

int Display::canvasHeight() const noexcept
{
    return canvas_.height;
}

const Canvas& Display::canvas() const noexcept
{
    return canvas_;
}

// ============================================================================
// Legacy Bitmap API
// ============================================================================

void Display::renderBitmapLine(std::string_view line)
{
    for (char c : line)
    {
        std::cout << kagu::getBackgroundColorChar(c) << " ";
    }
    std::cout << kagu::ansi::RESET << std::endl;
}

// ============================================================================
// Debug Output (immediate, bypasses canvas)
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
