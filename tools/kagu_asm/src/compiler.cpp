/**
 * @file compiler.cpp
 * @brief KaguASM Compiler implementation
 */

#include "compiler.hpp"
#include <kagu/kagu.hpp>
#include <iostream>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <cctype>
#include <cstdlib>

namespace fs = std::filesystem;

namespace kagu_asm {

// ============================================================================
// Command Patterns
// ============================================================================
const std::vector<CommandPattern> COMMAND_PATTERNS = {
    {"var", 2, R"(^\(_ cmd\)\(_ nam\)\(_ cmt\)$)", "var name - name should start from a letter and contain only letters, numbers and _"},
    {"label", 2, R"(^\(_ cmd\)\(_ nam\)\(_ cmt\)$)", "label name - name should start from a letter and contain only letters, numbers and _"},
    {"cpu_exec", 1, R"(^\(_ cmd\)\(_ cmt\)$)", "cpu_exec - should just contain this single command, it will execute what is stored in the operation register"},
    {"DEBUG_ON", 1, R"(^\(_ cmd\)\(_ cmt\)$)", "DEBUG_ON - should just contain this single command"},
    {"DEBUG_OFF", 1, R"(^\(_ cmd\)\(_ cmt\)$)", "DEBUG_OFF - should just contain this single command"},
    {"jump_err", 2, R"(^\(_ cmd\)\(_ num\|\* num\|_ lbl\|\* lbl\|_ var\|\* var\|\* reg\)\(_ cmt\)$)", "jump_err 100 or jump_err label:someName or jump_err *100 or jump_err *var:varName or jump_err *REG_A"},
    {"jump_if_not", 2, R"(^\(_ cmd\)\(_ num\|\* num\|_ lbl\|\* lbl\|_ var\|\* var\|\* reg\)\(_ cmt\)$)", "jump_if_not 100 or jump_if_not label:someName or jump_if_not *100 or jump_if_not *var:varName or jump_if_not *REG_A"},
    {"jump_if", 2, R"(^\(_ cmd\)\(_ num\|\* num\|_ lbl\|\* lbl\|_ var\|\* var\|\* reg\)\(_ cmt\)$)", "jump_if 100 or jump_if label:someName or jump_if *100 or jump_if *var:varName or jump_if *REG_A"},
    {"jump", 2, R"(^\(_ cmd\)\(_ num\|\* num\|_ lbl\|\* lbl\|_ var\|\* var\|\* reg\)\(_ cmt\)$)", "jump label:someName or jump 100 or jump *100 or jump *var:varName or jump *REG_A"},
    {"write", 5, R"(^\(_ cmd\)\(_ str\|_ num\|_ opr\|_ sys\|_ clr\|_ mod\|_ lbl\)\(_ kto\)\(_ num\|\* num\|_ reg\|\* reg\|_ var\|\* var\)\(_ cmt\)$)", "'write \"some string\" to address' or 'write 100 to address' or 'write OP_* to address' or 'write COLOR_* to address' or 'write SYS_CALL_* to address'"},
    {"copy", 5, R"(^\(_ cmd\)\(_ num\|\* num\|_ reg\|\* reg\|_ var\|\* var\|@ var\)\(_ kto\)\(_ num\|\* num\|_ reg\|\* reg\|_ var\|\* var\)\(_ cmt\)$)", "copy someAddress to otherAddress"}
};

// ============================================================================
// Pattern Matching
// ============================================================================
bool matchPattern(const std::string& pattern, const std::string& expectedStr) {
    std::vector<std::vector<std::string>> expectedGroups;
    
    std::string expected = expectedStr;
    if (!expected.empty() && expected[0] == '^') expected = expected.substr(1);
    if (!expected.empty() && expected.back() == '$') expected.pop_back();
    
    std::string cleaned;
    for (size_t i = 0; i < expected.length(); i++) {
        if (expected[i] == '\\' && i + 1 < expected.length()) {
            cleaned += expected[i + 1];
            i++;
        } else {
            cleaned += expected[i];
        }
    }
    expected = cleaned;
    
    size_t pos = 0;
    while (pos < expected.length()) {
        if (expected[pos] == '(') {
            size_t end = expected.find(')', pos);
            if (end == std::string::npos) return false;
            
            std::string group = expected.substr(pos + 1, end - pos - 1);
            std::vector<std::string> alternatives;
            
            size_t altStart = 0;
            for (size_t i = 0; i < group.length(); i++) {
                if (group[i] == '|') {
                    alternatives.push_back(group.substr(altStart, i - altStart));
                    altStart = i + 1;
                }
            }
            alternatives.push_back(group.substr(altStart));
            
            expectedGroups.push_back(alternatives);
            pos = end + 1;
        } else {
            pos++;
        }
    }
    
    std::vector<std::string> actualGroups;
    pos = 0;
    while (pos < pattern.length()) {
        if (pattern[pos] == '(') {
            size_t end = pattern.find(')', pos);
            if (end == std::string::npos) return false;
            actualGroups.push_back(pattern.substr(pos + 1, end - pos - 1));
            pos = end + 1;
        } else {
            pos++;
        }
    }
    
    if (actualGroups.size() != expectedGroups.size()) return false;
    
    for (size_t i = 0; i < actualGroups.size(); i++) {
        bool matched = false;
        for (const auto& alt : expectedGroups[i]) {
            if (actualGroups[i] == alt) {
                matched = true;
                break;
            }
        }
        if (!matched) return false;
    }
    
    return true;
}

// ============================================================================
// Symbol Table
// ============================================================================
bool SymbolTable::hasSymbol(const std::string& name) const {
    if (symbols::lookupSymbol(name).has_value()) {
        return true;
    }
    return userSymbols_.find(name) != userSymbols_.end();
}

bool SymbolTable::hasNumericSymbol(const std::string& name) const {
    auto sym = symbols::lookupSymbol(name);
    if (sym && sym->isInteger()) {
        return true;
    }
    return userSymbols_.find(name) != userSymbols_.end();
}

bool SymbolTable::hasStringSymbol(const std::string& name) const {
    auto sym = symbols::lookupSymbol(name);
    return sym && sym->isString();
}

int SymbolTable::getNumericSymbol(const std::string& name) const {
    auto sym = symbols::lookupSymbol(name);
    if (sym && sym->isInteger()) {
        return sym->intValue;
    }
    auto it = userSymbols_.find(name);
    if (it != userSymbols_.end()) {
        return it->second;
    }
    return -1;
}

std::string SymbolTable::getStringSymbol(const std::string& name) const {
    auto sym = symbols::lookupSymbol(name);
    if (sym && sym->isString()) {
        return std::string(sym->stringValue);
    }
    return "";
}

void SymbolTable::addUserSymbol(const std::string& name, int value) {
    userSymbols_[name] = value;
}

// ============================================================================
// Compiler
// ============================================================================
Compiler::Compiler(bool userSpace, bool debugInfo)
    : userSpace_(userSpace), debugInfo_(debugInfo), compilationErrorCount_(0) {
    
    if (userSpace_) {
        firstInstructionNo_ = kagu::config::USER_SPACE_START;
        outputFile_ = std::string(kagu::config::USER_DISK);
        mapFile_ = std::string(kagu::config::USER_MAP);
    } else {
        firstInstructionNo_ = kagu::toInt(kagu::Address::KernelStart);
        outputFile_ = std::string(kagu::config::KERNEL_DATA);
        mapFile_ = std::string(kagu::config::KERNEL_MAP);
    }
    
    nextInstrAddress_ = firstInstructionNo_;
}

bool Compiler::compile(const std::vector<std::string>& sourceFiles) {
    if (!pass1(sourceFiles)) {
        return false;
    }

    calculateAddresses();

    if (!pass2()) {
        return false;
    }

    if (compilationErrorCount_ != 0) {
        std::cerr << "\033[91mCompilation failed: " 
                  << compilationErrorCount_ << " error(s).\033[0m" << std::endl;
        return false;
    }

    writeSourceMap();

    std::cout << "\033[92mCompilation succeeded. Output image: "
              << outputFile_ << " | Source map: " << mapFile_ << "\033[0m" << std::endl;

    return true;
}

void Compiler::compilationError(const std::string& expectedSyntax, const std::string& errorInfo) {
    std::cerr << "\033[93mCompilation error\033[0m at " << currentFile_ 
              << ":" << currentLineNo_ << std::endl;
    std::cerr << "\033[91m" << currentLine_ << "\033[0m" << std::endl;
    if (!errorInfo.empty()) {
        std::cerr << "\033[91m" << errorInfo << "\033[0m" << std::endl;
    }
    std::cerr << "Expected syntax:\n\033[92m" << expectedSyntax << "\033[0m\n" << std::endl;

    compilationErrorCount_++;
    if (compilationErrorCount_ > 20) {
        std::cerr << "Too many compilation errors, aborting" << std::endl;
        std::exit(1);
    }
}

void Compiler::writeSourceMap() {
    std::ofstream out(mapFile_);
    if (!out) {
        std::cerr << "Warning: Cannot create source map: " << mapFile_ << std::endl;
        return;
    }

    for (size_t i = 0; i < parsedInstructions_.size(); i++) {
        int address = firstInstructionNo_ + static_cast<int>(i);
        const auto& instr = parsedInstructions_[i];
        out << address << " " << instr.sourceFile << ":" << instr.lineNumber << "\n";
    }

    // Emit variable address mappings so debuggers can resolve var:name → address
    for (const auto& [name, vi] : variablesOrdered_) {
        out << "var:" << name << " " << vi.address
            << " " << vi.file << ":" << vi.declarationLine << "\n";
    }
}

bool Compiler::pass1(const std::vector<std::string>& sourceFiles) {
    for (const auto& file : sourceFiles) {
        if (!fs::exists(file)) {
            std::cerr << file << " is not a valid source file" << std::endl;
            return false;
        }

        currentFile_ = file;
        std::ifstream inFile(file);
        if (!inFile) {
            std::cerr << "Cannot open file: " << file << std::endl;
            return false;
        }

        currentLineNo_ = 0;
        std::string line;

        while (std::getline(inFile, line)) {
            currentLineNo_++;
            currentLine_ = line;
            processLine(line);
        }
    }

    return compilationErrorCount_ == 0;
}

std::vector<std::string> Compiler::tokenizeLine(const std::string& line) {
    std::vector<std::string> tokens;
    std::string current;
    bool inQuotes = false;

    for (size_t i = 0; i < line.length(); i++) {
        char c = line[i];
        if (c == '"') {
            inQuotes = !inQuotes;
            current += c;
        } else if (std::isspace(static_cast<unsigned char>(c)) && !inQuotes) {
            if (!current.empty()) {
                tokens.push_back(current);
                current.clear();
            }
        } else {
            current += c;
        }
    }
    if (!current.empty()) {
        tokens.push_back(current);
    }

    return tokens;
}

void Compiler::processLine(const std::string& line) {
    std::vector<std::string> tokens = tokenizeLine(line);
    
    if (tokens.empty()) return;
    if (tokens[0].substr(0, 2) == "//") return;

    std::string cmd = tokens[0];

    const CommandPattern* pattern = nullptr;
    for (const auto& p : COMMAND_PATTERNS) {
        if (p.name == cmd) {
            pattern = &p;
            break;
        }
    }

    if (!pattern) {
        compilationError("Unknown command: " + cmd);
        return;
    }

    int lexemesCount = pattern->lexemeCount;
    std::string expectedPattern = pattern->pattern;
    std::string expectedSyntax = pattern->syntax;

    std::vector<Lexeme> lexemes;
    std::string patternStr;

    int tokensProcessed = 0;
    for (int i = 0; i < lexemesCount && i < static_cast<int>(tokens.size()); i++) {
        std::string token = tokens[i];
        
        if (token.substr(0, 2) == "//") {
            break;
        }
        
        if (i == 1 && cmd == "write") {
            size_t writePos = line.find("write");
            if (writePos != std::string::npos) {
                size_t quotePos = line.find('"', writePos + 5);
                if (quotePos != std::string::npos && token.front() != '"') {
                    size_t endQuote = line.find('"', quotePos + 1);
                    if (endQuote != std::string::npos) {
                        token = line.substr(quotePos, endQuote - quotePos + 1);
                    }
                }
            }
        }

        Lexeme lex = Lexer::parse(token);
        patternStr += lex.toPattern();
        lexemes.push_back(lex);
        tokensProcessed++;
    }

    if (tokensProcessed < static_cast<int>(tokens.size())) {
        std::string remaining;
        for (size_t i = tokensProcessed; i < tokens.size(); i++) {
            if (i > static_cast<size_t>(tokensProcessed)) remaining += " ";
            remaining += tokens[i];
        }
        Lexeme commentLex = Lexer::parse(remaining);
        patternStr += commentLex.toPattern();
    } else {
        patternStr += "(_ cmt)";
    }

    if (!matchPattern(patternStr, expectedPattern)) {
        compilationError(expectedSyntax, "Unexpected arguments for command " + cmd);
        return;
    }

    if (cmd == "var") {
        std::string varName = lexemes[1].value;
        if (variables_.find(varName) != variables_.end()) {
            compilationError(expectedSyntax, "Variable " + varName + " is already defined");
            return;
        }
        VariableInfo vi;
        vi.declarationAddress = nextInstrAddress_;
        vi.declarationLine = currentLineNo_;
        vi.file = currentFile_;
        variables_[varName] = vi;
        variablesOrdered_.push_back({varName, vi});
        return;
    }

    if (cmd == "label") {
        std::string labelName = lexemes[1].value;
        if (labels_.find(labelName) != labels_.end()) {
            compilationError(expectedSyntax, "Label " + labelName + " is already defined");
            return;
        }
        LabelInfo li;
        li.address = nextInstrAddress_;
        li.declarationLine = currentLineNo_;
        li.file = currentFile_;
        labels_[labelName] = li;
        return;
    }

    if (cmd == "DEBUG_ON" || cmd == "DEBUG_OFF") {
        ParsedInstruction instr;
        instr.sourceFile = currentFile_;
        instr.lineNumber = currentLineNo_;
        instr.lexemes = lexemes;
        parsedInstructions_.push_back(instr);
        nextInstrAddress_++;
        return;
    }

    ParsedInstruction instr;
    instr.sourceFile = currentFile_;
    instr.lineNumber = currentLineNo_;
    instr.lexemes = lexemes;
    parsedInstructions_.push_back(instr);
    nextInstrAddress_++;

    if (cmd == "write" && lexemes.size() > 1) {
        Lexeme valueLex = lexemes[1];
        std::string rawValue;
        std::string evalValue;

        switch (valueLex.type) {
            case LexemeType::STRING:
                rawValue = "\"" + valueLex.value + "\"";
                evalValue = valueLex.value;
                break;
            case LexemeType::NUMBER:
                rawValue = valueLex.value;
                evalValue = valueLex.value;
                break;
            case LexemeType::OPERATION:
            case LexemeType::SYSCALL:
            case LexemeType::COLOR:
                rawValue = valueLex.value;
                evalValue = std::to_string(symbolTable_.getNumericSymbol(valueLex.value));
                break;
            case LexemeType::MODE:
                rawValue = valueLex.value;
                evalValue = symbolTable_.getStringSymbol(valueLex.value);
                break;
            case LexemeType::LABEL:
                rawValue = "LABEL:" + valueLex.value;
                evalValue = "";
                break;
            default:
                break;
        }

        if (!rawValue.empty() && constantsIndex_.find(rawValue) == constantsIndex_.end()) {
            ConstantInfo ci;
            ci.rawValue = rawValue;
            ci.evaluatedValue = evalValue;
            constantsIndex_[rawValue] = constants_.size();
            constants_.push_back(ci);
        }
    }
}

void Compiler::calculateAddresses() {
    int constantsStart = nextInstrAddress_;
    for (size_t i = 0; i < constants_.size(); i++) {
        constants_[i].address = constantsStart + static_cast<int>(i);
    }

    int variablesStart = constantsStart + static_cast<int>(constants_.size());
    for (size_t i = 0; i < variablesOrdered_.size(); i++) {
        std::string name = variablesOrdered_[i].first;
        variables_[name].address = variablesStart + static_cast<int>(i);
        variablesOrdered_[i].second.address = variablesStart + static_cast<int>(i);
    }

    nextInstrAddress_ = variablesStart + static_cast<int>(variablesOrdered_.size());

    for (auto& ci : constants_) {
        if (ci.rawValue.substr(0, 6) == "LABEL:") {
            std::string labelName = ci.rawValue.substr(6);
            auto it = labels_.find(labelName);
            if (it != labels_.end()) {
                ci.evaluatedValue = std::to_string(it->second.address);
            }
        }
    }
}

bool Compiler::pass2() {
    fs::create_directories(fs::path(outputFile_).parent_path());

    std::ofstream outFile(outputFile_);
    if (!outFile) {
        std::cerr << "Cannot create output file: " << outputFile_ << std::endl;
        return false;
    }

    std::vector<std::string> outputLines;

    for (const auto& instr : parsedInstructions_) {
        currentFile_ = instr.sourceFile;
        currentLineNo_ = instr.lineNumber;
        currentLine_ = "";

        std::string cmd = instr.lexemes[0].value;
        std::string resStr;
        std::string debugStr = "# ";

        for (size_t i = 0; i < instr.lexemes.size(); i++) {
            const Lexeme& lex = instr.lexemes[i];
            std::string position = cmd + "_" + std::to_string(i);

            std::string evalResult = evalLexeme(lex, position);
            std::string debugResult = evalDebugInfo(lex, position);

            if (!resStr.empty() && !evalResult.empty()) resStr += " ";
            resStr += evalResult;

            if (!debugStr.empty() && !debugResult.empty()) debugStr += " ";
            debugStr += debugResult;
        }

        if (debugInfo_) {
            outputLines.push_back(resStr + " " + debugStr);
        } else {
            outputLines.push_back(resStr);
        }
    }

    if (debugInfo_ && !outputLines.empty()) {
        for (auto& line : outputLines) {
            size_t hashPos = line.find('#');
            if (hashPos != std::string::npos && hashPos < 15) {
                std::string before = line.substr(0, hashPos);
                std::string after = line.substr(hashPos);
                int spaces = 15 - static_cast<int>(hashPos);
                line = before + std::string(spaces, ' ') + after;
            }
        }
    }

    for (const auto& line : outputLines) {
        outFile << line << "\n";
    }

    for (const auto& ci : constants_) {
        outFile << ci.evaluatedValue << "\n";
    }

    for (size_t i = 0; i < variablesOrdered_.size(); i++) {
        outFile << "\n";
    }

    if (outputLines.empty()) {
        compilationError("", "Empty kernel file: no valid instructions present in the provided source files");
        return false;
    }

    return true;
}

std::string Compiler::evalLexeme(const Lexeme& lex, const std::string& position) {
    std::string prefix = (lex.prefix == '_') ? "" : std::string(1, lex.prefix);

    switch (lex.type) {
        case LexemeType::COMMAND: {
            if (lex.value == "copy" || lex.value == "write") {
                return std::to_string(kagu::toInt(kagu::Instruction::CopyFromToAddress));
            } else if (lex.value == "jump") {
                return std::to_string(kagu::toInt(kagu::Instruction::Jump));
            } else if (lex.value == "jump_if") {
                return std::to_string(kagu::toInt(kagu::Instruction::JumpIf));
            } else if (lex.value == "jump_if_not") {
                return std::to_string(kagu::toInt(kagu::Instruction::JumpIfNot));
            } else if (lex.value == "jump_err") {
                return std::to_string(kagu::toInt(kagu::Instruction::JumpErr));
            } else if (lex.value == "cpu_exec") {
                return std::to_string(kagu::toInt(kagu::Instruction::CpuExec));
            } else if (lex.value == "DEBUG_ON" || lex.value == "DEBUG_OFF") {
                return lex.value;
            }
            return "";
        }

        case LexemeType::KEYWORD_TO:
            return "";

        case LexemeType::NUMBER:
        case LexemeType::REGISTER:
        case LexemeType::OPERATION:
        case LexemeType::SYSCALL:
        case LexemeType::COLOR:
        case LexemeType::MODE: {
            if (position == "write_1") {
                std::string rawValue = lex.value;
                auto it = constantsIndex_.find(rawValue);
                if (it != constantsIndex_.end()) {
                    return std::to_string(constants_[it->second].address);
                }
            }
            
            if (lex.type == LexemeType::NUMBER) {
                return prefix + lex.value;
            }
            
            if (symbolTable_.hasNumericSymbol(lex.value)) {
                return prefix + std::to_string(symbolTable_.getNumericSymbol(lex.value));
            }
            if (symbolTable_.hasStringSymbol(lex.value)) {
                return prefix + symbolTable_.getStringSymbol(lex.value);
            }
            compilationError("", "Symbol " + lex.value + " is unknown");
            return "";
        }

        case LexemeType::STRING: {
            std::string rawValue = "\"" + lex.value + "\"";
            auto it = constantsIndex_.find(rawValue);
            if (it != constantsIndex_.end()) {
                return std::to_string(constants_[it->second].address);
            }
            return "";
        }

        case LexemeType::LABEL: {
            if (position == "write_1") {
                std::string rawValue = "LABEL:" + lex.value;
                auto it = constantsIndex_.find(rawValue);
                if (it != constantsIndex_.end()) {
                    return std::to_string(constants_[it->second].address);
                }
            } else {
                auto it = labels_.find(lex.value);
                if (it == labels_.end()) {
                    compilationError("", "Label " + lex.value + " is not defined");
                    return "";
                }
                return std::to_string(it->second.address);
            }
            return "";
        }

        case LexemeType::VARIABLE: {
            auto it = variables_.find(lex.value);
            if (it == variables_.end()) {
                compilationError("Variable should be declared before usage", 
                                 "Variable " + lex.value + " is not defined");
                return "";
            }
            return prefix + std::to_string(it->second.address);
        }

        default:
            return "";
    }
}

std::string Compiler::evalDebugInfo(const Lexeme& lex, const std::string& position) {
    std::string prefix = (lex.prefix == '_') ? "" : std::string(1, lex.prefix);

    switch (lex.type) {
        case LexemeType::COMMAND:
            return lex.value;

        case LexemeType::KEYWORD_TO:
            return "=>";

        case LexemeType::NUMBER:
            if (position.find("_1") != std::string::npos) {
                return "\"" + lex.value + "\"";
            }
            return prefix + lex.value;

        case LexemeType::STRING:
            return "\"" + lex.value + "\"";

        case LexemeType::REGISTER:
        case LexemeType::OPERATION:
        case LexemeType::SYSCALL:
        case LexemeType::COLOR:
        case LexemeType::MODE:
            return prefix + lex.value;

        case LexemeType::LABEL:
            return prefix + "lbl:" + lex.value;

        case LexemeType::VARIABLE:
            return prefix + "var:" + lex.value;

        default:
            return "";
    }
}

} // namespace kagu_asm
