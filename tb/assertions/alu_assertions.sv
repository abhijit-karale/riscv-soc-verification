//=============================================================================
// File: alu_assertions.sv
// Description: SystemVerilog Assertions (SVA) protocol and correctness checker
// for the RV32I ALU. Verifies arithmetic invariants, zero flag integrity,
// and unknown propagation.
//=============================================================================

`timescale 1ns/1ps

module alu_assertions
  import soc_pkg::*;
(
  input logic        clk,
  input logic [31:0] op_a,
  input logic [31:0] op_b,
  input alu_op_e     alu_op,
  input logic [31:0] result,
  input logic        zero
);

  //---------------------------------------------------------------------------
  // 1. Zero Flag Invariance Property
  // Zero flag MUST be high if and only if result is 32'h0000_0000
  //---------------------------------------------------------------------------
  property p_zero_flag_exact;
    @(posedge clk)
    (zero === (result == 32'h0000_0000));
  endproperty
  a_zero_flag_exact: assert property (p_zero_flag_exact)
    else $error("[SVA FAIL] ALU Zero flag mismatch! result=0x%08h, zero=%b", result, zero);

  //---------------------------------------------------------------------------
  // 2. Additive Identity: A + 0 = A
  //---------------------------------------------------------------------------
  property p_add_zero_identity;
    @(posedge clk)
    (alu_op == ALU_ADD && op_b == 32'h0000_0000) |-> (result == op_a);
  endproperty
  a_add_zero_identity: assert property (p_add_zero_identity)
    else $error("[SVA FAIL] A + 0 != A: op_a=0x%08h, result=0x%08h", op_a, result);

  //---------------------------------------------------------------------------
  // 3. Subtractive Self-Identity: A - A = 0
  //---------------------------------------------------------------------------
  property p_sub_self_identity;
    @(posedge clk)
    (alu_op == ALU_SUB && op_a == op_b) |-> (result == 32'h0000_0000 && zero == 1'b1);
  endproperty
  a_sub_self_identity: assert property (p_sub_self_identity)
    else $error("[SVA FAIL] A - A != 0: op_a=0x%08h, result=0x%08h", op_a, result);

  //---------------------------------------------------------------------------
  // 4. Bitwise Self-XOR: A ^ A = 0
  //---------------------------------------------------------------------------
  property p_xor_self_identity;
    @(posedge clk)
    (alu_op == ALU_XOR && op_a == op_b) |-> (result == 32'h0000_0000 && zero == 1'b1);
  endproperty
  a_xor_self_identity: assert property (p_xor_self_identity)
    else $error("[SVA FAIL] A ^ A != 0: op_a=0x%08h, result=0x%08h", op_a, result);

  //---------------------------------------------------------------------------
  // 5. Bitwise Self-AND / Self-OR Idempotence: A & A = A, A | A = A
  //---------------------------------------------------------------------------
  property p_and_self_idempotence;
    @(posedge clk)
    (alu_op == ALU_AND && op_a == op_b) |-> (result == op_a);
  endproperty
  a_and_self_idempotence: assert property (p_and_self_idempotence)
    else $error("[SVA FAIL] A & A != A: op_a=0x%08h, result=0x%08h", op_a, result);

  property p_or_self_idempotence;
    @(posedge clk)
    (alu_op == ALU_OR && op_a == op_b) |-> (result == op_a);
  endproperty
  a_or_self_idempotence: assert property (p_or_self_idempotence)
    else $error("[SVA FAIL] A | A != A: op_a=0x%08h, result=0x%08h", op_a, result);

  //---------------------------------------------------------------------------
  // 6. ALU_PASS Pass-through: result = op_b
  //---------------------------------------------------------------------------
  property p_pass_through;
    @(posedge clk)
    (alu_op == ALU_PASS) |-> (result == op_b);
  endproperty
  a_pass_through: assert property (p_pass_through)
    else $error("[SVA FAIL] ALU_PASS mismatch: op_b=0x%08h, result=0x%08h", op_b, result);

  //---------------------------------------------------------------------------
  // 7. No Unknown Values Propagated
  //---------------------------------------------------------------------------
  property p_no_unknown_propagation;
    @(posedge clk)
    (!$isunknown({op_a, op_b, alu_op})) |-> (!$isunknown({result, zero}));
  endproperty
  a_no_unknown_propagation: assert property (p_no_unknown_propagation)
    else $error("[SVA FAIL] Unknown (X/Z) detected at ALU outputs while inputs are known!");

endmodule : alu_assertions
