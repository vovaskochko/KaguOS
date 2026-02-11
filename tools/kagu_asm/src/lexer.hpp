/**
 * @file lexer.hpp
 * @brief Lexical analyzer for KaguASM
 */

#pragma once

#include <string>
#include <vector>

namespace kagu_asm {

// ============================================================================
// Lexeme Types
// ============================================================================
enum class LexemeType {
    COMMENT,    // cmt - comment or empty
    COMMAND,    // cmd - write, copy, jump, etc.
    KEYWORD_TO, // kto - the "to" keyword
    NUMBER,     // num - numeric literal
    STRING,     // str - string literal
    REGISTER,   // reg - REG_*, INFO_*, DISPLAY_*, KEYBOARD_*, PROGRAM_COUNTER, FREE_*
    OPERATION,  // opr - OP_*
    SYSCALL,    // sys - SYS_CALL_*
    COLOR,      // clr - COLOR_*
    MODE,       // mod - KEYBOARD_READ_*
    VARIABLE,   // var - var:name
    LABEL,      // lbl - label:name
    NAME,       // nam - identifier (used for label/var declarations)
    ERROR       // err - parsing error
};

// ============================================================================
// Lexeme
// ============================================================================
struct Lexeme {
    char prefix = '_';       // '_', '@', or '*'
    LexemeType type = LexemeType::ERROR;
    std::string value;       // the actual value or name

    std::string typeToString() const;
    std::string toString() const;
    std::string toPattern() const;
};

// ============================================================================
// Lexer
// ============================================================================
class Lexer {
public:
    static const std::vector<std::string> COMMANDS;

    static bool isCommand(const std::string& s);
    static bool isValidName(const std::string& s);
    static bool isNumber(const std::string& s);
    static Lexeme parse(const std::string& token);
};

} // namespace kagu_asm
