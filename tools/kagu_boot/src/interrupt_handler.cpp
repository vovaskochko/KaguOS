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
    int type = 0;
    int pc   = 0;
    int ignore = 0;

    std::istringstream iss(str);
    if (!(iss >> type >> pc >> ignore))
    {
        return std::nullopt;
    }

    data.type            = static_cast<InterruptType>(type);
    data.programCounter  = pc;
    data.ignoreResult    = (ignore == 1);
    return data;
}

std::string InterruptData::toString() const
{
    return std::to_string(static_cast<int>(type)) + " " +
           std::to_string(programCounter) + " " +
           (ignoreResult ? "1" : "0");
}

// ============================================================================
// InterruptHandler Constructor
// ============================================================================

InterruptHandler::InterruptHandler(RAM& ram)
    : ram_(ram)
    , timerEnabled_(false)
    , callback_(nullptr)
{
}

// ============================================================================
// Timer Management
// ============================================================================

bool InterruptHandler::checkTimer()
{
    if (ram_.isKernelMode())
    {
        return false;
    }

    std::string& timerStr = ram_.directAccess(
        kagu::toInt(kagu::Address::SysHwTimer)
    );

    if (timerStr.empty())
    {
        return false;
    }

    int timer;
    try
    {
        timer = std::stoi(timerStr);
    }
    catch (...)
    {
        return false;
    }

    if (timer < 0)
    {
        return false;  // disabled (TIMER_DISABLED = -1)
    }

    if (timer == 0)
    {
        timerStr = std::to_string(kagu::config::TIMER_DISABLED);
        return true;
    }
    else
    {
        timerStr = std::to_string(timer - 1);
    }

    return false;
}

void InterruptHandler::setTimer(int ticks)
{
    ram_.directAccess(kagu::toInt(kagu::Address::SysHwTimer)) = std::to_string(ticks);
    timerEnabled_ = (ticks >= 0);
}

void InterruptHandler::enableTimer(bool enabled) noexcept
{
    timerEnabled_ = enabled;
}

bool InterruptHandler::isTimerEnabled() const noexcept
{
    return timerEnabled_;
}

// ============================================================================
// Interrupt Data
// ============================================================================

std::optional<InterruptData> InterruptHandler::getInterruptData()
{
    const std::string& dataStr =
        ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptData));
    return InterruptData::parse(dataStr);
}

void InterruptHandler::setInterruptData(const InterruptData& data)
{
    ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptData)) = data.toString();
}

void InterruptHandler::clearInterruptData()
{
    ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptData)) = "";
}

// ============================================================================
// Interrupt Triggering
// ============================================================================

void InterruptHandler::triggerTimerInterrupt(kagu::ProgramCounter currentPC)
{
    InterruptData data{InterruptType::Timer, currentPC, true};
    setInterruptData(data);
    ram_.setKernelMode(true);
}

void InterruptHandler::triggerSysCall(kagu::ProgramCounter currentPC)
{
    InterruptData data{InterruptType::Software, currentPC, false};
    setInterruptData(data);
}

// ============================================================================
// Handler Addresses
// ============================================================================

kagu::RamAddress InterruptHandler::getSysCallHandler()
{
    const std::string& addr =
        ram_.directAccess(kagu::toInt(kagu::Address::SysCallHandler));
    return (addr.empty() || addr == "0") ? 0 : std::stoi(addr);
}

kagu::RamAddress InterruptHandler::getInterruptHandler()
{
    const std::string& addr =
        ram_.directAccess(kagu::toInt(kagu::Address::SysInterruptHandler));
    return (addr.empty() || addr == "0") ? 0 : std::stoi(addr);
}

// ============================================================================
// Callback
// ============================================================================

void InterruptHandler::setCallback(InterruptCallback callback)
{
    callback_ = std::move(callback);
}

void InterruptHandler::notifyCallback(InterruptType type, const InterruptData& data)
{
    if (callback_)
    {
        callback_(type, data);
    }
}

} // namespace kagu_boot
