//=============================================================================
// File: tb_pkg_sanity.sv
// Description: Day 1 Architectural Package Sanity and Self-Checking Testbench.
// Validates memory map boundary non-overlap, enum values, and width parameters.
//=============================================================================

`timescale 1ns/1ps

module tb_pkg_sanity;
  import soc_pkg::*;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  task check_cond(string name, bit cond);
    test_count++;
    if (cond) begin
      $display("[PASS] %s", name);
      pass_count++;
    end else begin
      $display("[FAIL] %s", name);
      error_count++;
    end
  endtask

  initial begin
    $display("=================================================================");
    $display("       DAY 1: RV32I SoC Package Sanity & Memory Map Test         ");
    $display("=================================================================");

    // 1. Memory Map Bounds & Non-overlap Checks
    check_cond("SRAM Base Address is 0x0000_0000", SRAM_BASE_ADDR == 32'h0000_0000);
    check_cond("SRAM Size is 32 KB", SRAM_SIZE == 32'h0000_8000);
    check_cond("SRAM End Address is 0x0000_7FFF", SRAM_END_ADDR == 32'h0000_7FFF);

    check_cond("GPIO Base is 0x4000_0000", GPIO_BASE_ADDR == 32'h4000_0000);
    check_cond("UART Base is 0x4000_1000", UART_BASE_ADDR == 32'h4000_1000);
    check_cond("Timer Base is 0x4000_2000", TIMER_BASE_ADDR == 32'h4000_2000);
    check_cond("INTC Base is 0x4000_3000", INTC_BASE_ADDR == 32'h4000_3000);

    check_cond("GPIO doesn't overlap UART", (GPIO_BASE_ADDR + GPIO_SIZE) <= UART_BASE_ADDR);
    check_cond("UART doesn't overlap Timer", (UART_BASE_ADDR + UART_SIZE) <= TIMER_BASE_ADDR);
    check_cond("Timer doesn't overlap INTC", (TIMER_BASE_ADDR + TIMER_SIZE) <= INTC_BASE_ADDR);
    check_cond("SRAM doesn't overlap Peripherals", SRAM_END_ADDR < APB_BASE_ADDR);

    // 2. Opcode Definitions Check
    check_cond("OPCODE_R_TYPE == 7'b0110011", OPCODE_R_TYPE == 7'b0110011);
    check_cond("OPCODE_I_TYPE == 7'b0010011", OPCODE_I_TYPE == 7'b0010011);
    check_cond("OPCODE_LOAD   == 7'b0000011", OPCODE_LOAD   == 7'b0000011);
    check_cond("OPCODE_STORE  == 7'b0100011", OPCODE_STORE  == 7'b0100011);
    check_cond("OPCODE_BRANCH == 7'b1100011", OPCODE_BRANCH == 7'b1100011);
    check_cond("OPCODE_JAL    == 7'b1101111", OPCODE_JAL    == 7'b1101111);
    check_cond("OPCODE_JALR   == 7'b1100111", OPCODE_JALR   == 7'b1100111);
    check_cond("OPCODE_LUI    == 7'b0110111", OPCODE_LUI    == 7'b0110111);
    check_cond("OPCODE_AUIPC  == 7'b0010111", OPCODE_AUIPC  == 7'b0010111);

    // 3. ALU Operations Check
    check_cond("ALU_ADD == 4'b0000", ALU_ADD == 4'b0000);
    check_cond("ALU_SUB == 4'b0001", ALU_SUB == 4'b0001);
    check_cond("ALU_AND == 4'b1001", ALU_AND == 4'b1001);
    check_cond("ALU_OR  == 4'b1000", ALU_OR  == 4'b1000);

    // 4. Bus Configurations
    check_cond("APB Address Width is 32-bit", APB_ADDR_WIDTH == 32);
    check_cond("APB Data Width is 32-bit", APB_DATA_WIDTH == 32);
    check_cond("Total APB Peripherals is 4", NUM_PERIPHERALS == 4);

    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Checks Executed   : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: Day 1 Package Sanity & Architecture PASSED!");
    end else begin
      $display("[RESULT] FAILURE: Found %0d package sanity check errors!", error_count);
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_pkg_sanity
