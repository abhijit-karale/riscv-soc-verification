//=============================================================================
// File: gpio_apb.sv
// Description: 8-bit Bidirectional Memory-Mapped GPIO with AMBA APB Interface.
// Includes configurable direction masks and edge-triggered pin change interrupts.
//=============================================================================

`timescale 1ns/1ps

module gpio_apb
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

  // External IO Pins
  input  logic [7:0]  gpio_in,
  output logic [7:0]  gpio_out,
  output logic [7:0]  gpio_oe,

  // Interrupt to INTC
  output logic        gpio_irq
);

  // Register Offsets
  localparam logic [11:0] REG_DATA_IN    = 12'h000;
  localparam logic [11:0] REG_DATA_OUT   = 12'h004;
  localparam logic [11:0] REG_DIR        = 12'h008;
  localparam logic [11:0] REG_INT_EN     = 12'h00C;
  localparam logic [11:0] REG_INT_STATUS = 12'h010;

  logic [7:0] reg_data_out;
  logic [7:0] reg_dir;
  logic [7:0] reg_int_en;
  logic [7:0] reg_int_status;

  logic [7:0] gpio_in_sync0, gpio_in_sync1, gpio_in_prev;
  logic [7:0] pin_toggle_event;

  // Single-cycle zero-wait-state slave
  assign pready  = 1'b1;
  assign pslverr = 1'b0;

  assign gpio_out = reg_data_out;
  assign gpio_oe  = reg_dir;
  assign gpio_irq = |(reg_int_status & reg_int_en);

  // Synchronize external input pins to PCLK
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      gpio_in_sync0 <= 8'h00;
      gpio_in_sync1 <= 8'h00;
      gpio_in_prev  <= 8'h00;
    end else begin
      gpio_in_sync0 <= gpio_in;
      gpio_in_sync1 <= gpio_in_sync0;
      gpio_in_prev  <= gpio_in_sync1;
    end
  end

  // Pin change toggle detector
  assign pin_toggle_event = gpio_in_sync1 ^ gpio_in_prev;

  // APB Write Handling
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      reg_data_out   <= 8'h00;
      reg_dir        <= 8'h00;
      reg_int_en     <= 8'h00;
      reg_int_status <= 8'h00;
    end else begin
      // Latch toggle events into interrupt status
      reg_int_status <= reg_int_status | (pin_toggle_event & reg_int_en);

      // Bus write handling
      if (psel && penable && pwrite) begin
        case (paddr[11:0])
          REG_DATA_OUT:   reg_data_out   <= pwdata[7:0];
          REG_DIR:        reg_dir        <= pwdata[7:0];
          REG_INT_EN:     reg_int_en     <= pwdata[7:0];
          REG_INT_STATUS: reg_int_status <= reg_int_status & ~pwdata[7:0]; // Write-1-to-Clear
          default: ;
        endcase
      end
    end
  end

  // APB Read Handling
  always_comb begin
    prdata = 32'h0000_0000;
    if (psel && !pwrite) begin
      case (paddr[11:0])
        REG_DATA_IN:    prdata = {24'h0, gpio_in_sync1};
        REG_DATA_OUT:   prdata = {24'h0, reg_data_out};
        REG_DIR:        prdata = {24'h0, reg_dir};
        REG_INT_EN:     prdata = {24'h0, reg_int_en};
        REG_INT_STATUS: prdata = {24'h0, reg_int_status};
        default:        prdata = 32'h0000_0000;
      endcase
    end
  end

endmodule : gpio_apb
