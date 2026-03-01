/**
 * @file main_boot.cpp
 * @brief KaguOS Emulator entry point
 *
 * Initialises hardware components and starts the CPU.
 * Supports kernel/user mode separation and system calls.
 */

#include "cpu.hpp"
#include "ram.hpp"
#include "disk.hpp"
#include "display.hpp"
#include "input.hpp"
#include "interrupt_handler.hpp"
#include "debug_server.hpp"

#include <kagu/kagu.hpp>

#include <iostream>
#include <fstream>
#include <memory>
#include <string>
#include <filesystem>

namespace fs = std::filesystem;

void printUsage(const char* progName)
{
    std::cerr << "KaguOS Emulator\n";
    std::cerr << "Usage: " << progName << " <cpu_firmware> <ram_size> [options]\n";
    std::cerr << "\n";
    std::cerr << "Arguments:\n";
    std::cerr << "  cpu_firmware    Path to cpu reset vector firmware\n";
    std::cerr << "  ram_size        RAM size in cells (minimum: "
              << kagu::config::MIN_RAM_SIZE << ")\n";
    std::cerr << "\n";
    std::cerr << "Options:\n";
    std::cerr << "  -d               Enable debug mode (dump RAM after each step)\n";
    std::cerr << "  -u               Enable debug only for user space instructions\n";
    std::cerr << "  -j               Print instruction info during execution\n";
    std::cerr << "  -s <ms>          Sleep between steps in debug mode (milliseconds)\n";
    std::cerr << "  --debug-port <p> Start TCP debug server on port p (DAP back-end)\n";
    std::cerr << "\n";
    std::cerr << "Examples:\n";
    std::cerr << "  " << progName << " hw/cpu_firmware.bin 2048\n";
    std::cerr << "  " << progName << " hw/cpu_firmware.bin 2048 -j\n";
    std::cerr << "  " << progName << " hw/cpu_firmware.bin 2048 --debug-port 4711\n";
}


int main(int argc, char* argv[])
{
    if (argc < 3)
    {
        printUsage(argv[0]);
        return 1;
    }
    
    // Parse required arguments
    std::string cpuFirmware = argv[1];
    int ramSize = 0;
    
    try
    {
        ramSize = std::stoi(argv[2]);
    }
    catch (const std::exception&)
    {
        std::cerr << "Error: Invalid RAM size: " << argv[2] << "\n";
        return 1;
    }
    
    if (ramSize < kagu::config::MIN_RAM_SIZE)
    {
        std::cerr << "Error: RAM size must be at least " 
                  << kagu::config::MIN_RAM_SIZE << "\n";
        return 1;
    }
    
    if (!fs::exists(cpuFirmware))
    {
        std::cerr << "Error: File not found: " << cpuFirmware << "\n";
        return 1;
    }
    
    // Parse options (after required arguments)
    bool debugMode     = false;
    bool debugUserOnly = false;
    bool printJumps    = false;
    int  debugSleepMs  = 0;
    int  debugPort     = 0;   // 0 = no debug server

    for (int i = 3; i < argc; i++)
    {
        std::string opt = argv[i];

        if (opt == "-d")
        {
            debugMode = true;
        }
        else if (opt == "-u")
        {
            debugUserOnly = true;
        }
        else if (opt == "-j")
        {
            printJumps = true;
        }
        else if (opt == "-s")
        {
            if (i + 1 >= argc)
            {
                std::cerr << "Error: -s requires an argument\n";
                return 1;
            }
            try
            {
                debugSleepMs = std::stoi(argv[i + 1]);
            }
            catch (const std::exception&)
            {
                std::cerr << "Error: Invalid sleep value: " << argv[i + 1] << "\n";
                return 1;
            }
            i++;
        }
        else if (opt == "--debug-port")
        {
            if (i + 1 >= argc)
            {
                std::cerr << "Error: --debug-port requires an argument\n";
                return 1;
            }
            try
            {
                debugPort = std::stoi(argv[i + 1]);
            }
            catch (const std::exception&)
            {
                std::cerr << "Error: Invalid port value: " << argv[i + 1] << "\n";
                return 1;
            }
            i++;
        }
        else
        {
            std::cerr << "Error: Unknown option: " << opt << "\n";
            printUsage(argv[0]);
            return 1;
        }
    }

    // Initialize hardware components
    kagu_boot::RAM            ram(ramSize);
    kagu_boot::Display        display;
    kagu_boot::Keyboard       keyboard;
    kagu_boot::Disk           disk;
    kagu_boot::InterruptHandler interrupts(ram);

    // Create CPU and configure debug settings
    kagu_boot::CPU cpu(ram, display, keyboard, disk, interrupts);
    cpu.setDebugMode(debugMode);
    cpu.setDebugUserOnly(debugUserOnly);
    cpu.setDebugPrintJumps(printJumps);
    cpu.setDebugSleep(debugSleepMs);

    if (debugPort > 0)
    {
        auto server = std::make_unique<kagu_boot::DebugServer>(debugPort);
        server->listen();
        server->waitForClient();
        cpu.setDebugServer(std::move(server));
    }

    try
    {
        // Now we can use reset vector to initiate execution of the instructions
        cpu.resetVector(cpuFirmware);
    }
    catch (const std::exception& e)
    {
        std::cerr << "\n[FATAL] " << e.what() << "\n";
        return 1;
    }
    
    return 0;
}
