# 30-Day RISC-V SoC Design and Verification Roadmap

This roadmap defines the day-by-day objectives, RTL sub-blocks, verification milestones, and signoff criteria for building and verifying the 32-bit RV32I SoC with AMBA APB peripherals.

---

## Phase 1: RV32I CPU Datapath & Core Design (Days 1–7)

| Day | Topic | RTL Deliverable | Verification Environment & Milestones | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 1** | SoC Architectural Specification & Packages | `rtl/common/soc_pkg.sv` | Global package sanity check, memory map verification | **Done** |
| **Day 2** | Arithmetic Logic Unit (ALU) & Invariants | `rtl/alu/rv32i_alu.sv` | SV TB (`tb_alu.sv`), SVA (`alu_assertions.sv`), 100% coverage closure (`VR-CPU-03`) | **Done** |
| **Day 3** | Register File (32 x 32-bit, Dual Read, Single Write) | `rtl/regfile/rv32i_regfile.sv` | Directed & random reads/writes, x0-is-zero invariant, dual-port read conflict tests (`VR-CPU-02`) | Planned |
| **Day 4** | Immediate Generator & Instruction Decoder | `rtl/cpu/rv32i_decoder.sv`, `rv32i_imm_gen.sv` | Decoding verification across R, I, S, B, U, J types (`VR-CPU-04`) | Planned |
| **Day 5** | Branch & Comparison Unit / Load-Store Unit | `rtl/cpu/rv32i_branch_unit.sv`, `rv32i_lsu.sv` | Branch condition evaluation, signed/unsigned comparisons, memory width alignment (`VR-CPU-05`) | Planned |
| **Day 6** | Program Counter & Instruction Fetch Unit | `rtl/cpu/rv32i_fetch.sv` | Sequential increment (+4), branch target, jump target, reset lock (`VR-CPU-01`) | Planned |
| **Day 7** | Single-Cycle RV32I Core Integration | `rtl/cpu/rv32i_core.sv` | Core-level testbench, RISC-V basic assembly instruction sequences | Planned |

---

## Phase 2: Memory & AMBA APB Bus Subsystem (Days 8–13)

| Day | Topic | RTL Deliverable | Verification Environment & Milestones | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 8** | Unified SRAM Memory Controller (32 KB) | `rtl/memory/sram_sp_32k.sv` | Read/Write timing, byte-enable masks, boundary access tests | Planned |
| **Day 9** | AMBA APB Interconnect & Decoder Bridge | `rtl/bus/apb_interconnect.sv` | Protocol checkers (SETUP, ACCESS, PENABLE, PREADY, PSLVERR) (`VR-BUS-01`) | Planned |
| **Day 10** | Memory-Mapped GPIO Controller | `rtl/peripherals/gpio_apb.sv` | Direction mask, pin sensing, edge-triggered interrupt test (`VR-PER-01`) | Planned |
| **Day 11** | UART Transmitter / Receiver (8-N-1) | `rtl/peripherals/uart_apb.sv` | Baud generator accuracy, TX shift register, RX framing, FIFO/status (`VR-PER-02`) | Planned |
| **Day 12** | 32-bit Timer with Compare Match & Prescaler | `rtl/peripherals/timer_apb.sv` | Free-run counter, rollover, compare-match IRQ generation (`VR-PER-03`) | Planned |
| **Day 13** | Prioritized Interrupt Controller (INTC) | `rtl/peripherals/intc_apb.sv` | Multi-source arbitration, masking, pending status, ACK handshake (`VR-INT-01`) | Planned |

---

## Phase 3: UVM Verification Environment (Days 14–20)

| Day | Topic | UVM Architecture | Verification Focus | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 14** | UVM Architecture & Transaction Modeling | `tb/uvm/apb_seq_item.sv`, `apb_config.sv` | Transaction item fields, constraints, print/copy/compare methods | Planned |
| **Day 15** | UVM Sequencer & Driver | `tb/uvm/apb_sequencer.sv`, `apb_driver.sv` | Non-blocking & wait-state APB pin-level driving | Planned |
| **Day 16** | UVM Monitor & Coverage Collector | `tb/uvm/apb_monitor.sv`, `apb_coverage.sv` | Protocol bus sampling, functional coverage covergroups | Planned |
| **Day 17** | UVM Agent & Environment Assembly | `tb/uvm/apb_agent.sv`, `soc_env.sv` | Active/passive agent packaging, configuration DB hookup | Planned |
| **Day 18** | Reference Model & Predictor | `tb/uvm/soc_ref_model.sv` | Golden transaction predictor for peripheral registers | Planned |
| **Day 19** | UVM Scoreboard Implementation | `tb/uvm/soc_scoreboard.sv` | Transaction comparison, out-of-order matching, error tracking | Planned |
| **Day 20** | Base Test and Constrained Sequences | `tb/uvm/tests/base_test.sv`, sequences | Virtual sequences coordinating APB master traffic | Planned |

---

## Phase 4: SVA Protocol Checkers & Formal Verification (Days 21–25)

| Day | Topic | Verification Strategy | Verification Scope | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 21** | APB Bus Protocol Assertions (SVA) | `tb/assertions/apb_protocol_sva.sv` | Setup/Access timing, address stability, PREADY handshake | Planned |
| **Day 22** | Core Architectural Invariant Assertions | `tb/assertions/core_invariants_sva.sv` | PC alignment, x0 constant invariance, illegal instruction traps | Planned |
| **Day 23** | Formal Proofs for ALU & RegFile | `formal/regfile_formal.sby` | SymbiYosys bounded model checking (BMC) on RegFile | Planned |
| **Day 24** | Formal Proofs for APB Slave Arbiter | `formal/apb_formal.sby` | Mutual exclusion, starvation-freedom, decoding sanity | Planned |
| **Day 25** | Formal Proofs for Interrupt Controller | `formal/intc_formal.sby` | Priority inversion proof, interrupt clearance proof | Planned |

---

## Phase 5: SoC Top-Level Integration & Signoff (Days 26–30)

| Day | Topic | Deliverables | Verification Scope | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 26** | SoC Top Integration (Core + Bus + Peripherals) | `rtl/soc_top.sv` | Pinouts, clock distribution, active-low reset tree | Planned |
| **Day 27** | Firmware Toolchain & Assembly Diagnostics | `firmware/diag_tests.s`, linker script | Directed assembly self-test programs compiled into hex | Planned |
| **Day 28** | SoC System Simulation with Firmware Execution | `tb/sv_tb/tb_soc_top.sv` | Execution of diagnostics from simulated SRAM (`VR-SOC-01`) | Planned |
| **Day 29** | Peripheral End-to-End Tests via Firmware | `firmware/periph_test.c` | UART echo, GPIO toggle, Timer periodic interrupt handling | Planned |
| **Day 30** | Regression Closure, Code Coverage & Signoff | `reports/final_signoff.md` | Final coverage metrics ($\ge 90\%$), assertion pass, project completion | Planned |
