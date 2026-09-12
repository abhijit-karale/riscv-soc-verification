//=============================================================================
// File: apb_interconnect.sv
// Description: AMBA APB Bridge and Peripheral Interconnect.
// Translates memory-mapped transactions into APB bus transfers and decodes
// addresses for 4 peripheral slaves: GPIO, UART, Timer, and INTC.
//=============================================================================

`timescale 1ns/1ps

module apb_interconnect
  import soc_pkg::*;
(
  input  logic        pclk,
  input  logic        presetn,

  // CPU Memory-Mapped Host Interface
  input  logic        cpu_req,        // Request flag (we || re)
  input  logic        cpu_we,         // Write enable
  input  logic        cpu_re,         // Read enable
  input  logic [31:0] cpu_addr,       // Transaction address
  input  logic [31:0] cpu_wdata,      // Write data
  output logic [31:0] cpu_rdata,      // Read data returned to CPU
  output logic        cpu_ready,      // Handshake complete

  // APB Master Bus Signals
  output logic [31:0] paddr,
  output logic [31:0] pwdata,
  output logic        pwrite,
  output logic        penable,

  // Slave Selects
  output logic [NUM_PERIPHERALS-1:0] psel,

  // Slave Response Multiplexing
  input  wire  [31:0] prdata [0:NUM_PERIPHERALS-1],
  input  logic [NUM_PERIPHERALS-1:0] pready,
  input  logic [NUM_PERIPHERALS-1:0] pslverr,

  output logic        apb_error
);

  apb_state_e state, next_state;
  logic [1:0] slave_sel;
  logic       valid_slave;

  // Peripheral Address Decoder
  // 0x4000_0000 - 0x4000_0FFF : GPIO  (Slave 0)
  // 0x4000_1000 - 0x4000_1FFF : UART  (Slave 1)
  // 0x4000_2000 - 0x4000_2FFF : Timer (Slave 2)
  // 0x4000_3000 - 0x4000_3FFF : INTC  (Slave 3)
  always_comb begin
    valid_slave = 1'b0;
    slave_sel   = 2'd0;

    if (cpu_addr[31:16] == 16'h4000) begin
      case (cpu_addr[15:12])
        4'h0: begin slave_sel = 2'd0; valid_slave = 1'b1; end // GPIO
        4'h1: begin slave_sel = 2'd1; valid_slave = 1'b1; end // UART
        4'h2: begin slave_sel = 2'd2; valid_slave = 1'b1; end // Timer
        4'h3: begin slave_sel = 2'd3; valid_slave = 1'b1; end // INTC
        default: begin valid_slave = 1'b0; end
      endcase
    end
  end

  // APB FSM State Transitions
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      state <= APB_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next State Logic & Control
  always_comb begin
    next_state = state;
    penable    = 1'b0;
    psel       = '0;
    paddr      = cpu_addr;
    pwdata     = cpu_wdata;
    pwrite     = cpu_we;
    cpu_ready  = 1'b0;
    cpu_rdata  = 32'h0000_0000;
    apb_error  = 1'b0;

    case (state)
      APB_IDLE: begin
        if (cpu_req && valid_slave) begin
          next_state = APB_SETUP;
        end else if (cpu_req && !valid_slave) begin
          // Unmapped memory address generates immediate error
          cpu_ready = 1'b1;
          apb_error = 1'b1;
        end
      end

      APB_SETUP: begin
        psel[slave_sel] = 1'b1;
        next_state      = APB_ACCESS;
      end

      APB_ACCESS: begin
        psel[slave_sel] = 1'b1;
        penable         = 1'b1;

        if (pready[slave_sel]) begin
          cpu_ready  = 1'b1;
          cpu_rdata  = prdata[slave_sel];
          apb_error  = pslverr[slave_sel];
          next_state = APB_IDLE;
        end
      end

      default: next_state = APB_IDLE;
    endcase
  end

endmodule : apb_interconnect
