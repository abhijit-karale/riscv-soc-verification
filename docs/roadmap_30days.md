# 30-Day RISC-V SoC Design and Verification Roadmap

This roadmap defines the day-by-day objectives, RTL sub-blocks, verification milestones, and signoff criteria for building and verifying the 32-bit RV32I SoC with AMBA APB peripherals.

---

## Phase 1: RV32I CPU Datapath & Core Design (Days 1–7)

| Day | Topic | RTL Deliverable | Verification Environment & Milestones | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 1** | SoC Architectural Specification & Packages | `rtl/common/soc_pkg.sv` | Global package sanity check, memory map verification (`tb_pkg_sanity.sv`) | **Done** |
| **Day 2** | Arithmetic Logic Unit (ALU) & Invariants | `rtl/alu/rv32i_alu.sv` | SV TB (`tb_alu.sv`), SVA (`alu_assertions.sv`), 100% coverage closure (`VR-CPU-03`) | **Done** |
| **Day 3** | Register File (32 x 32-bit, Dual Read, Single Write) | `rtl/regfile/rv32i_regfile.sv` | Directed & random reads/writes, x0-is-zero invariant, write forwarding (`VR-CPU-02`) | **Done** |
| **Day 4** | Immediate Generator & Instruction Decoder | `rtl/cpu/rv32i_decoder.sv`, `rv32i_imm_gen.sv` | Decoding verification across R, I, S, B, U, J types (`VR-CPU-04`) | **Done** |
| **Day 5** | Branch & Comparison Unit / Load-Store Unit | `rtl/cpu/rv32i_branch_unit.sv`, `rv32i_lsu.sv` | Branch condition evaluation, signed/unsigned comparisons, memory width alignment (`VR-CPU-05`) | **Done** |
| **Day 6** | Program Counter & Instruction Fetch Unit | `rtl/cpu/rv32i_fetch.sv` | Sequential increment (+4), branch target, jump target, reset lock (`VR-CPU-01`) | **Done** |
| **Day 7** | Single-Cycle RV32I Core Integration | `rtl/cpu/rv32i_core.sv` | Core-level testbench (`tb_core.sv`), RISC-V assembly instruction execution (`VR-CPU-01..05`) | **Done** |

---

## Phase 2: Memory & AMBA APB Bus Subsystem (Days 8–13)

| Day | Topic | RTL Deliverable | Verification Environment & Milestones | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 8** | Unified SRAM Memory Controller (32 KB) | `rtl/memory/sram_sp_32k.sv` | Read/Write timing, byte-enable masks, boundary access tests | **Done** |
| **Day 9** | AMBA APB Interconnect & Decoder Bridge | `rtl/bus/apb_interconnect.sv` | Protocol checkers (SETUP, ACCESS, PENABLE, PREADY, PSLVERR) (`VR-BUS-01`) | **Done** |
| **Day 10** | Memory-Mapped GPIO Controller | `rtl/peripherals/gpio_apb.sv` | Direction mask, pin sensing, edge-triggered interrupt test (`VR-PER-01`) | **Done** |
| **Day 11** | UART Transmitter / Receiver (8-N-1) | `rtl/peripherals/uart_apb.sv` | Baud generator accuracy, TX shift register, RX framing, FIFO/status (`VR-PER-02`) | **Done** |
| **Day 12** | 32-bit Timer with Compare Match & Prescaler | `rtl/peripherals/timer_apb.sv` | Free-run counter, rollover, compare-match IRQ generation (`VR-PER-03`) | **Done** |
| **Day 13** | Prioritized Interrupt Controller (INTC) | `rtl/peripherals/intc_apb.sv` | Multi-source arbitration, masking, pending status, ACK handshake (`VR-INT-01`) | **Done** |

---

## Phase 3: UVM Verification Environment (Days 14–20)

| Day | Topic | UVM Architecture | Verification Focus | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 14** | UVM Architecture & Transaction Modeling | `tb/uvm/apb_if.sv`, `apb_uvm_pkg.sv` | APB Interface, Sequence Items, constraints, print/copy/compare | **Done** |
| **Day 15** | UVM Sequencer & Driver | `tb/uvm/apb_uvm_pkg.sv` | Non-blocking & wait-state APB pin-level driving | **Done** |
| **Day 16** | UVM Monitor & Coverage Collector | `tb/uvm/apb_uvm_pkg.sv` | Protocol bus sampling, functional coverage covergroups | **Done** |
| **Day 17** | UVM Agent & Environment Assembly | `tb/uvm/apb_uvm_pkg.sv` | Active agent packaging, configuration DB hookup | **Done** |
| **Day 18** | Reference Model & Predictor | `tb/uvm/apb_uvm_pkg.sv` | Golden transaction predictor for peripheral registers | **Done** |
| **Day 19** | UVM Scoreboard Implementation | `tb/uvm/apb_uvm_pkg.sv` | Transaction comparison, out-of-order matching, error tracking | **Done** |
| **Day 20** | Base Test and Constrained Sequences | `tb/uvm/tb_uvm_top.sv` | Complete simulation run in QuestaSim with UVM 1.2 runtime (`VR-UVM-01`) | **Done** |

---

## Phase 4: SVA Protocol Checkers & Formal Verification (Days 21–25)

| Day | Topic | Verification Strategy | Verification Scope | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 21** | APB Bus Protocol Assertions (SVA) | `tb/assertions/apb_protocol_sva.sv` | Setup/Access timing, address stability, PREADY handshake | **Done** |
| **Day 22** | Core Architectural Invariant Assertions | `tb/assertions/core_invariants_sva.sv` | PC alignment, x0 constant invariance, illegal instruction traps | **Done** |
| **Day 23** | ALU & RegFile SVA Integration | `tb/assertions/alu_assertions.sv` | Bound mathematical operations and corner value checks | **Done** |
| **Day 24** | Formal Proofs for RegFile & APB Interconnect | `formal/regfile_formal.sv`, `apb_formal.sv` | SymbiYosys bounded model checking (BMC) on RegFile & APB | **Done** |
| **Day 25** | Formal Proofs for Interrupt Controller | `formal/intc_formal.sv` | Priority inversion proof, interrupt clearance proof (`VR-INT-01`) | **Done** |

---

## Phase 5: SoC Top-Level Integration & Signoff (Days 26–30)

| Day | Topic | Deliverables | Verification Scope | Status |
| :---: | :--- | :--- | :--- | :---: |
| **Day 26** | SoC Top Integration (Core + Bus + Peripherals) | `rtl/soc_top.sv` | Core, SRAM, Interconnect, GPIO, UART, Timer, INTC | **Done** |
| **Day 27** | Firmware Diagnostics & Memory Image | `firmware/diag_tests.s`, `diag_tests.hex` | Assembly self-test program preloaded into SRAM image | **Done** |
| **Day 28** | SoC System Simulation with Firmware Execution | `tb/sv_tb/tb_soc_top.sv` | Full end-to-end SoC simulation in QuestaSim (`VR-SOC-01`) | **Done** |
| **Day 29** | Peripheral MMIO Verification via Firmware | `tb/sv_tb/tb_soc_top.sv` | GPIO 0xA5 output, UART serial monitor, SRAM signature | **Done** |
| **Day 30** | Master Regression Runner & Final Signoff | `scripts/run_all_regressions.py`, `reports/final_signoff.md` | 100% testbench pass rate (12/12 checks), signoff approved | **Done** |
