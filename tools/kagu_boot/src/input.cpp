/**
 * @file input.cpp
 * @brief KaguOS Emulator - Keyboard Input Module (Implementation)
 */

#include "input.hpp"
#include <iostream>

#ifdef _WIN32
#include <windows.h>
#include <conio.h>
#else
#include <termios.h>
#include <unistd.h>
#endif

namespace kagu_boot
{

Keyboard::Keyboard()
    : lastInput_("")
    , pendingInput_(false)
{
}

// ============================================================================
// Input Reading
// ============================================================================

std::string Keyboard::readInput(kagu::KeyboardMode mode)
{
    std::string input;
    
    switch (mode)
    {
        case kagu::KeyboardMode::ReadLine:
            input = readLine(true);
            break;
            
        case kagu::KeyboardMode::ReadLineSilently:
            input = readLine(false);
            break;
            
        case kagu::KeyboardMode::ReadChar:
            input = std::string(1, readChar(true));
            break;
            
        case kagu::KeyboardMode::ReadCharSilently:
            input = std::string(1, readChar(false));
            break;
    }
    
    lastInput_ = input;
    pendingInput_ = false;
    
    return input;
}

std::string Keyboard::readInput(const std::string& modeStr)
{
    kagu::KeyboardMode mode = kagu::parseKeyboardMode(modeStr);
    return readInput(mode);
}

// ============================================================================
// Buffer Access
// ============================================================================

const std::string& Keyboard::getBuffer() const noexcept
{
    return lastInput_;
}

void Keyboard::setBuffer(const std::string& value)
{
    lastInput_ = value;
}

// ============================================================================
// Async Input Queue
// ============================================================================

bool Keyboard::hasPendingInput() const noexcept
{
    return pendingInput_;
}

void Keyboard::queueInput(const std::string& input)
{
    inputQueue_.push(input);
    pendingInput_ = true;
}

std::optional<std::string> Keyboard::pollInput()
{
    if (inputQueue_.empty())
    {
        pendingInput_ = false;
        return std::nullopt;
    }
    
    std::string input = inputQueue_.front();
    inputQueue_.pop();
    pendingInput_ = !inputQueue_.empty();
    
    return input;
}

// ============================================================================
// Low-Level Input
// ============================================================================

std::string Keyboard::readLine(bool echo)
{
    std::string input;
    
    if (echo)
    {
        std::getline(std::cin, input);
    }
    else
    {
        // Note: Full silent line reading is platform-specific
        std::getline(std::cin, input);
    }
    
    return input;
}

char Keyboard::readChar(bool echo)
{
    return readCharPlatform(echo);
}

int Keyboard::pollKey()
{
    return pollKeyPlatform();
}

// ============================================================================
// Platform-Specific Implementation
// ============================================================================

#ifdef _WIN32

char Keyboard::readCharPlatform(bool echo)
{
    HANDLE hStdin = GetStdHandle(STD_INPUT_HANDLE);
    DWORD mode = 0;
    GetConsoleMode(hStdin, &mode);
    SetConsoleMode(hStdin, mode & ~(ENABLE_ECHO_INPUT | ENABLE_LINE_INPUT));
    
    char ch = 0;
    DWORD read;
    ReadConsoleA(hStdin, &ch, 1, &read, NULL);
    
    SetConsoleMode(hStdin, mode);
    
    if (echo)
    {
        std::cout << ch;
    }
    
    return ch;
}

int Keyboard::pollKeyPlatform()
{
    if (_kbhit())
    {
        return _getch();
    }
    return 0;
}

#else

char Keyboard::readCharPlatform(bool echo)
{
    struct termios oldt, newt;
    char ch = '\0';
    
    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~ICANON;
    
    if (!echo)
    {
        newt.c_lflag &= ~ECHO;
    }
    
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    
    if (read(STDIN_FILENO, &ch, 1) < 0)
    {
        ch = '\0';
    }
    
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    
    if (echo)
    {
        std::cout << ch;
    }
    
    return ch;
}

int Keyboard::pollKeyPlatform()
{
    struct termios oldt, newt;
    int ch = 0;
    
    tcgetattr(STDIN_FILENO, &oldt);
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO);
    newt.c_cc[VMIN] = 0;
    newt.c_cc[VTIME] = 0;
    tcsetattr(STDIN_FILENO, TCSANOW, &newt);
    
    char c;
    if (read(STDIN_FILENO, &c, 1) == 1)
    {
        ch = static_cast<unsigned char>(c);
    }
    
    tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
    return ch;
}

#endif

} // namespace kagu_boot
