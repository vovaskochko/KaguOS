/**
 * @file types.hpp
 * @brief KaguOS - Basic type definitions
 * 
 * This file provides fundamental type aliases used throughout
 * the KaguOS emulator and assembler.
 * 
 * Architecture Notes:
 * - RAM is an array of text strings (std::string), not bytes
 * - Addressing starts at 1 (not 0)
 * - All data is stored and manipulated as strings
 */

#pragma once

#include <cstdint>
#include <string>
#include <string_view>
#include <type_traits>

namespace kagu
{

// ============================================================================
// Fundamental Type Aliases
// ============================================================================

/**
 * @brief RAM address type
 * 
 * Addresses in KaguOS start at 1.
 * Address 0 is reserved/invalid.
 */
using RamAddress = int;

/**
 * @brief RAM cell content type
 * 
 * Each RAM cell contains a string value.
 * This is the fundamental unit of storage in KaguOS.
 */
using RamCell = std::string;

/**
 * @brief Read-only view of RAM cell
 */
using RamCellView = std::string_view;

/**
 * @brief Program counter type
 */
using ProgramCounter = int;

/**
 * @brief Process ID type
 */
using ProcessId = int;

/**
 * @brief File descriptor type
 */
using FileDescriptor = int;

/**
 * @brief Disk block number type
 */
using BlockNumber = int;

// ============================================================================
// Utility Templates
// ============================================================================

/**
 * @brief Convert enum class to underlying integer value
 * @tparam E Enum class type
 * @param e Enum value to convert
 * @return Underlying integer value
 * 
 * Example:
 * @code
 *   auto val = toInt(Address::Op);  // Returns 2
 * @endcode
 */
template<typename E>
[[nodiscard]] constexpr auto toInt(E e) noexcept
    -> std::enable_if_t<std::is_enum_v<E>, std::underlying_type_t<E>>
{
    return static_cast<std::underlying_type_t<E>>(e);
}

/**
 * @brief Convert integer to enum class value
 * @tparam E Enum class type
 * @param value Integer value to convert
 * @return Enum class value
 * 
 * Example:
 * @code
 *   auto op = fromInt<Operation>(0);  // Returns Operation::Add
 * @endcode
 */
template<typename E>
[[nodiscard]] constexpr E fromInt(std::underlying_type_t<E> value) noexcept
{
    return static_cast<E>(value);
}

// ============================================================================
// Constants
// ============================================================================

/**
 * @brief Invalid/null address constant
 */
constexpr RamAddress INVALID_ADDRESS = 0;

/**
 * @brief First valid RAM address
 */
constexpr RamAddress FIRST_ADDRESS = 1;

/**
 * @brief Invalid process ID
 */
constexpr ProcessId INVALID_PID = -1;

/**
 * @brief Invalid file descriptor
 */
constexpr FileDescriptor INVALID_FD = -1;

} // namespace kagu
