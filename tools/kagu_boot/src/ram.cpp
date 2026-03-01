/**
 * @file ram.cpp
 * @brief KaguOS Emulator - RAM Memory Module (Implementation)
 */

#include "ram.hpp"
#include <fstream>
#include <iomanip>
#include <filesystem>

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
    , kernelMode_(true)
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
// Privileged registers (> UserSpaceEnd) are blocked in user mode.
// ============================================================================

const std::string& RAM::readRegister(kagu::Address reg) const
{
    int addr = kagu::toInt(reg);

    if (!kernelMode_ && addr > kagu::toInt(kagu::Address::UserSpaceEnd))
    {
        throw RamAccessViolation(
            "User mode read access to privileged register: " + std::to_string(addr),
            addr
        );
    }

    return data_[addr];
}

void RAM::writeRegister(kagu::Address reg, const std::string& value)
{
    int addr = kagu::toInt(reg);

    if (!kernelMode_ && addr > kagu::toInt(kagu::Address::UserSpaceEnd))
    {
        throw RamAccessViolation(
            "User mode write access to privileged register: " + std::to_string(addr),
            addr
        );
    }

    data_[addr] = value;
}

void RAM::writeRegister(kagu::Address reg, std::string&& value)
{
    int addr = kagu::toInt(reg);

    if (!kernelMode_ && addr > kagu::toInt(kagu::Address::UserSpaceEnd))
    {
        throw RamAccessViolation(
            "User mode write access to privileged register: " + std::to_string(addr),
            addr
        );
    }

    data_[addr] = std::move(value);
}

// ============================================================================
// General Access (integer address)
// Kernel mode: direct.
// User mode  : registers 1-UserSpaceEnd direct;
//              addresses > UserSpaceEnd translated by adding ProcStartAddress.
// ============================================================================

std::string RAM::read(kagu::RamAddress addr) const
{
    if (kernelMode_)
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

    // User mode: registers — direct
    if (addr >= 1 && addr <= kagu::toInt(kagu::Address::UserSpaceEnd))
    {
        return data_[addr];
    }

    // User mode: code/data — translated
    int procStart = getProcessStart();
    int procEnd   = getProcessEnd();
    int translated = addr + procStart;

    if (translated > procEnd)
    {
        throw RamAccessViolation(
            "User mode read access violation at address: " + std::to_string(addr) +
            " (translated: " + std::to_string(translated) + ")",
            addr
        );
    }

    return data_[translated];
}

std::string RAM::read(const std::string& addrStr) const
{
    return read(std::stoi(addrStr));
}

void RAM::write(kagu::RamAddress addr, const std::string& value)
{
    if (kernelMode_)
    {
        if (addr < 1 || addr > size_)
        {
            throw RamAccessViolation(
                "Write access to invalid address: " + std::to_string(addr),
                addr
            );
        }
        data_[addr] = value;
        return;
    }

    // User mode: registers — direct
    if (addr >= 1 && addr <= kagu::toInt(kagu::Address::UserSpaceEnd))
    {
        data_[addr] = value;
        return;
    }

    // User mode: code/data — translated
    int procStart = getProcessStart();
    int procEnd   = getProcessEnd();
    int translated = addr + procStart;

    if (translated > procEnd)
    {
        throw RamAccessViolation(
            "User mode write access violation at address: " + std::to_string(addr) +
            " (translated: " + std::to_string(translated) + ")",
            addr
        );
    }

    data_[translated] = value;
}

void RAM::write(kagu::RamAddress addr, std::string&& value)
{
    if (kernelMode_)
    {
        if (addr < 1 || addr > size_)
        {
            throw RamAccessViolation(
                "Write access to invalid address: " + std::to_string(addr),
                addr
            );
        }
        data_[addr] = std::move(value);
        return;
    }

    // User mode: registers — direct
    if (addr >= 1 && addr <= kagu::toInt(kagu::Address::UserSpaceEnd))
    {
        data_[addr] = std::move(value);
        return;
    }

    // User mode: code/data — translated
    int procStart = getProcessStart();
    int procEnd   = getProcessEnd();
    int translated = addr + procStart;

    if (translated > procEnd)
    {
        throw RamAccessViolation(
            "User mode write access violation at address: " + std::to_string(addr) +
            " (translated: " + std::to_string(translated) + ")",
            addr
        );
    }

    data_[translated] = std::move(value);
}

void RAM::write(const std::string& addrStr, const std::string& value)
{
    write(std::stoi(addrStr), value);
}

// ============================================================================
// Direct Access — bypasses all mode checks and translation (CPU internals only)
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
// Mode Control
// ============================================================================

void RAM::setKernelMode(bool kernel) noexcept
{
    kernelMode_ = kernel;
}

bool RAM::isKernelMode() const noexcept
{
    return kernelMode_;
}

// ============================================================================
// Process Bounds
// ============================================================================

kagu::RamAddress RAM::getProcessStart() const
{
    const std::string& val = data_[kagu::toInt(kagu::Address::ProcStartAddress)];
    if (val.empty() || val == "0") return 0;
    try { return std::stoi(val); } catch (...) { return 0; }
}

kagu::RamAddress RAM::getProcessEnd() const
{
    const std::string& val = data_[kagu::toInt(kagu::Address::ProcEndAddress)];
    if (val.empty() || val == "0") return 0;
    try { return std::stoi(val); } catch (...) { return 0; }
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

void RAM::dumpToFile(const std::string& filename, bool userOnly) const
{
    std::filesystem::path filepath(filename);
    if (filepath.has_parent_path())
    {
        try { std::filesystem::create_directories(filepath.parent_path()); }
        catch (...) {}
    }

    std::ofstream file(filename);
    if (!file) return;

    constexpr int NAME_WIDTH = 22;

    if (userOnly)
    {
        // Dump only user-space registers (1-UserSpaceEnd) with names
        for (int i = 1; i <= kagu::toInt(kagu::Address::UserSpaceEnd); ++i)
        {
            const char* name = kagu::getRegisterName(i);
            file << std::left << std::setw(NAME_WIDTH)
                 << (name ? name : "REG") << ": " << data_[i] << '\n';
        }
        return;
    }

    // Full dump: registers + firmware zone + code area
    for (int i = 1; i < kagu::toInt(kagu::Address::KernelStart); ++i)
    {
        const char* name = kagu::getRegisterName(i);
        file << std::left << std::setw(NAME_WIDTH)
             << (name ? name : "FIRMWARE") << ": " << data_[i] << '\n';
    }

    for (int i = kagu::toInt(kagu::Address::KernelStart); i <= size_; ++i)
    {
        file << data_[i] << '\n';
    }
}

} // namespace kagu_boot
