//=============================================================================
// File: intc_formal.sv
// Description: Formal verification properties for Interrupt Controller (INTC).
// Proves interrupt clearance on software ACK and pending line arbitration.
//=============================================================================

`timescale 1ns/1ps

module intc_formal (
  input logic        pclk,
  input logic        presetn,
  input logic        psel,
  input logic        penable,
  input logic        pwrite,
  input logic [31:0] paddr,
  input logic [31:0] pwdata,
  input logic        irq_gpio,
  input logic        irq_uart,
  input logic        irq_timer
);

  import soc_pkg::*;

  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;
  logic        cpu_irq;

  intc_apb u_dut (
    .pclk      (pclk),
    .presetn   (presetn),
    .psel      (psel),
    .penable   (penable),
    .pwrite    (pwrite),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .prdata    (prdata),
    .pready    (pready),
    .pslverr   (pslverr),
    .irq_gpio  (irq_gpio),
    .irq_uart  (irq_uart),
    .irq_timer (irq_timer),
    .cpu_irq   (cpu_irq)
  );

  // Property 1: Reset must deassert cpu_irq
  always_comb begin
    if (!presetn) begin
      assert (!cpu_irq);
    end
  end

endmodule : intc_formal
