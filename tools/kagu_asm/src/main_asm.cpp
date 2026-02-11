/**
 * @file main_asm.cpp
 * @brief KaguASM Compiler entry point
 * 
 * A two-pass assembler for KaguOS educational operating system.
 * Converts .kga assembly files to machine code (.disk files).
 */

#include "compiler.hpp"
#include <iostream>
#include <string>
#include <vector>

void printUsage(const char* progName) {
    std::cerr << "Usage: " << progName << " [options] <source_files...>" << std::endl;
    std::cerr << "Options:" << std::endl;
    std::cerr << "  -u, --user-space  Compile for user space (start at address " << kagu::config::USER_SPACE_START << ")" << std::endl;
    std::cerr << "  -n, --no-debug    Don't include debug comments in output" << std::endl;
    std::cerr << "  -h, --help        Show this help" << std::endl;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printUsage(argv[0]);
        return 1;
    }

    bool userSpace = false;
    bool debugInfo = true;
    std::vector<std::string> sourceFiles;

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "-u" || arg == "--user-space") {
            userSpace = true;
        } else if (arg == "-n" || arg == "--no-debug") {
            debugInfo = false;
        } else if (arg == "-h" || arg == "--help") {
            printUsage(argv[0]);
            return 0;
        } else if (arg[0] == '-') {
            std::cerr << "Unknown option: " << arg << std::endl;
            printUsage(argv[0]);
            return 1;
        } else {
            sourceFiles.push_back(arg);
        }
    }

    if (sourceFiles.empty()) {
        std::cerr << "No source files specified" << std::endl;
        printUsage(argv[0]);
        return 1;
    }

    kagu_asm::Compiler compiler(userSpace, debugInfo);
    return compiler.compile(sourceFiles) ? 0 : 1;
}
