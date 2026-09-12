//=============================================================================
// File: uart_apb.sv
// Description: 8-N-1 UART Peripheral with AMBA APB Interface.
// Includes internal baud rate generator, TX/RX shift registers, status flags,
// loopback mode, and interrupt generation.
//=============================================================================

`timescale 1ns/1ps

module uart_apb
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

  // Serial IO
  input  logic        uart_rx,
  output logic        uart_tx,

  // Interrupt to INTC
  output logic        uart_irq
);

  // Register Offsets
  localparam logic [11:0] REG_TX_DATA  = 12'h000;
  localparam logic [11:0] REG_RX_DATA  = 12'h004;
  localparam logic [11:0] REG_STATUS   = 12'h008;
  localparam logic [11:0] REG_CTRL     = 12'h00C;
  localparam logic [11:0] REG_BAUD_DIV = 12'h010;

  // Internal Registers
  logic [7:0]  rx_buffer;
  logic [7:0]  tx_buffer;
  logic [15:0] baud_div;
  logic        ctrl_tx_en, ctrl_rx_en, ctrl_loopback, ctrl_int_en;
  logic        status_tx_busy, status_rx_valid;

  // Transmitter state machine
  typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_e;
  tx_state_e tx_state;
  logic [15:0] tx_baud_cnt;
  logic [2:0]  tx_bit_idx;
  logic [7:0]  tx_shift_reg;
  logic        tx_serial_out;

  // Receiver state machine
  typedef enum logic [1:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP} rx_state_e;
  rx_state_e rx_state;
  logic [15:0] rx_baud_cnt;
  logic [2:0]  rx_bit_idx;
  logic [7:0]  rx_shift_reg;
  logic        rx_serial_in;

  assign pready  = 1'b1;
  assign pslverr = 1'b0;

  // Loopback multiplexer
  assign rx_serial_in = (ctrl_loopback) ? tx_serial_out : uart_rx;
  assign uart_tx      = tx_serial_out;
  assign uart_irq     = ctrl_int_en && (status_rx_valid || (!status_tx_busy));

  // Transmitter Logic
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      tx_state       <= TX_IDLE;
      tx_serial_out  <= 1'b1; // Mark state (high)
      tx_baud_cnt    <= '0;
      tx_bit_idx     <= '0;
      tx_shift_reg   <= '0;
      status_tx_busy <= 1'b0;
    end else begin
      case (tx_state)
        TX_IDLE: begin
          tx_serial_out  <= 1'b1;
          status_tx_busy <= 1'b0;
          if (psel && penable && pwrite && (paddr[11:0] == REG_TX_DATA) && ctrl_tx_en) begin
            tx_shift_reg   <= pwdata[7:0];
            status_tx_busy <= 1'b1;
            tx_baud_cnt    <= (baud_div > 0) ? baud_div : 16'd4;
            tx_state       <= TX_START;
          end
        end

        TX_START: begin
          tx_serial_out <= 1'b0; // Start bit
          if (tx_baud_cnt == 0) begin
            tx_baud_cnt <= (baud_div > 0) ? baud_div : 16'd4;
            tx_bit_idx  <= 3'd0;
            tx_state    <= TX_DATA;
          end else begin
            tx_baud_cnt <= tx_baud_cnt - 1;
          end
        end

        TX_DATA: begin
          tx_serial_out <= tx_shift_reg[tx_bit_idx];
          if (tx_baud_cnt == 0) begin
            tx_baud_cnt <= (baud_div > 0) ? baud_div : 16'd4;
            if (tx_bit_idx == 3'd7) begin
              tx_state <= TX_STOP;
            end else begin
              tx_bit_idx <= tx_bit_idx + 1;
            end
          end else begin
            tx_baud_cnt <= tx_baud_cnt - 1;
          end
        end

        TX_STOP: begin
          tx_serial_out <= 1'b1; // Stop bit
          if (tx_baud_cnt == 0) begin
            status_tx_busy <= 1'b0;
            tx_state       <= TX_IDLE;
          end else begin
            tx_baud_cnt <= tx_baud_cnt - 1;
          end
        end
      endcase
    end
  end

  // Receiver Logic
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      rx_state        <= RX_IDLE;
      rx_baud_cnt     <= '0;
      rx_bit_idx      <= '0;
      rx_shift_reg    <= '0;
      rx_buffer       <= '0;
      status_rx_valid <= 1'b0;
    end else begin
      // Clear valid flag on reading RX_DATA
      if (psel && penable && !pwrite && (paddr[11:0] == REG_RX_DATA)) begin
        status_rx_valid <= 1'b0;
      end

      case (rx_state)
        RX_IDLE: begin
          if (ctrl_rx_en && !rx_serial_in) begin // Detect start bit falling edge
            rx_baud_cnt <= (baud_div > 0) ? (baud_div / 2) : 16'd2; // Sample mid-bit
            rx_state    <= RX_START;
          end
        end

        RX_START: begin
          if (rx_baud_cnt == 0) begin
            if (!rx_serial_in) begin // Verify start bit still low
              rx_baud_cnt <= (baud_div > 0) ? baud_div : 16'd4;
              rx_bit_idx  <= 3'd0;
              rx_state    <= RX_DATA;
            end else begin
              rx_state <= RX_IDLE; // False start
            end
          end else begin
            rx_baud_cnt <= rx_baud_cnt - 1;
          end
        end

        RX_DATA: begin
          if (rx_baud_cnt == 0) begin
            rx_shift_reg[rx_bit_idx] <= rx_serial_in;
            rx_baud_cnt <= (baud_div > 0) ? baud_div : 16'd4;
            if (rx_bit_idx == 3'd7) begin
              rx_state <= RX_STOP;
            end else begin
              rx_bit_idx <= rx_bit_idx + 1;
            end
          end else begin
            rx_baud_cnt <= rx_baud_cnt - 1;
          end
        end

        RX_STOP: begin
          if (rx_baud_cnt == 0) begin
            if (rx_serial_in) begin // Stop bit is high
              rx_buffer       <= rx_shift_reg;
              status_rx_valid <= 1'b1;
            end
            rx_state <= RX_IDLE;
          end else begin
            rx_baud_cnt <= rx_baud_cnt - 1;
          end
        end
      endcase
    end
  end

  // APB Write Register Configuration
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      ctrl_tx_en    <= 1'b1; // Default enabled
      ctrl_rx_en    <= 1'b1;
      ctrl_loopback <= 1'b0;
      ctrl_int_en   <= 1'b0;
      baud_div      <= 16'd4; // Fast default for sim
    end else if (psel && penable && pwrite) begin
      case (paddr[11:0])
        REG_CTRL: begin
          ctrl_tx_en    <= pwdata[0];
          ctrl_rx_en    <= pwdata[1];
          ctrl_loopback <= pwdata[2];
          ctrl_int_en   <= pwdata[3];
        end
        REG_BAUD_DIV: begin
          baud_div <= pwdata[15:0];
        end
        default: ;
      endcase
    end
  end

  // APB Read Multiplexing
  always_comb begin
    prdata = 32'h0000_0000;
    if (psel && !pwrite) begin
      case (paddr[11:0])
        REG_RX_DATA:  prdata = {24'h0, rx_buffer};
        REG_STATUS:   prdata = {29'h0, (!status_tx_busy), status_rx_valid, status_tx_busy};
        REG_CTRL:     prdata = {28'h0, ctrl_int_en, ctrl_loopback, ctrl_rx_en, ctrl_tx_en};
        REG_BAUD_DIV: prdata = {16'h0, baud_div};
        default:      prdata = 32'h0000_0000;
      endcase
    end
  end

endmodule : uart_apb
