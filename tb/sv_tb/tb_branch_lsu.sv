//=============================================================================
// File: tb_branch_lsu.sv
// Description: Testbench for Branch Decision Unit & Load-Store Unit (VR-CPU-05).
// Tests all branch conditions and byte/halfword/word memory alignments.
//=============================================================================

`timescale 1ns/1ps

module tb_branch_lsu;
  import soc_pkg::*;

  // Branch signals
  logic [31:0]  br_a, br_b;
  branch_op_e   branch_op;
  logic         branch_taken;

  // LSU signals
  logic [31:0]  lsu_addr;
  logic [31:0]  lsu_wdata;
  mem_width_e   lsu_width;
  logic [31:0]  raw_rdata;
  logic [31:0]  formatted_rdata;
  logic [31:0]  formatted_wdata;
  logic [3:0]   byte_enable;
  logic         align_error;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  // DUTs
  rv32i_branch_unit u_br (
    .op_a         (br_a),
    .op_b         (br_b),
    .branch_op    (branch_op),
    .branch_taken (branch_taken)
  );

  rv32i_lsu u_lsu (
    .addr            (lsu_addr),
    .wr_data         (lsu_wdata),
    .mem_width       (lsu_width),
    .raw_rdata       (raw_rdata),
    .formatted_rdata (formatted_rdata),
    .formatted_wdata (formatted_wdata),
    .byte_enable     (byte_enable),
    .align_error     (align_error)
  );

  task automatic check_br(input logic [31:0] a, input logic [31:0] b, input branch_op_e op, input logic exp, input string desc);
    test_count++;
    br_a = a;
    br_b = b;
    branch_op = op;
    #1;
    if (branch_taken !== exp) begin
      $display("[FAIL] %s: Expected taken=%b, Got %b (a=0x%08h, b=0x%08h)", desc, exp, branch_taken, a, b);
      error_count++;
    end else pass_count++;
  endtask

  initial begin
    $display("=================================================================");
    $display("       DAY 5: Branch & LSU Verification (VR-CPU-05)              ");
    $display("=================================================================");

    //-------------------------------------------------------------------------
    // 1. Branch Unit Checks
    //-------------------------------------------------------------------------
    $display("[CHECK 1] Testing Branch Unit (BEQ, BNE, BLT, BGE, BLTU, BGEU)...");
    check_br(32'd10, 32'd10, BR_BEQ, 1'b1, "BEQ Equal");
    check_br(32'd10, 32'd20, BR_BEQ, 1'b0, "BEQ Not Equal");

    check_br(32'd10, 32'd20, BR_BNE, 1'b1, "BNE Not Equal");
    check_br(32'd10, 32'd10, BR_BNE, 1'b0, "BNE Equal");

    check_br(-32'd5, 32'd5,  BR_BLT, 1'b1, "BLT -5 < 5 (Signed)");
    check_br(32'd5,  -32'd5, BR_BLT, 1'b0, "BLT 5 < -5 (Signed)");

    check_br(32'd5,  -32'd5, BR_BGE, 1'b1, "BGE 5 >= -5 (Signed)");
    check_br(-32'd5, 32'd5,  BR_BGE, 1'b0, "BGE -5 >= 5 (Signed)");

    check_br(32'h0000_0005, 32'hFFFF_FFFB, BR_BLTU, 1'b1, "BLTU 5 < 0xFFFFFFFB (Unsigned)");
    check_br(32'hFFFF_FFFB, 32'h0000_0005, BR_BLTU, 1'b0, "BLTU 0xFFFFFFFB < 5 (Unsigned)");

    check_br(32'hFFFF_FFFB, 32'h0000_0005, BR_BGEU, 1'b1, "BGEU 0xFFFFFFFB >= 5 (Unsigned)");
    check_br(32'h0000_0005, 32'hFFFF_FFFB, BR_BGEU, 1'b0, "BGEU 5 >= 0xFFFFFFFB (Unsigned)");

    //-------------------------------------------------------------------------
    // 2. Load-Store Unit Store Formatting & Byte-Enables
    //-------------------------------------------------------------------------
    $display("[CHECK 2] Testing LSU Store Formatting and Byte Enables...");
    lsu_wdata = 32'h1234_5678;

    // SB at offset 0, 1, 2, 3
    lsu_width = MEM_BYTE;
    lsu_addr  = 32'h1000; #1;
    test_count++;
    if (byte_enable !== 4'b0001 || formatted_wdata[7:0] !== 8'h78) begin
      $display("[FAIL] SB at offset 0 failed!"); error_count++;
    end else pass_count++;

    lsu_addr  = 32'h1001; #1;
    test_count++;
    if (byte_enable !== 4'b0010 || formatted_wdata[15:8] !== 8'h78) begin
      $display("[FAIL] SB at offset 1 failed!"); error_count++;
    end else pass_count++;

    lsu_addr  = 32'h1002; #1;
    test_count++;
    if (byte_enable !== 4'b0100 || formatted_wdata[23:16] !== 8'h78) begin
      $display("[FAIL] SB at offset 2 failed!"); error_count++;
    end else pass_count++;

    lsu_addr  = 32'h1003; #1;
    test_count++;
    if (byte_enable !== 4'b1000 || formatted_wdata[31:24] !== 8'h78) begin
      $display("[FAIL] SB at offset 3 failed!"); error_count++;
    end else pass_count++;

    // SH at offset 0 and 2
    lsu_width = MEM_HALF;
    lsu_addr  = 32'h1000; #1;
    test_count++;
    if (byte_enable !== 4'b0011 || formatted_wdata[15:0] !== 16'h5678) begin
      $display("[FAIL] SH at offset 0 failed!"); error_count++;
    end else pass_count++;

    lsu_addr  = 32'h1002; #1;
    test_count++;
    if (byte_enable !== 4'b1100 || formatted_wdata[31:16] !== 16'h5678) begin
      $display("[FAIL] SH at offset 2 failed!"); error_count++;
    end else pass_count++;

    // SW at offset 0
    lsu_width = MEM_WORD;
    lsu_addr  = 32'h1000; #1;
    test_count++;
    if (byte_enable !== 4'b1111 || formatted_wdata !== 32'h1234_5678) begin
      $display("[FAIL] SW failed!"); error_count++;
    end else pass_count++;

    //-------------------------------------------------------------------------
    // 3. Load Formatting & Sign Extension
    //-------------------------------------------------------------------------
    $display("[CHECK 3] Testing LSU Load Data Formatting & Sign Extension...");
    raw_rdata = 32'h8F12_A57C; // byte 0 = 0x7C, byte 1 = 0xA5 (-91 or 165), byte 2 = 0x12, byte 3 = 0x8F (-113)

    // LB: Sign-extended byte
    lsu_width = MEM_BYTE;
    lsu_addr  = 32'h0001; #1; // byte 1 = 0xA5 (MSB=1, sign extended)
    test_count++;
    if (formatted_rdata !== 32'hFFFF_FFA5) begin
      $display("[FAIL] LB sign extension failed: Got 0x%08h", formatted_rdata); error_count++;
    end else pass_count++;

    // LBU: Zero-extended byte
    lsu_width = MEM_BYTEU;
    lsu_addr  = 32'h0001; #1;
    test_count++;
    if (formatted_rdata !== 32'h0000_00A5) begin
      $display("[FAIL] LBU zero extension failed: Got 0x%08h", formatted_rdata); error_count++;
    end else pass_count++;

    // LH: Sign-extended halfword
    lsu_width = MEM_HALF;
    lsu_addr  = 32'h0000; #1; // halfword 0 = 0xA57C (MSB=1, sign extended)
    test_count++;
    if (formatted_rdata !== 32'hFFFF_A57C) begin
      $display("[FAIL] LH sign extension failed: Got 0x%08h", formatted_rdata); error_count++;
    end else pass_count++;

    // LHU: Zero-extended halfword
    lsu_width = MEM_HALFU;
    lsu_addr  = 32'h0000; #1;
    test_count++;
    if (formatted_rdata !== 32'h0000_A57C) begin
      $display("[FAIL] LHU zero extension failed: Got 0x%08h", formatted_rdata); error_count++;
    end else pass_count++;

    // LW: Full word
    lsu_width = MEM_WORD;
    lsu_addr  = 32'h0000; #1;
    test_count++;
    if (formatted_rdata !== 32'h8F12_A57C) begin
      $display("[FAIL] LW failed: Got 0x%08h", formatted_rdata); error_count++;
    end else pass_count++;

    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Checks Executed   : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: Day 5 Branch & LSU Verified!");
      $display("         VR-CPU-05 (Branch & Load/Store Unit) PASSED.");
    end else begin
      $display("[RESULT] FAILURE: Found %0d Branch/LSU verification errors!", error_count);
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_branch_lsu
