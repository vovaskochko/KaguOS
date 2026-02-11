/**
 * @file lexer.cpp
 * @brief Lexical analyzer implementation
 */

#include "lexer.hpp"
#include "symbols.hpp"
#include <algorithm>
#include <cctype>

namespace kagu_asm {

// ============================================================================
// Lexeme Implementation
// ============================================================================

std::string Lexeme::typeToString() const {
    switch (type) {
        case LexemeType::COMMENT: return "cmt";
        case LexemeType::COMMAND: return "cmd";
        case LexemeType::KEYWORD_TO: return "kto";
        case LexemeType::NUMBER: return "num";
        case LexemeType::STRING: return "str";
        case LexemeType::REGISTER: return "reg";
        case LexemeType::OPERATION: return "opr";
        case LexemeType::SYSCALL: return "sys";
        case LexemeType::COLOR: return "clr";
        case LexemeType::MODE: return "mod";
        case LexemeType::VARIABLE: return "var";
        case LexemeType::LABEL: return "lbl";
        case LexemeType::NAME: return "nam";
        case LexemeType::ERROR: return "err";
    }
    return "unk";
}

std::string Lexeme::toString() const {
    std::string p(1, prefix);
    return p + " " + typeToString() + (value.empty() ? "" : " " + value);
}

std::string Lexeme::toPattern() const {
    std::string p(1, prefix);
    return "(" + p + " " + typeToString() + ")";
}

// ============================================================================
// Lexer Static Members
// ============================================================================

const std::vector<std::string> Lexer::COMMANDS = {
    "write", "copy", "label", "jump", "jump_if", "jump_if_not", 
    "jump_err", "cpu_exec", "var", "DEBUG_ON", "DEBUG_OFF"
};

// ============================================================================
// Lexer Methods
// ============================================================================

bool Lexer::isCommand(const std::string& s) {
    return std::find(COMMANDS.begin(), COMMANDS.end(), s) != COMMANDS.end();
}

bool Lexer::isValidName(const std::string& s) {
    if (s.empty()) return false;
    if (!std::isalpha(static_cast<unsigned char>(s[0]))) return false;
    for (char c : s) {
        if (!std::isalnum(static_cast<unsigned char>(c)) && c != '_') return false;
    }
    return true;
}

bool Lexer::isNumber(const std::string& s) {
    if (s.empty()) return false;
    size_t start = 0;
    if (s[0] == '-') start = 1;
    if (start >= s.length()) return false;
    for (size_t i = start; i < s.length(); i++) {
        if (!std::isdigit(static_cast<unsigned char>(s[i]))) return false;
    }
    return true;
}

Lexeme Lexer::parse(const std::string& token) {
    Lexeme lex;
    lex.prefix = '_';
    
    if (token.empty() || token.substr(0, 2) == "//") {
        lex.type = LexemeType::COMMENT;
        return lex;
    }

    std::string curLexeme = token;

    // Check for prefix
    if (!curLexeme.empty() && (curLexeme[0] == '@' || curLexeme[0] == '*')) {
        lex.prefix = curLexeme[0];
        curLexeme = curLexeme.substr(1);
    }

    // String literal
    if (curLexeme.length() >= 2 && curLexeme.front() == '"' && curLexeme.back() == '"') {
        lex.type = LexemeType::STRING;
        lex.value = curLexeme.substr(1, curLexeme.length() - 2);
        return lex;
    }

    // Number
    if (isNumber(curLexeme)) {
        lex.type = LexemeType::NUMBER;
        lex.value = curLexeme;
        return lex;
    }

    // Variable reference: var:name
    if (curLexeme.length() > 4 && curLexeme.substr(0, 4) == "var:") {
        lex.type = LexemeType::VARIABLE;
        lex.value = curLexeme.substr(4);
        return lex;
    }

    // Label reference: label:name
    if (curLexeme.length() > 6 && curLexeme.substr(0, 6) == "label:") {
        lex.type = LexemeType::LABEL;
        lex.value = curLexeme.substr(6);
        return lex;
    }

    // Keyword "to"
    if (curLexeme == "to") {
        lex.type = LexemeType::KEYWORD_TO;
        lex.value = curLexeme;
        return lex;
    }

    // Command
    if (isCommand(curLexeme)) {
        lex.type = LexemeType::COMMAND;
        lex.value = curLexeme;
        return lex;
    }

    // Use symbols module for built-in symbol detection
    if (symbols::isOperationSymbol(curLexeme)) {
        if (symbols::parseOperation(curLexeme)) {
            lex.type = LexemeType::OPERATION;
            lex.value = curLexeme;
            return lex;
        }
    }

    if (symbols::isSysCallSymbol(curLexeme)) {
        if (symbols::parseSysCall(curLexeme)) {
            lex.type = LexemeType::SYSCALL;
            lex.value = curLexeme;
            return lex;
        }
    }

    if (symbols::isColorSymbol(curLexeme)) {
        if (symbols::parseColor(curLexeme)) {
            lex.type = LexemeType::COLOR;
            lex.value = curLexeme;
            return lex;
        }
    }

    if (symbols::isKeyboardModeSymbol(curLexeme)) {
        if (symbols::parseKeyboardMode(curLexeme)) {
            lex.type = LexemeType::MODE;
            lex.value = curLexeme;
            return lex;
        }
    }

    if (symbols::isAddressSymbol(curLexeme)) {
        if (symbols::parseAddress(curLexeme)) {
            lex.type = LexemeType::REGISTER;
            lex.value = curLexeme;
            return lex;
        }
    }

    // Valid name (for label/var declarations)
    if (isValidName(curLexeme)) {
        lex.type = LexemeType::NAME;
        lex.value = curLexeme;
        return lex;
    }

    // Error
    lex.type = LexemeType::ERROR;
    lex.value = curLexeme;
    return lex;
}

} // namespace kagu_asm
