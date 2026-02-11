/**
 * @file test_libkagu.cpp
 * @brief Unit tests for libkagu library
 */

#include <kagu/kagu.hpp>
#include <iostream>
#include <cassert>
#include <string>

// ============================================================================
// Test Helpers
// ============================================================================

int tests_passed = 0;
int tests_failed = 0;

#define TEST(name) void test_##name()

#define RUN_TEST(name) do { \
    std::cout << "Running " #name "... "; \
    try { \
        test_##name(); \
        std::cout << kagu::successText("PASS") << std::endl; \
        tests_passed++; \
    } catch (const std::exception& e) { \
        std::cout << kagu::errorText("FAIL: ") << e.what() << std::endl; \
        tests_failed++; \
    } \
} while(0)

#define ASSERT_EQ(a, b) do { \
    if ((a) != (b)) { \
        throw std::runtime_error("Assertion failed: " #a " != " #b); \
    } \
} while(0)

#define ASSERT_TRUE(x) do { \
    if (!(x)) { \
        throw std::runtime_error("Assertion failed: " #x); \
    } \
} while(0)

// ============================================================================
// Types Tests
// ============================================================================

TEST(toInt_basic)
{
    // New layout: Op=1, A=2, ...
    ASSERT_EQ(kagu::toInt(kagu::Address::Op), 1);
    ASSERT_EQ(kagu::toInt(kagu::Address::A), 2);
    ASSERT_EQ(kagu::toInt(kagu::Operation::Add), 0);
    ASSERT_EQ(kagu::toInt(kagu::Color::Green), 1);
}

TEST(fromInt_basic)
{
    ASSERT_EQ(kagu::fromInt<kagu::Address>(1), kagu::Address::Op);
    ASSERT_EQ(kagu::fromInt<kagu::Operation>(0), kagu::Operation::Add);
    ASSERT_EQ(kagu::fromInt<kagu::Color>(1), kagu::Color::Green);
}

// ============================================================================
// Registers Tests
// ============================================================================

TEST(address_values)
{
    // New compact layout (1-10 user space, 11-30 kernel, 31+ code)
    ASSERT_EQ(kagu::toInt(kagu::Address::Op), 1);
    ASSERT_EQ(kagu::toInt(kagu::Address::A), 2);
    ASSERT_EQ(kagu::toInt(kagu::Address::B), 3);
    ASSERT_EQ(kagu::toInt(kagu::Address::C), 4);
    ASSERT_EQ(kagu::toInt(kagu::Address::D), 5);
    ASSERT_EQ(kagu::toInt(kagu::Address::E), 6);
    ASSERT_EQ(kagu::toInt(kagu::Address::Res), 7);
    ASSERT_EQ(kagu::toInt(kagu::Address::BoolRes), 8);
    ASSERT_EQ(kagu::toInt(kagu::Address::Error), 9);
    ASSERT_EQ(kagu::toInt(kagu::Address::LastKey), 10);
    ASSERT_EQ(kagu::toInt(kagu::Address::UserSpaceEnd), 10);
    ASSERT_EQ(kagu::toInt(kagu::Address::SysEnergy), 11);
    ASSERT_EQ(kagu::toInt(kagu::Address::DisplayBuffer), 12);
    ASSERT_EQ(kagu::toInt(kagu::Address::ProgramCounter), 16);
    ASSERT_EQ(kagu::toInt(kagu::Address::KernelStart), 31);
}

TEST(isUserAccessible)
{
    ASSERT_TRUE(kagu::isUserAccessible(kagu::Address::Op));
    ASSERT_TRUE(kagu::isUserAccessible(kagu::Address::A));
    ASSERT_TRUE(kagu::isUserAccessible(kagu::Address::Error));
    ASSERT_TRUE(kagu::isUserAccessible(kagu::Address::LastKey));
    ASSERT_TRUE(kagu::isUserAccessible(kagu::Address::UserSpaceEnd));
    ASSERT_TRUE(!kagu::isUserAccessible(kagu::Address::SysEnergy));
    ASSERT_TRUE(!kagu::isUserAccessible(kagu::Address::DisplayBuffer));
    ASSERT_TRUE(!kagu::isUserAccessible(kagu::Address::ProgramCounter));
    ASSERT_TRUE(!kagu::isUserAccessible(kagu::Address::KernelStart));
}

TEST(isUserAccessible_int)
{
    ASSERT_TRUE(kagu::isUserAccessible(1));
    ASSERT_TRUE(kagu::isUserAccessible(10));
    ASSERT_TRUE(!kagu::isUserAccessible(11));
    ASSERT_TRUE(!kagu::isUserAccessible(31));
}

TEST(getRegisterName)
{
    ASSERT_EQ(std::string(kagu::getRegisterName(kagu::Address::Op)), "REG_OP");
    ASSERT_EQ(std::string(kagu::getRegisterName(kagu::Address::A)), "REG_A");
    ASSERT_EQ(std::string(kagu::getRegisterName(kagu::Address::E)), "REG_E");
    ASSERT_EQ(std::string(kagu::getRegisterName(kagu::Address::LastKey)), "REG_LAST_KEY");
    ASSERT_EQ(std::string(kagu::getRegisterName(kagu::Address::SysEnergy)), "SYS_ENERGY");
    ASSERT_EQ(std::string(kagu::getRegisterName(kagu::Address::DisplayBuffer)), "DISPLAY_BUFFER");
}

// ============================================================================
// Opcodes Tests
// ============================================================================

TEST(operation_values)
{
    ASSERT_EQ(kagu::toInt(kagu::Operation::Add), 0);
    ASSERT_EQ(kagu::toInt(kagu::Operation::Sub), 1);
    ASSERT_EQ(kagu::toInt(kagu::Operation::CmpEq), 8);
    ASSERT_EQ(kagu::toInt(kagu::Operation::Display), 19);
    ASSERT_EQ(kagu::toInt(kagu::Operation::DisplayLn), 20);
    ASSERT_EQ(kagu::toInt(kagu::Operation::SysCall), 25);
    ASSERT_EQ(kagu::toInt(kagu::Operation::Halt), 30);
}

TEST(isPrivileged)
{
    ASSERT_TRUE(!kagu::isPrivileged(kagu::Operation::Add));
    ASSERT_TRUE(!kagu::isPrivileged(kagu::Operation::CmpEq));
    ASSERT_TRUE(kagu::isPrivileged(kagu::Operation::ReadInput));
    ASSERT_TRUE(kagu::isPrivileged(kagu::Operation::Display));
    ASSERT_TRUE(kagu::isPrivileged(kagu::Operation::ReadBlock));
    ASSERT_TRUE(!kagu::isPrivileged(kagu::Operation::SysCall));
    ASSERT_TRUE(kagu::isPrivileged(kagu::Operation::SysReturn));
}

TEST(isArithmetic)
{
    ASSERT_TRUE(kagu::isArithmetic(kagu::Operation::Add));
    ASSERT_TRUE(kagu::isArithmetic(kagu::Operation::Sub));
    ASSERT_TRUE(kagu::isArithmetic(kagu::Operation::Mul));
    ASSERT_TRUE(!kagu::isArithmetic(kagu::Operation::CmpEq));
    ASSERT_TRUE(!kagu::isArithmetic(kagu::Operation::Display));
}

TEST(isComparison)
{
    ASSERT_TRUE(kagu::isComparison(kagu::Operation::CmpEq));
    ASSERT_TRUE(kagu::isComparison(kagu::Operation::CmpNeq));
    ASSERT_TRUE(kagu::isComparison(kagu::Operation::CmpLt));
    ASSERT_TRUE(kagu::isComparison(kagu::Operation::CmpLe));
    ASSERT_TRUE(!kagu::isComparison(kagu::Operation::Add));
}

TEST(isStringOperation)
{
    ASSERT_TRUE(kagu::isStringOperation(kagu::Operation::Contains));
    ASSERT_TRUE(kagu::isStringOperation(kagu::Operation::GetLength));
    ASSERT_TRUE(kagu::isStringOperation(kagu::Operation::ConcatWith));
    ASSERT_TRUE(!kagu::isStringOperation(kagu::Operation::Add));
}

TEST(instruction_values)
{
    ASSERT_EQ(kagu::toInt(kagu::Instruction::CpuExec), 0);
    ASSERT_EQ(kagu::toInt(kagu::Instruction::CopyFromToAddress), 1);
    ASSERT_EQ(kagu::toInt(kagu::Instruction::Jump), 3);
    ASSERT_EQ(kagu::toInt(kagu::Instruction::JumpIf), 4);
    ASSERT_EQ(kagu::toInt(kagu::Instruction::JumpIfNot), 5);
    ASSERT_EQ(kagu::toInt(kagu::Instruction::JumpErr), 6);
}

// ============================================================================
// Syscalls Tests
// ============================================================================

TEST(syscall_values)
{
    ASSERT_EQ(kagu::toInt(kagu::SysCall::Exit), 0);
    ASSERT_EQ(kagu::toInt(kagu::SysCall::PrintLn), 1);
    ASSERT_EQ(kagu::toInt(kagu::SysCall::Open), 4);
    ASSERT_EQ(kagu::toInt(kagu::SysCall::Read), 7);
    ASSERT_EQ(kagu::toInt(kagu::SysCall::Write), 8);
    ASSERT_EQ(kagu::toInt(kagu::SysCall::SchedProgram), 14);
}

TEST(getSysCallCount)
{
    ASSERT_EQ(kagu::getSysCallCount(), 19);
}

TEST(isValidSysCall)
{
    ASSERT_TRUE(kagu::isValidSysCall(0));
    ASSERT_TRUE(kagu::isValidSysCall(18));
    ASSERT_TRUE(!kagu::isValidSysCall(-1));
    ASSERT_TRUE(!kagu::isValidSysCall(19));
}

TEST(isFileSysCall)
{
    ASSERT_TRUE(kagu::isFileSysCall(kagu::SysCall::Open));
    ASSERT_TRUE(kagu::isFileSysCall(kagu::SysCall::Read));
    ASSERT_TRUE(kagu::isFileSysCall(kagu::SysCall::Write));
    ASSERT_TRUE(!kagu::isFileSysCall(kagu::SysCall::Exit));
    ASSERT_TRUE(!kagu::isFileSysCall(kagu::SysCall::PrintLn));
}

// ============================================================================
// Colors Tests
// ============================================================================

TEST(color_values)
{
    ASSERT_EQ(kagu::toInt(kagu::Color::No), 0);
    ASSERT_EQ(kagu::toInt(kagu::Color::Green), 1);
    ASSERT_EQ(kagu::toInt(kagu::Color::Yellow), 2);
    ASSERT_EQ(kagu::toInt(kagu::Color::Red), 3);
}

TEST(getForegroundColor)
{
    ASSERT_EQ(kagu::getForegroundColor(kagu::Color::Green), "\033[92m");
    ASSERT_EQ(kagu::getForegroundColor(kagu::Color::Red), "\033[91m");
    ASSERT_EQ(kagu::getForegroundColor(kagu::Color::No), "\033[0m");
}

TEST(getBackgroundColor)
{
    ASSERT_EQ(kagu::getBackgroundColor(kagu::Color::Green), "\033[48;5;2m");
    ASSERT_EQ(kagu::getBackgroundColor(kagu::Color::Red), "\033[48;5;1m");
}

TEST(getBackgroundColorChar)
{
    ASSERT_EQ(kagu::getBackgroundColorChar('g'), "\033[48;5;2m");
    ASSERT_EQ(kagu::getBackgroundColorChar('r'), "\033[48;5;1m");
    ASSERT_EQ(kagu::getBackgroundColorChar('n'), "\033[49m");
}

TEST(colorize)
{
    std::string result = kagu::colorize("test", kagu::Color::Green);
    ASSERT_TRUE(result.find("\033[92m") != std::string::npos);
    ASSERT_TRUE(result.find("test") != std::string::npos);
    ASSERT_TRUE(result.find("\033[0m") != std::string::npos);
}

// ============================================================================
// Keyboard Tests
// ============================================================================

TEST(keyboardModeValue)
{
    ASSERT_EQ(kagu::keyboardModeValue(kagu::KeyboardMode::ReadLine), "KeyboardReadLine");
    ASSERT_EQ(kagu::keyboardModeValue(kagu::KeyboardMode::ReadLineSilently), "KeyboardReadLineSilently");
    ASSERT_EQ(kagu::keyboardModeValue(kagu::KeyboardMode::ReadChar), "KeyboardReadChar");
    ASSERT_EQ(kagu::keyboardModeValue(kagu::KeyboardMode::ReadCharSilently), "KeyboardReadCharSilently");
}

TEST(parseKeyboardMode)
{
    ASSERT_EQ(kagu::parseKeyboardMode("KeyboardReadLine"), kagu::KeyboardMode::ReadLine);
    ASSERT_EQ(kagu::parseKeyboardMode("KeyboardReadChar"), kagu::KeyboardMode::ReadChar);
    ASSERT_EQ(kagu::parseKeyboardMode("KeyboardReadCharSilently"), kagu::KeyboardMode::ReadCharSilently);
    ASSERT_EQ(kagu::parseKeyboardMode("unknown"), kagu::KeyboardMode::ReadLine);
}

TEST(isCharMode)
{
    ASSERT_TRUE(!kagu::isCharMode(kagu::KeyboardMode::ReadLine));
    ASSERT_TRUE(!kagu::isCharMode(kagu::KeyboardMode::ReadLineSilently));
    ASSERT_TRUE(kagu::isCharMode(kagu::KeyboardMode::ReadChar));
    ASSERT_TRUE(kagu::isCharMode(kagu::KeyboardMode::ReadCharSilently));
}

TEST(isSilentMode)
{
    ASSERT_TRUE(!kagu::isSilentMode(kagu::KeyboardMode::ReadLine));
    ASSERT_TRUE(kagu::isSilentMode(kagu::KeyboardMode::ReadLineSilently));
    ASSERT_TRUE(!kagu::isSilentMode(kagu::KeyboardMode::ReadChar));
    ASSERT_TRUE(kagu::isSilentMode(kagu::KeyboardMode::ReadCharSilently));
}

// ============================================================================
// Config Tests
// ============================================================================

TEST(config_values)
{
    ASSERT_EQ(kagu::config::DEFAULT_RAM_SIZE, 4600);
    // USER_SPACE_START changed from 17 to 11 (first kernel register)
    ASSERT_EQ(kagu::config::USER_SPACE_START, 11);
    ASSERT_EQ(kagu::config::DEFAULT_TIME_QUANTUM, 50);
}

// ============================================================================
// Version Tests
// ============================================================================

TEST(version)
{
    ASSERT_TRUE(kagu::VERSION.major >= 2);
    ASSERT_TRUE(kagu::VERSION.isAtLeast(2, 0, 0));
}

// ============================================================================
// Main
// ============================================================================

int main()
{
    std::cout << "=== libkagu Unit Tests ===" << std::endl;
    std::cout << "Library version: " << kagu::VERSION.toString() << std::endl;
    std::cout << std::endl;
    
    // Types tests
    RUN_TEST(toInt_basic);
    RUN_TEST(fromInt_basic);
    
    // Registers tests
    RUN_TEST(address_values);
    RUN_TEST(isUserAccessible);
    RUN_TEST(isUserAccessible_int);
    RUN_TEST(getRegisterName);
    
    // Opcodes tests
    RUN_TEST(operation_values);
    RUN_TEST(isPrivileged);
    RUN_TEST(isArithmetic);
    RUN_TEST(isComparison);
    RUN_TEST(isStringOperation);
    RUN_TEST(instruction_values);
    
    // Syscalls tests
    RUN_TEST(syscall_values);
    RUN_TEST(getSysCallCount);
    RUN_TEST(isValidSysCall);
    RUN_TEST(isFileSysCall);
    
    // Colors tests
    RUN_TEST(color_values);
    RUN_TEST(getForegroundColor);
    RUN_TEST(getBackgroundColor);
    RUN_TEST(getBackgroundColorChar);
    RUN_TEST(colorize);
    
    // Keyboard tests
    RUN_TEST(keyboardModeValue);
    RUN_TEST(parseKeyboardMode);
    RUN_TEST(isCharMode);
    RUN_TEST(isSilentMode);
    
    // Config tests
    RUN_TEST(config_values);
    
    // Version tests
    RUN_TEST(version);
    
    std::cout << std::endl;
    std::cout << "=== Results ===" << std::endl;
    std::cout << "Passed: " << tests_passed << std::endl;
    std::cout << "Failed: " << tests_failed << std::endl;
    
    return tests_failed > 0 ? 1 : 0;
}
