//=============================================================================
// File: tb_decoder.sv
// Description: Comprehensive testbench for RV32I Decoder & Immediate Generator
// (VR-CPU-04). Verifies control signal generation and immediate extraction.
//=============================================================================

`timescale 1ns/1ps

module tb_decoder;
  import soc_pkg::*;

  logic [31:0]  instr;
  logic [4:0]   rs1_addr, rs2_addr, rd_addr;
  logic [2:0]   funct3;
  logic [6:0]   funct7;
  opcode_e      opcode;
  alu_op_e      alu_op;
  logic         src_a_sel;
  logic [1:0]   src_b_sel, wb_sel;
  logic         reg_write, mem_read, mem_write, branch, jump, jalr, illegal_instr;
  mem_width_e   mem_width;
  branch_op_e   branch_op;

  logic [31:0]  imm_i, imm_s, imm_b, imm_u, imm_j;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  // DUTs
  rv32i_decoder u_dec (
    .instr         (instr),
    .rs1_addr      (rs1_addr),
    .rs2_addr      (rs2_addr),
    .rd_addr       (rd_addr),
    .funct3        (funct3),
    .funct7        (funct7),
    .opcode        (opcode),
    .alu_op        (alu_op),
    .src_a_sel     (src_a_sel),
    .src_b_sel     (src_b_sel),
    .wb_sel        (wb_sel),
    .reg_write     (reg_write),
    .mem_read      (mem_read),
    .mem_write     (mem_write),
    .branch        (branch),
    .jump          (jump),
    .jalr          (jalr),
    .mem_width     (mem_width),
    .branch_op     (branch_op),
    .illegal_instr (illegal_instr)
  );

  rv32i_imm_gen u_imm (
    .instr (instr),
    .imm_i (imm_i),
    .imm_s (imm_s),
    .imm_b (imm_b),
    .imm_u (imm_u),
    .imm_j (imm_j)
  );

  task automatic check_ctrl(
    input string  name,
    input alu_op_e exp_alu_op,
    input logic    exp_reg_wr,
    input logic    exp_mem_rd,
    input logic    exp_mem_wr,
    input logic    exp_branch,
    input logic    exp_jump
  );
    test_count++;
    #1;
    if (alu_op !== exp_alu_op || reg_write !== exp_reg_wr ||
        mem_read !== exp_mem_rd || mem_write !== exp_mem_wr ||
        branch !== exp_branch || jump !== exp_jump) begin
      $display("[FAIL] %s: Control signal mismatch! alu_op=%s, reg_wr=%b, mem_rd=%b, mem_wr=%b, br=%b, jmp=%b",
               name, alu_op.name(), reg_write, mem_read, mem_write, branch, jump);
      error_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    $display("=================================================================");
    $display("       DAY 4: RV32I Decoder & ImmGen Verification (VR-CPU-04)    ");
    $display("=================================================================");

    // 1. R-Type: ADD rd=x1, rs1=x2, rs2=x3 (0000000 00011 00010 000 00001 0110011)
    instr = 32'b0000000_00011_00010_000_00001_0110011;
    check_ctrl("ADD x1, x2, x3", ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);

    // 2. R-Type: SUB rd=x1, rs1=x2, rs2=x3 (0100000 00011 00010 000 00001 0110011)
    instr = 32'b0100000_00011_00010_000_00001_0110011;
    check_ctrl("SUB x1, x2, x3", ALU_SUB, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);

    // 3. I-Type: ADDI rd=x5, rs1=x1, imm=-4 (111111111100 00001 000 00101 0010011)
    instr = 32'hFFC08293;
    check_ctrl("ADDI x5, x1, -4", ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    test_count++;
    if (imm_i !== 32'hFFFF_FFFC) begin
      $display("[FAIL] ADDI immediate sign extension mismatch: Got 0x%08h", imm_i);
      error_count++;
    end else pass_count++;

    // 4. Load: LW rd=x10, rs1=x2, offset=16 (000000010000 00010 010 01010 0000011)
    instr = 32'h01012503;
    check_ctrl("LW x10, 16(x2)", ALU_ADD, 1'b1, 1'b1, 1'b0, 1'b0, 1'b0);

    // 5. Store: SW rs2=x10, rs1=x2, offset=32
    instr = 32'h02A12023;
    check_ctrl("SW x10, 32(x2)", ALU_ADD, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
    test_count++;
    if (imm_s !== 32'd32) begin
      $display("[FAIL] SW immediate mismatch: Got %0d", imm_s);
      error_count++;
    end else pass_count++;

    // 6. Branch: BEQ rs1=x1, rs2=x2, offset=-8
    instr = 32'hFE208CE3;
    check_ctrl("BEQ x1, x2, -8", ALU_ADD, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
    test_count++;
    if (imm_b !== -32'd8) begin
      $display("[FAIL] BEQ immediate mismatch: Got %0d", $signed(imm_b));
      error_count++;
    end else pass_count++;

    // 7. Jump: JAL rd=x1, offset=1024
    instr = 32'h400000EF;
    check_ctrl("JAL x1, 1024", ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);

    // 8. Upper: LUI rd=x3, imm=0x12345
    instr = 32'h123451B7;
    check_ctrl("LUI x3, 0x12345", ALU_PASS, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);
    test_count++;
    if (imm_u !== 32'h1234_5000) begin
      $display("[FAIL] LUI imm_u mismatch: Got 0x%08h", imm_u);
      error_count++;
    end else pass_count++;

    // 9. AUIPC: AUIPC rd=x4, imm=0x80000
    instr = 32'h80000217;
    check_ctrl("AUIPC x4, 0x80000", ALU_ADD, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);

    // 10. Illegal Instruction Check
    instr = 32'hFFFF_FFFF;
    #1;
    test_count++;
    if (illegal_instr !== 1'b1) begin
      $display("[FAIL] Illegal instruction 0xFFFFFFFF not flagged!");
      error_count++;
    end else pass_count++;

    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Checks Executed   : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: Day 4 RV32I Decoder & ImmGen Verified!");
      $display("         VR-CPU-04 (Instruction Formats & Decoding) PASSED.");
    end else begin
      $display("[RESULT] FAILURE: Found %0d Decoder verification errors!", error_count);
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_decoder
