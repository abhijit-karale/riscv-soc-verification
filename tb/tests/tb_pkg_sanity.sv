//=============================================================================
// File: tb_pkg_sanity.sv
// Description: Sanity testbench verifying architectural definitions in soc_pkg.sv.
//=============================================================================

`timescale 1ns/1ps

module tb_pkg_sanity;
  import soc_pkg::*;

  int error_count = 0;

  initial begin
    $display("=========================================================");
    $display("       DAY 1: RV32I SoC Architectural Sanity Check       ");
    $display("=========================================================");

    // Verify Memory Map Addresses
    $display("[CHECK] Checking Memory Map Base Addresses...");
    if (SRAM_BASE_ADDR !== 32'h0000_0000) begin
      $display("[ERROR] SRAM_BASE_ADDR mismatch!");
      error_count++;
    end
    if (GPIO_BASE_ADDR !== 32'h4000_0000) begin
      $display("[ERROR] GPIO_BASE_ADDR mismatch!");
      error_count++;
    end
    if (UART_BASE_ADDR !== 32'h4000_1000) begin
      $display("[ERROR] UART_BASE_ADDR mismatch!");
      error_count++;
    end
    if (TIMER_BASE_ADDR !== 32'h4000_2000) begin
      $display("[ERROR] TIMER_BASE_ADDR mismatch!");
      error_count++;
    end
    if (INTC_BASE_ADDR !== 32'h4000_3000) begin
      $display("[ERROR] INTC_BASE_ADDR mismatch!");
      error_count++;
    end

    // Verify Opcode Encodings
    $display("[CHECK] Checking RV32I Opcode Encodings...");
    if (OPCODE_R_TYPE !== 7'b0110011) begin
      $display("[ERROR] OPCODE_R_TYPE mismatch!");
      error_count++;
    end
    if (OPCODE_LOAD !== 7'b0000011) begin
      $display("[ERROR] OPCODE_LOAD mismatch!");
      error_count++;
    end
    if (OPCODE_STORE !== 7'b0100011) begin
      $display("[ERROR] OPCODE_STORE mismatch!");
      error_count++;
    end
    if (OPCODE_BRANCH !== 7'b1100011) begin
      $display("[ERROR] OPCODE_BRANCH mismatch!");
      error_count++;
    end

    // Final Report
    $display("---------------------------------------------------------");
    if (error_count == 0) begin
      $display("[RESULT] PASS: All Day 1 Architectural Definitions Verified.");
    end else begin
      $display("[RESULT] FAIL: Found %0d architectural definition errors!", error_count);
    end
    $display("=========================================================");
    $finish;
  end

endmodule
