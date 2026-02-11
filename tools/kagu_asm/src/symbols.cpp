/**
 * @file symbols.cpp
 * @brief Implementation of symbol name parsing and lookup
 */

#include "symbols.hpp"
#include <unordered_map>
#include <array>

namespace kagu_asm::symbols {

namespace {

// ============================================================================
// Address Mappings (NEW LAYOUT - no INFO_ registers)
// ============================================================================

struct AddressEntry {
    std::string_view name;
    kagu::Address address;
};

constexpr std::array ADDRESS_TABLE = {
    // Operation register
    AddressEntry{"REG_OP", kagu::Address::Op},
    
    // General purpose registers
    AddressEntry{"REG_A", kagu::Address::A},
    AddressEntry{"REG_B", kagu::Address::B},
    AddressEntry{"REG_C", kagu::Address::C},
    AddressEntry{"REG_D", kagu::Address::D},
    AddressEntry{"REG_E", kagu::Address::E},
    AddressEntry{"REG_F", kagu::Address::F},

    // Result registers
    AddressEntry{"REG_RES", kagu::Address::Res},
    AddressEntry{"REG_BOOL_RES", kagu::Address::BoolRes},
    
    // Error register
    AddressEntry{"REG_ERROR", kagu::Address::Error},
    
    // Last key (non-blocking input)
    AddressEntry{"REG_LAST_KEY", kagu::Address::LastKey},
    
    // User space end marker
    AddressEntry{"REG_USER_SPACE_REGS_END", kagu::Address::UserSpaceEnd},
    
    // System energy counter
    AddressEntry{"SYS_ENERGY", kagu::Address::SysEnergy},
    
    // Display
    AddressEntry{"DISPLAY_BUFFER", kagu::Address::DisplayBuffer},
    AddressEntry{"DISPLAY_COLOR", kagu::Address::DisplayColor},
    AddressEntry{"DISPLAY_BACKGROUND", kagu::Address::DisplayBackground},
    
    // Keyboard
    AddressEntry{"KEYBOARD_BUFFER", kagu::Address::KeyboardBuffer},
    
    // Program counter
    AddressEntry{"PROGRAM_COUNTER", kagu::Address::ProgramCounter},
    
    // Memory management
    AddressEntry{"FREE_MEMORY_START", kagu::Address::FreeMemoryStart},
    AddressEntry{"FREE_MEMORY_END", kagu::Address::FreeMemoryEnd},
    AddressEntry{"FREE_CHUNKS", kagu::Address::FreeChunks},
    
    // Process info
    AddressEntry{"REG_PROC_START_ADDRESS", kagu::Address::ProcStartAddress},
    AddressEntry{"REG_PROC_END_ADDRESS", kagu::Address::ProcEndAddress},
    
    // System call handling
    AddressEntry{"REG_SYS_CALL_HANDLER", kagu::Address::SysCallHandler},
    AddressEntry{"REG_SYS_RET_ADDRESS", kagu::Address::SysRetAddress},
    AddressEntry{"REG_SYS_INTERRUPT_HANDLER", kagu::Address::SysInterruptHandler},
    AddressEntry{"REG_SYS_INTERRUPT_DATA", kagu::Address::SysInterruptData},
    AddressEntry{"REG_SYS_HW_TIMER", kagu::Address::SysHwTimer},
    
    // Kernel
    AddressEntry{"KERNEL_START", kagu::Address::KernelStart},
};

const std::unordered_map<std::string_view, kagu::Address>& getAddressMap() {
    static const auto map = []() {
        std::unordered_map<std::string_view, kagu::Address> m;
        m.reserve(ADDRESS_TABLE.size());
        for (const auto& entry : ADDRESS_TABLE) {
            m.emplace(entry.name, entry.address);
        }
        return m;
    }();
    return map;
}

// ============================================================================
// Operation Mappings
// ============================================================================

struct OperationEntry {
    std::string_view name;
    kagu::Operation operation;
};

constexpr std::array OPERATION_TABLE = {
    OperationEntry{"OP_ADD", kagu::Operation::Add},
    OperationEntry{"OP_SUB", kagu::Operation::Sub},
    OperationEntry{"OP_INCR", kagu::Operation::Incr},
    OperationEntry{"OP_DECR", kagu::Operation::Decr},
    OperationEntry{"OP_DIV", kagu::Operation::Div},
    OperationEntry{"OP_MOD", kagu::Operation::Mod},
    OperationEntry{"OP_MUL", kagu::Operation::Mul},
    OperationEntry{"OP_IS_NUM", kagu::Operation::IsNum},
    OperationEntry{"OP_CMP_EQ", kagu::Operation::CmpEq},
    OperationEntry{"OP_CMP_NEQ", kagu::Operation::CmpNeq},
    OperationEntry{"OP_CMP_LT", kagu::Operation::CmpLt},
    OperationEntry{"OP_CMP_LE", kagu::Operation::CmpLe},
    OperationEntry{"OP_CONTAINS", kagu::Operation::Contains},
    OperationEntry{"OP_GET_LENGTH", kagu::Operation::GetLength},
    OperationEntry{"OP_STARTS_WITH", kagu::Operation::StartsWith},
    OperationEntry{"OP_GET_COLUMN", kagu::Operation::GetColumn},
    OperationEntry{"OP_REPLACE_COLUMN", kagu::Operation::ReplaceColumn},
    OperationEntry{"OP_CONCAT_WITH", kagu::Operation::ConcatWith},
    OperationEntry{"OP_READ_INPUT", kagu::Operation::ReadInput},
    OperationEntry{"OP_DISPLAY", kagu::Operation::Display},
    OperationEntry{"OP_DISPLAY_LN", kagu::Operation::DisplayLn},
    OperationEntry{"OP_READ_BLOCK", kagu::Operation::ReadBlock},
    OperationEntry{"OP_WRITE_BLOCK", kagu::Operation::WriteBlock},
    OperationEntry{"OP_SET_BACKGROUND_COLOR", kagu::Operation::SetBackgroundColor},
    OperationEntry{"OP_RENDER_BITMAP", kagu::Operation::RenderBitmap},
    OperationEntry{"OP_SYS_CALL", kagu::Operation::SysCall},
    OperationEntry{"OP_SYS_RETURN", kagu::Operation::SysReturn},
    OperationEntry{"OP_ENCRYPT_DATA", kagu::Operation::EncryptData},
    OperationEntry{"OP_DECRYPT_DATA", kagu::Operation::DecryptData},
    OperationEntry{"OP_NOP", kagu::Operation::Nop},
    OperationEntry{"OP_HALT", kagu::Operation::Halt},
    OperationEntry{"OP_UNKNOWN", kagu::Operation::Unknown},
};

const std::unordered_map<std::string_view, kagu::Operation>& getOperationMap() {
    static const auto map = []() {
        std::unordered_map<std::string_view, kagu::Operation> m;
        m.reserve(OPERATION_TABLE.size());
        for (const auto& entry : OPERATION_TABLE) {
            m.emplace(entry.name, entry.operation);
        }
        return m;
    }();
    return map;
}

// ============================================================================
// System Call Mappings
// ============================================================================

struct SysCallEntry {
    std::string_view name;
    kagu::SysCall syscall;
};

constexpr std::array SYSCALL_TABLE = {
    SysCallEntry{"SYS_CALL_EXIT", kagu::SysCall::Exit},
    SysCallEntry{"SYS_CALL_PRINTLN", kagu::SysCall::PrintLn},
    SysCallEntry{"SYS_CALL_PRINT", kagu::SysCall::Print},
    SysCallEntry{"SYS_CALL_READ_INPUT", kagu::SysCall::ReadInput},
    SysCallEntry{"SYS_CALL_OPEN", kagu::SysCall::Open},
    SysCallEntry{"SYS_CALL_DESCRIPTOR_INFO", kagu::SysCall::DescriptorInfo},
    SysCallEntry{"SYS_CALL_CLOSE", kagu::SysCall::Close},
    SysCallEntry{"SYS_CALL_READ", kagu::SysCall::Read},
    SysCallEntry{"SYS_CALL_WRITE", kagu::SysCall::Write},
    SysCallEntry{"SYS_CALL_SET_BACKGROUND", kagu::SysCall::SetBackground},
    SysCallEntry{"SYS_CALL_RENDER_BITMAP", kagu::SysCall::RenderBitmap},
    SysCallEntry{"SYS_CALL_SLEEP", kagu::SysCall::Sleep},
    SysCallEntry{"SYS_CALL_GET_FILE_ATTR", kagu::SysCall::GetFileAttr},
    SysCallEntry{"SYS_CALL_SET_FILE_ATTR", kagu::SysCall::SetFileAttr},
    SysCallEntry{"SYS_CALL_SCHED_PROGRAM", kagu::SysCall::SchedProgram},
    SysCallEntry{"SYS_CALL_IS_PROCESS_ACTIVE", kagu::SysCall::IsProcessActive},
    SysCallEntry{"SYS_CALL_KILL_PROCESS", kagu::SysCall::KillProcess},
    SysCallEntry{"SYS_CALL_SKIP_SCHED", kagu::SysCall::SkipSched},
    SysCallEntry{"SYS_CALL_WAIT_SCHED", kagu::SysCall::WaitSched},
};

const std::unordered_map<std::string_view, kagu::SysCall>& getSysCallMap() {
    static const auto map = []() {
        std::unordered_map<std::string_view, kagu::SysCall> m;
        m.reserve(SYSCALL_TABLE.size());
        for (const auto& entry : SYSCALL_TABLE) {
            m.emplace(entry.name, entry.syscall);
        }
        return m;
    }();
    return map;
}

// ============================================================================
// Color Mappings
// ============================================================================

struct ColorEntry {
    std::string_view name;
    kagu::Color color;
};

constexpr std::array COLOR_TABLE = {
    ColorEntry{"COLOR_NO", kagu::Color::No},
    ColorEntry{"COLOR_GREEN", kagu::Color::Green},
    ColorEntry{"COLOR_YELLOW", kagu::Color::Yellow},
    ColorEntry{"COLOR_RED", kagu::Color::Red},
    ColorEntry{"COLOR_BLACK", kagu::Color::Black},
    ColorEntry{"COLOR_BLUE", kagu::Color::Blue},
    ColorEntry{"COLOR_MAGENTA", kagu::Color::Magenta},
    ColorEntry{"COLOR_CYAN", kagu::Color::Cyan},
    ColorEntry{"COLOR_WHITE", kagu::Color::White},
    ColorEntry{"COLOR_PINK", kagu::Color::Pink}
};

const std::unordered_map<std::string_view, kagu::Color>& getColorMap() {
    static const auto map = []() {
        std::unordered_map<std::string_view, kagu::Color> m;
        m.reserve(COLOR_TABLE.size());
        for (const auto& entry : COLOR_TABLE) {
            m.emplace(entry.name, entry.color);
        }
        return m;
    }();
    return map;
}

// ============================================================================
// Keyboard Mode Mappings
// ============================================================================

struct KeyboardModeEntry {
    std::string_view name;
    std::string_view value;
    kagu::KeyboardMode mode;
};

constexpr std::array KEYBOARD_MODE_TABLE = {
    KeyboardModeEntry{"KEYBOARD_READ_LINE", "KeyboardReadLine", kagu::KeyboardMode::ReadLine},
    KeyboardModeEntry{"KEYBOARD_READ_LINE_SILENTLY", "KeyboardReadLineSilently", kagu::KeyboardMode::ReadLineSilently},
    KeyboardModeEntry{"KEYBOARD_READ_CHAR", "KeyboardReadChar", kagu::KeyboardMode::ReadChar},
    KeyboardModeEntry{"KEYBOARD_READ_CHAR_SILENTLY", "KeyboardReadCharSilently", kagu::KeyboardMode::ReadCharSilently},
};

const std::unordered_map<std::string_view, kagu::KeyboardMode>& getKeyboardModeMap() {
    static const auto map = []() {
        std::unordered_map<std::string_view, kagu::KeyboardMode> m;
        m.reserve(KEYBOARD_MODE_TABLE.size());
        for (const auto& entry : KEYBOARD_MODE_TABLE) {
            m.emplace(entry.name, entry.mode);
        }
        return m;
    }();
    return map;
}

} // anonymous namespace

// ============================================================================
// Address Functions Implementation
// ============================================================================

std::optional<kagu::Address> parseAddress(std::string_view name) {
    const auto& map = getAddressMap();
    auto it = map.find(name);
    return it != map.end() ? std::optional{it->second} : std::nullopt;
}

std::string_view addressName(kagu::Address addr) {
    for (const auto& entry : ADDRESS_TABLE) {
        if (entry.address == addr) {
            return entry.name;
        }
    }
    return "UNKNOWN_ADDRESS";
}

bool isAddressSymbol(std::string_view name) {
    if (name.size() < 4) return false;
    
    return name.substr(0, 4) == "REG_" ||
           name.substr(0, 4) == "SYS_" ||
           name.substr(0, 5) == "FREE_" ||
           name == "DISPLAY_BUFFER" ||
           name == "DISPLAY_COLOR" ||
           name == "DISPLAY_BACKGROUND" ||
           name == "KEYBOARD_BUFFER" ||
           name == "PROGRAM_COUNTER" ||
           name == "KERNEL_START";
}

// ============================================================================
// Operation Functions Implementation
// ============================================================================

std::optional<kagu::Operation> parseOperation(std::string_view name) {
    const auto& map = getOperationMap();
    auto it = map.find(name);
    return it != map.end() ? std::optional{it->second} : std::nullopt;
}

std::string_view operationName(kagu::Operation op) {
    for (const auto& entry : OPERATION_TABLE) {
        if (entry.operation == op) {
            return entry.name;
        }
    }
    return "OP_UNKNOWN";
}

// ============================================================================
// System Call Functions Implementation
// ============================================================================

std::optional<kagu::SysCall> parseSysCall(std::string_view name) {
    const auto& map = getSysCallMap();
    auto it = map.find(name);
    return it != map.end() ? std::optional{it->second} : std::nullopt;
}

std::string_view sysCallName(kagu::SysCall sc) {
    for (const auto& entry : SYSCALL_TABLE) {
        if (entry.syscall == sc) {
            return entry.name;
        }
    }
    return "SYS_CALL_UNKNOWN";
}

// ============================================================================
// Color Functions Implementation
// ============================================================================

std::optional<kagu::Color> parseColor(std::string_view name) {
    const auto& map = getColorMap();
    auto it = map.find(name);
    return it != map.end() ? std::optional{it->second} : std::nullopt;
}

std::string_view colorName(kagu::Color c) {
    for (const auto& entry : COLOR_TABLE) {
        if (entry.color == c) {
            return entry.name;
        }
    }
    return "COLOR_UNKNOWN";
}

// ============================================================================
// Keyboard Mode Functions Implementation
// ============================================================================

std::optional<kagu::KeyboardMode> parseKeyboardMode(std::string_view name) {
    const auto& map = getKeyboardModeMap();
    auto it = map.find(name);
    return it != map.end() ? std::optional{it->second} : std::nullopt;
}

std::string_view keyboardModeName(kagu::KeyboardMode mode) {
    for (const auto& entry : KEYBOARD_MODE_TABLE) {
        if (entry.mode == mode) {
            return entry.name;
        }
    }
    return "KEYBOARD_READ_UNKNOWN";
}

std::string_view keyboardModeValue(kagu::KeyboardMode mode) {
    for (const auto& entry : KEYBOARD_MODE_TABLE) {
        if (entry.mode == mode) {
            return entry.value;
        }
    }
    return "";
}

// ============================================================================
// Generic Symbol Lookup Implementation
// ============================================================================

std::optional<SymbolValue> lookupSymbol(std::string_view name) {
    // Try address
    if (auto addr = parseAddress(name)) {
        return SymbolValue{SymbolValue::Type::Integer, kagu::toInt(*addr), {}};
    }
    
    // Try operation
    if (auto op = parseOperation(name)) {
        return SymbolValue{SymbolValue::Type::Integer, kagu::toInt(*op), {}};
    }
    
    // Try syscall
    if (auto sc = parseSysCall(name)) {
        return SymbolValue{SymbolValue::Type::Integer, kagu::toInt(*sc), {}};
    }
    
    // Try color
    if (auto c = parseColor(name)) {
        return SymbolValue{SymbolValue::Type::Integer, kagu::toInt(*c), {}};
    }
    
    // Try keyboard mode (returns string value)
    if (auto km = parseKeyboardMode(name)) {
        return SymbolValue{SymbolValue::Type::String, 0, kagu_asm::symbols::keyboardModeValue(*km)};
    }
    
    return std::nullopt;
}

} // namespace kagu_asm::symbols
