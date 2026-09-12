//=============================================================================
// File: timer_apb.sv
// Description: 32-bit Timer with Compare Match, Prescaler, and APB Interface.
// Supports continuous up-counting, auto-reset, and interrupt generation.
//=============================================================================

`timescale 1ns/1ps

module timer_apb
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

  // Interrupt to INTC
  output logic        timer_irq
);

  // Register Offsets
  localparam logic [11:0] REG_COUNTER   = 12'h000;
  localparam logic [11:0] REG_COMPARE   = 12'h004;
  localparam logic [11:0] REG_CTRL      = 12'h008;
  localparam logic [11:0] REG_STATUS    = 12'h00C;
  localparam logic [11:0] REG_PRESCALER = 12'h010;

  logic [31:0] counter;
  logic [31:0] compare;
  logic [15:0] prescaler;
  logic [15:0] p_cnt;
  logic        ctrl_en, ctrl_auto_reset, ctrl_int_en;
  logic        status_match;

  assign pready    = 1'b1;
  assign pslverr   = 1'b0;
  assign timer_irq = status_match && ctrl_int_en;

  // Counter & Prescaler Engine
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      counter      <= 32'h0000_0000;
      compare      <= 32'hFFFF_FFFF;
      prescaler    <= 16'h0000;
      p_cnt        <= 16'h0000;
      ctrl_en      <= 1'b0;
      ctrl_auto_reset <= 1'b1;
      ctrl_int_en  <= 1'b0;
      status_match <= 1'b0;
    end else begin
      // Timer Counting Logic
      if (ctrl_en) begin
        if (p_cnt == prescaler) begin
          p_cnt <= 16'h0000;
          if (counter == compare) begin
            status_match <= 1'b1;
            if (ctrl_auto_reset) begin
              counter <= 32'h0000_0000;
            end else begin
              counter <= counter + 32'd1;
            end
          end else begin
            counter <= counter + 32'd1;
          end
        end else begin
          p_cnt <= p_cnt + 16'd1;
        end
      end

      // APB Write Register Access
      if (psel && penable && pwrite) begin
        case (paddr[11:0])
          REG_COUNTER:   counter   <= pwdata;
          REG_COMPARE:   compare   <= pwdata;
          REG_PRESCALER: prescaler <= pwdata[15:0];
          REG_CTRL: begin
            ctrl_en         <= pwdata[0];
            ctrl_auto_reset <= pwdata[1];
            ctrl_int_en     <= pwdata[2];
          end
          REG_STATUS: begin
            if (pwdata[0]) status_match <= 1'b0; // W1C
          end
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
        REG_COUNTER:   prdata = counter;
        REG_COMPARE:   prdata = compare;
        REG_CTRL:      prdata = {29'h0, ctrl_int_en, ctrl_auto_reset, ctrl_en};
        REG_STATUS:    prdata = {31'h0, status_match};
        REG_PRESCALER: prdata = {16'h0, prescaler};
        default:       prdata = 32'h0000_0000;
      endcase
    end
  end

endmodule : timer_apb
