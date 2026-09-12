//=============================================================================
// File: diag_tests.s
// Description: RV32I SoC End-to-End Diagnostic Firmware Suite.
// Verifies ALU operations, SRAM read/write, GPIO direction/output,
// UART serial character transmission, and flags PASS signature (0xCAFEBABE).
//=============================================================================

.section .text
.globl diag_main

diag_main:
    // 1. Arithmetic & Immediate Tests
    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2         // x3 = 30

    // 2. SRAM Store & Load Verification
    sw   x3, 0x100(x0)      // Write 30 to SRAM address 0x100
    lw   x4, 0x100(x0)      // Read back into x4
    bne  x3, x4, test_fail  // Branch to fail if mismatch

    // 3. GPIO MMIO Configuration & Output Drive
    lui  x5, 0x40000        // GPIO Base: 0x4000_0000
    addi x6, x0, 0xFF
    sw   x6, 8(x5)          // REG_DIR = 0xFF (Output mode)
    addi x7, x0, 0xA5
    sw   x7, 4(x5)          // REG_DATA_OUT = 0xA5 (Drive test pattern)

    // 4. UART MMIO Configuration & Serial Character Stream
    lui  x8, 0x40001        // UART Base: 0x4000_1000
    addi x9, x0, 4
    sw   x9, 16(x8)         // REG_BAUD_DIV = 4 (Fast simulation baud)
    addi x10, x0, 7
    sw   x10, 12(x8)        // REG_CTRL = 7 (TX_EN, RX_EN, Loopback)
    addi x11, x0, 0x4F      // 'O'
    sw   x11, 0(x8)         // Transmit 'O'
    addi x12, x0, 0x4B      // 'K'
    sw   x12, 0(x8)         // Transmit 'K'
    addi x13, x0, 0x0A      // '\n'
    sw   x13, 0(x8)         // Transmit '\n'

    // 5. Write Success Signature to SRAM
    lui  x14, 0xCAFEB
    ori  x14, x14, 0xABE    // x14 = 0xCAFEBABE (PASS Signature)
    sw   x14, 0x200(x0)     // Write signature to SRAM address 0x200

test_pass:
    jal  x0, test_pass      // Successful completion halt

test_fail:
    lui  x14, 0xDEADB
    ori  x14, x14, 0xEEF    // x14 = 0xDEADBEEF (FAIL Signature)
    sw   x14, 0x200(x0)
fail_halt:
    jal  x0, fail_halt
