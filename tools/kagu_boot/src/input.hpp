/**
 * @file input.hpp
 * @brief KaguOS Emulator - Keyboard Input Module (Header)
 */

#pragma once

#include <kagu/kagu.hpp>
#include <string>
#include <queue>
#include <optional>

namespace kagu_boot
{

/**
 * @brief Keyboard input handler
 */
class Keyboard
{
public:
    Keyboard();
    
    // Input Reading
    [[nodiscard]] std::string readInput(kagu::KeyboardMode mode);
    [[nodiscard]] std::string readInput(const std::string& modeStr);
    
    // Non-blocking key polling
    [[nodiscard]] int pollKey();
    
    // Buffer Access
    [[nodiscard]] const std::string& getBuffer() const noexcept;
    void setBuffer(const std::string& value);
    
    // Async Input Queue
    [[nodiscard]] bool hasPendingInput() const noexcept;
    void queueInput(const std::string& input);
    [[nodiscard]] std::optional<std::string> pollInput();
    
    // Low-Level Input
    [[nodiscard]] std::string readLine(bool echo);
    [[nodiscard]] char readChar(bool echo);
    
private:
    std::string lastInput_;
    bool pendingInput_;
    std::queue<std::string> inputQueue_;
    
    [[nodiscard]] char readCharPlatform(bool echo);
    [[nodiscard]] int pollKeyPlatform();
};

} // namespace kagu_boot
