/**
 * @file cpu.hpp
 * @brief KaguOS Emulator - CPU Module (Bare Metal Edition)
 * 
 * No kernel/user mode, no interrupts, no syscalls.
 * All operations are directly available.
 */

#pragma once

#include <kagu/kagu.hpp>
#include "ram.hpp"
#include "display.hpp"
#include "input.hpp"
#include "disk.hpp"

#include <string>
#include <stdexcept>

namespace kagu_boot
{

/**
 * @brief CPU execution exception
 */
class CpuException : public std::runtime_error
{
public:
    explicit CpuException(const std::string& message);
};

/**
 * @brief CPU emulator (Bare Metal Edition)
 * 
 * All operations are available without privilege checking.
 * SysCall and SysReturn operations will cause a fatal error.
 */
class CPU
{
public:
    CPU(
        RAM& ram,
        Display& display,
        Keyboard& keyboard,
        Disk& disk
    );
    
    // Execution Control
    void resetVector(const std::string& firmware);
    void step();
    void halt();
    [[nodiscard]] bool isRunning() const noexcept;
    
    // Debug Configuration
    void setDebugMode(bool enabled) noexcept;
    void setDebugPrintJumps(bool enabled) noexcept;
    void setDebugSleep(int milliseconds) noexcept;
    
private:
    RAM& ram_;
    Display& display_;
    Keyboard& keyboard_;
    Disk& disk_;
    
    bool running_;
    bool debugMode_;
    bool debugPrintJumps_;
    int debugSleepMs_;
    
    // Program Counter Management
    [[nodiscard]] kagu::ProgramCounter getProgramCounter();
    void setProgramCounter(kagu::ProgramCounter pc);
    void jumpNext();
    void jump(kagu::RamAddress address);
    void jumpIf(kagu::RamAddress address);
    void jumpIfNot(kagu::RamAddress address);
    void jumpErr(kagu::RamAddress address);
    void debug(bool enable);
    
    // Address Resolution
    [[nodiscard]] kagu::RamAddress resolveAddress(const std::string& addr);
    
    // Instruction Execution
    void executeInstruction(const std::string& instruction);
    void executeCopy(const std::string& src, const std::string& dest);
    void executeCpuExec();
    
    // Arithmetic Operations
    void execAdd(const std::string& a, const std::string& b);
    void execSub(const std::string& a, const std::string& b);
    void execIncr(const std::string& a);
    void execDecr(const std::string& a);
    void execDiv(const std::string& a, const std::string& b);
    void execMod(const std::string& a, const std::string& b);
    void execMul(const std::string& a, const std::string& b);
    
    // Type Check
    void execIsNum(const std::string& a);
    
    // Comparison Operations
    void execCmpEq(const std::string& a, const std::string& b);
    void execCmpNeq(const std::string& a, const std::string& b);
    void execCmpLt(const std::string& a, const std::string& b);
    void execCmpLe(const std::string& a, const std::string& b);
    
    // String Operations
    void execContains(const std::string& a, const std::string& b);
    void execGetLength(const std::string& a);
    void execStartsWith(const std::string& a, const std::string& b);
    void execGetColumn(const std::string& a, const std::string& b, const std::string& c);
    void execReplaceColumn(const std::string& a, const std::string& b, 
                           const std::string& c, const std::string& d);
    void execConcatWith(const std::string& a, const std::string& b, const std::string& c);
    
    // I/O Operations
    void execReadInput();
    void execDisplay(bool newline);
    
    // Disk Operations
    void execReadBlock(const std::string& diskName, const std::string& blockNum);
    void execWriteBlock(const std::string& diskName, const std::string& blockNum,
                        const std::string& data);
    
    // Display Control
    void execSetBackground(const std::string& color);
    void execRenderBitmap(const std::string& startStr, const std::string& endStr);
    
    // Control Operations
    void execNop(const std::string& a);
    
    // Error Handling
    void handleMemoryError(const RamAccessViolation& e);
    void handleCpuError(const CpuException& e);
    
    // Debug Helpers
    void printDebugInfo();
    
    // Utility Functions
    [[nodiscard]] static bool isFloat(const std::string& s);
    [[nodiscard]] static std::string formatNumber(double value);
};

} // namespace kagu_boot
