/**
 * @file compiler.hpp
 * @brief KaguASM Compiler - two-pass assembler
 */

#pragma once

#include "lexer.hpp"
#include "symbols.hpp"
#include <string>
#include <vector>
#include <unordered_map>

namespace kagu_asm {

// ============================================================================
// Parsed Instruction
// ============================================================================
struct ParsedInstruction {
    std::string sourceFile;
    int lineNumber = 0;
    std::vector<Lexeme> lexemes;
};

// ============================================================================
// Symbol Info Structures
// ============================================================================
struct LabelInfo {
    int address = 0;
    int declarationLine = 0;
    std::string file;
};

struct VariableInfo {
    int address = 0;
    int declarationAddress = 0;
    int declarationLine = 0;
    std::string file;
};

struct ConstantInfo {
    std::string rawValue;
    std::string evaluatedValue;
    int address = 0;
};

// ============================================================================
// Command Pattern
// ============================================================================
struct CommandPattern {
    std::string name;
    int lexemeCount;
    std::string pattern;
    std::string syntax;
};

// ============================================================================
// Symbol Table
// ============================================================================
class SymbolTable {
public:
    bool hasSymbol(const std::string& name) const;
    bool hasNumericSymbol(const std::string& name) const;
    bool hasStringSymbol(const std::string& name) const;
    int getNumericSymbol(const std::string& name) const;
    std::string getStringSymbol(const std::string& name) const;
    void addUserSymbol(const std::string& name, int value);

private:
    std::unordered_map<std::string, int> userSymbols_;
};

// ============================================================================
// Compiler
// ============================================================================
class Compiler {
public:
    Compiler(bool userSpace = false, bool debugInfo = true);
    
    bool compile(const std::vector<std::string>& sourceFiles);
    
    const std::string& outputFile() const { return outputFile_; }
    int errorCount() const { return compilationErrorCount_; }

private:
    // Configuration
    bool userSpace_;
    bool debugInfo_;
    int firstInstructionNo_;
    int nextInstrAddress_;
    std::string outputFile_;
    int compilationErrorCount_;

    // Parsing state
    std::string currentFile_;
    int currentLineNo_;
    std::string currentLine_;

    // Symbol tables
    SymbolTable symbolTable_;
    std::unordered_map<std::string, LabelInfo> labels_;
    std::unordered_map<std::string, VariableInfo> variables_;
    std::vector<std::pair<std::string, VariableInfo>> variablesOrdered_;

    // Constants
    std::vector<ConstantInfo> constants_;
    std::unordered_map<std::string, size_t> constantsIndex_;

    // Parsed instructions
    std::vector<ParsedInstruction> parsedInstructions_;

    // Pass 1: Lexical analysis
    bool pass1(const std::vector<std::string>& sourceFiles);
    std::vector<std::string> tokenizeLine(const std::string& line);
    void processLine(const std::string& line);

    // Address calculation
    void calculateAddresses();

    // Pass 2: Code generation
    bool pass2();
    std::string evalLexeme(const Lexeme& lex, const std::string& position);
    std::string evalDebugInfo(const Lexeme& lex, const std::string& position);

    // Error handling
    void compilationError(const std::string& expectedSyntax, const std::string& errorInfo = "");
};

// Pattern matching
bool matchPattern(const std::string& pattern, const std::string& expectedStr);

// Command patterns
extern const std::vector<CommandPattern> COMMAND_PATTERNS;

} // namespace kagu_asm
