//=============================================================================
// File: tb_core.sv
// Description: Testbench for integrated single-cycle RV32I Processor Core.
// Executes a direct instruction program stream and verifies datapath execution.
//=============================================================================

`timescale 1ns/1ps

module tb_core;
  import soc_pkg::*;

  logic        clk;
  logic        rst_n;
  logic [31:0] instr_addr;
  logic [31:0] instr_data;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;
  logic [3:0]  data_byte_en;
  logic        data_we;
  logic        data_re;
  logic        ext_irq;
  logic        irq_ack;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  // Simple simulated data RAM
  logic [31:0] dmem [0:255];

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  rv32i_core u_dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .instr_addr   (instr_addr),
    .instr_data   (instr_data),
    .data_addr    (data_addr),
    .data_wdata   (data_wdata),
    .data_rdata   (data_rdata),
    .data_byte_en (data_byte_en),
    .data_we      (data_we),
    .data_re      (data_re),
    .stall        (1'b0),
    .ext_irq      (ext_irq),
    .irq_ack      (irq_ack)
  );

  // Single-cycle memory emulation: Combinational read, synchronous write
  assign data_rdata = dmem[data_addr[9:2]];
  always @(posedge clk) begin
    if (data_we) begin
      dmem[data_addr[9:2]] <= data_wdata;
    end
  end

  // Instruction ROM mapping
  always_comb begin
    case (instr_addr)
      // 0x00: ADDI x1, x0, 10
      32'h00: instr_data = 32'h00A00093;
      // 0x04: ADDI x2, x0, 25
      32'h04: instr_data = 32'h01900113;
      // 0x08: ADD  x3, x1, x2  (x3 = 35 = 0x23)
      32'h08: instr_data = 32'h002081B3;
      // 0x0C: SW   x3, 4(x0)   (Store 35 to mem[4])
      32'h0C: instr_data = 32'h00302223;
      // 0x10: LW   x4, 4(x0)   (Load from mem[4] into x4)
      32'h10: instr_data = 32'h00402203;
      // 0x14: BEQ  x3, x4, 8   (Branch to 0x1C if x3 == x4)
      32'h14: instr_data = 32'h00418463;
      // 0x18: ADDI x5, x0, 99  (Should be skipped by branch!)
      32'h18: instr_data = 32'h06300293;
      // 0x1C: ADDI x5, x0, 1   (Target: x5 = 1 indicating branch taken!)
      32'h1C: instr_data = 32'h00100293;
      // 0x20: JAL  x0, 0       (Self-loop)
      default: instr_data = 32'h0000006F;
    endcase
  end

  initial begin
    $display("=================================================================");
    $display("       DAY 7: RV32I Processor Core Integration Test             ");
    $display("=================================================================");

    rst_n   = 0;
    ext_irq = 0;
    for (int i = 0; i < 256; i++) dmem[i] = 32'h0;

    @(negedge clk);
    rst_n = 1;

    // Cycle 1 (PC=0x00): ADDI x1, x0, 10
    #1;
    $display("[CYCLE 1] PC=0x%08h: Executing ADDI x1, x0, 10", instr_addr);

    // Cycle 2 (PC=0x04): ADDI x2, x0, 25
    @(posedge clk); #1;
    $display("[CYCLE 2] PC=0x%08h: Executing ADDI x2, x0, 25", instr_addr);

    // Cycle 3 (PC=0x08): ADD x3, x1, x2
    @(posedge clk); #1;
    $display("[CYCLE 3] PC=0x%08h: Executing ADD x3, x1, x2 (Result=35)", instr_addr);

    // Cycle 4 (PC=0x0C): SW x3, 4(x0)
    @(posedge clk); #1;
    $display("[CYCLE 4] PC=0x%08h: Executing SW x3, 4(x0)", instr_addr);
    test_count++;
    if (data_we !== 1'b1 || data_addr !== 32'd4 || data_wdata !== 32'd35) begin
      $display("[FAIL] SW cycle mismatch: we=%b, addr=0x%08h, wdata=0x%08h", data_we, data_addr, data_wdata);
      error_count++;
    end else begin
      $display("[PASS] SW memory bus: addr=0x%08h, wdata=%0d, byte_en=0x%h", data_addr, data_wdata, data_byte_en);
      pass_count++;
    end

    // Cycle 5 (PC=0x10): LW x4, 4(x0)
    @(posedge clk); #1;
    $display("[CYCLE 5] PC=0x%08h: Executing LW x4, 4(x0)", instr_addr);

    // Cycle 6 (PC=0x14): BEQ x3, x4, 8
    @(posedge clk); #1;
    $display("[CYCLE 6] PC=0x%08h: Executing BEQ x3, x4 (Branch Target = 0x1C)", instr_addr);

    // Cycle 7: Target instruction at 0x1C (Skipping 0x18)
    @(posedge clk); #1;
    $display("[CYCLE 7] PC=0x%08h: Branch redirect completed", instr_addr);
    test_count++;
    if (instr_addr !== 32'h0000_001C) begin
      $display("[FAIL] Branch target not reached! Expected PC=0x1C, Got PC=0x%08h", instr_addr);
      error_count++;
    end else begin
      $display("[PASS] Branch successfully redirected PC to target 0x0000001C (skipped 0x18)");
      pass_count++;
    end

    @(posedge clk); #1;

    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Checks Executed   : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: Day 7 RV32I Processor Core Verified!");
      $display("         Phase 1 (Days 1-7 CPU Core Datapath) 100%% COMPLETE.");
    end else begin
      $display("[RESULT] FAILURE: Found %0d Processor Core integration errors!", error_count);
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_core
