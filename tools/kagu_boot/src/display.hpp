/**
 * @file display.hpp
 * @brief KaguOS Emulator - Display Output Module (Header)
 * 
 * Features off-screen Canvas buffer for bitmap compositing.
 * Bitmaps are drawn to canvas and rendered together.
 */

#pragma once

#include <kagu/kagu.hpp>
#include <string>
#include <string_view>
#include <vector>

namespace kagu_boot
{

/**
 * @brief Off-screen canvas for bitmap compositing
 * 
 * Holds a 2D buffer of color characters that can be
 * composited from multiple bitmaps before rendering.
 */
struct Canvas
{
    /// 2D pixel buffer (color chars: 'g', 'r', 'b', 'n', etc.)
    std::vector<std::string> pixels;
    
    /// Canvas dimensions
    int width = 0;
    int height = 0;
    
    /// Background fill color (default: 'n' = no color/transparent)
    char backgroundColor = 'n';
    
    /// Dirty flag: true if canvas needs re-rendering
    bool dirty = false;
    
    /// Check if canvas is empty/uninitialized
    [[nodiscard]] bool empty() const noexcept;
    
    /// Clear canvas to empty state
    void reset();
    
    /// Fill entire canvas with background color
    void fill();
    
    /// Resize canvas, preserving existing content
    void resize(int newWidth, int newHeight);
    
    /// Initialize canvas with given size
    void initialize(int w, int h, char bgColor = 'n');
    
    /// Set pixel at (x, y) if within bounds
    void setPixel(int x, int y, char color);
    
    /// Get pixel at (x, y), returns backgroundColor if out of bounds
    [[nodiscard]] char getPixel(int x, int y) const;
};

/**
 * @brief Terminal display handler with off-screen canvas
 */
class Display
{
public:
    Display();
    
    // ========================================================================
    // Text Output (immediate, bypasses canvas)
    // ========================================================================
    
    void print(std::string_view text, kagu::Color color = kagu::Color::No);
    void println(std::string_view text, kagu::Color color = kagu::Color::No);
    void printWithColorStr(
        std::string_view text, 
        const std::string& colorStr, 
        bool newline = false
    );
    
    // ========================================================================
    // Terminal Background Control
    // ========================================================================
    
    void setBackground(kagu::Color color);
    std::string setBackgroundStr(const std::string& colorStr);
    void resetBackground();
    [[nodiscard]] kagu::Color getBackground() const noexcept;
    
    // ========================================================================
    // Screen Control
    // ========================================================================
    
    /// Clear terminal and fill with canvas background color
    void clear();
    
    /// Reset terminal attributes (colors)
    void reset();
    
    /// Move cursor to position (0-based)
    void moveCursor(int x, int y);
    
    /// Hide cursor
    void hideCursor();
    
    /// Show cursor
    void showCursor();
    
    // ========================================================================
    // Canvas Operations
    // ========================================================================
    
    /// Set canvas background color for new/expanded areas
    void setCanvasBackground(char color);
    
    /// Get current canvas background color
    [[nodiscard]] char getCanvasBackground() const noexcept;
    
    /// Set canvas/screen dimensions
    void setCanvasSize(int width, int height);
    
    /// Draw bitmap onto canvas at position (x, y)
    /// Automatically expands canvas if needed
    void drawBitmap(int x, int y, const std::vector<std::string>& bitmap);
    
    /// Render canvas to terminal
    void render();
    
    /// Render canvas to terminal at specific position
    void render(int screenX, int screenY);
    
    /// Check if canvas needs rendering
    [[nodiscard]] bool isDirty() const noexcept;
    
    /// Get canvas dimensions
    [[nodiscard]] int canvasWidth() const noexcept;
    [[nodiscard]] int canvasHeight() const noexcept;
    
    /// Direct canvas access (for advanced usage)
    [[nodiscard]] const Canvas& canvas() const noexcept;
    
    // ========================================================================
    // Legacy Bitmap API (for backward compatibility)
    // ========================================================================
    
    /// Render single bitmap line directly to terminal (legacy)
    void renderBitmapLine(std::string_view line);
    
    /// Legacy: read bitmap from RAM and render via canvas
    template<typename ReadFunc>
    void renderBitmap(int startAddr, int endAddr, ReadFunc&& readFunc)
    {
        renderBitmap(startAddr, endAddr, 0, 0, std::forward<ReadFunc>(readFunc));
    }
    
    /// Legacy: read bitmap from RAM and render via canvas at position
    template<typename ReadFunc>
    void renderBitmap(int startAddr, int endAddr, int x, int y, ReadFunc&& readFunc)
    {
        // Collect bitmap lines from RAM
        std::vector<std::string> bitmap;
        bitmap.reserve(endAddr - startAddr);
        
        for (int i = startAddr; i < endAddr; ++i)
        {
            bitmap.push_back(readFunc(i));
        }
        
        // Draw to canvas and render
        drawBitmap(x, y, bitmap);
        render(0, 0);
    }
    
    // ========================================================================
    // Debug Output (immediate, bypasses canvas)
    // ========================================================================
    
    void debug(std::string_view message, bool isKernel = true, int pid = 0);
    void error(std::string_view message);
    void info(std::string_view message);
    
private:
    /// Off-screen canvas buffer
    Canvas canvas_;
    
    /// Screen dimensions for full-screen clear
    int screenWidth_ = 80;
    int screenHeight_ = 24;
    
    /// Current terminal background color
    kagu::Color currentBackground_;
    
    /// Current terminal text color
    kagu::Color currentColor_;
    
    /// Render single row of canvas with color optimization
    void renderCanvasRow(int row, int screenX, int screenY);
    
    /// Fill entire screen with background color
    void fillScreen();
};

} // namespace kagu_boot
