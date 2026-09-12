//=============================================================================
// File: intc_apb.sv
// Description: Prioritized Interrupt Controller (INTC) with APB Interface.
// Aggregates peripheral interrupts from GPIO, UART, and Timer, provides
// masking, pending status, priority arbitration, and software ACK handshake.
//=============================================================================

`timescale 1ns/1ps

module intc_apb
  import soc_pkg::*;
(
  input  logic        pclk,
  input  logic        presetn,

  // APB Slave Interface
  input  logic        psel,
  input  logic        penable,
  input  logic        pwrite,
  input  logic [31:0] paddr,
  input  logic [31:0] pwdata,
  output logic [31:0] prdata,
  output logic        pready,
  output logic        pslverr,

  // Peripheral Interrupt Inputs
  input  logic        irq_gpio,   // Source 0
  input  logic        irq_uart,   // Source 1
  input  logic        irq_timer,  // Source 2

  // Output to Core
  output logic        cpu_irq
);

  // Register Offsets
  localparam logic [11:0] REG_RAW_STATUS = 12'h000;
  localparam logic [11:0] REG_ENABLE     = 12'h004;
  localparam logic [11:0] REG_PENDING    = 12'h008;
  localparam logic [11:0] REG_PRIORITY   = 12'h00C;
  localparam logic [11:0] REG_ACK        = 12'h010;

  logic [2:0] raw_status;
  logic [2:0] enable;
  logic [2:0] pending;
  logic [5:0] priority_cfg;

  assign raw_status = {irq_timer, irq_uart, irq_gpio};
  assign pready     = 1'b1;
  assign pslverr    = 1'b0;
  assign cpu_irq    = |pending;

  // Latch pending interrupts and handle software ACK
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      pending      <= 3'b000;
      enable       <= 3'b000;
      priority_cfg <= 6'b10_01_00; // Default priorities (Timer > UART > GPIO)
    end else begin
      // Latch new incoming enabled interrupts
      pending <= (pending | (raw_status & enable));

      // APB Write Register Access
      if (psel && penable && pwrite) begin
        case (paddr[11:0])
          REG_ENABLE:   enable       <= pwdata[2:0];
          REG_PRIORITY: priority_cfg <= pwdata[5:0];
          REG_ACK:      pending      <= pending & ~pwdata[2:0]; // Clear acknowledged bits
          default: ;
        endcase
      end
    end
  end

  // APB Read Multiplexing
  always_comb begin
    prdata = 32'h0000_0000;
    if (psel && !pwrite) begin
      case (paddr[11:0])
        REG_RAW_STATUS: prdata = {29'h0, raw_status};
        REG_ENABLE:     prdata = {29'h0, enable};
        REG_PENDING:    prdata = {29'h0, pending};
        REG_PRIORITY:   prdata = {26'h0, priority_cfg};
        default:        prdata = 32'h0000_0000;
      endcase
    end
  end

endmodule : intc_apb
