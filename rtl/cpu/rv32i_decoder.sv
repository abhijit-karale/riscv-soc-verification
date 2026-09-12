//=============================================================================
// File: rv32i_decoder.sv
// Description: Synthesizable instruction decoder for RV32I ISA.
// Decodes instruction fields and generates control signals for datapath.
//=============================================================================

`timescale 1ns/1ps

module rv32i_decoder
  import soc_pkg::*;
(
  input  logic [31:0]   instr,

  // Instruction Fields
  output logic [4:0]    rs1_addr,
  output logic [4:0]    rs2_addr,
  output logic [4:0]    rd_addr,
  output logic [2:0]    funct3,
  output logic [6:0]    funct7,
  output opcode_e       opcode,

  // Control Signals
  output alu_op_e       alu_op,
  output logic          src_a_sel,      // 0: rs1_data, 1: PC
  output logic [1:0]    src_b_sel,      // 0: rs2_data, 1: immediate, 2: 4 (for link PC+4)
  output logic [1:0]    wb_sel,         // 0: alu_result, 1: mem_data, 2: pc_plus_4
  output logic          reg_write,      // Register file write enable
  output logic          mem_read,       // Data memory read enable
  output logic          mem_write,      // Data memory write enable
  output logic          branch,         // Branch instruction
  output logic          jump,           // JAL or JALR
  output logic          jalr,           // Specifically JALR (target = rs1 + imm)
  output mem_width_e    mem_width,      // Byte, halfword, word access size
  output branch_op_e    branch_op,      // BEQ, BNE, BLT, BGE, BLTU, BGEU
  output logic          illegal_instr   // Illegal instruction detected
);

  // Extract bitfields
  assign opcode   = opcode_e'(instr[6:0]);
  assign rd_addr  = instr[11:7];
  assign funct3   = instr[14:12];
  assign rs1_addr = instr[19:15];
  assign rs2_addr = instr[24:20];
  assign funct7   = instr[31:25];

  assign mem_width = mem_width_e'(funct3);
  assign branch_op = branch_op_e'(funct3);

  always_comb begin
    // Defaults
    alu_op        = ALU_ADD;
    src_a_sel     = 1'b0; // rs1
    src_b_sel     = 2'd0; // rs2
    wb_sel        = 2'd0; // alu_result
    reg_write     = 1'b0;
    mem_read      = 1'b0;
    mem_write     = 1'b0;
    branch        = 1'b0;
    jump          = 1'b0;
    jalr          = 1'b0;
    illegal_instr = 1'b0;

    case (opcode)
      // R-type: Register-Register ALU Operations
      OPCODE_R_TYPE: begin
        reg_write = 1'b1;
        src_a_sel = 1'b0; // rs1
        src_b_sel = 2'd0; // rs2
        wb_sel    = 2'd0; // alu_result

        case (funct3)
          3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
          3'b001: alu_op = ALU_SLL;
          3'b010: alu_op = ALU_SLT;
          3'b011: alu_op = ALU_SLTU;
          3'b100: alu_op = ALU_XOR;
          3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
          3'b110: alu_op = ALU_OR;
          3'b111: alu_op = ALU_AND;
          default: illegal_instr = 1'b1;
        endcase
      end

      // I-type: Register-Immediate ALU Operations
      OPCODE_I_TYPE: begin
        reg_write = 1'b1;
        src_a_sel = 1'b0; // rs1
        src_b_sel = 2'd1; // imm_i
        wb_sel    = 2'd0; // alu_result

        case (funct3)
          3'b000: alu_op = ALU_ADD; // ADDI
          3'b001: alu_op = ALU_SLL; // SLLI
          3'b010: alu_op = ALU_SLT; // SLTI
          3'b011: alu_op = ALU_SLTU;// SLTIU
          3'b100: alu_op = ALU_XOR; // XORI
          3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRAI / SRLI
          3'b110: alu_op = ALU_OR;  // ORI
          3'b111: alu_op = ALU_AND; // ANDI
          default: illegal_instr = 1'b1;
        endcase
      end

      // Load Instructions (LB, LH, LW, LBU, LHU)
      OPCODE_LOAD: begin
        reg_write = 1'b1;
        src_a_sel = 1'b0; // rs1 (base address)
        src_b_sel = 2'd1; // imm_i (offset)
        alu_op    = ALU_ADD;
        mem_read  = 1'b1;
        wb_sel    = 2'd1; // mem_data
      end

      // Store Instructions (SB, SH, SW)
      OPCODE_STORE: begin
        src_a_sel = 1'b0; // rs1 (base address)
        src_b_sel = 2'd1; // imm_s (offset)
        alu_op    = ALU_ADD;
        mem_write = 1'b1;
      end

      // Branch Instructions (BEQ, BNE, BLT, BGE, BLTU, BGEU)
      OPCODE_BRANCH: begin
        branch    = 1'b1;
        src_a_sel = 1'b0;
        src_b_sel = 2'd0;
      end

      // Jump and Link (JAL)
      OPCODE_JAL: begin
        jump      = 1'b1;
        reg_write = 1'b1;
        wb_sel    = 2'd2; // pc + 4
      end

      // Jump and Link Register (JALR)
      OPCODE_JALR: begin
        jump      = 1'b1;
        jalr      = 1'b1;
        reg_write = 1'b1;
        wb_sel    = 2'd2; // pc + 4
      end

      // Load Upper Immediate (LUI)
      OPCODE_LUI: begin
        reg_write = 1'b1;
        alu_op    = ALU_PASS;
        src_b_sel = 2'd1; // imm_u
        wb_sel    = 2'd0; // alu_result
      end

      // Add Upper Immediate to PC (AUIPC)
      OPCODE_AUIPC: begin
        reg_write = 1'b1;
        src_a_sel = 1'b1; // PC
        src_b_sel = 2'd1; // imm_u
        alu_op    = ALU_ADD;
        wb_sel    = 2'd0; // alu_result
      end

      // System / Environment (ECALL, EBREAK, FENCE)
      OPCODE_SYSTEM: begin
        // Supported as NOP/trap hook
      end

      default: begin
        illegal_instr = 1'b1;
      end
    endcase
  end

endmodule : rv32i_decoder
