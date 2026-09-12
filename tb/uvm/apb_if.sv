//=============================================================================
// File: apb_if.sv
// Description: SystemVerilog Interface for AMBA APB Bus with clocking block.
//=============================================================================

`timescale 1ns/1ps

interface apb_if (input logic pclk, input logic presetn);
  import soc_pkg::*;

  logic [31:0]               paddr;
  logic [31:0]               pwdata;
  logic                      pwrite;
  logic                      penable;
  logic [NUM_PERIPHERALS-1:0] psel;
  logic [31:0]               prdata;
  logic                      pready;
  logic                      pslverr;

  // Modport for Driver
  modport drv_mp (
    input  pclk, presetn, prdata, pready, pslverr,
    output paddr, pwdata, pwrite, penable, psel
  );

  // Modport for Monitor
  modport mon_mp (
    input  pclk, presetn, paddr, pwdata, pwrite, penable, psel, prdata, pready, pslverr
  );

endinterface : apb_if
