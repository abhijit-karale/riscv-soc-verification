//=============================================================================
// File: rv32i_branch_unit.sv
// Description: RV32I Branch Decision Unit. Evaluates conditional branch
// conditions for BEQ, BNE, BLT, BGE, BLTU, and BGEU.
//=============================================================================

`timescale 1ns/1ps

module rv32i_branch_unit
  import soc_pkg::*;
(
  input  logic [31:0] op_a,
  input  logic [31:0] op_b,
  input  branch_op_e  branch_op,
  output logic        branch_taken
);

  always_comb begin
    case (branch_op)
      BR_BEQ:  branch_taken = (op_a == op_b);
      BR_BNE:  branch_taken = (op_a != op_b);
      BR_BLT:  branch_taken = ($signed(op_a) < $signed(op_b));
      BR_BGE:  branch_taken = ($signed(op_a) >= $signed(op_b));
      BR_BLTU: branch_taken = (op_a < op_b);
      BR_BGEU: branch_taken = (op_a >= op_b);
      default: branch_taken = 1'b0;
    endcase
  end

endmodule : rv32i_branch_unit
