/**
 * @file interrupt_handler.hpp
 * @brief KaguOS Emulator - Interrupt Handling Module (Header)
 *
 * Manages system call dispatch and interrupt context.
 * Timer-based scheduling (week 10) will extend this module.
 */

#pragma once

#include <kagu/kagu.hpp>
#include "ram.hpp"
#include <optional>
#include <string>

namespace kagu_boot
{

/**
 * @brief Interrupt context saved on OP_SYS_CALL and read on OP_SYS_RETURN.
 *
 * Serialised as three space-separated integers in REG_SYS_INTERRUPT_DATA:
 *   "<type> <pc> <ignoreResult>"
 *
 * - type        : 0 = software (syscall)
 * - pc          : program counter to return to
 * - ignoreResult: 1 = do not restore REG_RES/REG_ERROR on return
 *                 0 = restore them (standard syscall return)
 */
struct InterruptData
{
    int type = 0;
    kagu::ProgramCounter programCounter = 0;
    bool ignoreResult = false;

    static std::optional<InterruptData> parse(const std::string& str);
    [[nodiscard]] std::string toString() const;
};

/**
 * @brief Interrupt handler
 *
 * Week 7 scope: syscall dispatch only.
 * Week 10 will add timer-based preemption.
 */
class InterruptHandler
{
public:
    explicit InterruptHandler(RAM& ram);

    /// Address of the kernel syscall handler routine (reads REG_SYS_CALL_HANDLER).
    [[nodiscard]] kagu::RamAddress getSysCallHandler();

private:
    RAM& ram_;
};

} // namespace kagu_boot
