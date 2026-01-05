/**
 * @file disk.cpp
 * @brief KaguOS Emulator - Disk I/O Module (Implementation)
 */

#include "disk.hpp"
#include <fstream>
#include <vector>

namespace kagu_boot
{

Disk::Disk(const std::string& hwDir)
    : hwDir_(hwDir)
{
}

// ============================================================================
// Block Operations
// ============================================================================

std::optional<std::string> Disk::readBlock(
    const std::string& diskName, 
    kagu::BlockNumber blockNumber
)
{
    std::ifstream file(hwDir_ + "/" + diskName);
    if (!file)
    {
        return std::nullopt;
    }
    
    std::string line;
    
    // First line contains block count
    if (blockNumber < 1 || !std::getline(file, line))
    {
        return std::nullopt;
    }
    
    int blockCount = std::stoi(line);
    if (blockNumber > blockCount)
    {
        return std::nullopt;
    }
    
    // Skip to requested block
    for (int i = 2; i <= blockNumber; ++i)
    {
        if (!std::getline(file, line))
        {
            return std::nullopt;
        }
    }
    
    return line;
}

bool Disk::writeBlock(
    const std::string& diskName, 
    kagu::BlockNumber blockNumber,
    const std::string& data
)
{
    std::vector<std::string> lines;
    std::string filePath = hwDir_ + "/" + diskName;
    
    // Read all existing lines
    {
        std::ifstream fileIn(filePath);
        if (!fileIn)
        {
            return false;
        }
        
        std::string line;
        while (std::getline(fileIn, line))
        {
            lines.push_back(line);
        }
    }
    
    if (lines.empty())
    {
        return false;
    }
    
    int blockCount = std::stoi(lines[0]);
    
    // Cannot overwrite block 1 (size header) and must be within bounds
    if (blockNumber < 2 || blockNumber >= blockCount)
    {
        return false;
    }
    
    // Update the block (blockNumber is 1-based, vector is 0-based)
    if (static_cast<size_t>(blockNumber - 1) >= lines.size())
    {
        lines.resize(blockNumber, "");
    }
    lines[blockNumber - 1] = data;
    
    // Write back
    std::ofstream fileOut(filePath);
    if (!fileOut)
    {
        return false;
    }
    
    for (const auto& line : lines)
    {
        fileOut << line << "\n";
    }
    
    return true;
}

// ============================================================================
// Disk Information
// ============================================================================

int Disk::getBlockCount(const std::string& diskName)
{
    auto result = readBlock(diskName, 1);
    if (!result)
    {
        return 0;
    }
    
    try
    {
        return std::stoi(*result);
    }
    catch (...)
    {
        return 0;
    }
}

bool Disk::exists(const std::string& diskName) const
{
    std::ifstream file(hwDir_ + "/" + diskName);
    return file.good();
}

// ============================================================================
// Configuration
// ============================================================================

void Disk::setHardwareDir(const std::string& path)
{
    hwDir_ = path;
}

const std::string& Disk::getHardwareDir() const noexcept
{
    return hwDir_;
}

} // namespace kagu_boot
