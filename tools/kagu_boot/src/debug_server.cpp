/**
 * @file debug_server.cpp
 * @brief KaguOS Debugger - TCP debug server implementation
 */

#include "debug_server.hpp"
#include "ram.hpp"

#include <iostream>
#include <sstream>
#include <stdexcept>
#include <cstring>
#include <cerrno>

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

namespace kagu_boot
{

// ============================================================================
// Construction / Destruction
// ============================================================================

DebugServer::DebugServer(int port, int ramSize)
    : port_(port)
    , ramSize_(ramSize)
    , serverFd_(-1)
    , clientFd_(-1)
    , stepMode_(false)
{
}

DebugServer::~DebugServer()
{
    if (clientFd_ >= 0) ::close(clientFd_);
    if (serverFd_ >= 0) ::close(serverFd_);
}

// ============================================================================
// Connection
// ============================================================================

void DebugServer::listen()
{
    serverFd_ = ::socket(AF_INET, SOCK_STREAM, 0);
    if (serverFd_ < 0)
        throw std::runtime_error(
            std::string("[DEBUG SERVER] socket() failed: ") + std::strerror(errno));

    int opt = 1;
    ::setsockopt(serverFd_, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(static_cast<uint16_t>(port_));

    if (::bind(serverFd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0)
        throw std::runtime_error(
            std::string("[DEBUG SERVER] bind() failed: ") + std::strerror(errno));

    if (::listen(serverFd_, 1) < 0)
        throw std::runtime_error(
            std::string("[DEBUG SERVER] listen() failed: ") + std::strerror(errno));
}

void DebugServer::waitForClient()
{
    std::cerr << "[DEBUG SERVER] Listening on port " << port_
              << ", waiting for client...\n";

    clientFd_ = ::accept(serverFd_, nullptr, nullptr);
    if (clientFd_ < 0)
        throw std::runtime_error(
            std::string("[DEBUG SERVER] accept() failed: ") + std::strerror(errno));

    std::cerr << "[DEBUG SERVER] Client connected.\n";

    // Announce RAM size so the adapter doesn't need to know it upfront.
    sendLine("READY " + std::to_string(ramSize_));

    // Start in step-mode so the very first instruction is reported to the adapter.
    stepMode_ = true;
}

// ============================================================================
// Low-level I/O
// ============================================================================

std::string DebugServer::readLine()
{
    std::string line;
    char c;
    while (true)
    {
        ssize_t n = ::recv(clientFd_, &c, 1, 0);
        if (n <= 0) return "";   // disconnected or error
        if (c == '\n') break;
        if (c != '\r') line += c;
    }
    return line;
}

void DebugServer::sendLine(const std::string& line)
{
    std::string msg = line + "\n";
    const char* buf = msg.c_str();
    size_t      rem = msg.size();
    while (rem > 0)
    {
        ssize_t n = ::send(clientFd_, buf, rem, 0);
        if (n <= 0) return;
        buf += n;
        rem -= static_cast<size_t>(n);
    }
}

// ============================================================================
// Command Handling
// ============================================================================

bool DebugServer::handleCommand(const std::string& cmd, RAM& ram, bool& out_quit)
{
    out_quit = false;

    if (cmd == "CONTINUE")
    {
        stepMode_ = false;
        return true;
    }

    if (cmd == "STEP")
    {
        stepMode_ = true;
        return true;   // resume; CPU will pause again after the next instruction
    }

    if (cmd.size() > 6 && cmd.substr(0, 6) == "BREAK ")
    {
        try { breakpoints_.insert(std::stoi(cmd.substr(6))); } catch (...) {}
        return false;
    }

    if (cmd.size() > 6 && cmd.substr(0, 6) == "CLEAR ")
    {
        try { breakpoints_.erase(std::stoi(cmd.substr(6))); } catch (...) {}
        return false;
    }

    if (cmd.size() > 6 && cmd.substr(0, 6) == "STATE ")
    {
        std::istringstream ss(cmd.substr(6));
        int start = 0, end = 0;
        ss >> start >> end;
        for (int a = start; a <= end; a++)
        {
            try
            {
                sendLine("RAM " + std::to_string(a) + " " + ram.directAccess(a));
            }
            catch (...) {}
        }
        sendLine("END");
        return false;
    }

    if (cmd.size() > 4 && cmd.substr(0, 4) == "SET ")
    {
        std::string rest = cmd.substr(4);
        size_t sp = rest.find(' ');
        if (sp != std::string::npos)
        {
            try
            {
                int addr = std::stoi(rest.substr(0, sp));
                ram.directAccess(addr) = rest.substr(sp + 1);
            }
            catch (...) {}
        }
        return false;
    }

    if (cmd == "QUIT")
    {
        out_quit = true;
        return true;
    }

    // Unknown command — stay paused
    return false;
}

// ============================================================================
// CPU Hooks
// ============================================================================

bool DebugServer::checkBreakpoint(int pc, RAM& ram)
{
    if (clientFd_ < 0) return true;

    bool hit = breakpoints_.count(pc) > 0 || stepMode_;
    if (!hit) return true;

    sendLine("PAUSED " + std::to_string(pc));

    while (true)
    {
        std::string cmd = readLine();
        if (cmd.empty()) return false;   // client disconnected → stop CPU

        bool out_quit = false;
        bool resume   = handleCommand(cmd, ram, out_quit);
        if (out_quit) return false;
        if (resume)   return true;
    }
}

void DebugServer::notifyHalted(RAM& ram)
{
    if (clientFd_ < 0) return;

    sendLine("HALTED");

    // Keep accepting STATE / CLEAR / BREAK queries after halt so the adapter
    // can read final RAM state.  Stop on QUIT or client disconnect.
    while (true)
    {
        std::string cmd = readLine();
        if (cmd.empty()) break;

        bool out_quit = false;
        handleCommand(cmd, ram, out_quit);
        if (out_quit) break;
    }
}

} // namespace kagu_boot
