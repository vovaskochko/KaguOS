/**
 * @file interrupt_handler.cpp
 * @brief KaguOS Emulator - Interrupt Handling Module (Implementation)
 */

#include "interrupt_handler.hpp"
#include <sstream>

namespace kagu_boot
{

// ============================================================================
// InterruptData
// ============================================================================

std::optional<InterruptData> InterruptData::parse(const std::string& str)
{
    if (str.empty())
    {
        return std::nullopt;
    }

    InterruptData data;
    int ignore = 0;

    std::istringstream iss(str);
    if (!(iss >> data.type >> data.programCounter >> ignore))
    {
        return std::nullopt;
    }

    data.ignoreResult = (ignore == 1);
    return data;
}

std::string InterruptData::toString() const
{
    return std::to_string(type) + " " +
           std::to_string(programCounter) + " " +
           (ignoreResult ? "1" : "0");
}

// ============================================================================
// InterruptHandler
// ============================================================================

InterruptHandler::InterruptHandler(RAM& ram)
    : ram_(ram)
{
}

kagu::RamAddress InterruptHandler::getSysCallHandler()
{
    // System register — bypass mode checking with directAccess.
    const std::string& addr = ram_.directAccess(kagu::toInt(kagu::Address::SysCallHandler));
    return (addr.empty() || addr == "0") ? 0 : std::stoi(addr);
}

} // namespace kagu_boot
