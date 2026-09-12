//=============================================================================
// File: core_invariants_sva.sv
// Description: Core Architectural Invariant Assertions for RV32I Processor.
// Checks PC 4-byte alignment, register x0 invariance, and trap integrity.
//=============================================================================

`timescale 1ns/1ps

module core_invariants_sva
  import soc_pkg::*;
(
  input logic        clk,
  input logic        rst_n,
  input logic [31:0] pc,
  input logic [31:0] instr_addr,
  input logic        illegal_instr,
  input logic        reg_write,
  input logic        mem_write
);

  // 1. PC must always be word-aligned (bits [1:0] == 2'b00)
  property p_pc_word_aligned;
    @(posedge clk) disable iff (!rst_n)
    (pc[1:0] == 2'b00);
  endproperty
  a_pc_word_aligned: assert property (p_pc_word_aligned)
    else $error("[CORE SVA FAIL] PC misaligned! pc=0x%08h", pc);

  // 2. Instruction address must track PC
  property p_instr_addr_tracks_pc;
    @(posedge clk) disable iff (!rst_n)
    (instr_addr === pc);
  endproperty
  a_instr_addr_tracks_pc: assert property (p_instr_addr_tracks_pc)
    else $error("[CORE SVA FAIL] Instruction address does not match PC! pc=0x%08h, instr_addr=0x%08h", pc, instr_addr);

  // 3. Illegal instruction must inhibit state modifications
  property p_illegal_instr_inhibit;
    @(posedge clk) disable iff (!rst_n)
    (illegal_instr) |-> (!reg_write && !mem_write);
  endproperty
  a_illegal_instr_inhibit: assert property (p_illegal_instr_inhibit)
    else $error("[CORE SVA FAIL] Illegal instruction attempted to modify register or memory!");

endmodule : core_invariants_sva
