/**
 * @file opcodes.hpp
 * @brief KaguOS - CPU instructions and operations
 * 
 * This file defines:
 * - Instruction: Top-level CPU instruction codes (stored in .disk files)
 * - Operation: Micro-operations executed via CpuExec instruction
 * 
 * Execution Model:
 * 1. CPU fetches instruction from RAM[ProgramCounter]
 * 2. Decodes instruction code (first number in line)
 * 3. For Instruction::CpuExec: reads Op register and executes operation
 * 4. Operations read from A/B/C/D and write to Res/BoolRes/Error
 */

#pragma once

#include "types.hpp"

namespace kagu
{

// ============================================================================
// CPU Instructions (Top-Level)
// ============================================================================

/**
 * @brief CPU instruction codes
 * 
 * These are the opcodes that appear at the start of each line in .disk files.
 * Each instruction may have additional operands following the opcode.
 * 
 * Format examples:
 * - "0"           -> CpuExec (execute operation in Op register)
 * - "1 src dest"  -> CopyFromToAddress (copy value)
 * - "2 addr"      -> Jump (unconditional jump)
 */
enum class Instruction : int
{
    /// Execute operation specified in Op register
    /// Format: 0
    /// Reads operation code from Address::Op, executes it
    CpuExec = 0,
    
    /// Copy value from source address to destination address
    /// Format: 1 <src> <dest>
    /// Supports prefixes: * (dereference), @ (literal value)
    CopyFromToAddress = 1,
        
    /// Unconditional jump to address
    /// Format: 2 <addr>
    /// Supports prefix * for indirect jump
    Jump = 2,
    
    /// Conditional jump if BoolRes == "1"
    /// Format: 3 <addr>
    JumpIf = 3,
    
    /// Conditional jump if BoolRes == "0"
    /// Format: 4 <addr>
    JumpIfNot = 4,
    
    /// Conditional jump if Error register is not empty
    /// Format: 5 <addr>
    JumpErr = 5,

    /// Debug enable/disable
    /// Format: 6 0 to disable, 6 1 to enable
    Debug = 6
};

// ============================================================================
// CPU Operations (Micro-operations)
// ============================================================================

/**
 * @brief CPU operation codes
 * 
 * Operations are stored in the Op register and executed by CpuExec instruction.
 * Most operations read from A/B/C/D registers and write to Res or BoolRes.
 * 
 * Operation categories:
 * - Arithmetic (0-6): Add, Sub, Incr, Decr, Div, Mod, Mul
 * - Type check (7): IsNum
 * - Comparison (8-11): CmpEq, CmpNeq, CmpLt, CmpLe
 * - String (12-17): Contains, GetLength, StartsWith, GetColumn, ReplaceColumn, ConcatWith
 * - I/O (18-20): ReadInput, Display, DisplayLn [privileged]
 * - Disk (21-22): ReadBlock, WriteBlock [privileged]
 * - Display (23-24): SetBackgroundColor, RenderBitmap [privileged]
 * - System (25-26): SysCall, SysReturn
 * - Crypto (27-28): EncryptData, DecryptData [placeholder]
 * - Control (29-30): Nop, Halt
 */
enum class Operation : int
{
    // ========================================================================
    // Arithmetic Operations (0-6)
    // ========================================================================
    
    /// Addition: Res = A + B
    /// Supports both integer and floating-point strings
    Add = 0,
    
    /// Subtraction: Res = A - B
    Sub = 1,
    
    /// Increment: Res = A + 1
    Incr = 2,
    
    /// Decrement: Res = A - 1
    Decr = 3,
    
    /// Division: Res = A / B
    /// Sets Error on division by zero
    Div = 4,
    
    /// Modulo: Res = A % B (integer only)
    /// Sets Error on modulo by zero
    Mod = 5,
    
    /// Multiplication: Res = A * B
    Mul = 6,
    
    // ========================================================================
    // Type Checking (7)
    // ========================================================================
    
    /// Check if A is numeric: BoolRes = isNumber(A)
    /// Returns "1" if A matches regex ^-?\d*(\.\d+)?$
    IsNum = 7,
    
    // ========================================================================
    // Comparison Operations (8-11)
    // ========================================================================
    
    /// String equality: BoolRes = (A == B) ? "1" : "0"
    CmpEq = 8,
    
    /// String inequality: BoolRes = (A != B) ? "1" : "0"
    CmpNeq = 9,
    
    /// Numeric less than: BoolRes = (int(A) < int(B)) ? "1" : "0"
    CmpLt = 10,
    
    /// Numeric less or equal: BoolRes = (int(A) <= int(B)) ? "1" : "0"
    CmpLe = 11,
    
    // ========================================================================
    // String Operations (12-17)
    // ========================================================================
    
    /// Substring search: BoolRes = A.contains(B)
    /// If found: Res = position (1-based), BoolRes = "1"
    /// If not found: Res = "", BoolRes = "0"
    Contains = 12,
    
    /// String length: Res = A.length()
    GetLength = 13,
    
    /// Prefix check and removal
    /// If A.startsWith(B): BoolRes = "1", Res = A.removePrefix(B)
    /// Otherwise: BoolRes = "0", Res = ""
    StartsWith = 14,
    
    /// Get column/character from string
    /// If C empty: Res = A[B-1] (1-based character index)
    /// If C non-empty: Res = A.split(C)[B] (B-th token)
    GetColumn = 15,
    
    /// Replace column/character in string
    /// If C empty: A[B-1] = D (replace character)
    /// If C non-empty: A.split(C)[B] = D (replace token)
    ReplaceColumn = 16,
    
    /// Concatenation with separator: Res = A + C + B
    ConcatWith = 17,
    
    // ========================================================================
    // I/O Operations (18-20) - PRIVILEGED
    // ========================================================================
    
    /// Read keyboard input to KeyboardBuffer
    /// Mode determined by current KeyboardBuffer value
    ReadInput = 18,
    
    /// Display: print DisplayBuffer (no newline)
    /// Uses DisplayColor for text color
    Display = 19,
    
    /// DisplayLn: print DisplayBuffer with newline
    DisplayLn = 20,
    
    // ========================================================================
    // Disk Operations (21-22) - PRIVILEGED
    // ========================================================================
    
    /// Read disk block: Res = disk[A].block[B]
    /// A = disk name, B = block number
    ReadBlock = 21,
    
    /// Write disk block: disk[A].block[B] = C
    WriteBlock = 22,
    
    // ========================================================================
    // Display Control (23-24) - PRIVILEGED
    // ========================================================================
    
    /// Set terminal background color from A
    SetBackgroundColor = 23,
    
    /// Render bitmap from RAM addresses A to B
    RenderBitmap = 24,
    
    // ========================================================================
    // System Call Operations (25-26)
    // ========================================================================
    
    /// Trigger system call (user space -> kernel)
    /// Syscall number in D register, args in A/B/C
    /// NOT privileged - this is how user space enters kernel
    SysCall = 25,
    
    /// Return from system call (kernel -> user space)
    /// PRIVILEGED - only kernel can execute
    SysReturn = 26,
    
    // ========================================================================
    // Encryption (27-28) - Placeholder
    // ========================================================================
    
    /// Encrypt data: Res = encrypt(A)
    /// Currently a no-op (returns A unchanged)
    EncryptData = 27,
    
    /// Decrypt data: Res = decrypt(A)
    /// Currently a no-op (returns A unchanged)
    DecryptData = 28,
    
    // ========================================================================
    // Control Operations (29-31)
    // ========================================================================
    
    /// No operation / sleep
    /// If A is numeric: sleep for A seconds
    Nop = 29,
    
    /// Halt CPU execution
    /// Dumps RAM to file and exits
    Halt = 30,
    
    /// Invalid/unknown operation marker
    Unknown = 31
};

// ============================================================================
// Operation Utility Functions
// ============================================================================

/**
 * @brief Check if an operation requires kernel mode
 * @param op Operation to check
 * @return true if operation is privileged
 * 
 * Privileged operations can only be executed in kernel mode.
 * SysCall is NOT privileged - it's the mechanism to enter kernel mode.
 */
[[nodiscard]] constexpr bool isPrivileged(Operation op) noexcept
{
    // ReadInput through DecryptData are privileged, except SysCall
    return op >= Operation::ReadInput && op != Operation::SysCall;
}

/**
 * @brief Check if operation is an arithmetic operation
 * @param op Operation to check
 * @return true if operation is arithmetic
 */
[[nodiscard]] constexpr bool isArithmetic(Operation op) noexcept
{
    return op >= Operation::Add && op <= Operation::Mul;
}

/**
 * @brief Check if operation is a comparison operation
 * @param op Operation to check
 * @return true if operation is comparison
 */
[[nodiscard]] constexpr bool isComparison(Operation op) noexcept
{
    return op >= Operation::CmpEq && op <= Operation::CmpLe;
}

/**
 * @brief Check if operation is a string operation
 * @param op Operation to check
 * @return true if operation is string manipulation
 */
[[nodiscard]] constexpr bool isStringOperation(Operation op) noexcept
{
    return op >= Operation::Contains && op <= Operation::ConcatWith;
}

/**
 * @brief Check if operation is an I/O operation
 * @param op Operation to check
 * @return true if operation is I/O
 */
[[nodiscard]] constexpr bool isIOOperation(Operation op) noexcept
{
    return op >= Operation::ReadInput && op <= Operation::DisplayLn;
}

/**
 * @brief Check if operation is a disk operation
 * @param op Operation to check
 * @return true if operation is disk access
 */
[[nodiscard]] constexpr bool isDiskOperation(Operation op) noexcept
{
    return op >= Operation::ReadBlock && op <= Operation::WriteBlock;
}

/**
 * @brief Get energy cost for an operation
 * @param op Operation to get cost for
 * @return Energy cost (arbitrary units)
 * 
 * Cost categories:
 * - Simple ops (arithmetic, comparison): 1
 * - String ops: 2-3
 * - I/O ops: 5-10
 * - Disk ops: 10
 * - System ops: 5
 */
[[nodiscard]] constexpr int getOperationCost(Operation op) noexcept
{
    switch (op)
    {
        // Arithmetic - cheap
        case Operation::Add:
        case Operation::Sub:
        case Operation::Incr:
        case Operation::Decr:
        case Operation::Mul:
            return 1;
        
        case Operation::Div:
        case Operation::Mod:
            return 2;
        
        // Type check - cheap
        case Operation::IsNum:
            return 1;
        
        // Comparisons - cheap
        case Operation::CmpEq:
        case Operation::CmpNeq:
        case Operation::CmpLt:
        case Operation::CmpLe:
            return 1;
        
        // String operations - medium
        case Operation::GetLength:
            return 1;
        case Operation::Contains:
        case Operation::StartsWith:
            return 2;
        case Operation::GetColumn:
        case Operation::ReplaceColumn:
        case Operation::ConcatWith:
            return 3;
        
        // I/O - expensive
        case Operation::ReadInput:
            return 10;
        case Operation::Display:
        case Operation::DisplayLn:
            return 5;
        
        // Disk - expensive
        case Operation::ReadBlock:
        case Operation::WriteBlock:
            return 10;
        
        // Display control - medium
        case Operation::SetBackgroundColor:
            return 3;
        case Operation::RenderBitmap:
            return 20;
        
        // System calls - medium
        case Operation::SysCall:
        case Operation::SysReturn:
            return 5;
        
        // Crypto - expensive (placeholder)
        case Operation::EncryptData:
        case Operation::DecryptData:
            return 15;
        
        // Control
        case Operation::Nop:
            return 1;
        case Operation::Halt:
            return 0;
        
        default:
            return 1;
    }
}

} // namespace kagu
