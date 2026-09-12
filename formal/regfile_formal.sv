//=============================================================================
// File: regfile_formal.sv
// Description: Formal verification property module for RV32I Register File.
// Proves x0 hardwired-to-zero invariance and write-through forwarding.
//=============================================================================

`timescale 1ns/1ps

module regfile_formal (
  input logic        clk,
  input logic        rst_n,
  input logic [4:0]  rs1_addr,
  input logic [4:0]  rs2_addr,
  input logic        wr_en,
  input logic [4:0]  rd_addr,
  input logic [31:0] rd_data
);

  logic [31:0] rs1_data;
  logic [31:0] rs2_data;

  // DUT Instance
  rv32i_regfile u_dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .rs1_addr (rs1_addr),
    .rs1_data (rs1_data),
    .rs2_addr (rs2_addr),
    .rs2_data (rs2_data),
    .wr_en    (wr_en),
    .rd_addr  (rd_addr),
    .rd_data  (rd_data)
  );

  // Formal Assumptions
  always_comb begin
    if (!rst_n) begin
      assume (wr_en == 1'b0);
    end
  end

  // Formal Assertions
  always_comb begin
    // Invariant 1: Register x0 always reads 0 on Port 1
    if (rs1_addr == 5'd0) begin
      assert (rs1_data == 32'h0000_0000);
    end

    // Invariant 2: Register x0 always reads 0 on Port 2
    if (rs2_addr == 5'd0) begin
      assert (rs2_data == 32'h0000_0000);
    end

    // Invariant 3: Write-to-read forwarding transparency
    if (wr_en && (rd_addr != 5'd0) && (rd_addr == rs1_addr)) begin
      assert (rs1_data == rd_data);
    end
    if (wr_en && (rd_addr != 5'd0) && (rd_addr == rs2_addr)) begin
      assert (rs2_data == rd_data);
    end
  end

endmodule : regfile_formal
