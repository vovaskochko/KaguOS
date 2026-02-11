/**
 * @file config.hpp
 * @brief KaguOS - System configuration constants
 * 
 * Contains default values for system configuration.
 * Some values can be overridden via /config.txt at boot time.
 */

#pragma once

#include "types.hpp"
#include <string_view>

namespace kagu
{

/**
 * @brief System configuration constants
 */
namespace config
{
    // ========================================================================
    // Memory Configuration
    // ========================================================================
    
    /// Minimum RAM size for kernel operation
    constexpr int MIN_RAM_SIZE = 100;
    
    /// Default memory size per process
    constexpr int DEFAULT_PROC_MEMORY_SIZE = 250;
    
    /// Default maximum number of concurrent processes
    constexpr int DEFAULT_MAX_PROC_COUNT = 10;
    
    /// Default maximum number of open file descriptors
    constexpr int DEFAULT_MAX_FD_COUNT = 50;
    
    // ========================================================================
    // Scheduler Configuration
    // ========================================================================
    
    /// Default scheduler time quantum (ticks)
    constexpr int DEFAULT_TIME_QUANTUM = 50;
    
    /// Hardware timer disabled value
    constexpr int TIMER_DISABLED = -1;
    
    // ========================================================================
    // Directory Paths
    // ========================================================================
    
    /// Hardware devices directory
    constexpr std::string_view HW_DIR = "hw";
    
    /// Temporary files directory
    constexpr std::string_view TMP_DIR = "tmp";
    
    /// Build output directory
    constexpr std::string_view BUILD_DIR = "build";
    
    // ========================================================================
    // File Paths
    // ========================================================================
    
    /// Default kernel disk path
    constexpr std::string_view KERNEL_DATA = "build/kernel.data";
    
    /// Default user program disk path
    constexpr std::string_view USER_DISK = "build/user.disk";
    
    /// RAM dump file for debugging (kernel mode)
    constexpr std::string_view RAM_DUMP_FILE = "tmp/RAM.txt";
    
    /// User RAM dump file (user mode)
    constexpr std::string_view USER_RAM_DUMP_FILE = "tmp/RAM_user.txt";
    
    /// Mount point information file
    constexpr std::string_view MOUNT_INFO_FILE = "mount.info";
    
    /// System configuration file
    constexpr std::string_view CONFIG_FILE = "/config.txt";
    
    // ========================================================================
    // Address Space Configuration (New Layout)
    // ========================================================================
    
    /// User space starting address (first kernel register = end of user space + 1)
    /// With new layout: User space is 1-10, kernel starts at 11
    constexpr int USER_SPACE_START = 11;
    
    /// Number of user-accessible registers (1-10)
    constexpr int USER_REGISTER_COUNT = 10;
    
    // ========================================================================
    // Debug Configuration
    // ========================================================================
    
    /// Default debug mode state
    constexpr bool DEFAULT_DEBUG_MODE = false;
    
    /// Default debug sleep interval (none)
    constexpr int DEFAULT_DEBUG_SLEEP_MS = 0;
    
} // namespace config

} // namespace kagu
