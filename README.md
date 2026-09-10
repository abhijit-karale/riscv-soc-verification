# RISC-V SoC Verification using SystemVerilog, UVM, SVA and Formal Verification

A complete, industry-oriented 30-day hardware design and verification repository implementing a 32-bit RISC-V (RV32I) SoC with an AMBA APB peripheral subsystem and verification suite.

## Project Architecture
- **CPU Core:** RV32I base integer instruction set (ALU, Register File, ImmGen, Decoder, Branch Unit, PC/IF).
- **Interconnect:** AMBA APB compatible bus interface with address decoding and wait-state support.
- **Peripherals:** Memory-mapped GPIO, 8-N-1 UART, 32-bit Timer with compare match, and prioritized Interrupt Controller.
- **Memory Subsystem:** 32 KB SRAM accommodating program and data sections.

## Verification Methodology
- **Languages & Frameworks:** IEEE 1800 SystemVerilog, UVM 1.2, SystemVerilog Assertions (SVA).
- **Simulators:** Siemens QuestaSim / ModelSim, Icarus Verilog.
- **Formal Verification:** SymbiYosys / Yosys for formal property proofs.
- **Automation:** Python test harness and regression runner.

## Directory Structure
- `rtl/`: Synthesizable SystemVerilog RTL modules.
- `tb/`: SystemVerilog testbenches, UVM environment, assertions, and golden reference model.
- `formal/`: Formal verification properties and `.sby` scripts.
- `docs/`: Architectural specifications and verification plan.
- `sim/`: Simulation logs, artifacts, and build libraries.
- `waveforms/`: Saved waveform dumps (`.wlf`, `.vcd`).
- `reports/`: Coverage reports, regression outputs, and formal proofs.
