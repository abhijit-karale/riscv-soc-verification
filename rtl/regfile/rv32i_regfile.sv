//=============================================================================
// File: rv32i_regfile.sv
// Description: Synthesizable 32-entry x 32-bit Register File for RV32I Core.
// Supports dual asynchronous read ports, single synchronous write port,
// write-to-read internal forwarding, and hardwired x0 = 0.
//=============================================================================

`timescale 1ns/1ps

module rv32i_regfile #(
  parameter bit FORWARDING = 0
)(
  input  logic        clk,
  input  logic        rst_n,

  // Read Port 1
  input  logic [4:0]  rs1_addr,
  output logic [31:0] rs1_data,

  // Read Port 2
  input  logic [4:0]  rs2_addr,
  output logic [31:0] rs2_data,

  // Write Port
  input  logic        wr_en,
  input  logic [4:0]  rd_addr,
  input  logic [31:0] rd_data
);

  // 32 General-Purpose 32-bit Registers
  logic [31:0] rf [0:31];

  // Synchronous Write Operation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 32; i++) begin
        rf[i] <= 32'h0000_0000;
      end
    end else if (wr_en && (rd_addr != 5'd0)) begin
      rf[rd_addr] <= rd_data;
    end
  end

  // Asynchronous Read with x0=0 check and optional write-forwarding bypass
  always_comb begin
    // Port 1 Read Logic
    if (rs1_addr == 5'd0) begin
      rs1_data = 32'h0000_0000;
    end else if (FORWARDING && wr_en && (rd_addr == rs1_addr)) begin
      rs1_data = rd_data; // Forwarding enabled
    end else begin
      rs1_data = rf[rs1_addr];
    end

    // Port 2 Read Logic
    if (rs2_addr == 5'd0) begin
      rs2_data = 32'h0000_0000;
    end else if (FORWARDING && wr_en && (rd_addr == rs2_addr)) begin
      rs2_data = rd_data; // Forwarding enabled
    end else begin
      rs2_data = rf[rs2_addr];
    end
  end

endmodule : rv32i_regfile
