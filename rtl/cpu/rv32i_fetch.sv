//=============================================================================
// File: rv32i_fetch.sv
// Description: Program Counter (PC) and Instruction Fetch Unit for RV32I.
// Generates sequential PC (+4), branch target, jump target (JAL / JALR),
// and supports pipeline stall/lock.
//=============================================================================

`timescale 1ns/1ps

module rv32i_fetch (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        stall,          // Freeze PC increment
  input  logic        branch_taken,   // Branch condition met
  input  logic        jump,           // Unconditional jump (JAL / JALR)
  input  logic [31:0] branch_target,  // PC + imm_b
  input  logic [31:0] jump_target,    // PC + imm_j or (rs1 + imm_i) & ~1

  output logic [31:0] pc,             // Current Program Counter
  output logic [31:0] pc_plus_4       // Sequential PC + 4
);

  logic [31:0] next_pc;

  assign pc_plus_4 = pc + 32'd4;

  // Next PC arbitration logic (Jumps/branches take priority over sequential +4)
  always_comb begin
    if (jump) begin
      next_pc = {jump_target[31:1], 1'b0}; // RV32I requirement: LSB forced to 0
    end else if (branch_taken) begin
      next_pc = {branch_target[31:1], 1'b0};
    end else begin
      next_pc = pc_plus_4;
    end
  end

  // Synchronous PC Register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 32'h0000_0000; // Reset vector (SRAM Base)
    end else if (!stall) begin
      pc <= next_pc;
    end
  end

endmodule : rv32i_fetch
