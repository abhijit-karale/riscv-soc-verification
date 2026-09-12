//=============================================================================
// File: tb_regfile.sv
// Description: Advanced self-checking testbench for RV32I Register File (VR-CPU-02).
// Tests x0 hardwired zero invariance, dual read ports, simultaneous read/write,
// and random register patterns.
//=============================================================================

`timescale 1ns/1ps

module tb_regfile;
  logic        clk;
  logic        rst_n;
  logic [4:0]  rs1_addr;
  logic [31:0] rs1_data;
  logic [4:0]  rs2_addr;
  logic [31:0] rs2_data;
  logic        wr_en;
  logic [4:0]  rd_addr;
  logic [31:0] rd_data;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  // Golden model shadow register file
  logic [31:0] shadow_rf [0:31];

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // DUT Instantiation
  rv32i_regfile #(.FORWARDING(1)) u_dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .rs1_addr (rs1_addr),
    .rs1_data (rs1_data),
    .rs2_addr (rs2_addr),
    .rs2_data (rs2_data),
    .wr_en    (wr_en),
    .rd_addr  (rd_addr),
    .rd_data  (rd_data)
  );

  // Task to perform synchronous write
  task automatic write_reg(input logic [4:0] addr, input logic [31:0] data);
    @(posedge clk);
    wr_en   <= 1'b1;
    rd_addr <= addr;
    rd_data <= data;
    if (addr != 5'd0) begin
      shadow_rf[addr] = data;
    end
    @(posedge clk);
    wr_en   <= 1'b0;
    rd_addr <= 5'd0;
    rd_data <= 32'h0;
  endtask

  // Task to check read ports
  task automatic check_reads(input logic [4:0] a1, input logic [4:0] a2, input string desc);
    test_count++;
    rs1_addr = a1;
    rs2_addr = a2;
    #1; // Asynchronous read settling

    if (rs1_data !== shadow_rf[a1]) begin
      $display("[FAIL] %s - Port 1: Addr %0d Expected 0x%08h, Got 0x%08h", desc, a1, shadow_rf[a1], rs1_data);
      error_count++;
    end else if (rs2_data !== shadow_rf[a2]) begin
      $display("[FAIL] %s - Port 2: Addr %0d Expected 0x%08h, Got 0x%08h", desc, a2, shadow_rf[a2], rs2_data);
      error_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    $display("=================================================================");
    $display("       DAY 3: RV32I Register File Verification (VR-CPU-02)       ");
    $display("=================================================================");

    // Initialize signals
    rst_n    = 0;
    wr_en    = 0;
    rd_addr  = 0;
    rd_data  = 0;
    rs1_addr = 0;
    rs2_addr = 0;
    for (int i = 0; i < 32; i++) shadow_rf[i] = 32'h0;

    // Reset sequence
    #20 rst_n = 1;
    @(posedge clk);

    // 1. Check all registers are 0 after reset
    $display("[CHECK 1] Verifying all registers reset to 0x00000000...");
    for (int i = 0; i < 32; i++) begin
      check_reads(5'(i), 5'(i), "Post-reset zero check");
    end

    // 2. Write unique patterns to all registers x1 to x31
    $display("[CHECK 2] Writing unique signatures to x1..x31...");
    for (int i = 1; i < 32; i++) begin
      write_reg(5'(i), 32'hA000_0000 | (i << 16) | (32'hF00D + i));
    end

    // 3. Read back and verify all registers
    $display("[CHECK 3] Reading back all registers via dual ports...");
    for (int i = 0; i < 16; i++) begin
      check_reads(5'(i), 5'(31-i), "Dual-port sweep");
    end

    // 4. Hardwired x0 invariance check
    $display("[CHECK 4] Testing x0 Hardwired Zero Invariance Property...");
    write_reg(5'd0, 32'hDEAD_BEEF); // Attempt overwrite of x0
    write_reg(5'd0, 32'hFFFF_FFFF);
    check_reads(5'd0, 5'd0, "x0 must read 0x0 even after write attempts");

    // 5. Write-through Forwarding Hazard Check
    $display("[CHECK 5] Testing Simultaneous Write and Read Forwarding...");
    @(posedge clk);
    wr_en    <= 1'b1;
    rd_addr  <= 5'd7;
    rd_data  <= 32'hBEEF_CAFE;
    rs1_addr <= 5'd7; // Reading same register during write
    rs2_addr <= 5'd7;
    #1;
    test_count++;
    if (rs1_data !== 32'hBEEF_CAFE || rs2_data !== 32'hBEEF_CAFE) begin
      $display("[FAIL] Forwarding mismatch: Expected 0x%08h, Got Port1=0x%08h, Port2=0x%08h",
               32'hBEEF_CAFE, rs1_data, rs2_data);
      error_count++;
    end else begin
      pass_count++;
    end
    @(posedge clk);
    wr_en <= 1'b0;
    shadow_rf[7] = 32'hBEEF_CAFE;

    // 6. Randomized Reads/Writes
    $display("[CHECK 6] Running 500 Constrained Random Read/Write Cycles...");
    repeat (500) begin
      logic [4:0]  rand_waddr;
      logic [31:0] rand_wdata;
      logic [4:0]  rand_r1;
      logic [4:0]  rand_r2;

      rand_waddr = $urandom_range(0, 31);
      rand_wdata = $urandom();
      rand_r1    = $urandom_range(0, 31);
      rand_r2    = $urandom_range(0, 31);

      write_reg(rand_waddr, rand_wdata);
      check_reads(rand_r1, rand_r2, "Randomized read check");
    end

    // Final Report
    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Checks Executed   : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: Day 3 RV32I Register File Verified!");
      $display("         VR-CPU-02 (x0 Invariance & Dual Read/Write) PASSED.");
    end else begin
      $display("[RESULT] FAILURE: Found %0d Register File verification errors!", error_count);
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_regfile
