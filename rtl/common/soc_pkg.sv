//=============================================================================
// File: soc_pkg.sv
// Description: Global architectural package for RV32I SoC.
// Contains instruction opcodes, ALU operation enums, memory map constants,
// and APB bus configurations.
//=============================================================================

package soc_pkg;

  //---------------------------------------------------------------------------
  // RV32I Base Instruction Opcodes [6:0]
  //---------------------------------------------------------------------------
  typedef enum logic [6:0] {
    OPCODE_R_TYPE  = 7'b0110011, // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
    OPCODE_I_TYPE  = 7'b0010011, // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
    OPCODE_LOAD    = 7'b0000011, // LB, LH, LW, LBU, LHU
    OPCODE_STORE   = 7'b0100011, // SB, SH, SW
    OPCODE_BRANCH  = 7'b1100011, // BEQ, BNE, BLT, BGE, BLTU, BGEU
    OPCODE_JAL     = 7'b1101111, // JAL
    OPCODE_JALR    = 7'b1100111, // JALR
    OPCODE_LUI     = 7'b0110111, // LUI
    OPCODE_AUIPC   = 7'b0010111, // AUIPC
    OPCODE_SYSTEM  = 7'b1110011  // ECALL, EBREAK, CSR
  } opcode_e;

  //---------------------------------------------------------------------------
  // ALU Operations
  //---------------------------------------------------------------------------
  typedef enum logic [3:0] {
    ALU_ADD  = 4'b0000,
    ALU_SUB  = 4'b0001,
    ALU_SLL  = 4'b0010,
    ALU_SLT  = 4'b0011,
    ALU_SLTU = 4'b0100,
    ALU_XOR  = 4'b0101,
    ALU_SRL  = 4'b0110,
    ALU_SRA  = 4'b0111,
    ALU_OR   = 4'b1000,
    ALU_AND  = 4'b1001,
    ALU_PASS = 4'b1010
  } alu_op_e;

  //---------------------------------------------------------------------------
  // Branch Comparison Types (funct3 for Branch)
  //---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    BR_BEQ  = 3'b000,
    BR_BNE  = 3'b001,
    BR_BLT  = 3'b100,
    BR_BGE  = 3'b101,
    BR_BLTU = 3'b110,
    BR_BGEU = 3'b111
  } branch_op_e;

  //---------------------------------------------------------------------------
  // Memory Access Widths (funct3 for Load/Store)
  //---------------------------------------------------------------------------
  typedef enum logic [2:0] {
    MEM_BYTE  = 3'b000, // LB / SB
    MEM_HALF  = 3'b001, // LH / SH
    MEM_WORD  = 3'b010, // LW / SW
    MEM_BYTEU = 3'b100, // LBU
    MEM_HALFU = 3'b101  // LHU
  } mem_width_e;

  //---------------------------------------------------------------------------
  // SoC Memory Map Constants
  //---------------------------------------------------------------------------
  localparam logic [31:0] SRAM_BASE_ADDR   = 32'h0000_0000;
  localparam logic [31:0] SRAM_SIZE        = 32'h0000_8000; // 32 KB
  localparam logic [31:0] SRAM_END_ADDR    = SRAM_BASE_ADDR + SRAM_SIZE - 1;

  localparam logic [31:0] APB_BASE_ADDR    = 32'h4000_0000;

  localparam logic [31:0] GPIO_BASE_ADDR   = 32'h4000_0000;
  localparam logic [31:0] GPIO_SIZE        = 32'h0000_1000; // 4 KB

  localparam logic [31:0] UART_BASE_ADDR   = 32'h4000_1000;
  localparam logic [31:0] UART_SIZE        = 32'h0000_1000; // 4 KB

  localparam logic [31:0] TIMER_BASE_ADDR  = 32'h4000_2000;
  localparam logic [31:0] TIMER_SIZE       = 32'h0000_1000; // 4 KB

  localparam logic [31:0] INTC_BASE_ADDR   = 32'h4000_3000;
  localparam logic [31:0] INTC_SIZE        = 32'h0000_1000; // 4 KB

  //---------------------------------------------------------------------------
  // APB Protocol Constants
  //---------------------------------------------------------------------------
  localparam int APB_ADDR_WIDTH = 32;
  localparam int APB_DATA_WIDTH = 32;
  localparam int NUM_PERIPHERALS = 4;

  typedef enum logic [1:0] {
    APB_IDLE   = 2'b00,
    APB_SETUP  = 2'b01,
    APB_ACCESS = 2'b10
  } apb_state_e;

endpackage : soc_pkg
