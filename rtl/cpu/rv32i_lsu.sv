//=============================================================================
// File: rv32i_lsu.sv
// Description: RV32I Load-Store Unit (LSU).
// Handles data formatting, byte lane alignment, sign extension for loads
// (LB, LH, LW, LBU, LHU), byte-enable generation for stores (SB, SH, SW),
// and misaligned address detection.
//=============================================================================

`timescale 1ns/1ps

module rv32i_lsu
  import soc_pkg::*;
(
  input  logic [31:0]  addr,            // Memory address
  input  logic [31:0]  wr_data,         // Raw store data from rs2
  input  mem_width_e   mem_width,       // Access width (BYTE, HALF, WORD, etc.)
  input  logic [31:0]  raw_rdata,       // Raw 32-bit word read from memory

  output logic [31:0]  formatted_rdata, // Sign/zero-extended data for CPU
  output logic [31:0]  formatted_wdata, // Byte-aligned store data for memory
  output logic [3:0]   byte_enable,     // 4-bit byte-enable write mask
  output logic         align_error      // Misaligned access flag
);

  logic [1:0] byte_offset;
  assign byte_offset = addr[1:0];

  // Store Formatting and Byte-Enable Generation
  always_comb begin
    align_error     = 1'b0;
    byte_enable     = 4'b0000;
    formatted_wdata = 32'h0000_0000;

    case (mem_width)
      MEM_BYTE, MEM_BYTEU: begin // Store Byte (SB)
        case (byte_offset)
          2'b00: begin
            byte_enable     = 4'b0001;
            formatted_wdata = {24'h0, wr_data[7:0]};
          end
          2'b01: begin
            byte_enable     = 4'b0010;
            formatted_wdata = {16'h0, wr_data[7:0], 8'h0};
          end
          2'b10: begin
            byte_enable     = 4'b0100;
            formatted_wdata = {8'h0, wr_data[7:0], 16'h0};
          end
          2'b11: begin
            byte_enable     = 4'b1000;
            formatted_wdata = {wr_data[7:0], 24'h0};
          end
        endcase
      end

      MEM_HALF, MEM_HALFU: begin // Store Halfword (SH)
        if (byte_offset[0] != 1'b0) begin
          align_error = 1'b1;
        end
        if (byte_offset[1] == 1'b0) begin
          byte_enable     = 4'b0011;
          formatted_wdata = {16'h0, wr_data[15:0]};
        end else begin
          byte_enable     = 4'b1100;
          formatted_wdata = {wr_data[15:0], 16'h0};
        end
      end

      MEM_WORD: begin // Store Word (SW)
        if (byte_offset != 2'b00) begin
          align_error = 1'b1;
        end
        byte_enable     = 4'b1111;
        formatted_wdata = wr_data;
      end

      default: begin
        byte_enable     = 4'b0000;
        formatted_wdata = 32'h0;
      end
    endcase
  end

  // Load Formatting and Sign Extension
  always_comb begin
    formatted_rdata = 32'h0000_0000;

    case (mem_width)
      MEM_BYTE: begin // LB: Sign-extended byte
        case (byte_offset)
          2'b00: formatted_rdata = {{24{raw_rdata[7]}},  raw_rdata[7:0]};
          2'b01: formatted_rdata = {{24{raw_rdata[15]}}, raw_rdata[15:8]};
          2'b10: formatted_rdata = {{24{raw_rdata[23]}}, raw_rdata[23:16]};
          2'b11: formatted_rdata = {{24{raw_rdata[31]}}, raw_rdata[31:24]};
        endcase
      end

      MEM_BYTEU: begin // LBU: Zero-extended byte
        case (byte_offset)
          2'b00: formatted_rdata = {24'h0, raw_rdata[7:0]};
          2'b01: formatted_rdata = {24'h0, raw_rdata[15:8]};
          2'b10: formatted_rdata = {24'h0, raw_rdata[23:16]};
          2'b11: formatted_rdata = {24'h0, raw_rdata[31:24]};
        endcase
      end

      MEM_HALF: begin // LH: Sign-extended halfword
        if (byte_offset[1] == 1'b0) begin
          formatted_rdata = {{16{raw_rdata[15]}}, raw_rdata[15:0]};
        end else begin
          formatted_rdata = {{16{raw_rdata[31]}}, raw_rdata[31:16]};
        end
      end

      MEM_HALFU: begin // LHU: Zero-extended halfword
        if (byte_offset[1] == 1'b0) begin
          formatted_rdata = {16'h0, raw_rdata[15:0]};
        end else begin
          formatted_rdata = {16'h0, raw_rdata[31:16]};
        end
      end

      MEM_WORD: begin // LW: Full word
        formatted_rdata = raw_rdata;
      end

      default: begin
        formatted_rdata = raw_rdata;
      end
    endcase
  end

endmodule : rv32i_lsu
