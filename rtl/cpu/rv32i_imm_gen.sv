//=============================================================================
// File: rv32i_imm_gen.sv
// Description: RV32I Immediate Generator supporting all 5 immediate formats:
// I-type, S-type, B-type, U-type, and J-type (sign-extended to 32 bits).
//=============================================================================

`timescale 1ns/1ps

module rv32i_imm_gen (
  input  logic [31:0] instr,
  output logic [31:0] imm_i,
  output logic [31:0] imm_s,
  output logic [31:0] imm_b,
  output logic [31:0] imm_u,
  output logic [31:0] imm_j
);

  // I-type immediate (Loads, JALR, Arithmetic Immediates)
  assign imm_i = {{20{instr[31]}}, instr[31:20]};

  // S-type immediate (Store instructions)
  assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

  // B-type immediate (Conditional branches, 2-byte aligned)
  assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};

  // U-type immediate (LUI, AUIPC)
  assign imm_u = {instr[31:12], 12'h000};

  // J-type immediate (JAL, 2-byte aligned)
  assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

endmodule : rv32i_imm_gen
