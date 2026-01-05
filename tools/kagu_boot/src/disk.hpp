/**
 * @file disk.hpp
 * @brief KaguOS Emulator - Disk I/O Module (Header)
 */

#pragma once

#include <kagu/kagu.hpp>
#include <string>
#include <optional>

namespace kagu_boot
{

/**
 * @brief Disk I/O handler
 */
class Disk
{
public:
    explicit Disk(const std::string& hwDir = std::string(kagu::config::HW_DIR));
    
    // Block Operations
    [[nodiscard]] std::optional<std::string> readBlock(
        const std::string& diskName, 
        kagu::BlockNumber blockNumber
    );
    
    bool writeBlock(
        const std::string& diskName, 
        kagu::BlockNumber blockNumber,
        const std::string& data
    );
    
    // Disk Information
    [[nodiscard]] int getBlockCount(const std::string& diskName);
    [[nodiscard]] bool exists(const std::string& diskName) const;
    
    // Configuration
    void setHardwareDir(const std::string& path);
    [[nodiscard]] const std::string& getHardwareDir() const noexcept;
    
private:
    std::string hwDir_;
};

} // namespace kagu_boot
