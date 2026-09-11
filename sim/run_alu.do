#=============================================================================
# File: run_alu.do
# Description: QuestaSim simulation script for Day 2 RV32I ALU
#=============================================================================

# Create work library if it does not exist
if [file exists work] {
    vdel -lib work -all
}
vlib work

# Compile source files
vlog -sv rtl/common/soc_pkg.sv \
         rtl/alu/rv32i_alu.sv \
         tb/assertions/alu_assertions.sv \
         tb/sv_tb/tb_alu.sv

# Optimize and load design
vsim -c -coverage -assertdebug work.tb_alu

# Run simulation to completion
run -all

# Exit batch simulation
quit -f
