/**
 * @file debug_server.hpp
 * @brief KaguOS Debugger - TCP debug server
 *
 * Implements a simple line-based TCP protocol so a DAP adapter (e.g. Python)
 * can control kagu_boot as a debugger back-end.
 *
 * Protocol (UTF-8 text, newline-delimited):
 *
 *   Server → Client:
 *     PAUSED <pc>          stopped at a breakpoint or after STEP
 *     HALTED               CPU executed HALT
 *     RAM <addr> <value>   one line per address in response to STATE
 *     END                  end of a RAM dump
 *
 *   Client → Server:
 *     CONTINUE             resume execution
 *     STEP                 execute one instruction then pause again
 *     BREAK <addr>         add a breakpoint at address
 *     CLEAR <addr>         remove a breakpoint
 *     STATE <start> <end>  dump RAM[start..end] (inclusive)
 *     SET <addr> <value>   write value into RAM[addr] (live edit)
 *     QUIT                 terminate the emulator
 */

#pragma once

#include <string>
#include <unordered_set>

namespace kagu_boot
{

// Forward declaration — full definition in ram.hpp
class RAM;

class DebugServer
{
public:
    DebugServer(int port, int ramSize);
    ~DebugServer();

    // Non-copyable — owns OS file descriptors
    DebugServer(const DebugServer&)            = delete;
    DebugServer& operator=(const DebugServer&) = delete;

    /// Bind and listen on the configured port. Must be called before waitForClient().
    void listen();

    /// Block until exactly one client connects.
    void waitForClient();

    /// Called from CPU::step() after the PC is resolved.
    /// If pc is in the breakpoints set, or step-mode is active, sends "PAUSED <pc>"
    /// and processes commands until CONTINUE or STEP arrives.
    /// Returns false if QUIT was received (caller should stop the CPU).
    bool checkBreakpoint(int pc, RAM& ram);

    /// Called from CPU::halt() — sends "HALTED" and keeps accepting queries.
    void notifyHalted(RAM& ram);

private:
    int port_;
    int ramSize_;
    int serverFd_;
    int clientFd_;

    std::unordered_set<int> breakpoints_;
    bool stepMode_;   ///< true → pause after every instruction

    std::string readLine();
    void sendLine(const std::string& line);

    /// Handle one client command.
    /// Returns true when execution should resume (CONTINUE / STEP / QUIT).
    /// out_quit is set to true only on QUIT.
    bool handleCommand(const std::string& cmd, RAM& ram, bool& out_quit);
};

} // namespace kagu_boot
