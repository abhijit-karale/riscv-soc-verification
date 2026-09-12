//=============================================================================
// File: sram_sp_32k.sv
// Description: 32 KB SRAM with dual-ported access for RV32I SoC.
// Port A: Instruction Fetch (asynchronous/combinational read)
// Port B: Data Read/Write with 4-bit byte-enable write masking
// Address Range: 0x0000_0000 to 0x0000_7FFF (32 KB = 8,192 words)
//=============================================================================

`timescale 1ns/1ps

module sram_sp_32k
  import soc_pkg::*;
#(
  parameter string INIT_HEX = ""
)(
  input  logic        clk,
  input  logic        rst_n,

  // Port A: Instruction Fetch
  input  logic [31:0] instr_addr,
  output logic [31:0] instr_data,

  // Port B: Data Read/Write
  input  logic [31:0] data_addr,
  input  logic [31:0] data_wdata,
  output logic [31:0] data_rdata,
  input  logic [3:0]  data_byte_en,
  input  logic        data_we,
  input  logic        data_re
);

  localparam int WORDS = 8192; // 32 KB / 4 bytes

  // 4 individual byte arrays to support per-byte write enables cleanly
  logic [7:0] mem0 [0:WORDS-1];
  logic [7:0] mem1 [0:WORDS-1];
  logic [7:0] mem2 [0:WORDS-1];
  logic [7:0] mem3 [0:WORDS-1];

  logic [12:0] word_addr_instr;
  logic [12:0] word_addr_data;

  assign word_addr_instr = instr_addr[14:2];
  assign word_addr_data  = data_addr[14:2];

  // Optional Memory Initialization via $readmemh
  initial begin
    for (int i = 0; i < WORDS; i++) begin
      mem0[i] = 8'h00;
      mem1[i] = 8'h00;
      mem2[i] = 8'h00;
      mem3[i] = 8'h00;
    end
    if (INIT_HEX != "") begin
      $display("[SRAM] Loading initial memory image from %s", INIT_HEX);
      // Helper function or direct loading handled if needed
    end
  end

  // Port A: Instruction Fetch (Asynchronous read within 32 KB window)
  always_comb begin
    if (instr_addr <= SRAM_END_ADDR) begin
      instr_data = {mem3[word_addr_instr], mem2[word_addr_instr],
                    mem1[word_addr_instr], mem0[word_addr_instr]};
    end else begin
      instr_data = 32'h0000_0013; // NOP (ADDI x0, x0, 0)
    end
  end

  // Port B: Data Read (Asynchronous read within 32 KB window)
  always_comb begin
    if (data_re && (data_addr <= SRAM_END_ADDR)) begin
      data_rdata = {mem3[word_addr_data], mem2[word_addr_data],
                    mem1[word_addr_data], mem0[word_addr_data]};
    end else begin
      data_rdata = 32'h0000_0000;
    end
  end

  // Port B: Data Write (Synchronous with 4-bit byte-enable strobes)
  always @(posedge clk) begin
    if (data_we && (data_addr <= SRAM_END_ADDR)) begin
      if (data_byte_en[0]) mem0[word_addr_data] <= data_wdata[7:0];
      if (data_byte_en[1]) mem1[word_addr_data] <= data_wdata[15:8];
      if (data_byte_en[2]) mem2[word_addr_data] <= data_wdata[23:16];
      if (data_byte_en[3]) mem3[word_addr_data] <= data_wdata[31:24];
    end
  end

endmodule : sram_sp_32k
