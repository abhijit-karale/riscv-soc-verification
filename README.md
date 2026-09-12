# RISC-V SoC Verification using SystemVerilog, UVM, SVA and Formal Verification

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Regression: 100% PASS](https://img.shields.io/badge/Regression-100%25%20PASS-brightgreen.svg)](reports/final_signoff.md)
[![Simulator: QuestaSim 10.7c](https://img.shields.io/badge/Simulator-QuestaSim%2010.7c-blue.svg)](file:///docs/verification_plan.md)
[![UVM: 1.2](https://img.shields.io/badge/UVM-1.2-purple.svg)](tb/uvm/)

A complete, production-grade 30-day hardware design and verification repository implementing a 32-bit RISC-V (RV32I) SoC with an AMBA APB peripheral subsystem and verification suite spanning SV testbenches, UVM 1.2, SystemVerilog Assertions (SVA), SymbiYosys Formal BMC proofs, and bare-metal firmware execution.

---

## 1. Project Architecture

- **CPU Core (`rv32i_core`):** RV32I base integer instruction set. Single-cycle execution datapath with decoupled instruction fetch (`rv32i_fetch`), 32x32 register file (`rv32i_regfile`), instruction decoder (`rv32i_decoder`), immediate generator (`rv32i_imm_gen`), ALU (`rv32i_alu`), branch comparison unit (`rv32i_branch_unit`), and load/store alignment unit (`rv32i_lsu`).
- **Memory Subsystem (`sram_sp_32k`):** 32 KB byte-addressable single-port SRAM mapped from `0x0000_0000` to `0x0000_7FFF` with byte write enables.
- **Interconnect (`apb_interconnect`):** AMBA APB bridge decoder routing CPU transactions across 4 peripheral address windows (`0x4000_0000` to `0x4000_3FFF`) with wait-state stalling support.
- **Peripherals:**
  - **GPIO (`gpio_apb`):** 8-bit bidirectional general-purpose I/O with pin-change interrupt generation (`0x4000_0000`).
  - **UART (`uart_apb`):** 8-N-1 serial transceiver with programmable baud divisor and loopback mode (`0x4000_1000`).
  - **Timer (`timer_apb`):** 32-bit counter with programmable prescaler, compare-match interrupt, and auto-reload (`0x4000_2000`).
  - **INTC (`intc_apb`):** Prioritized interrupt controller arbitrating GPIO, UART, and Timer interrupts (`0x4000_3000`).

---

## 2. Directory Structure

```
RISV/
├── rtl/                        # Synthesizable SystemVerilog RTL
│   ├── common/soc_pkg.sv       # Architectural definitions, opcodes, memory map
│   ├── alu/rv32i_alu.sv        # RV32I 32-bit ALU
│   ├── regfile/rv32i_regfile.sv# 32x32 Register File with x0 hardwired to 0
│   ├── cpu/                    # Core sub-modules (Fetch, Decoder, ImmGen, Branch, LSU, Core)
│   ├── memory/sram_sp_32k.sv   # 32 KB SRAM memory controller
│   ├── bus/apb_interconnect.sv # AMBA APB Interconnect decoder bridge
│   ├── peripherals/            # GPIO, UART, Timer, INTC APB slaves
│   └── soc_top.sv              # Integrated SoC top-level wrapper
├── tb/                         # Verification Environment
│   ├── sv_tb/                  # Unit and subsystem SystemVerilog testbenches
│   ├── uvm/                    # Full UVM 1.2 environment (Agents, Drivers, Monitors, Scoreboard)
│   └── assertions/             # SVA protocol checkers (APB & Core invariants)
├── formal/                     # SymbiYosys formal verification proofs (.sby & .sv)
├── firmware/                   # Diagnostic assembly source and hex images (diag_tests.hex)
├── scripts/                    # Regression runners (run_all_regressions.py)
├── docs/                       # Architecture, 30-Day Roadmap, and Verification Plan
└── reports/                    # Final signoff reports (final_signoff.md)
```

---

## 3. 30-Day Curriculum Execution & Signoff Matrix

All 30 days are complete and verified with **100% PASS** rate across 12 regression testbenches and formal suites:

| Phase | Days | Focus Areas | Deliverables | Status |
| :---: | :---: | :--- | :--- | :---: |
| **Phase 1** | Days 1–7 | CPU Core Datapath & Sub-blocks | ALU, RegFile, Decoder, ImmGen, Branch, LSU, Fetch, Core | **100% PASS** |
| **Phase 2** | Days 8–13 | 32KB SRAM & APB Subsystem | SRAM, APB Bridge, GPIO, UART, Timer, INTC | **100% PASS** |
| **Phase 3** | Days 14–20 | UVM 1.2 Verification Environment | APB Agent, Sequencer, Driver, Monitor, Scoreboard | **100% PASS** |
| **Phase 4** | Days 21–25 | SVA Assertions & Formal Proofs | APB SVA, Core Invariants, RegFile/APB/INTC Formal BMC | **100% PASS** |
| **Phase 5** | Days 26–30 | SoC Integration, Firmware & Signoff | SoC Top, Assembly Diag Firmware, System Simulation, Signoff | **100% PASS** |

Detailed results are available in [`reports/final_signoff.md`](file:///reports/final_signoff.md).

---

## 4. How to Run Regressions

### Prerequisites
- Python 3.8+
- Siemens QuestaSim / ModelSim (`vlog`, `vsim`) with UVM 1.2 runtime

### Execute Master Regression Suite
To compile all modules, run all 10 simulation testbenches, check all SVA/formal models, and regenerate the signoff report:

```powershell
python scripts/run_all_regressions.py
```

### Run Specific Testbenches
- **Run RV32I ALU Testbench with SVA:**
  ```powershell
  python scripts/run_alu_sim.py
  ```
- **Run UVM 1.2 APB Testbench:**
  ```powershell
  vlog -sv rtl/common/soc_pkg.sv rtl/peripherals/gpio_apb.sv tb/uvm/apb_if.sv tb/uvm/apb_uvm_pkg.sv tb/uvm/tb_uvm_top.sv
  vsim -c -do "run -all; quit -f" -sv_lib C:/questasim64_10.7c/uvm-1.1d/win64/uvm_dpi work.tb_uvm_top
  ```
- **Run End-to-End SoC System Simulation with Firmware:**
  ```powershell
  vlog -sv rtl/common/soc_pkg.sv rtl/alu/rv32i_alu.sv rtl/regfile/rv32i_regfile.sv rtl/cpu/rv32i_decoder.sv rtl/cpu/rv32i_imm_gen.sv rtl/cpu/rv32i_branch_unit.sv rtl/cpu/rv32i_lsu.sv rtl/cpu/rv32i_fetch.sv rtl/cpu/rv32i_core.sv rtl/memory/sram_sp_32k.sv rtl/bus/apb_interconnect.sv rtl/peripherals/gpio_apb.sv rtl/peripherals/uart_apb.sv rtl/peripherals/timer_apb.sv rtl/peripherals/intc_apb.sv rtl/soc_top.sv tb/sv_tb/tb_soc_top.sv
  vsim -c -do "run -all; quit -f" work.tb_soc_top
  ```
