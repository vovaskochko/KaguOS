/**
 * @file ram.cpp
 * @brief KaguOS Emulator - RAM Memory Module (Bare Metal Edition)
 * 
 * Flat memory model implementation.
 */

#include "ram.hpp"
#include <fstream>
#include <iomanip>

namespace kagu_boot
{

// ============================================================================
// RamAccessViolation
// ============================================================================

RamAccessViolation::RamAccessViolation(const std::string& message, kagu::RamAddress addr)
    : std::runtime_error(message)
    , address_(addr)
{
}

kagu::RamAddress RamAccessViolation::address() const noexcept
{
    return address_;
}

// ============================================================================
// RAM Constructor
// ============================================================================

RAM::RAM(int size)
    : data_(size + 1, "0")
    , size_(size)
{
    if (size < kagu::config::MIN_RAM_SIZE)
    {
        throw std::invalid_argument(
            "RAM size must be at least " + 
            std::to_string(kagu::config::MIN_RAM_SIZE)
        );
    }
}

// ============================================================================
// Register Access (Address enum)
// ============================================================================

const std::string& RAM::readRegister(kagu::Address reg) const
{
    int addr = kagu::toInt(reg);
    
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Read access to invalid register address: " + std::to_string(addr),
            addr
        );
    }
    
    return data_[addr];
}

void RAM::writeRegister(kagu::Address reg, const std::string& value)
{
    int addr = kagu::toInt(reg);
    
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Write access to invalid register address: " + std::to_string(addr),
            addr
        );
    }
    
    data_[addr] = value;
}

void RAM::writeRegister(kagu::Address reg, std::string&& value)
{
    int addr = kagu::toInt(reg);
    
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Write access to invalid register address: " + std::to_string(addr),
            addr
        );
    }
    
    data_[addr] = std::move(value);
}

// ============================================================================
// General Access (integer address) - Flat memory, no translation
// ============================================================================

std::string RAM::read(kagu::RamAddress addr) const
{
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Read access to invalid address: " + std::to_string(addr),
            addr
        );
    }
    return data_[addr];
}

std::string RAM::read(const std::string& addrStr) const
{
    int addr = std::stoi(addrStr);
    return read(addr);
}

void RAM::write(kagu::RamAddress addr, const std::string& value)
{
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Write access to invalid address: " + std::to_string(addr),
            addr
        );
    }
    data_[addr] = value;
}

void RAM::write(kagu::RamAddress addr, std::string&& value)
{
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Write access to invalid address: " + std::to_string(addr),
            addr
        );
    }
    data_[addr] = std::move(value);
}

void RAM::write(const std::string& addrStr, const std::string& value)
{
    int addr = std::stoi(addrStr);
    write(addr, value);
}

// ============================================================================
// Direct Access (same as general access in bare metal mode)
// ============================================================================

std::string& RAM::directAccess(kagu::RamAddress addr)
{
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Direct access to invalid address: " + std::to_string(addr),
            addr
        );
    }
    return data_[addr];
}

const std::string& RAM::directAccess(kagu::RamAddress addr) const
{
    if (addr < 1 || addr > size_)
    {
        throw RamAccessViolation(
            "Direct access to invalid address: " + std::to_string(addr),
            addr
        );
    }
    return data_[addr];
}

// ============================================================================
// Information
// ============================================================================

int RAM::size() const noexcept
{
    return size_;
}

// ============================================================================
// Debug
// ============================================================================

void RAM::dumpToFile(const std::string& filename) const
{
    std::ofstream file(filename);
    if (!file)
    {
        return;
    }
    
    constexpr int NAME_WIDTH = 22;
    
    // Dump registers (1-30) with aligned names
    for (int i = 1; i < kagu::toInt(kagu::Address::KernelStart); ++i)
    {
        const char* name = kagu::getRegisterName(i);
        if (name)
        {
            file << std::left << std::setw(NAME_WIDTH) << name << ": " << data_[i] << '\n';
        }
        else
        {
            file << std::left << std::setw(NAME_WIDTH) << "UNUSED" << ": " << data_[i] << '\n';
        }
    }
    
    // Dump code area (31+) as-is
    for (int i = kagu::toInt(kagu::Address::KernelStart); i <= size_; ++i)
    {
        file << data_[i] << '\n';
    }
}

} // namespace kagu_boot
