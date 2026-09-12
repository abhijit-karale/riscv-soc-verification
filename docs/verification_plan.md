# RISC-V SoC Verification Plan & Signoff Matrix

## 1. Overview and Verification Goals
The objective of this verification plan is to achieve complete functional, assertion, coverage, and system-level signoff closure on the RV32I SoC across the 30-day curriculum. Verification spans block-level, subsystem-level, and top-level environments using:
1. Pure SystemVerilog directed and constrained random testbenches
2. SystemVerilog Assertions (SVA) for protocol and architectural invariant checks
3. Full UVM 1.2 environment with Sequencers, Drivers, Monitors, Coverage Collectors, and Scoreboards
4. Formal verification proofs using bounded model checking for architectural invariants
5. Bare-metal assembly diagnostic firmware booting and executing end-to-end on the integrated SoC

---

## 2. Feature Matrix & Verification Signoff Status

| Feature ID | Block | Description | Method | Target Metric | Final Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **VR-PKG-01** | Global Package | Package definitions, opcodes, and memory boundaries | SV TB (`tb_pkg_sanity`) | 100% constant consistency | **PASSED (Day 1)** |
| **VR-CPU-01** | PC & Fetch | Sequential increment (+4), branch target, jump target, stall | SV TB (`tb_fetch`) | 100% Branch/Jump paths | **PASSED (Day 6)** |
| **VR-CPU-02** | RegFile | 32 registers, $x_0$ constant 0, dual-read, single-write | SV TB (`tb_regfile`) + Formal | Formal BMC proof of $x_0=0$ | **PASSED (Day 3, 24)** |
| **VR-CPU-03** | ALU | 10 operations, corner values (`0x0`, `0xFFFFFFFF`, signs) | SV TB + SVA Covergroups | 100% Opcode & Corner bins | **PASSED (Day 2)** |
| **VR-CPU-04** | Decoder/Imm | All 6 instruction formats (R, I, S, B, U, J) decoded correctly | SV TB (`tb_decoder`) | 100% RV32I instruction bins | **PASSED (Day 4)** |
| **VR-CPU-05** | Load/Store | Byte, Halfword, Word accesses, sign/zero extension, alignment | SV TB (`tb_branch_lsu`) | All access sizes & signs | **PASSED (Day 5)** |
| **VR-BUS-01** | APB Interconnect | Setup/Access phase timing, multi-slave decoding, slave routing | SV TB + Formal BMC | Zero protocol violations | **PASSED (Day 8-9, 24)** |
| **VR-PER-01** | GPIO | Port direction toggling, input pin sensing, pin-change interrupt | SV Subsystem + UVM Agent | Read/Write/IRQ closure | **PASSED (Day 10, 14-20)** |
| **VR-PER-02** | UART | TX shift register, RX framing, baud generator, loopback mode | SV Subsystem + Console Monitor | Baud accuracy & characters | **PASSED (Day 11, 26-29)** |
| **VR-PER-03** | Timer | 32-bit counter roll-over, prescaler, compare match interrupt | SV Subsystem Testbench | Interrupt latency verification | **PASSED (Day 12)** |
| **VR-INT-01** | INTC | Priority arbitration between GPIO, UART, Timer; masking & ACK | SV Subsystem + Formal BMC | Priority ordering verified | **PASSED (Day 13, 25)** |
| **VR-UVM-01** | UVM Environment | APB Agent (Driver, Monitor, Sequencer), Scoreboard, Predictor | UVM 1.2 Test Suite | 0 Errors, 0 Fatals, 100% Matches | **PASSED (Day 14-20)** |
| **VR-SVA-01** | Protocol SVA | APB timing properties and CPU core invariants | SVA Concurrent Assertions | 100% Assertions Clean | **PASSED (Day 21-23)** |
| **VR-FRM-01** | Formal Verification | SymbiYosys BMC proofs for RegFile x0, APB, and INTC | SymbiYosys / Formal SV Models | Mathematical proof | **PASSED (Day 24-25)** |
| **VR-SOC-01** | SoC Top System | End-to-end bare-metal firmware execution from 32 KB SRAM | System Test (`tb_soc_top`) | `0xCAFEBABE` PASS signature | **PASSED (Day 26-30)** |

---

## 3. SystemVerilog Assertions (SVA) Coverage
1. **Reset State Assertions:** Checked via `core_invariants_sva.sv`.
2. **x0 Constant Invariance:** Proved via bounded model checking in `formal/regfile_formal.sv` and checked dynamically in `tb/sv_tb/tb_regfile.sv`.
3. **APB Protocol Properties (`tb/assertions/apb_protocol_sva.sv`):**
   - Address and write control stability throughout transfer phases.
   - PENABLE sequencing (strictly asserted 1 cycle after PSEL).
   - Handshake closure on `PENABLE && PREADY`.
   - Setup phase assertion checks.

---

## 4. UVM Architecture Signoff
- **Agent:** Standard UVM 1.2 active agent driving APB transfers with cycle-accurate timing.
- **Coverage:** Comprehensive coverage collector monitoring transfer directions, addresses, and strobe combinations.
- **Scoreboard:** Compares RTL APB outputs against self-contained reference model with zero mismatches.
- **Result:** Successfully simulated in QuestaSim with UVM 1.2 runtime library.

---

## 5. Regression & Automated Signoff
All 12 checks across the 30-day curriculum are automated in `scripts/run_all_regressions.py` and documented in `reports/final_signoff.md`.
- **Pass Rate:** 100% (12/12 testbenches and formal suites passing)
- **Status:** **COMPLETE SIGNED-OFF**
