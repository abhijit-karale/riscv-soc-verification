# RISC-V SoC Architecture Specification

## 1. System Overview
The RISC-V SoC is a 32-bit embedded system built around an RV32I base integer core, an AMBA APB-compatible peripheral interconnect, unified SRAM memory, and memory-mapped input/output (MMIO) peripherals.

```
+---------------------------------------------------------------------------------------+
|                                    RISC-V SoC TOP                                     |
|                                                                                       |
|  +--------------------+                     +---------------------------------------+ |
|  |   RV32I Core       |                     |             Memory System             | |
|  |                    |                     |                                       | |
|  |  +--------------+  |  Instr Bus (Fetch)  |  +---------------------------------+  | |
|  |  | PC & Fetch   |==|====================>|  | Unified / Dual-Port RAM         |  | |
|  |  +--------------+  |  Instr Data [31:0]  |  | 0x0000_0000 - 0x0000_7FFF (32KB)|  | |
|  |         |          |<--------------------|  +---------------------------------+  | |
|  |  +--------------+  |                     |                   ^                   | |
|  |  | RegFile x0-31|  |                     |                   |                   | |
|  |  +--------------+  |                     +-------------------|-------------------+ |
|  |         |          |                                         | Data Bus (R/W)      |
|  |  +--------------+  |                                         v                     |
|  |  | ALU & Branch |  |       Data Bus       +-------------------------------------+  |
|  |  +--------------+  |====================> |        Bus Interconnect / Bridge    |  |
|  |         |          |                      |        (Memory & APB Master)        |  |
|  |  +--------------+  |                      +-------------------------------------+  |
|  |  | Control Unit |  |                                         |                     |
|  |  +--------------+  |                                    APB  | PADDR, PWDATA,      |
|  |         ^          |                                    Bus  | PENABLE, PSELx,     |
|  |         | IRQ      |                                         | PRDATA, PREADY      |
|  +---------|----------+                                         v                     |
|            |                               +---------------------------------------+  |
|            |                               |         APB Peripherals Fabric        |  |
|            |                               |                                       |  |
|    +---------------+  GPIO Interrupt       |  +---------------------------------+  |  |
|    | Interrupt     |<----------------------|--| GPIO Controller (0x4000_0000)   |====> External Pins
|    | Controller    |  UART Interrupt       |  +---------------------------------+  |  |
|    | (Priority     |<----------------------|--| UART Peripheral (0x4000_1000)   |====> TX / RX
|    |  & Masking)   |  Timer Interrupt      |  +---------------------------------+  |  |
|    |               |<----------------------|--| 32-bit Timer    (0x4000_2000)   |  |  |
|    +---------------+                       |  +---------------------------------+  |  |
|                                            +---------------------------------------+  |
+---------------------------------------------------------------------------------------+
```

## 2. Core Specification (RV32I)
- **Standard:** RV32I User-Level ISA version 2.2.
- **Data Path:** 32-bit integer datapath.
- **Registers:** 32 general-purpose registers ($x_0$ to $x_{31}$), with $x_0$ hardwired to zero.
- **Instruction Support:**
  - Computational: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLT`, `SLTU`, `SLL`, `SRL`, `SRA`
  - Immediate: `ADDI`, `SLTI`, `SLTIU`, `XORI`, `ORI`, `ANDI`, `SLLI`, `SRLI`, `SRAI`, `LUI`, `AUIPC`
  - Loads/Stores: `LB`, `LH`, `LW`, `LBU`, `LHU`, `SB`, `SH`, `SW`
  - Control Transfer: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, `JAL`, `JALR`

## 3. Memory Map

| Address Range | Size | Component | Function |
| :--- | :--- | :--- | :--- |
| `0x0000_0000` – `0x0000_7FFF` | 32 KB | SRAM | Instructions and Data RAM |
| `0x4000_0000` – `0x4000_0FFF` | 4 KB | GPIO | Port Data In, Out, Direction, Pin Change IRQ |
| `0x4000_1000` – `0x4000_1FFF` | 4 KB | UART | TX/RX buffer, Status, Control, Baud Divisor |
| `0x4000_2000` – `0x4000_2FFF` | 4 KB | Timer | 32-bit Counter, Comparator, Prescaler, Match IRQ |
| `0x4000_3000` – `0x4000_3FFF` | 4 KB | INTC | Interrupt Status, Enable, Priority, ACK |

## 4. Bus Protocol: AMBA APB
- **Signals:** `PCLK`, `PRESETn`, `PADDR[31:0]`, `PSELx`, `PENABLE`, `PWRITE`, `PWDATA[31:0]`, `PRDATA[31:0]`, `PREADY`, `PSLVERR`.
- **Phases:**
  1. `IDLE`: Normal waiting state.
  2. `SETUP`: Address, write data, control driven, `PSEL` asserted.
  3. `ACCESS`: `PENABLE` asserted. Slave drives `PREADY`. Transfer completes at the rising clock edge when `PENABLE && PREADY` is true.

## 5. Subsystem Details
- **GPIO:** 8-bit bidirectional with configurable direction mask and edge-triggered interrupt.
- **UART:** 8-N-1 serial framing with internal baud rate generator and status flags (`TX_EMPTY`, `RX_READY`).
- **Timer:** Continuous 32-bit up-counter with auto-reset or free-run, compare register, and interrupt generation.
- **Interrupt Controller:** Fixed and programmable priority resolver aggregating peripheral interrupts into a single CPU interrupt line.
