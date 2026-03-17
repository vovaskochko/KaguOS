/**
 * @file interrupt_handler.hpp
 * @brief KaguOS Emulator - Interrupt Handling Module (Header)
 *
 * Manages system call dispatch and hardware timer interrupt context.
 */

#pragma once

#include <kagu/kagu.hpp>
#include "ram.hpp"
#include <functional>
#include <optional>
#include <string>

namespace kagu_boot
{

/**
 * @brief Interrupt types
 */
enum class InterruptType
{
    Software = 0,
    Timer    = 1,
    Keyboard = 2
};

/**
 * @brief Interrupt context saved on OP_SYS_CALL and read on OP_SYS_RETURN.
 *
 * Serialised as three space-separated integers in REG_SYS_INTERRUPT_DATA:
 *   "<type> <pc> <ignoreResult>"
 *
 * - type        : 0 = software (syscall), 1 = timer
 * - pc          : program counter to return to
 * - ignoreResult: 1 = do not restore REG_RES/REG_ERROR on return
 *                 0 = restore them (standard syscall return)
 */
struct InterruptData
{
    InterruptType type          = InterruptType::Software;
    kagu::ProgramCounter programCounter = 0;
    bool ignoreResult           = false;

    static std::optional<InterruptData> parse(const std::string& str);
    [[nodiscard]] std::string toString() const;
};

/**
 * @brief Interrupt handler — syscall dispatch and timer-based preemption.
 */
class InterruptHandler
{
public:
    using InterruptCallback = std::function<void(InterruptType, const InterruptData&)>;

    explicit InterruptHandler(RAM& ram);

    // Timer Management
    [[nodiscard]] bool checkTimer();
    void setTimer(int ticks);
    void enableTimer(bool enabled) noexcept;
    [[nodiscard]] bool isTimerEnabled() const noexcept;

    // Interrupt Data
    [[nodiscard]] std::optional<InterruptData> getInterruptData();
    void setInterruptData(const InterruptData& data);
    void clearInterruptData();

    // Interrupt Triggering
    void triggerTimerInterrupt(kagu::ProgramCounter currentPC);
    void triggerSysCall(kagu::ProgramCounter currentPC);

    // Handler Addresses
    [[nodiscard]] kagu::RamAddress getSysCallHandler();
    [[nodiscard]] kagu::RamAddress getInterruptHandler();

    // Callback
    void setCallback(InterruptCallback callback);
    void notifyCallback(InterruptType type, const InterruptData& data);

private:
    RAM& ram_;
    bool timerEnabled_;
    InterruptCallback callback_;
};

} // namespace kagu_boot
