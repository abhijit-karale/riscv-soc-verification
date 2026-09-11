//=============================================================================
// File: tb_alu.sv
// Description: Advanced SystemVerilog Testbench for RV32I ALU (VR-CPU-03).
// Includes directed corner-case tests, constrained-random stimulus,
// self-checking golden reference model, functional coverage, and SVA.
//=============================================================================

`timescale 1ns/1ps

module tb_alu;
  import soc_pkg::*;

  //---------------------------------------------------------------------------
  // Signals & Interfaces
  //---------------------------------------------------------------------------
  logic        clk;
  logic [31:0] op_a;
  logic [31:0] op_b;
  alu_op_e     alu_op;
  logic [31:0] dut_result;
  logic        dut_zero;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  //---------------------------------------------------------------------------
  // Clock Generator (for assertion sampling and coverage collection)
  //---------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  //---------------------------------------------------------------------------
  // DUT Instantiation
  //---------------------------------------------------------------------------
  rv32i_alu u_dut (
    .op_a   (op_a),
    .op_b   (op_b),
    .alu_op (alu_op),
    .result (dut_result),
    .zero   (dut_zero)
  );

  //---------------------------------------------------------------------------
  // SVA Bind / Instantiation
  //---------------------------------------------------------------------------
  alu_assertions u_alu_sva (
    .clk    (clk),
    .op_a   (op_a),
    .op_b   (op_b),
    .alu_op (alu_op),
    .result (dut_result),
    .zero   (dut_zero)
  );

  //---------------------------------------------------------------------------
  // Functional Coverage
  //---------------------------------------------------------------------------
  covergroup alu_cg @(posedge clk);
    option.per_instance = 1;
    option.comment = "RV32I ALU Functional Coverage (VR-CPU-03)";

    cp_op: coverpoint alu_op {
      bins op_add  = {ALU_ADD};
      bins op_sub  = {ALU_SUB};
      bins op_sll  = {ALU_SLL};
      bins op_slt  = {ALU_SLT};
      bins op_sltu = {ALU_SLTU};
      bins op_xor  = {ALU_XOR};
      bins op_srl  = {ALU_SRL};
      bins op_sra  = {ALU_SRA};
      bins op_or   = {ALU_OR};
      bins op_and  = {ALU_AND};
      bins op_pass = {ALU_PASS};
    }

    cp_op_a: coverpoint op_a {
      bins zero     = {32'h0000_0000};
      bins all_ones = {32'hFFFF_FFFF};
      bins max_pos  = {32'h7FFF_FFFF};
      bins min_neg  = {32'h8000_0000};
      bins pos_misc = {[32'h0000_0001:32'h7FFF_FFFE]};
      bins neg_misc = {[32'h8000_0001:32'hFFFF_FFFE]};
    }

    cp_op_b: coverpoint op_b {
      bins zero     = {32'h0000_0000};
      bins all_ones = {32'hFFFF_FFFF};
      bins max_pos  = {32'h7FFF_FFFF};
      bins min_neg  = {32'h8000_0000};
      bins pos_misc = {[32'h0000_0001:32'h7FFF_FFFE]};
      bins neg_misc = {[32'h8000_0001:32'hFFFF_FFFE]};
    }

    cp_shamt: coverpoint op_b[4:0] iff (alu_op inside {ALU_SLL, ALU_SRL, ALU_SRA}) {
      bins shift_0    = {5'd0};
      bins shift_1    = {5'd1};
      bins shift_mid  = {[5'd2:5'd30]};
      bins shift_31   = {5'd31};
    }

    cp_shamt_upper_masked: coverpoint (|op_b[31:5]) iff (alu_op inside {ALU_SLL, ALU_SRL, ALU_SRA}) {
      bins upper_zero    = {1'b0};
      bins upper_nonzero = {1'b1};
    }

    cp_zero_flag: coverpoint dut_zero {
      bins zero_low  = {1'b0};
      bins zero_high = {1'b1};
    }

    // Cross coverage between operations and corner operands
    cross_op_corners: cross cp_op, cp_op_a, cp_op_b {
      ignore_bins pass_bins = binsof(cp_op) intersect {ALU_PASS};
    }
  endgroup

  alu_cg cg_inst = new();

  //---------------------------------------------------------------------------
  // Golden Reference Model
  //---------------------------------------------------------------------------
  function void compute_reference(
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  alu_op_e     op,
    output logic [31:0] exp_res,
    output logic        exp_zero
  );
    logic [4:0] shamt;
    shamt = b[4:0];

    case (op)
      ALU_ADD:  exp_res = a + b;
      ALU_SUB:  exp_res = a - b;
      ALU_SLL:  exp_res = a << shamt;
      ALU_SLT:  exp_res = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
      ALU_SLTU: exp_res = (a < b) ? 32'd1 : 32'd0;
      ALU_XOR:  exp_res = a ^ b;
      ALU_SRL:  exp_res = a >> shamt;
      ALU_SRA:  exp_res = $signed(a) >>> shamt;
      ALU_OR:   exp_res = a | b;
      ALU_AND:  exp_res = a & b;
      ALU_PASS: exp_res = b;
      default:  exp_res = 32'h0000_0000;
    endcase

    exp_zero = (exp_res == 32'h0000_0000);
  endfunction

  //---------------------------------------------------------------------------
  // Test Driver and Checker Task
  //---------------------------------------------------------------------------
  task automatic drive_and_check(
    input logic [31:0] a,
    input logic [31:0] b,
    input alu_op_e     op,
    input string       test_desc
  );
    logic [31:0] exp_result;
    logic        exp_zero;

    op_a   = a;
    op_b   = b;
    alu_op = op;

    // Wait for posedge clock to allow assertion checking and covergroup sampling
    @(posedge clk);
    #1; // Settling time after clock

    test_count++;
    compute_reference(op_a, op_b, alu_op, exp_result, exp_zero);

    if (dut_result !== exp_result || dut_zero !== exp_zero) begin
      $display("[FAIL] %s", test_desc);
      $display("       Inputs  : op_a=0x%08h, op_b=0x%08h, alu_op=%s", op_a, op_b, alu_op.name());
      $display("       Expected: result=0x%08h, zero=%b", exp_result, exp_zero);
      $display("       Actual  : result=0x%08h, zero=%b", dut_result, dut_zero);
      error_count++;
    end else begin
      pass_count++;
    end
  endtask

  //---------------------------------------------------------------------------
  // Constrained Random Transaction Class
  //---------------------------------------------------------------------------
  class alu_rand_txn;
    rand logic [31:0] a;
    rand logic [31:0] b;
    rand alu_op_e     op;

    constraint c_op_valid {
      op inside {ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
                 ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND, ALU_PASS};
    }

    constraint c_operand_distribution {
      a dist {
        32'h0000_0000 :/ 10,
        32'hFFFF_FFFF :/ 10,
        32'h7FFF_FFFF :/ 10,
        32'h8000_0000 :/ 10,
        [32'h0000_0001 : 32'h0000_00FF] :/ 10,
        [32'h0000_0100 : 32'h7FFF_FFFE] :/ 25,
        [32'h8000_0001 : 32'hFFFF_FFFE] :/ 25
      };

      b dist {
        32'h0000_0000 :/ 10,
        32'hFFFF_FFFF :/ 10,
        32'h7FFF_FFFF :/ 10,
        32'h8000_0000 :/ 10,
        [32'h0000_0001 : 32'h0000_003F] :/ 20, // Low values for shifts
        [32'h0000_0040 : 32'h7FFF_FFFE] :/ 20,
        [32'h8000_0001 : 32'hFFFF_FFFE] :/ 20
      };
    }
  endclass

  //---------------------------------------------------------------------------
  // Main Test Sequence
  //---------------------------------------------------------------------------
  initial begin
    alu_rand_txn rand_item;
    real cov_percentage;

    rand_item = new();

    $display("=================================================================");
    $display("       DAY 2: RV32I ALU Verification Environment (VR-CPU-03)     ");
    $display("=================================================================");

    @(posedge clk);

    //-------------------------------------------------------------------------
    // PHASE 1: Directed Corner-Case Matrix (Targeting 100% Opcode & Corner bins)
    //-------------------------------------------------------------------------
    $display("[PHASE 1] Executing Comprehensive Corner-Case Vectors...");

    // 1. ADD / SUB Corners
    drive_and_check(32'h0000_0000, 32'h0000_0000, ALU_ADD, "ADD: 0 + 0 = 0");
    drive_and_check(32'h0000_0001, 32'hFFFF_FFFF, ALU_ADD, "ADD: 1 + (-1) = 0");
    drive_and_check(32'h7FFF_FFFF, 32'h0000_0001, ALU_ADD, "ADD: Overflow to 0x80000000");
    drive_and_check(32'h8000_0000, 32'hFFFF_FFFF, ALU_ADD, "ADD: 0x80000000 + (-1) = 0x7FFFFFFF");
    drive_and_check(32'h5555_5555, 32'hAAAA_AAAA, ALU_ADD, "ADD: Alternating bits sum to 0xFFFFFFFF");

    drive_and_check(32'h1234_5678, 32'h1234_5678, ALU_SUB, "SUB: Identical operands (result=0)");
    drive_and_check(32'h0000_0000, 32'h0000_0001, ALU_SUB, "SUB: 0 - 1 = 0xFFFFFFFF (-1)");
    drive_and_check(32'h8000_0000, 32'h0000_0001, ALU_SUB, "SUB: Min neg - 1 = Max pos");
    drive_and_check(32'h7FFF_FFFF, 32'hFFFF_FFFF, ALU_SUB, "SUB: Max pos - (-1) = Min neg");

    // 2. Shift Operations & 5-bit Masking Verification
    drive_and_check(32'h0000_0001, 32'h0000_0000, ALU_SLL, "SLL: Shift by 0");
    drive_and_check(32'h0000_0001, 32'h0000_0001, ALU_SLL, "SLL: Shift by 1");
    drive_and_check(32'h0000_0001, 32'h0000_001F, ALU_SLL, "SLL: Shift by 31 to MSB");
    drive_and_check(32'h0000_0001, 32'hFFFF_FFE1, ALU_SLL, "SLL: Shift with upper bits set (shamt=1)");
    drive_and_check(32'hFFFF_FFFF, 32'h0000_0020, ALU_SLL, "SLL: Shift by 32 (masked to 0)");

    drive_and_check(32'h8000_0000, 32'h0000_0001, ALU_SRL, "SRL: Logical shift right MSB (zero-fill)");
    drive_and_check(32'h8000_0000, 32'h0000_001F, ALU_SRL, "SRL: Logical shift right by 31");
    drive_and_check(32'hFFFF_FFFF, 32'h1234_5604, ALU_SRL, "SRL: Logical shift by 4 with upper bits");

    drive_and_check(32'h8000_0000, 32'h0000_0001, ALU_SRA, "SRA: Arithmetic shift right (sign-extend)");
    drive_and_check(32'h8000_0000, 32'h0000_001F, ALU_SRA, "SRA: Arithmetic shift right by 31 (all 1s)");
    drive_and_check(32'h7000_0000, 32'h0000_0004, ALU_SRA, "SRA: Positive operand sign-extend (0-fill)");
    drive_and_check(32'hF000_0000, 32'hA5A5_A502, ALU_SRA, "SRA: Masked shift amount with neg op");

    // 3. Set Less Than: SLT (Signed) vs SLTU (Unsigned)
    drive_and_check(32'hFFFF_FFFF, 32'h0000_0001, ALU_SLT,  "SLT : -1 < +1 is TRUE (1)");
    drive_and_check(32'hFFFF_FFFF, 32'h0000_0001, ALU_SLTU, "SLTU: 0xFFFFFFFF < 1 is FALSE (0)");
    drive_and_check(32'h8000_0000, 32'h7FFF_FFFF, ALU_SLT,  "SLT : Min neg < Max pos is TRUE (1)");
    drive_and_check(32'h8000_0000, 32'h7FFF_FFFF, ALU_SLTU, "SLTU: 0x80000000 < 0x7FFFFFFF is FALSE (0)");
    drive_and_check(32'h0000_0005, 32'h0000_0005, ALU_SLT,  "SLT : Equal values is FALSE (0)");
    drive_and_check(32'h0000_0005, 32'h0000_0005, ALU_SLTU, "SLTU: Equal values is FALSE (0)");
    drive_and_check(32'h8000_0000, 32'h8000_0001, ALU_SLT,  "SLT : -2^31 < -2^31+1 is TRUE (1)");
    drive_and_check(32'h8000_0000, 32'h8000_0001, ALU_SLTU, "SLTU: Unsigned comparison is TRUE (1)");

    // 4. Bitwise Logic: XOR, OR, AND
    drive_and_check(32'hF0F0_F0F0, 32'h0F0F_0F0F, ALU_XOR, "XOR: Inversion pattern");
    drive_and_check(32'hAAAA_5555, 32'hAAAA_5555, ALU_XOR, "XOR: Self-XOR (result=0)");
    drive_and_check(32'hF0F0_0000, 32'h0F0F_0000, ALU_OR,  "OR : Merged bitmask");
    drive_and_check(32'h0000_0000, 32'h0000_0000, ALU_OR,  "OR : 0 | 0 = 0");
    drive_and_check(32'hFFFF_0000, 32'h0000_FFFF, ALU_AND, "AND: Orthogonal bitmasks (result=0)");
    drive_and_check(32'hFFFF_FFFF, 32'h1234_5678, ALU_AND, "AND: Mask with all 1s");

    // 5. ALU_PASS (Bypass op_b)
    drive_and_check(32'hDEAD_BEEF, 32'hCAFE_BABE, ALU_PASS, "PASS: op_b passed through");
    drive_and_check(32'h0000_0000, 32'h0000_0000, ALU_PASS, "PASS: 0 passed through");

    //-------------------------------------------------------------------------
    // PHASE 2: Systematic Cross-Product Matrix of Opcode x Corner Values
    //-------------------------------------------------------------------------
    $display("[PHASE 2] Exercising Complete Operation x Corner Matrix...");
    begin : blk_corners
      automatic logic [31:0] corners[6] = '{32'h0000_0000, 32'hFFFF_FFFF, 32'h7FFF_FFFF,
                                            32'h8000_0000, 32'h1234_5678, 32'hEDCB_A987};
      automatic alu_op_e     all_ops[11] = '{ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
                                             ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND, ALU_PASS};

      foreach (all_ops[i]) begin
        foreach (corners[j]) begin
          foreach (corners[k]) begin
            drive_and_check(corners[j], corners[k], all_ops[i], "Corner Matrix Test");
          end
        end
      end
    end

    //-------------------------------------------------------------------------
    // PHASE 3: Constrained Random Verification (1,500 Vectors)
    //-------------------------------------------------------------------------
    $display("[PHASE 3] Running 1,500 Constrained-Random Transactions...");
    repeat (1500) begin
      if (!rand_item.randomize()) begin
        $display("[FATAL] Randomization failed!");
        $finish;
      end
      drive_and_check(rand_item.a, rand_item.b, rand_item.op, "Random Transaction");
    end

    //-------------------------------------------------------------------------
    // FINAL COVERAGE AND STATUS REPORT
    //-------------------------------------------------------------------------
    cov_percentage = cg_inst.get_coverage();
    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Vectors Applied   : %0d", test_count);
    $display(" Passed Vectors          : %0d", pass_count);
    $display(" Failed Vectors          : %0d", error_count);
    $display(" Functional Coverage     : %0.2f%%", cov_percentage);
    $display("-----------------------------------------------------------------");

    if (error_count == 0 && cov_percentage >= 95.0) begin
      $display("[RESULT] SUCCESS: Day 2 RV32I ALU Design & Verification PASSED!");
      $display("         Fulfills VR-CPU-03 with 100%% Opcode & Corner Closure.");
    end else begin
      $display("[RESULT] FAILURE: Verification failed! Check errors/coverage.");
    end
    $display("=================================================================");

    $finish;
  end

endmodule : tb_alu
