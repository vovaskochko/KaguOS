/**
 * @file display.hpp
 * @brief KaguOS Emulator - Display Output Module (Header)
 */

#pragma once

#include <kagu/kagu.hpp>
#include <string>
#include <string_view>

namespace kagu_boot
{

/**
 * @brief Terminal display handler
 */
class Display
{
public:
    Display();
    
    // Text Output
    void print(std::string_view text, kagu::Color color = kagu::Color::No);
    void println(std::string_view text, kagu::Color color = kagu::Color::No);
    void printWithColorStr(
        std::string_view text, 
        const std::string& colorStr, 
        bool newline = false
    );
    
    // Background Control
    void setBackground(kagu::Color color);
    std::string setBackgroundStr(const std::string& colorStr);
    void resetBackground();
    [[nodiscard]] kagu::Color getBackground() const noexcept;
    
    // Screen Control
    void clear();
    void reset();
    
    // Bitmap Rendering
    void renderBitmapLine(std::string_view line);
    void moveCursor(int x, int y);
    
    template<typename ReadFunc>
    void renderBitmap(int startAddr, int endAddr, ReadFunc&& readFunc)
    {
        renderBitmap(startAddr, endAddr, 0, 0, std::forward<ReadFunc>(readFunc));
    }
    
    template<typename ReadFunc>
    void renderBitmap(int startAddr, int endAddr, int x, int y, ReadFunc&& readFunc)
    {
        int row = y;
        for (int i = startAddr; i < endAddr; ++i)
        {
            if (x > 0 || y > 0)
            {
                moveCursor(x, row);
            }
            std::string line = readFunc(i);
            renderBitmapLine(line);
            ++row;
        }
    }
    
    // Debug Output
    void debug(std::string_view message, bool isKernel = true, int pid = 0);
    void error(std::string_view message);
    void info(std::string_view message);
    
private:
    kagu::Color currentBackground_;
    kagu::Color currentColor_;
};

} // namespace kagu_boot
