//=============================================================================
// File: tb_fetch.sv
// Description: Testbench for RV32I Fetch & Program Counter Unit (VR-CPU-01).
// Tests sequential PC (+4), branch target redirects, jump targets, and stalls.
//=============================================================================

`timescale 1ns/1ps

module tb_fetch;
  logic        clk;
  logic        rst_n;
  logic        stall;
  logic        branch_taken;
  logic        jump;
  logic [31:0] branch_target;
  logic [31:0] jump_target;
  logic [31:0] pc;
  logic [31:0] pc_plus_4;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  rv32i_fetch u_dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .stall         (stall),
    .branch_taken  (branch_taken),
    .jump          (jump),
    .branch_target (branch_target),
    .jump_target   (jump_target),
    .pc            (pc),
    .pc_plus_4     (pc_plus_4)
  );

  task automatic check_pc(input logic [31:0] exp_pc, input string desc);
    test_count++;
    if (pc !== exp_pc) begin
      $display("[FAIL] %s: Expected PC=0x%08h, Got 0x%08h", desc, exp_pc, pc);
      error_count++;
    end else pass_count++;
  endtask

  initial begin
    $display("=================================================================");
    $display("       DAY 6: Fetch & PC Management Verification (VR-CPU-01)     ");
    $display("=================================================================");

    rst_n         = 0;
    stall         = 0;
    branch_taken  = 0;
    jump          = 0;
    branch_target = 0;
    jump_target   = 0;

    // Reset check
    @(negedge clk);
    check_pc(32'h0000_0000, "Reset PC vector");

    // Release reset
    rst_n = 1;

    // Sequential steps
    $display("[CHECK 1] Verifying sequential PC+4 increments...");
    @(posedge clk); #1; check_pc(32'h0000_0004, "Step 1");
    @(posedge clk); #1; check_pc(32'h0000_0008, "Step 2");
    @(posedge clk); #1; check_pc(32'h0000_000C, "Step 3");

    // Branch redirection
    $display("[CHECK 2] Testing Branch Redirection...");
    @(negedge clk);
    branch_taken  = 1'b1;
    branch_target = 32'h0000_0100;
    @(posedge clk);
    #1;
    check_pc(32'h0000_0100, "Branch Target 0x100 taken");
    @(negedge clk);
    branch_taken  = 1'b0;
    @(posedge clk);
    #1;
    check_pc(32'h0000_0104, "Post-branch sequential step");

    // Jump redirection
    $display("[CHECK 3] Testing Jump (JAL/JALR) Redirection & Alignment...");
    @(negedge clk);
    jump        = 1'b1;
    jump_target = 32'h0000_1001; // Odd address to test LSB zeroing
    @(posedge clk);
    #1;
    check_pc(32'h0000_1000, "Jump target LSB forced to 0");
    @(negedge clk);
    jump        = 1'b0;

    // Stall check
    $display("[CHECK 4] Testing PC Freeze under Stall...");
    @(negedge clk);
    stall = 1'b1;
    @(posedge clk); #1; check_pc(32'h0000_1004, "PC frozen cycle 1");
    @(posedge clk); #1; check_pc(32'h0000_1004, "PC frozen cycle 2");
    @(negedge clk);
    stall = 1'b0;
    @(posedge clk); #1; check_pc(32'h0000_1008, "PC resumes after stall");

    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Checks Executed   : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: Day 6 Fetch & PC Unit Verified!");
      $display("         VR-CPU-01 (PC & Fetch Sequences) PASSED.");
    end else begin
      $display("[RESULT] FAILURE: Found %0d Fetch/PC verification errors!", error_count);
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_fetch
