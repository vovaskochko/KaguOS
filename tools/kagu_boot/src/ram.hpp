/**
 * @file ram.hpp
 * @brief KaguOS Emulator - RAM Memory Module
 *
 * Memory access is mode-aware:
 * - Kernel mode  : full direct access to all addresses.
 * - User mode    : registers 1-UserSpaceEnd accessed directly;
 *                  addresses > UserSpaceEnd translated by adding ProcStartAddress,
 *                  so user programs are isolated within their allocated region.
 */

#pragma once

#include <kagu/kagu.hpp>
#include <vector>
#include <string>
#include <stdexcept>

namespace kagu_boot
{

/**
 * @brief RAM access violation exception
 */
class RamAccessViolation : public std::runtime_error
{
public:
    RamAccessViolation(const std::string& message, kagu::RamAddress addr);
    
    [[nodiscard]] kagu::RamAddress address() const noexcept;
    
private:
    kagu::RamAddress address_;
};

/**
 * @brief RAM Memory class
 *
 * Two access modes:
 *   - Kernel mode (default): all addresses directly accessible.
 *   - User mode: registers 1-UserSpaceEnd direct; higher addresses translated
 *     by adding ProcStartAddress so user programs are memory-isolated.
 *
 * directAccess() always bypasses mode checks — for CPU internals only.
 */
class RAM
{
public:
    explicit RAM(int size);

    // Register Access (Address enum) — bounds + privilege checked
    [[nodiscard]] const std::string& readRegister(kagu::Address reg) const;
    void writeRegister(kagu::Address reg, const std::string& value);
    void writeRegister(kagu::Address reg, std::string&& value);

    // General Access (integer address) — translated in user mode
    [[nodiscard]] std::string read(kagu::RamAddress addr) const;
    [[nodiscard]] std::string read(const std::string& addrStr) const;

    void write(kagu::RamAddress addr, const std::string& value);
    void write(kagu::RamAddress addr, std::string&& value);
    void write(const std::string& addrStr, const std::string& value);

    // Direct Access — bypasses all checking and translation (CPU internals only)
    [[nodiscard]] std::string& directAccess(kagu::RamAddress addr);
    [[nodiscard]] const std::string& directAccess(kagu::RamAddress addr) const;

    // Mode Control
    void setKernelMode(bool kernel) noexcept;
    [[nodiscard]] bool isKernelMode() const noexcept;

    // Process Bounds (read from system registers)
    [[nodiscard]] kagu::RamAddress getProcessStart() const;
    [[nodiscard]] kagu::RamAddress getProcessEnd() const;

    // Information
    [[nodiscard]] int size() const noexcept;

    // Debug
    void dumpToFile(const std::string& filename, bool userOnly = false) const;

private:
    std::vector<std::string> data_;
    int size_;
    bool kernelMode_;
};

} // namespace kagu_boot
