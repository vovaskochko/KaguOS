/**
 * @file cpu.cpp
 * @brief KaguOS Emulator - CPU Module (Implementation)
 */

#include "cpu.hpp"
#include "debug_server.hpp"
#include <sstream>
#include <regex>
#include <chrono>
#include <thread>
#include <vector>
#include <iostream>
#include <fstream>

namespace kagu_boot
{

// ============================================================================
// CpuException
// ============================================================================

CpuException::CpuException(const std::string& message)
    : std::runtime_error(message)
{
}

// ============================================================================
// CPU Constructor
// ============================================================================

CPU::CPU(
    RAM& ram,
    Display& display,
    Keyboard& keyboard,
    Disk& disk,
    InterruptHandler& interrupts
)
    : ram_(ram)
    , display_(display)
    , keyboard_(keyboard)
    , disk_(disk)
    , interrupts_(interrupts)
    , running_(false)
    , debugMode_(false)
    , debugUserOnly_(false)
    , debugPrintJumps_(false)
    , debugSleepMs_(0)
{
}

// ============================================================================
// Execution Control
// ============================================================================

void CPU::resetVector(const std::string& firmware)
{
    std::ifstream firmwareData(firmware);
    if (!firmwareData)
    {
        throw CpuException("CRITICAL ERROR: CPU firmware not found.");
    }

    int address = 1;
    std::string line;

    while (std::getline(firmwareData, line))
    {
        if (address >= ram_.size())
        {
            throw CpuException("CRITICAL ERROR: Firmware image exceeds RAM size.");
        }
        ram_.directAccess(address) = line;
        address++;
    }

    // FREE_MEMORY_END starts at RAM size — shrinks as heap/stack grows
    ram_.directAccess(kagu::toInt(kagu::Address::FreeMemoryEnd)) = std::to_string(ram_.size());

    running_ = true;
    while (running_)
    {
        step();
    }
}

void CPU::step()
{
    jumpNext();

    if (shouldDebugPrint() && debugPrintJumps_)
    {
        printDebugInfo();
    }

    kagu::ProgramCounter pc = getProgramCounter();

    if (debugServer_)
    {
        if (!debugServer_->checkBreakpoint(static_cast<int>(pc), ram_))
        {
            running_ = false;
            return;
        }
    }

    std::string instruction = ram_.read(pc);

    // DEBUG_ON / DEBUG_OFF are mode-aware: in kernel mode they set the global
    // flag, in user mode they set the user-only flag.
    if (instruction.substr(0, 8) == "DEBUG_ON")
    {
        if (ram_.isKernelMode())
            debugMode_ = true;
        else
            debugUserOnly_ = true;
        display_.info("DEBUG ON");
        return;
    }
    else if (instruction.substr(0, 9) == "DEBUG_OFF")
    {
        if (ram_.isKernelMode())
            debugMode_ = false;
        else
            debugUserOnly_ = false;
        display_.info("DEBUG OFF");
        return;
    }

    // Non-blocking keyboard poll — use directAccess; valid in both modes
    int key = keyboard_.pollKey();
    if (key != 0)
    {
        ram_.directAccess(kagu::toInt(kagu::Address::LastKey)) = std::to_string(key);
    }

    try
    {
        executeInstruction(instruction);
    }
    catch (const RamAccessViolation& e)
    {
        handleMemoryError(e);
    }
    catch (const CpuException& e)
    {
        handleCpuError(e);
    }
    catch (const std::exception& e)
    {
        std::cerr << "[FATAL] Exception in step: " << e.what() << "\n";
        std::cerr << "[FATAL] PC=" << pc << " Instruction: " << instruction << "\n";
        std::cerr << "[FATAL] KernelMode=" << (ram_.isKernelMode() ? "yes" : "no") << "\n";
        throw;
    }

    if (shouldDebugPrint())
    {
        ram_.dumpToFile(dumpFile(), !ram_.isKernelMode());

        if (debugSleepMs_ > 0)
        {
            std::this_thread::sleep_for(std::chrono::milliseconds(debugSleepMs_));
        }
    }

    if (!ram_.isKernelMode() && interrupts_.checkTimer())
    {
        handleTimerInterrupt();
    }
}

void CPU::halt()
{
    display_.info("CPU halted.");
    ram_.dumpToFile(dumpFile());
    if (debugServer_)
    {
        debugServer_->notifyHalted(ram_);
    }
    running_ = false;
}

bool CPU::isRunning() const noexcept
{
    return running_;
}

// ============================================================================
// Debug Configuration
// ============================================================================

void CPU::setDebugMode(bool enabled) noexcept      { debugMode_      = enabled; }
void CPU::setDebugUserOnly(bool enabled) noexcept  { debugUserOnly_  = enabled; }
void CPU::setDebugPrintJumps(bool enabled) noexcept{ debugPrintJumps_= enabled; }
void CPU::setDebugSleep(int milliseconds) noexcept { debugSleepMs_   = milliseconds; }
void CPU::setDebugServer(std::unique_ptr<DebugServer> server) noexcept
{
    debugServer_ = std::move(server);
}

// ============================================================================
// Program Counter Management
// ============================================================================

kagu::ProgramCounter CPU::getProgramCounter()
{
    return std::stoi(ram_.directAccess(kagu::toInt(kagu::Address::ProgramCounter)));
}

void CPU::setProgramCounter(kagu::ProgramCounter pc)
{
    ram_.directAccess(kagu::toInt(kagu::Address::ProgramCounter)) = std::to_string(pc);
}

void CPU::jumpNext()  { setProgramCounter(getProgramCounter() + 1); }

void CPU::jump(kagu::RamAddress address)
{
    setProgramCounter(address - 1);
}

void CPU::jumpIf(kagu::RamAddress address)
{
    if (ram_.readRegister(kagu::Address::BoolRes) == "1") jump(address);
}

void CPU::jumpIfNot(kagu::RamAddress address)
{
    if (ram_.readRegister(kagu::Address::BoolRes) == "0") jump(address);
}

void CPU::jumpErr(kagu::RamAddress address)
{
    if (!ram_.readRegister(kagu::Address::Error).empty()) jump(address);
}

void CPU::debug(bool enable) { debugMode_ = enable; }

// ============================================================================
// Address Resolution
// ============================================================================

kagu::RamAddress CPU::resolveAddress(const std::string& addr)
{
    if (addr.empty()) throw CpuException("Empty address");

    if (addr[0] == '*')
    {
        std::string value = ram_.read(std::stoi(addr.substr(1)));
        return std::stoi(value);
    }

    return std::stoi(addr);
}

// ============================================================================
// Instruction Execution
// ============================================================================

void CPU::executeInstruction(const std::string& instruction)
{
    std::istringstream iss(instruction);
    int instrCode;

    if (!(iss >> instrCode))
    {
        throw CpuException("Invalid instruction format: " + instruction);
    }

    auto instr = kagu::fromInt<kagu::Instruction>(instrCode);

    switch (instr)
    {
        case kagu::Instruction::CpuExec:
            executeCpuExec();
            break;

        case kagu::Instruction::CopyFromToAddress:
        {
            std::string src, dest;
            if (!(iss >> src >> dest)) throw CpuException("copy requires 2 arguments");
            executeCopy(src, dest);
            break;
        }

        case kagu::Instruction::Jump:
        {
            std::string addr = instruction.substr(instruction.find(' ') + 1);
            jump(resolveAddress(addr));
            break;
        }

        case kagu::Instruction::JumpIf:
        {
            std::string addr = instruction.substr(instruction.find(' ') + 1);
            jumpIf(resolveAddress(addr));
            break;
        }

        case kagu::Instruction::JumpIfNot:
        {
            std::string addr = instruction.substr(instruction.find(' ') + 1);
            jumpIfNot(resolveAddress(addr));
            break;
        }

        case kagu::Instruction::JumpErr:
        {
            std::string addr = instruction.substr(instruction.find(' ') + 1);
            jumpErr(resolveAddress(addr));
            break;
        }

        case kagu::Instruction::Debug:
        {
            std::string value = instruction.substr(instruction.find(' ') + 1);
            debug(value != "0");
            break;
        }

        default:
            throw CpuException("Unknown instruction: " + instruction);
    }
}

void CPU::executeCopy(const std::string& src, const std::string& dest)
{
    std::string srcAddr  = src;
    std::string destAddr = dest;

    if (!src.empty()  && src[0]  == '*') srcAddr  = ram_.read(std::stoi(src.substr(1)));
    if (!dest.empty() && dest[0] == '*') destAddr = ram_.read(std::stoi(dest.substr(1)));

    if (!src.empty() && src[0] == '@')
        ram_.write(std::stoi(destAddr), src.substr(1));
    else
        ram_.write(std::stoi(destAddr), ram_.read(std::stoi(srcAddr)));
}

void CPU::executeCpuExec()
{
    std::string opStr = ram_.readRegister(kagu::Address::Op);
    if (opStr.empty()) return;

    int opCode = std::stoi(opStr);
    auto op = kagu::fromInt<kagu::Operation>(opCode);

    // Privileged operations may not run in user mode
    if (!ram_.isKernelMode() && kagu::isPrivileged(op))
    {
        throw CpuException(
            "User mode cannot execute privileged operation: " + std::to_string(opCode)
        );
    }

    // Track energy — SysEnergy is a privileged register; use directAccess
    int energyCost = kagu::getOperationCost(op);
    std::string& energyRef = ram_.directAccess(kagu::toInt(kagu::Address::SysEnergy));
    int currentEnergy = energyRef.empty() ? 0 : std::stoi(energyRef);
    energyRef = std::to_string(currentEnergy + energyCost);

    // Save REG_RES / REG_ERROR BEFORE clearing them.
    // execSysReturn needs the kernel-set values that existed just before SYS_RETURN.
    std::string savedRes = ram_.readRegister(kagu::Address::Res);
    std::string savedErr = ram_.readRegister(kagu::Address::Error);

    ram_.writeRegister(kagu::Address::Error, "");

    std::string regA = ram_.readRegister(kagu::Address::A);
    std::string regB = ram_.readRegister(kagu::Address::B);
    std::string regC = ram_.readRegister(kagu::Address::C);
    std::string regD = ram_.readRegister(kagu::Address::D);

    switch (op)
    {
        case kagu::Operation::Add:           execAdd(regA, regB);              break;
        case kagu::Operation::Sub:           execSub(regA, regB);              break;
        case kagu::Operation::Incr:          execIncr(regA);                   break;
        case kagu::Operation::Decr:          execDecr(regA);                   break;
        case kagu::Operation::Div:           execDiv(regA, regB);              break;
        case kagu::Operation::Mod:           execMod(regA, regB);              break;
        case kagu::Operation::Mul:           execMul(regA, regB);              break;
        case kagu::Operation::IsNum:         execIsNum(regA);                  break;
        case kagu::Operation::CmpEq:         execCmpEq(regA, regB);            break;
        case kagu::Operation::CmpNeq:        execCmpNeq(regA, regB);           break;
        case kagu::Operation::CmpLt:         execCmpLt(regA, regB);            break;
        case kagu::Operation::CmpLe:         execCmpLe(regA, regB);            break;
        case kagu::Operation::Contains:      execContains(regA, regB);         break;
        case kagu::Operation::GetLength:     execGetLength(regA);              break;
        case kagu::Operation::StartsWith:    execStartsWith(regA, regB);       break;
        case kagu::Operation::GetColumn:     execGetColumn(regA, regB, regC);  break;
        case kagu::Operation::ReplaceColumn: execReplaceColumn(regA, regB, regC, regD); break;
        case kagu::Operation::ConcatWith:    execConcatWith(regA, regB, regC); break;
        case kagu::Operation::ReadInput:     execReadInput();                  break;
        case kagu::Operation::Display:       execDisplay(false);               break;
        case kagu::Operation::DisplayLn:     execDisplay(true);                break;
        case kagu::Operation::ReadBlock:     execReadBlock(regA, regB);        break;
        case kagu::Operation::WriteBlock:    execWriteBlock(regA, regB, regC); break;
        case kagu::Operation::SetBackgroundColor: execSetBackground(regA);     break;
        case kagu::Operation::RenderBitmap:  execRenderBitmap(regA, regB);     break;
        case kagu::Operation::SysCall:       execSysCall();                    break;
        case kagu::Operation::SysReturn:     execSysReturn(savedRes, savedErr); break;
        case kagu::Operation::EncryptData:
        case kagu::Operation::DecryptData:
            ram_.writeRegister(kagu::Address::Res, regA);
            break;
        case kagu::Operation::Nop:           execNop(regA);                    break;
        case kagu::Operation::Halt:          halt();                           break;
        default:
            throw CpuException("Unknown operation: " + std::to_string(opCode));
    }
}

// ============================================================================
// Arithmetic Operations
// ============================================================================

void CPU::execAdd(const std::string& a, const std::string& b)
{
    if (isFloat(a) || isFloat(b))
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) + std::stod(b)));
    else
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) + std::stoi(b)));
}

void CPU::execSub(const std::string& a, const std::string& b)
{
    if (isFloat(a) || isFloat(b))
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) - std::stod(b)));
    else
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) - std::stoi(b)));
}

void CPU::execIncr(const std::string& a)
{
    if (isFloat(a))
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) + 1));
    else
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) + 1));
}

void CPU::execDecr(const std::string& a)
{
    if (isFloat(a))
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) - 1));
    else
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) - 1));
}

void CPU::execDiv(const std::string& a, const std::string& b)
{
    if (b == "0" || b == "0.0")
    {
        ram_.writeRegister(kagu::Address::Error, "Division by zero");
        return;
    }
    if (isFloat(a) || isFloat(b))
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) / std::stod(b)));
    else
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) / std::stoi(b)));
}

void CPU::execMod(const std::string& a, const std::string& b)
{
    if (b == "0")
    {
        ram_.writeRegister(kagu::Address::Error, "Modulo by zero");
        return;
    }
    ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) % std::stoi(b)));
}

void CPU::execMul(const std::string& a, const std::string& b)
{
    if (isFloat(a) || isFloat(b))
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) * std::stod(b)));
    else
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) * std::stoi(b)));
}

// ============================================================================
// Type Check
// ============================================================================

void CPU::execIsNum(const std::string& a)
{
    static const std::regex numPattern(R"(^-?\d*\.?\d+$)");
    ram_.writeRegister(kagu::Address::BoolRes,
                       std::regex_match(a, numPattern) ? "1" : "0");
}

// ============================================================================
// Comparison Operations
// ============================================================================

void CPU::execCmpEq(const std::string& a, const std::string& b)
{
    ram_.writeRegister(kagu::Address::BoolRes, (a == b) ? "1" : "0");
}

void CPU::execCmpNeq(const std::string& a, const std::string& b)
{
    ram_.writeRegister(kagu::Address::BoolRes, (a != b) ? "1" : "0");
}

void CPU::execCmpLt(const std::string& a, const std::string& b)
{
    bool result = (isFloat(a) || isFloat(b))
        ? (std::stod(a) < std::stod(b))
        : (std::stoi(a) < std::stoi(b));
    ram_.writeRegister(kagu::Address::BoolRes, result ? "1" : "0");
}

void CPU::execCmpLe(const std::string& a, const std::string& b)
{
    bool result = (isFloat(a) || isFloat(b))
        ? (std::stod(a) <= std::stod(b))
        : (std::stoi(a) <= std::stoi(b));
    ram_.writeRegister(kagu::Address::BoolRes, result ? "1" : "0");
}

// ============================================================================
// String Operations
// ============================================================================

void CPU::execContains(const std::string& a, const std::string& b)
{
    size_t pos = a.find(b);
    if (pos != std::string::npos)
    {
        ram_.writeRegister(kagu::Address::Res, std::to_string(pos + 1));
        ram_.writeRegister(kagu::Address::BoolRes, "1");
    }
    else
    {
        ram_.writeRegister(kagu::Address::Res, "");
        ram_.writeRegister(kagu::Address::BoolRes, "0");
    }
}

void CPU::execGetLength(const std::string& a)
{
    ram_.writeRegister(kagu::Address::Res, std::to_string(a.length()));
}

void CPU::execStartsWith(const std::string& a, const std::string& b)
{
    if (a.length() >= b.length() && a.substr(0, b.length()) == b)
    {
        ram_.writeRegister(kagu::Address::BoolRes, "1");
        ram_.writeRegister(kagu::Address::Res, a.substr(b.length()));
    }
    else
    {
        ram_.writeRegister(kagu::Address::BoolRes, "0");
        ram_.writeRegister(kagu::Address::Res, "");
    }
}

void CPU::execGetColumn(const std::string& a, const std::string& b, const std::string& c)
{
    int columnIndex = std::stoi(b);

    if (c.empty())
    {
        if (columnIndex >= 1 && columnIndex <= static_cast<int>(a.length()))
            ram_.writeRegister(kagu::Address::Res, std::string(1, a[columnIndex - 1]));
        else
            ram_.writeRegister(kagu::Address::Res, "");
        return;
    }

    std::vector<std::string> tokens;
    std::string current;
    for (char ch : a)
    {
        if (c.find(ch) != std::string::npos)
        {
            if (!current.empty()) { tokens.push_back(current); current.clear(); }
        }
        else
        {
            current += ch;
        }
    }
    if (!current.empty()) tokens.push_back(current);

    if (columnIndex >= 1 && columnIndex <= static_cast<int>(tokens.size()))
        ram_.writeRegister(kagu::Address::Res, tokens[columnIndex - 1]);
    else
        ram_.writeRegister(kagu::Address::Res, "");
}

void CPU::execReplaceColumn(const std::string& a, const std::string& b,
                            const std::string& c, const std::string& d)
{
    int columnIndex = std::stoi(b);
    std::string result;

    if (c.empty())
    {
        result = a;
        if (columnIndex >= 1 && columnIndex <= static_cast<int>(a.length()))
            result[columnIndex - 1] = d.empty() ? ' ' : d[0];
    }
    else
    {
        std::vector<std::string> tokens;
        std::string current;
        for (char ch : a)
        {
            if (c.find(ch) != std::string::npos) { tokens.push_back(current); current.clear(); }
            else current += ch;
        }
        tokens.push_back(current);

        if (columnIndex >= 1 && columnIndex <= static_cast<int>(tokens.size()))
            tokens[columnIndex - 1] = d;

        for (size_t i = 0; i < tokens.size(); ++i)
        {
            if (i > 0) result += c;
            result += tokens[i];
        }
    }

    ram_.writeRegister(kagu::Address::Res, result);
}

void CPU::execConcatWith(const std::string& a, const std::string& b, const std::string& c)
{
    ram_.writeRegister(kagu::Address::Res, a + c + b);
}

// ============================================================================
// I/O Operations (privileged — blocked in user mode)
// ============================================================================

void CPU::execReadInput()
{
    std::string mode  = ram_.readRegister(kagu::Address::KeyboardBuffer);
    std::string input = keyboard_.readInput(mode);
    if (keyboard_.isEOF())
    {
        // Ctrl+D or end of piped input — exit cleanly
        running_ = false;
        return;
    }
    ram_.writeRegister(kagu::Address::KeyboardBuffer, input);
}

void CPU::execDisplay(bool newline)
{
    std::string buffer = ram_.readRegister(kagu::Address::DisplayBuffer);
    std::string color  = ram_.readRegister(kagu::Address::DisplayColor);
    display_.printWithColorStr(buffer, color, newline);
}

// ============================================================================
// Disk Operations (privileged — blocked in user mode)
// ============================================================================

void CPU::execReadBlock(const std::string& diskName, const std::string& blockNum)
{
    auto result = disk_.readBlock(diskName, std::stoi(blockNum));
    if (result)
        ram_.writeRegister(kagu::Address::Res, *result);
    else
        ram_.writeRegister(kagu::Address::Error, "Failed to read block");
}

void CPU::execWriteBlock(const std::string& diskName,
                         const std::string& blockNum,
                         const std::string& data)
{
    if (!disk_.writeBlock(diskName, std::stoi(blockNum), data))
        ram_.writeRegister(kagu::Address::Error, "Failed to write block");
}

// ============================================================================
// Display Control (privileged — blocked in user mode)
// ============================================================================

void CPU::execSetBackground(const std::string& color)
{
    std::string bgCode = display_.setBackgroundStr(color);
    ram_.writeRegister(kagu::Address::DisplayBackground, bgCode);
    display_.clear();
}

void CPU::execRenderBitmap(const std::string& startStr, const std::string& endStr)
{
    int startAddr = std::stoi(startStr);
    int endAddr   = std::stoi(endStr);

    std::string xStr = ram_.readRegister(kagu::Address::C);
    std::string yStr = ram_.readRegister(kagu::Address::D);
    int x = (xStr.empty() || xStr == "0") ? 0 : std::stoi(xStr);
    int y = (yStr.empty() || yStr == "0") ? 0 : std::stoi(yStr);

    display_.renderBitmap(startAddr, endAddr, x, y, [this](int addr) {
        return ram_.read(addr);
    });
}

// ============================================================================
// System Call Operations
// ============================================================================

/**
 * OP_SYS_CALL — user mode → kernel mode
 *
 * 1. Switch to kernel mode.
 * 2. Backup user registers (1-UserSpaceEnd) into process memory at ProcStartAddress.
 * 3. Save current PC in REG_SYS_INTERRUPT_DATA as "0 <pc> 0".
 * 4. Jump to kernel syscall handler (REG_SYS_CALL_HANDLER).
 */
void CPU::execSysCall()
{
    if (shouldDebugPrint())
        display_.debug("Switch from user mode to kernel mode.", false);

    ram_.setKernelMode(true);

    const std::string& procOffsetStr =
        ram_.directAccess(kagu::toInt(kagu::Address::ProcStartAddress));

    if (!procOffsetStr.empty() && procOffsetStr != "0")
    {
        int procOffset = std::stoi(procOffsetStr);
        for (int i = 1; i <= kagu::toInt(kagu::Address::UserSpaceEnd); ++i)
        {
            ram_.directAccess(i + procOffset) = ram_.directAccess(i);
        }
    }

    kagu::ProgramCounter pc = getProgramCounter();
    ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptData)) =
        "0 " + std::to_string(pc) + " 0";

    kagu::RamAddress handler = interrupts_.getSysCallHandler();
    jump(handler);
}

/**
 * OP_SYS_RETURN — kernel mode → user mode
 *
 * 1. Restore user registers (1-UserSpaceEnd) from process memory backup.
 * 2. Overwrite REG_RES / REG_ERROR with kernel return values (savedRes / savedErr).
 * 3. Restore user PC from REG_SYS_INTERRUPT_DATA.
 * 4. Clear REG_SYS_INTERRUPT_DATA.
 * 5. Switch to user mode.
 *
 * ignoreResult flag in SysInterruptData:
 *   "0" = normal syscall return  → write savedRes / savedErr to user registers
 *   "1" = first program launch   → keep whatever was restored from backup
 */
void CPU::execSysReturn(const std::string& savedRes, const std::string& savedErr)
{
    const std::string& procOffsetStr =
        ram_.directAccess(kagu::toInt(kagu::Address::ProcStartAddress));

    if (!procOffsetStr.empty() && procOffsetStr != "0")
    {
        int procOffset = std::stoi(procOffsetStr);
        for (int i = 1; i <= kagu::toInt(kagu::Address::UserSpaceEnd); ++i)
        {
            ram_.directAccess(i) = ram_.directAccess(i + procOffset);
        }
    }

    std::string intData =
        ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptData));
    std::istringstream iss(intData);
    std::string typeStr, pcStr, ignoreFlag;
    iss >> typeStr >> pcStr >> ignoreFlag;

    if (ignoreFlag != "1")
    {
        ram_.directAccess(kagu::toInt(kagu::Address::Res))   = savedRes;
        ram_.directAccess(kagu::toInt(kagu::Address::Error)) = savedErr;
    }

    ram_.directAccess(kagu::toInt(kagu::Address::ProgramCounter)) = pcStr;
    ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptData)) = "";

    ram_.setKernelMode(false);

    if (shouldDebugPrint())
        display_.debug("Switch from kernel mode to user mode.", false);
}

// ============================================================================
// Control Operations
// ============================================================================

void CPU::execNop(const std::string& a)
{
    if (!a.empty())
    {
        double seconds = std::stod(a);
        std::this_thread::sleep_for(
            std::chrono::milliseconds(static_cast<int>(seconds * 1000))
        );
    }
}

// ============================================================================
// Error Handling
// ============================================================================

/**
 * Memory access violation:
 *  - Kernel mode → fatal (system is broken).
 *  - User mode   → graceful crash: trigger SYS_CALL_EXIT(139) so the kernel
 *                  shell regains control.
 */
void CPU::handleMemoryError(const RamAccessViolation& e)
{
    if (ram_.isKernelMode())
    {
        display_.error(std::string("[FATAL] Kernel mode memory error: ") + e.what());
        ram_.dumpToFile(kagu::config::RAM_DUMP_FILE.data());
        running_ = false;
    }
    else
    {
        display_.error(std::string("[ERROR] Segmentation fault (SIGSEGV): ") + e.what());
        ram_.dumpToFile(kagu::config::USER_RAM_DUMP_FILE.data());

        // Synthesise SYS_CALL_EXIT(139) to hand control back to kernel shell
        ram_.writeRegister(kagu::Address::A,  "139");
        ram_.writeRegister(kagu::Address::E,  "0");  // SYS_CALL_EXIT = 0
        ram_.writeRegister(kagu::Address::Op,
            std::to_string(kagu::toInt(kagu::Operation::SysCall)));
        executeCpuExec();
    }
}

/**
 * CPU exception (privilege violation, unknown op, etc.):
 *  - Kernel mode → fatal.
 *  - User mode   → graceful crash via SYS_CALL_EXIT(1).
 */
void CPU::handleCpuError(const CpuException& e)
{
    if (ram_.isKernelMode())
    {
        display_.error(std::string("[FATAL] Kernel mode CPU error: ") + e.what());
        ram_.dumpToFile(kagu::config::RAM_DUMP_FILE.data());
        running_ = false;
    }
    else
    {
        display_.error(std::string("[ERROR] User program crashed: ") + e.what());
        ram_.dumpToFile(kagu::config::USER_RAM_DUMP_FILE.data());

        // Synthesise SYS_CALL_EXIT(1)
        ram_.writeRegister(kagu::Address::A,  "1");
        ram_.writeRegister(kagu::Address::E,  "0");  // SYS_CALL_EXIT = 0
        ram_.writeRegister(kagu::Address::Op,
            std::to_string(kagu::toInt(kagu::Operation::SysCall)));
        executeCpuExec();
    }
}

// ============================================================================
// Timer Interrupt
// ============================================================================

void CPU::handleTimerInterrupt()
{
    kagu::ProgramCounter pc = getProgramCounter();
    ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptData)) =
        "1 " + std::to_string(pc) + " 1";
    ram_.setKernelMode(true);
    ram_.dumpToFile(dumpFile());
    jump(interrupts_.getInterruptHandler());
}

// ============================================================================
// Debug Helpers
// ============================================================================

bool CPU::shouldDebugPrint() const noexcept
{
    return debugMode_ || (debugUserOnly_ && !ram_.isKernelMode());
}

const char* CPU::dumpFile() const noexcept
{
    return ram_.isKernelMode()
        ? kagu::config::RAM_DUMP_FILE.data()
        : kagu::config::USER_RAM_DUMP_FILE.data();
}

void CPU::printDebugInfo()
{
    kagu::ProgramCounter pc = getProgramCounter();
    std::string cmd = ram_.read(pc);

    const char* prefix = ram_.isKernelMode()
        ? "\033[34m[KERNEL]"
        : "\033[33m[USER]  ";

    std::cerr << prefix << "\033[0m Command " << pc
              << ": \033[35m" << cmd << "\033[0m" << std::endl;
}

// ============================================================================
// Utility Functions
// ============================================================================

bool CPU::isFloat(const std::string& s)
{
    return s.find('.') != std::string::npos;
}

std::string CPU::formatNumber(double value)
{
    std::ostringstream out;
    out.precision(10);
    out << std::fixed << value;

    std::string result = out.str();
    result.erase(result.find_last_not_of('0') + 1, std::string::npos);
    if (result.back() == '.') result.pop_back();

    return result;
}

} // namespace kagu_boot
