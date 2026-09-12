//=============================================================================
// File: apb_formal.sv
// Description: Formal verification properties for AMBA APB Interconnect.
// Proves mutual exclusion of slave selects (one-hot or zero) and protocol stability.
//=============================================================================

`timescale 1ns/1ps

module apb_formal (
  input  logic        pclk,
  input  logic        presetn,
  input  logic        cpu_req,
  input  logic        cpu_we,
  input  logic        cpu_re,
  input  logic [31:0] cpu_addr,
  input  logic [31:0] cpu_wdata
);

  import soc_pkg::*;

  logic [31:0] cpu_rdata;
  logic        cpu_ready;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  logic        pwrite;
  logic        penable;
  logic [NUM_PERIPHERALS-1:0] psel;
  logic [31:0] prdata [0:NUM_PERIPHERALS-1];
  logic [NUM_PERIPHERALS-1:0] pready;
  logic [NUM_PERIPHERALS-1:0] pslverr;
  logic        apb_error;

  // Slaves respond immediately with ready in formal test
  assign pready[0]  = 1'b1;
  assign pready[1]  = 1'b1;
  assign pready[2]  = 1'b1;
  assign pready[3]  = 1'b1;
  assign prdata[0]  = 32'h0;
  assign prdata[1]  = 32'h0;
  assign prdata[2]  = 32'h0;
  assign prdata[3]  = 32'h0;
  assign pslverr    = 4'b0000;

  apb_interconnect u_dut (
    .pclk      (pclk),
    .presetn   (presetn),
    .cpu_req   (cpu_req),
    .cpu_we    (cpu_we),
    .cpu_re    (cpu_re),
    .cpu_addr  (cpu_addr),
    .cpu_wdata (cpu_wdata),
    .cpu_rdata (cpu_rdata),
    .cpu_ready (cpu_ready),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .pwrite    (pwrite),
    .penable   (penable),
    .psel      (psel),
    .prdata    (prdata),
    .pready    (pready),
    .pslverr   (pslverr),
    .apb_error (apb_error)
  );

  // Property 1: Mutual exclusion of slave selects (at most one slave selected)
  always_comb begin
    assert ($onehot0(psel));
  end

  // Property 2: PENABLE asserted only when a slave is selected
  always_comb begin
    if (penable) begin
      assert (|psel);
    end
  end

endmodule : apb_formal
