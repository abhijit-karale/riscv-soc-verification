//=============================================================================
// File: soc_top.sv
// Description: Top-Level Synthesizable System-on-Chip (SoC) for 32-bit RV32I.
// Integrates RV32I Core, 32 KB SRAM, Bus Interconnect, APB Bridge, and
// Memory-Mapped Peripherals (GPIO, UART, Timer, INTC).
//=============================================================================

`timescale 1ns/1ps

module soc_top
  import soc_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // External GPIO Pins
  input  logic [7:0]  gpio_pins_in,
  output logic [7:0]  gpio_pins_out,
  output logic [7:0]  gpio_pins_oe,

  // External UART Serial Line
  input  logic        uart_rx,
  output logic        uart_tx
);

  //---------------------------------------------------------------------------
  // Internal Bus Interconnect Signals
  //---------------------------------------------------------------------------
  // Core Instruction Bus (Fetch)
  logic [31:0] instr_addr;
  logic [31:0] instr_data;

  // Core Data Bus (LSU)
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;
  logic [3:0]  data_byte_en;
  logic        data_we;
  logic        data_re;

  // Interrupt Signals
  logic        cpu_irq;
  logic        irq_ack;
  logic        gpio_irq;
  logic        uart_irq;
  logic        timer_irq;

  // SRAM Data Interface Signals
  logic [31:0] sram_data_rdata;
  logic        sram_data_we;
  logic        sram_data_re;

  // APB Bus Interface Signals
  logic        apb_cpu_req;
  logic [31:0] apb_cpu_rdata;
  logic        apb_cpu_ready;
  logic        apb_error;

  logic [31:0] paddr, pwdata;
  logic        pwrite, penable;
  logic [NUM_PERIPHERALS-1:0] psel;
  wire  [31:0] prdata_bus [0:NUM_PERIPHERALS-1];
  logic [NUM_PERIPHERALS-1:0] pready_bus;
  logic [NUM_PERIPHERALS-1:0] pslverr_bus;

  // Address Routing: SRAM vs APB MMIO
  logic is_sram_access;
  logic is_apb_access;

  assign is_sram_access = (data_addr < APB_BASE_ADDR);
  assign is_apb_access  = (data_addr >= APB_BASE_ADDR);

  assign sram_data_we   = data_we && is_sram_access;
  assign sram_data_re   = data_re && is_sram_access;

  assign apb_cpu_req    = (data_we || data_re) && is_apb_access;

  // Data Read Multiplexer
  assign data_rdata     = (is_apb_access) ? apb_cpu_rdata : sram_data_rdata;

  logic core_stall;
  assign core_stall = (data_we || data_re) && is_apb_access && !apb_cpu_ready;

  //---------------------------------------------------------------------------
  // 1. RV32I Processor Core
  //---------------------------------------------------------------------------
  rv32i_core u_core (
    .clk          (clk),
    .rst_n        (rst_n),
    .instr_addr   (instr_addr),
    .instr_data   (instr_data),
    .data_addr    (data_addr),
    .data_wdata   (data_wdata),
    .data_rdata   (data_rdata),
    .data_byte_en (data_byte_en),
    .data_we      (data_we),
    .data_re      (data_re),
    .stall        (core_stall),
    .ext_irq      (cpu_irq),
    .irq_ack      (irq_ack)
  );

  //---------------------------------------------------------------------------
  // 2. Unified 32 KB Dual-Port SRAM
  //---------------------------------------------------------------------------
  sram_sp_32k u_sram (
    .clk          (clk),
    .rst_n        (rst_n),
    .instr_addr   (instr_addr),
    .instr_data   (instr_data),
    .data_addr    (data_addr),
    .data_wdata   (data_wdata),
    .data_rdata   (sram_data_rdata),
    .data_byte_en (data_byte_en),
    .data_we      (sram_data_we),
    .data_re      (sram_data_re)
  );

  //---------------------------------------------------------------------------
  // 3. APB Interconnect & Decoder Bridge
  //---------------------------------------------------------------------------
  apb_interconnect u_apb_bridge (
    .pclk      (clk),
    .presetn   (rst_n),
    .cpu_req   (apb_cpu_req),
    .cpu_we    (data_we),
    .cpu_re    (data_re),
    .cpu_addr  (data_addr),
    .cpu_wdata (data_wdata),
    .cpu_rdata (apb_cpu_rdata),
    .cpu_ready (apb_cpu_ready),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .pwrite    (pwrite),
    .penable   (penable),
    .psel      (psel),
    .prdata    (prdata_bus),
    .pready    (pready_bus),
    .pslverr   (pslverr_bus),
    .apb_error (apb_error)
  );

  //---------------------------------------------------------------------------
  // 4. Peripheral Slaves
  //---------------------------------------------------------------------------
  // Slave 0: GPIO (0x4000_0000 - 0x4000_0FFF)
  gpio_apb u_gpio (
    .pclk     (clk),
    .presetn  (rst_n),
    .psel     (psel[0]),
    .penable  (penable),
    .pwrite   (pwrite),
    .paddr    (paddr),
    .pwdata   (pwdata),
    .prdata   (prdata_bus[0]),
    .pready   (pready_bus[0]),
    .pslverr  (pslverr_bus[0]),
    .gpio_in  (gpio_pins_in),
    .gpio_out (gpio_pins_out),
    .gpio_oe  (gpio_pins_oe),
    .gpio_irq (gpio_irq)
  );

  // Slave 1: UART (0x4000_1000 - 0x4000_1FFF)
  uart_apb u_uart (
    .pclk     (clk),
    .presetn  (rst_n),
    .psel     (psel[1]),
    .penable  (penable),
    .pwrite   (pwrite),
    .paddr    (paddr),
    .pwdata   (pwdata),
    .prdata   (prdata_bus[1]),
    .pready   (pready_bus[1]),
    .pslverr  (pslverr_bus[1]),
    .uart_rx  (uart_rx),
    .uart_tx  (uart_tx),
    .uart_irq (uart_irq)
  );

  // Slave 2: Timer (0x4000_2000 - 0x4000_2FFF)
  timer_apb u_timer (
    .pclk      (clk),
    .presetn   (rst_n),
    .psel      (psel[2]),
    .penable   (penable),
    .pwrite    (pwrite),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .prdata    (prdata_bus[2]),
    .pready    (pready_bus[2]),
    .pslverr   (pslverr_bus[2]),
    .timer_irq (timer_irq)
  );

  // Slave 3: INTC (0x4000_3000 - 0x4000_3FFF)
  intc_apb u_intc (
    .pclk      (clk),
    .presetn   (rst_n),
    .psel      (psel[3]),
    .penable   (penable),
    .pwrite    (pwrite),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .prdata    (prdata_bus[3]),
    .pready    (pready_bus[3]),
    .pslverr   (pslverr_bus[3]),
    .irq_gpio  (gpio_irq),
    .irq_uart  (uart_irq),
    .irq_timer (timer_irq),
    .cpu_irq   (cpu_irq)
  );

endmodule : soc_top
