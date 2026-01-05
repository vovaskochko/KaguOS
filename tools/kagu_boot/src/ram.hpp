/**
 * @file ram.hpp
 * @brief KaguOS Emulator - RAM Memory Module (Bare Metal Edition)
 * 
 * Flat memory model - all addresses are physical addresses.
 * No kernel/user mode distinction, no address translation.
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
 * @brief RAM Memory class (Bare Metal Edition)
 * 
 * Flat memory model:
 * - All addresses 1 to size are directly accessible
 * - No kernel/user mode distinction
 * - No address translation
 */
class RAM
{
public:
    explicit RAM(int size);
    
    // Register Access (Address enum)
    [[nodiscard]] const std::string& readRegister(kagu::Address reg) const;
    void writeRegister(kagu::Address reg, const std::string& value);
    void writeRegister(kagu::Address reg, std::string&& value);
    
    // General Access (integer address)
    [[nodiscard]] std::string read(kagu::RamAddress addr) const;
    [[nodiscard]] std::string read(const std::string& addrStr) const;
    
    void write(kagu::RamAddress addr, const std::string& value);
    void write(kagu::RamAddress addr, std::string&& value);
    void write(const std::string& addrStr, const std::string& value);
    
    // Direct Access (same as general access in bare metal mode)
    [[nodiscard]] std::string& directAccess(kagu::RamAddress addr);
    [[nodiscard]] const std::string& directAccess(kagu::RamAddress addr) const;
    
    // Information
    [[nodiscard]] int size() const noexcept;
    
    // Debug
    void dumpToFile(const std::string& filename) const;
    
private:
    std::vector<std::string> data_;
    int size_;
};

} // namespace kagu_boot
