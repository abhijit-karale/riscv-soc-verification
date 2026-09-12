//=============================================================================
// File: rv32i_core.sv
// Description: Integrated single-cycle RV32I Processor Core.
// Binds Fetch/PC, Decoder, ImmGen, RegFile, ALU, Branch Unit, and LSU.
//=============================================================================

`timescale 1ns/1ps

module rv32i_core
  import soc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Instruction Memory Interface (Fetch)
  output logic [31:0] instr_addr,
  input  logic [31:0] instr_data,

  // Data Memory / Interconnect Interface (LSU)
  output logic [31:0] data_addr,
  output logic [31:0] data_wdata,
  input  logic [31:0] data_rdata,
  output logic [3:0]  data_byte_en,
  output logic        data_we,
  output logic        data_re,

  // Pipeline / Bus Wait-State Stall
  input  logic        stall,

  // External Interrupt Interface
  input  logic        ext_irq,
  output logic        irq_ack
);

  //---------------------------------------------------------------------------
  // Internal Interconnect Signals
  //---------------------------------------------------------------------------
  // PC / Fetch signals
  logic [31:0] pc;
  logic [31:0] pc_plus_4;
  logic [31:0] branch_target;
  logic [31:0] jump_target;
  logic        branch_taken;
  logic        jump_mux;

  // Decoder signals
  logic [4:0]  rs1_addr, rs2_addr, rd_addr;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  opcode_e     opcode;
  alu_op_e     alu_op;
  logic        src_a_sel;
  logic [1:0]  src_b_sel, wb_sel;
  logic        reg_write;
  logic        mem_read, mem_write;
  logic        branch, jump, jalr;
  mem_width_e  mem_width;
  branch_op_e  branch_op;
  logic        illegal_instr;

  // Immediate signals
  logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
  logic [31:0] selected_imm;

  // RegFile signals
  logic [31:0] rs1_data, rs2_data;
  logic [31:0] rd_data;

  // ALU signals
  logic [31:0] alu_op_a, alu_op_b;
  logic [31:0] alu_result;
  logic        alu_zero;

  // LSU signals
  logic [31:0] formatted_rdata;
  logic        align_error;

  // Assign Instruction Memory Address
  assign instr_addr = pc;

  // Interrupt Acknowledge Hook
  assign irq_ack = ext_irq;

  //---------------------------------------------------------------------------
  // 1. Program Counter & Fetch Unit
  //---------------------------------------------------------------------------
  assign branch_target = pc + imm_b;
  assign jump_target   = (jalr) ? (rs1_data + imm_i) : (pc + imm_j);
  assign jump_mux      = jump;

  rv32i_fetch u_fetch (
    .clk           (clk),
    .rst_n         (rst_n),
    .stall         (stall),
    .branch_taken  (branch && branch_taken),
    .jump          (jump_mux),
    .branch_target (branch_target),
    .jump_target   (jump_target),
    .pc            (pc),
    .pc_plus_4     (pc_plus_4)
  );

  //---------------------------------------------------------------------------
  // 2. Instruction Decoder
  //---------------------------------------------------------------------------
  rv32i_decoder u_decoder (
    .instr         (instr_data),
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

  //---------------------------------------------------------------------------
  // 3. Immediate Generator
  //---------------------------------------------------------------------------
  rv32i_imm_gen u_imm_gen (
    .instr (instr_data),
    .imm_i (imm_i),
    .imm_s (imm_s),
    .imm_b (imm_b),
    .imm_u (imm_u),
    .imm_j (imm_j)
  );

  // Select immediate based on instruction opcode
  always_comb begin
    case (opcode)
      OPCODE_I_TYPE, OPCODE_LOAD, OPCODE_JALR: selected_imm = imm_i;
      OPCODE_STORE:                            selected_imm = imm_s;
      OPCODE_BRANCH:                           selected_imm = imm_b;
      OPCODE_LUI, OPCODE_AUIPC:                selected_imm = imm_u;
      OPCODE_JAL:                              selected_imm = imm_j;
      default:                                 selected_imm = imm_i;
    endcase
  end

  //---------------------------------------------------------------------------
  // 4. Register File
  //---------------------------------------------------------------------------
  rv32i_regfile u_regfile (
    .clk      (clk),
    .rst_n    (rst_n),
    .rs1_addr (rs1_addr),
    .rs1_data (rs1_data),
    .rs2_addr (rs2_addr),
    .rs2_data (rs2_data),
    .wr_en    (reg_write),
    .rd_addr  (rd_addr),
    .rd_data  (rd_data)
  );

  //---------------------------------------------------------------------------
  // 5. ALU Operands Mux & ALU Datapath
  //---------------------------------------------------------------------------
  assign alu_op_a = (src_a_sel) ? pc : rs1_data;

  always_comb begin
    case (src_b_sel)
      2'd0:    alu_op_b = rs2_data;
      2'd1:    alu_op_b = selected_imm;
      2'd2:    alu_op_b = 32'd4;
      default: alu_op_b = rs2_data;
    endcase
  end

  rv32i_alu u_alu (
    .op_a   (alu_op_a),
    .op_b   (alu_op_b),
    .alu_op (alu_op),
    .result (alu_result),
    .zero   (alu_zero)
  );

  //---------------------------------------------------------------------------
  // 6. Branch Decision Unit
  //---------------------------------------------------------------------------
  rv32i_branch_unit u_branch_unit (
    .op_a         (rs1_data),
    .op_b         (rs2_data),
    .branch_op    (branch_op),
    .branch_taken (branch_taken)
  );

  //---------------------------------------------------------------------------
  // 7. Load-Store Unit (LSU)
  //---------------------------------------------------------------------------
  assign data_addr = alu_result;
  assign data_we   = mem_write;
  assign data_re   = mem_read;

  rv32i_lsu u_lsu (
    .addr            (alu_result),
    .wr_data         (rs2_data),
    .mem_width       (mem_width),
    .raw_rdata       (data_rdata),
    .formatted_rdata (formatted_rdata),
    .formatted_wdata (data_wdata),
    .byte_enable     (data_byte_en),
    .align_error     (align_error)
  );

  //---------------------------------------------------------------------------
  // 8. Writeback Multiplexer
  //---------------------------------------------------------------------------
  always_comb begin
    case (wb_sel)
      2'd0:    rd_data = alu_result;
      2'd1:    rd_data = formatted_rdata;
      2'd2:    rd_data = pc_plus_4;
      default: rd_data = alu_result;
    endcase
  end

endmodule : rv32i_core
