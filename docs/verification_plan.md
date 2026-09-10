# RISC-V SoC Verification Plan

## 1. Overview and Verification Goals
The objective of this verification plan is to achieve complete functional, assertion, and coverage closure on the RV32I SoC. Verification spans block-level, subsystem-level, and top-level environments using:
1. Pure SystemVerilog directed and constrained random tests
2. SystemVerilog Assertions (SVA) for protocol and architectural checks
3. Full UVM 1.2 environment with Sequencers, Drivers, Monitors, Scoreboard, and Reference Model
4. Formal verification using SymbiYosys for invariant proving

## 2. Feature Matrix & Test Intent

| Feature ID | Block | Description | Method | Target Metric |
| :--- | :--- | :--- | :--- | :--- |
| **VR-CPU-01** | PC & Fetch | Sequential increment, branch target, jump target, reset lock | SV TB / SVA | 100% Branch/Jump paths |
| **VR-CPU-02** | RegFile | 32 registers, $x_0$ constant 0, dual-read, single-write conflict | SV TB / Formal | Formal proof of $x_0=0$ |
| **VR-CPU-03** | ALU | 10 operations, corner values (`0x00000000`, `0xFFFFFFFF`, signs) | SV TB / Coverage | 100% Opcode & Corner bins |
| **VR-CPU-04** | Decoder/Imm | All 6 instruction formats (R, I, S, B, U, J) decoded correctly | SV TB / Coverage | 100% RV32I instruction bins |
| **VR-CPU-05** | Load/Store | Byte, Halfword, Word accesses, alignment verification | SV TB / SVA | All access sizes & signs |
| **VR-BUS-01** | APB Interconnect | Setup/Access phase timing, multi-slave decoding, slave error | UVM / SVA | Zero protocol violations |
| **VR-PER-01** | GPIO | Port direction toggling, input pin sensing, interrupt generation | UVM | Read/Write/IRQ closure |
| **VR-PER-02** | UART | TX shift register, RX framing, baud generator correctness | UVM | Baud accuracy, loopback |
| **VR-PER-03** | Timer | 32-bit counter roll-over, compare match interrupt | UVM / SVA | Interrupt latency verification |
| **VR-INT-01** | INTC | Arbitration between GPIO, UART, Timer; masking and ACK | UVM | Priority ordering verified |
| **VR-SOC-01** | SoC Top | End-to-end firmware execution from SRAM | System Test | Clean test program pass |

## 3. SystemVerilog Assertions (SVA) Strategy
1. **Reset State Assertions:** Ensure registers and state machines enter valid initial states immediately following reset deassertion.
2. **x0 Constant Invariance:** Assert that register $x_0$ always reads as zero under all clock cycles and write conditions.
3. **APB Protocol Properties:**
   - `PADDR`, `PWRITE`, `PSEL` must remain stable between `SETUP` and `ACCESS`.
   - `PENABLE` must assert exactly one cycle after `PSEL` asserts.
   - Handshake completes only when `PENABLE && PREADY`.

## 4. UVM Architecture
- **UVM Agent:** Active agent containing `uvm_driver`, `uvm_sequencer`, and `uvm_monitor` driving APB transactions and monitoring responses.
- **Scoreboard & Predictor:** Compares monitored pin activity against an independent behavioral reference model of the RV32I CPU and peripherals.
- **Functional Coverage:** Functional covergroups sampling instruction types, ALU operands, register combinations, memory addresses, and APB states.

## 5. Coverage Goals
- **Functional Coverage:** $\ge 90\%$ closure across all bins.
- **Code Coverage:** High line, branch, and toggle coverage on synthesis-targeted RTL.
- **Assertion Coverage:** 100% of defined properties exercised without failure.
