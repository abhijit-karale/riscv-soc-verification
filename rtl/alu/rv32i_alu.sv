 //=============================================================================
// File: rv32i_alu.sv
// Description: Synthesizable 32-bit Arithmetic Logic Unit (ALU) for RV32I Core.
// Implements all standard RV32I computational operations and ALU_PASS.
//=============================================================================

`timescale 1ns/1ps

module rv32i_alu
  import soc_pkg::*;
(
  input  logic [31:0]   op_a,    // First operand (rs1)
  input  logic [31:0]   op_b,    // Second operand (rs2 or immediate)
  input  alu_op_e       alu_op,  // ALU operation select
  output logic [31:0]   result,  // 32-bit computation result
  output logic          zero     // Asserted high when result == 32'h0000_0000
);

  // Shift amount is strictly the lower 5 bits of op_b in RV32I
  logic [4:0] shamt;
  assign shamt = op_b[4:0];

  // Combinational ALU Datapath
  always_comb begin
    case (alu_op)
      ALU_ADD: begin
        result = op_a + op_b;
      end

      ALU_SUB: begin
        result = op_a - op_b;
      end

      ALU_SLL: begin
        result = op_a << shamt;
      end

      ALU_SLT: begin
        // Signed comparison: 1 if op_a < op_b, else 0
        result = ($signed(op_a) < $signed(op_b)) ? 32'd1 : 32'd0;
      end

      ALU_SLTU: begin
        // Unsigned comparison: 1 if op_a < op_b, else 0
        result = (op_a < op_b) ? 32'd1 : 32'd0;
      end

      ALU_XOR: begin
        result = op_a ^ op_b;
      end

      ALU_SRL: begin
        // Logical right shift (zero-extended)
        result = op_a >> shamt;
      end

      ALU_SRA: begin
        // Arithmetic right shift (sign-extended)
        result = $signed(op_a) >>> shamt;
      end

      ALU_OR: begin
        result = op_a | op_b;
      end

      ALU_AND: begin
        result = op_a & op_b;
      end

      ALU_PASS: begin
        // Direct pass-through of op_b (used for LUI / bypass)
        result = op_b;
      end

      default: begin
        result = 32'h0000_0000;
      end
    endcase
  end

  // Zero flag generation: true when all 32 bits of result are 0
  assign zero = (result == 32'h0000_0000);

endmodule : rv32i_alu
