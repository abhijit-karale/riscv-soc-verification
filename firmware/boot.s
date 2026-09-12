//=============================================================================
// File: boot.s
// Description: RV32I Reset and Bootloader Handler for RISC-V SoC.
// Initializes stack pointer, zeros general-purpose registers,
// and jumps to the diagnostic main routine.
//=============================================================================

.section .text.boot
.globl _start

_start:
    // Initialize Stack Pointer to top of SRAM (32 KB = 0x0000_8000)
    lui  sp, %hi(0x00008000)
    addi sp, sp, %lo(0x00008000)

    // Clear register state
    addi x1,  x0, 0
    addi x3,  x0, 0
    addi x4,  x0, 0
    addi x5,  x0, 0
    addi x6,  x0, 0
    addi x7,  x0, 0
    addi x8,  x0, 0
    addi x9,  x0, 0
    addi x10, x0, 0
    addi x11, x0, 0
    addi x12, x0, 0
    addi x13, x0, 0
    addi x14, x0, 0
    addi x15, x0, 0

    // Jump to diagnostic suite
    jal  x0, diag_main

// Infinite Trap loop for unexpected exceptions
trap_handler:
    jal  x0, trap_handler
