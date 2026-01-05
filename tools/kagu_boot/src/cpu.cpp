/**
 * @file cpu.cpp
 * @brief KaguOS Emulator - CPU Module (Bare Metal Edition)
 */

#include "cpu.hpp"
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
    Disk& disk
)
    : ram_(ram)
    , display_(display)
    , keyboard_(keyboard)
    , disk_(disk)
    , running_(false)
    , debugMode_(false)
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

    // Load the entire firmware file into RAM line by line
    while (std::getline(firmwareData, line))
    {
        if (address >= ram_.size())
        {
            throw CpuException("CRITICAL ERROR: Firmware image exceeds RAM size.");
        }

        ram_.directAccess(address) = line;
        address++;
    }

    // Initialize FREE_MEMORY_END with RAM size to support dynamic memory allocation
    ram_.directAccess(kagu::toInt(kagu::Address::FreeMemoryEnd)) = std::to_string(ram_.size());

    // Start Fetch-Decode-Execute loop
    running_ = true;    
    while (running_)
    {
        step();
    }
}

void CPU::step()
{
    jumpNext();
    
    if (debugMode_ && debugPrintJumps_)
    {
        printDebugInfo();
    }
    
    kagu::ProgramCounter pc = getProgramCounter();
    std::string instruction = ram_.read(pc);
    
    // Handle debug commands
    if (instruction.substr(0, 8) == "DEBUG_ON")
    {
        debugMode_ = true;
        display_.info("DEBUG ON");
        return;
    }
    else if (instruction.substr(0, 9) == "DEBUG_OFF")
    {
        debugMode_ = false;
        display_.info("DEBUG OFF");
        return;
    }
    
    // Poll keyboard for non-blocking input and update LastKey register
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
        throw;
    }
    
    if (debugMode_)
    {
        ram_.dumpToFile(std::string(kagu::config::RAM_DUMP_FILE));
        
        if (debugSleepMs_ > 0)
        {
            std::this_thread::sleep_for(
                std::chrono::milliseconds(debugSleepMs_)
            );
        }
    }
}

void CPU::halt()
{
    display_.info("CPU halted.");
    ram_.dumpToFile(std::string(kagu::config::RAM_DUMP_FILE));
    running_ = false;
}

bool CPU::isRunning() const noexcept
{
    return running_;
}

// ============================================================================
// Debug Configuration
// ============================================================================

void CPU::setDebugMode(bool enabled) noexcept
{
    debugMode_ = enabled;
}

void CPU::setDebugPrintJumps(bool enabled) noexcept
{
    debugPrintJumps_ = enabled;
}

void CPU::setDebugSleep(int milliseconds) noexcept
{
    debugSleepMs_ = milliseconds;
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

void CPU::jumpNext()
{
    setProgramCounter(getProgramCounter() + 1);
}

void CPU::jump(kagu::RamAddress address)
{
    setProgramCounter(address - 1);
}

void CPU::jumpIf(kagu::RamAddress address)
{
    if (ram_.readRegister(kagu::Address::BoolRes) == "1")
    {
        jump(address);
    }
}

void CPU::jumpIfNot(kagu::RamAddress address)
{
    if (ram_.readRegister(kagu::Address::BoolRes) == "0")
    {
        jump(address);
    }
}

void CPU::jumpErr(kagu::RamAddress address)
{
    if (!ram_.readRegister(kagu::Address::Error).empty())
    {
        jump(address);
    }
}

void CPU::debug(bool enable)
{
    debugMode_ = enable;
}

// ============================================================================
// Address Resolution
// ============================================================================

kagu::RamAddress CPU::resolveAddress(const std::string& addr)
{
    if (addr.empty())
    {
        throw CpuException("Empty address");
    }
    
    if (addr[0] == '*')
    {
        std::string innerAddr = addr.substr(1);
        std::string value = ram_.read(std::stoi(innerAddr));
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
            if (!(iss >> src >> dest))
            {
                throw CpuException("copy requires 2 arguments");
            }
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
    std::string srcAddr = src;
    std::string destAddr = dest;
    
    if (!src.empty() && src[0] == '*')
    {
        srcAddr = ram_.read(std::stoi(src.substr(1)));
    }
    
    if (!dest.empty() && dest[0] == '*')
    {
        destAddr = ram_.read(std::stoi(dest.substr(1)));
    }
    
    if (!src.empty() && src[0] == '@')
    {
        ram_.write(std::stoi(destAddr), src.substr(1));
    }
    else
    {
        ram_.write(std::stoi(destAddr), ram_.read(std::stoi(srcAddr)));
    }
}

void CPU::executeCpuExec()
{
    std::string opStr = ram_.readRegister(kagu::Address::Op);
    if (opStr.empty()) {
        return;
    }
    
    int opCode = std::stoi(opStr);
    auto op = kagu::fromInt<kagu::Operation>(opCode);
    
    // Increment energy counter based on operation cost
    int energyCost = kagu::getOperationCost(op);
    std::string& energyRef = ram_.directAccess(kagu::toInt(kagu::Address::SysEnergy));
    int currentEnergy = energyRef.empty() ? 0 : std::stoi(energyRef);
    energyRef = std::to_string(currentEnergy + energyCost);
    
    ram_.writeRegister(kagu::Address::Error, "");
    
    std::string regA = ram_.readRegister(kagu::Address::A);
    std::string regB = ram_.readRegister(kagu::Address::B);
    std::string regC = ram_.readRegister(kagu::Address::C);
    std::string regD = ram_.readRegister(kagu::Address::D);
    
    switch (op)
    {
        case kagu::Operation::Add:
            execAdd(regA, regB);
            break;
        case kagu::Operation::Sub:
            execSub(regA, regB);
            break;
        case kagu::Operation::Incr:
            execIncr(regA);
            break;
        case kagu::Operation::Decr:
            execDecr(regA);
            break;
        case kagu::Operation::Div:
            execDiv(regA, regB);
            break;
        case kagu::Operation::Mod:
            execMod(regA, regB);
            break;
        case kagu::Operation::Mul:
            execMul(regA, regB);
            break;
        case kagu::Operation::IsNum:
            execIsNum(regA);
            break;
        case kagu::Operation::CmpEq:
            execCmpEq(regA, regB);
            break;
        case kagu::Operation::CmpNeq:
            execCmpNeq(regA, regB);
            break;
        case kagu::Operation::CmpLt:
            execCmpLt(regA, regB);
            break;
        case kagu::Operation::CmpLe:
            execCmpLe(regA, regB);
            break;
        case kagu::Operation::Contains:
            execContains(regA, regB);
            break;
        case kagu::Operation::GetLength:
            execGetLength(regA);
            break;
        case kagu::Operation::StartsWith:
            execStartsWith(regA, regB);
            break;
        case kagu::Operation::GetColumn:
            execGetColumn(regA, regB, regC);
            break;
        case kagu::Operation::ReplaceColumn:
            execReplaceColumn(regA, regB, regC, regD);
            break;
        case kagu::Operation::ConcatWith:
            execConcatWith(regA, regB, regC);
            break;
        case kagu::Operation::ReadInput:
            execReadInput();
            break;
        case kagu::Operation::Display:
            execDisplay(false);
            break;
        case kagu::Operation::DisplayLn:
            execDisplay(true);
            break;
        case kagu::Operation::ReadBlock:
            execReadBlock(regA, regB);
            break;
        case kagu::Operation::WriteBlock:
            execWriteBlock(regA, regB, regC);
            break;
        case kagu::Operation::SetBackgroundColor:
            execSetBackground(regA);
            break;
        case kagu::Operation::RenderBitmap:
            execRenderBitmap(regA, regB);
            break;
        case kagu::Operation::SysCall:
            throw CpuException("CRITICAL ERROR: System calls are not supported in Bare Metal mode. "
                             "Use direct hardware access instead.");
        case kagu::Operation::SysReturn:
            throw CpuException("CRITICAL ERROR: Invalid instruction SYS_RETURN in Bare Metal mode.");
        case kagu::Operation::EncryptData:
        case kagu::Operation::DecryptData:
            ram_.writeRegister(kagu::Address::Res, regA);
            break;
        case kagu::Operation::Nop:
            execNop(regA);
            break;
        case kagu::Operation::Halt:
            halt();
            break;
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
    {
        double result = std::stod(a) + std::stod(b);
        ram_.writeRegister(kagu::Address::Res, formatNumber(result));
    }
    else
    {
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) + std::stoi(b)));
    }
}

void CPU::execSub(const std::string& a, const std::string& b)
{
    if (isFloat(a) || isFloat(b))
    {
        double result = std::stod(a) - std::stod(b);
        ram_.writeRegister(kagu::Address::Res, formatNumber(result));
    }
    else
    {
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) - std::stoi(b)));
    }
}

void CPU::execIncr(const std::string& a)
{
    if (isFloat(a))
    {
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) + 1));
    }
    else
    {
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) + 1));
    }
}

void CPU::execDecr(const std::string& a)
{
    if (isFloat(a))
    {
        ram_.writeRegister(kagu::Address::Res, formatNumber(std::stod(a) - 1));
    }
    else
    {
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) - 1));
    }
}

void CPU::execDiv(const std::string& a, const std::string& b)
{
    if (b == "0" || b == "0.0")
    {
        ram_.writeRegister(kagu::Address::Error, "Division by zero");
        return;
    }
    
    if (isFloat(a) || isFloat(b))
    {
        double result = std::stod(a) / std::stod(b);
        ram_.writeRegister(kagu::Address::Res, formatNumber(result));
    }
    else
    {
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) / std::stoi(b)));
    }
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
    {
        double result = std::stod(a) * std::stod(b);
        ram_.writeRegister(kagu::Address::Res, formatNumber(result));
    }
    else
    {
        ram_.writeRegister(kagu::Address::Res, std::to_string(std::stoi(a) * std::stoi(b)));
    }
}

// ============================================================================
// Type Check
// ============================================================================

void CPU::execIsNum(const std::string& a)
{
    static const std::regex numPattern(R"(^-?\d*\.?\d+$)");
    bool isNum = std::regex_match(a, numPattern);
    ram_.writeRegister(kagu::Address::BoolRes, isNum ? "1" : "0");
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
    if (isFloat(a) || isFloat(b))
    {
        ram_.writeRegister(kagu::Address::BoolRes, (std::stod(a) < std::stod(b)) ? "1" : "0");
    }
    else
    {
        ram_.writeRegister(kagu::Address::BoolRes, (std::stoi(a) < std::stoi(b)) ? "1" : "0");
    }
}

void CPU::execCmpLe(const std::string& a, const std::string& b)
{
    if (isFloat(a) || isFloat(b))
    {
        ram_.writeRegister(kagu::Address::BoolRes, (std::stod(a) <= std::stod(b)) ? "1" : "0");
    }
    else
    {
        ram_.writeRegister(kagu::Address::BoolRes, (std::stoi(a) <= std::stoi(b)) ? "1" : "0");
    }
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
        {
            ram_.writeRegister(kagu::Address::Res, std::string(1, a[columnIndex - 1]));
        }
        else
        {
            ram_.writeRegister(kagu::Address::Res, "");
        }
    }
    else
    {
        std::vector<std::string> tokens;
        std::string current;
        
        for (char ch : a)
        {
            if (c.find(ch) != std::string::npos)
            {
                if (!current.empty())
                {
                    tokens.push_back(current);
                    current.clear();
                }
            }
            else
            {
                current += ch;
            }
        }
        if (!current.empty())
        {
            tokens.push_back(current);
        }
        
        if (columnIndex >= 1 && columnIndex <= static_cast<int>(tokens.size()))
        {
            ram_.writeRegister(kagu::Address::Res, tokens[columnIndex - 1]);
        }
        else
        {
            ram_.writeRegister(kagu::Address::Res, "");
        }
    }
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
        {
            result[columnIndex - 1] = d.empty() ? ' ' : d[0];
        }
    }
    else
    {
        std::vector<std::string> tokens;
        std::string current;
        
        for (char ch : a)
        {
            if (c.find(ch) != std::string::npos)
            {
                tokens.push_back(current);
                current.clear();
            }
            else
            {
                current += ch;
            }
        }
        tokens.push_back(current);
        
        if (columnIndex >= 1 && columnIndex <= static_cast<int>(tokens.size()))
        {
            tokens[columnIndex - 1] = d;
        }
        
        for (size_t i = 0; i < tokens.size(); ++i)
        {
            if (i > 0)
            {
                result += c;
            }
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
// I/O Operations
// ============================================================================

void CPU::execReadInput()
{
    std::string mode = ram_.readRegister(kagu::Address::KeyboardBuffer);
    std::string input = keyboard_.readInput(mode);
    ram_.writeRegister(kagu::Address::KeyboardBuffer, input);
}

void CPU::execDisplay(bool newline)
{
    std::string buffer = ram_.readRegister(kagu::Address::DisplayBuffer);
    std::string color = ram_.readRegister(kagu::Address::DisplayColor);
    display_.printWithColorStr(buffer, color, newline);
}

// ============================================================================
// Disk Operations
// ============================================================================

void CPU::execReadBlock(const std::string& diskName, const std::string& blockNum)
{
    auto result = disk_.readBlock(diskName, std::stoi(blockNum));
    if (result)
    {
        ram_.writeRegister(kagu::Address::Res, *result);
    }
    else
    {
        ram_.writeRegister(kagu::Address::Error, "Failed to read block");
    }
}

void CPU::execWriteBlock(
    const std::string& diskName, 
    const std::string& blockNum,
    const std::string& data
)
{
    if (!disk_.writeBlock(diskName, std::stoi(blockNum), data))
    {
        ram_.writeRegister(kagu::Address::Error, "Failed to write block");
    }
}

// ============================================================================
// Display Control
// ============================================================================

void CPU::execSetBackground(const std::string& color)
{
    std::string bgCode = display_.setBackgroundStr(color);
    ram_.writeRegister(kagu::Address::DisplayBackground, bgCode);
}

void CPU::execRenderBitmap(const std::string& startStr, const std::string& endStr)
{
    int startAddr = std::stoi(startStr);
    int endAddr = std::stoi(endStr);
    
    std::string xStr = ram_.readRegister(kagu::Address::C);
    std::string yStr = ram_.readRegister(kagu::Address::D);
    int x = (xStr.empty() || xStr == "0") ? 0 : std::stoi(xStr);
    int y = (yStr.empty() || yStr == "0") ? 0 : std::stoi(yStr);
    
    display_.renderBitmap(startAddr, endAddr, x, y, [this](int addr) {
        return ram_.read(addr);
    });
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

void CPU::handleMemoryError(const RamAccessViolation& e)
{
    display_.error(std::string("[FATAL] Memory access error: ") + e.what());
    ram_.dumpToFile(std::string(kagu::config::RAM_DUMP_FILE));
    running_ = false;
}

void CPU::handleCpuError(const CpuException& e)
{
    display_.error(std::string("[FATAL] CPU error: ") + e.what());
    ram_.dumpToFile(std::string(kagu::config::RAM_DUMP_FILE));
    running_ = false;
}

// ============================================================================
// Debug Helpers
// ============================================================================

void CPU::printDebugInfo()
{
    kagu::ProgramCounter pc = getProgramCounter();
    std::string cmd = ram_.read(pc);
    
    std::cout << "\033[34m[DEBUG]\033[0m Command " << pc 
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
    if (result.back() == '.')
    {
        result.pop_back();
    }
    
    return result;
}

} // namespace kagu_boot
