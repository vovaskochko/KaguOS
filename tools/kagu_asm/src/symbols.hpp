/**
 * @file symbols.hpp
 * @brief Symbol name parsing and lookup for KaguOS assembler
 */

#pragma once

#include <kagu/kagu.hpp>
#include <optional>
#include <string_view>
#include <string>

namespace kagu_asm::symbols {

// ============================================================================
// Symbol Value
// ============================================================================
struct SymbolValue {
    enum class Type {
        Integer,    ///< Numeric value (address, opcode, etc.)
        String      ///< String value (keyboard mode value)
    };
    
    Type type;
    int intValue = 0;
    std::string_view stringValue;
    
    bool isInteger() const { return type == Type::Integer; }
    bool isString() const { return type == Type::String; }
};

// ============================================================================
// Address Symbol Parsing
// ============================================================================
std::optional<kagu::Address> parseAddress(std::string_view name);
std::string_view addressName(kagu::Address addr);
bool isAddressSymbol(std::string_view name);

// ============================================================================
// Operation Symbol Parsing
// ============================================================================
std::optional<kagu::Operation> parseOperation(std::string_view name);
std::string_view operationName(kagu::Operation op);

inline bool isOperationSymbol(std::string_view name) {
    return name.size() >= 3 && name.substr(0, 3) == "OP_";
}

// ============================================================================
// System Call Symbol Parsing
// ============================================================================
std::optional<kagu::SysCall> parseSysCall(std::string_view name);
std::string_view sysCallName(kagu::SysCall sc);

inline bool isSysCallSymbol(std::string_view name) {
    return name.size() >= 9 && name.substr(0, 9) == "SYS_CALL_";
}

// ============================================================================
// Color Symbol Parsing
// ============================================================================
std::optional<kagu::Color> parseColor(std::string_view name);
std::string_view colorName(kagu::Color c);

inline bool isColorSymbol(std::string_view name) {
    return name.size() >= 6 && name.substr(0, 6) == "COLOR_";
}

// ============================================================================
// Keyboard Mode Symbol Parsing
// ============================================================================
std::optional<kagu::KeyboardMode> parseKeyboardMode(std::string_view name);
std::string_view keyboardModeName(kagu::KeyboardMode mode);
std::string_view keyboardModeValue(kagu::KeyboardMode mode);

inline bool isKeyboardModeSymbol(std::string_view name) {
    return name.size() >= 14 && name.substr(0, 14) == "KEYBOARD_READ_";
}

// ============================================================================
// Generic Symbol Lookup
// ============================================================================
std::optional<SymbolValue> lookupSymbol(std::string_view name);

} // namespace kagu_asm::symbols
