//=============================================================================
// File: tb_uvm_top.sv
// Description: UVM Testbench Top for APB Subsystem.
// Instantiates APB interface, peripheral slaves, registers vif with config_db,
// and initiates UVM test execution.
//=============================================================================

`timescale 1ns/1ps

module tb_uvm_top;
  import uvm_pkg::*;
  import soc_pkg::*;
  import apb_uvm_pkg::*;
  `include "uvm_macros.svh"

  logic pclk;
  logic presetn;

  // Clock generation (100 MHz)
  initial begin
    pclk = 0;
    forever #5 pclk = ~pclk;
  end

  // Reset generation
  initial begin
    presetn = 0;
    #25 presetn = 1;
  end

  // APB Interface Instance
  apb_if intf (pclk, presetn);

  // Peripheral Interconnect & Slave Instantiations
  logic [31:0] prdata_bus [0:NUM_PERIPHERALS-1];
  logic [NUM_PERIPHERALS-1:0] pready_bus;
  logic [NUM_PERIPHERALS-1:0] pslverr_bus;

  // Peripheral External Pins & IRQs
  logic [7:0] gpio_in, gpio_out, gpio_oe;
  logic       uart_rx, uart_tx;
  logic       gpio_irq, uart_irq, timer_irq, cpu_irq;

  // Multiplex responses
  always_comb begin
    case (intf.paddr[15:12])
      4'h0: begin intf.prdata = prdata_bus[0]; intf.pready = pready_bus[0]; intf.pslverr = pslverr_bus[0]; end
      4'h1: begin intf.prdata = prdata_bus[1]; intf.pready = pready_bus[1]; intf.pslverr = pslverr_bus[1]; end
      4'h2: begin intf.prdata = prdata_bus[2]; intf.pready = pready_bus[2]; intf.pslverr = pslverr_bus[2]; end
      4'h3: begin intf.prdata = prdata_bus[3]; intf.pready = pready_bus[3]; intf.pslverr = pslverr_bus[3]; end
      default: begin intf.prdata = 32'h0; intf.pready = 1'b1; intf.pslverr = 1'b1; end
    endcase
  end

  // Slave 0: GPIO
  gpio_apb u_gpio (
    .pclk     (pclk),
    .presetn  (presetn),
    .psel     (intf.psel[0]),
    .penable  (intf.penable),
    .pwrite   (intf.pwrite),
    .paddr    (intf.paddr),
    .pwdata   (intf.pwdata),
    .prdata   (prdata_bus[0]),
    .pready   (pready_bus[0]),
    .pslverr  (pslverr_bus[0]),
    .gpio_in  (8'h55),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe),
    .gpio_irq (gpio_irq)
  );

  // Slave 1: UART
  uart_apb u_uart (
    .pclk     (pclk),
    .presetn  (presetn),
    .psel     (intf.psel[1]),
    .penable  (intf.penable),
    .pwrite   (intf.pwrite),
    .paddr    (intf.paddr),
    .pwdata   (intf.pwdata),
    .prdata   (prdata_bus[1]),
    .pready   (pready_bus[1]),
    .pslverr  (pslverr_bus[1]),
    .uart_rx  (1'b1),
    .uart_tx  (uart_tx),
    .uart_irq (uart_irq)
  );

  // Slave 2: Timer
  timer_apb u_timer (
    .pclk      (pclk),
    .presetn   (presetn),
    .psel      (intf.psel[2]),
    .penable   (intf.penable),
    .pwrite    (intf.pwrite),
    .paddr     (intf.paddr),
    .pwdata    (intf.pwdata),
    .prdata    (prdata_bus[2]),
    .pready    (pready_bus[2]),
    .pslverr   (pslverr_bus[2]),
    .timer_irq (timer_irq)
  );

  // Slave 3: INTC
  intc_apb u_intc (
    .pclk      (pclk),
    .presetn   (presetn),
    .psel      (intf.psel[3]),
    .penable   (intf.penable),
    .pwrite    (intf.pwrite),
    .paddr     (intf.paddr),
    .pwdata    (intf.pwdata),
    .prdata    (prdata_bus[3]),
    .pready    (pready_bus[3]),
    .pslverr   (pslverr_bus[3]),
    .irq_gpio  (gpio_irq),
    .irq_uart  (uart_irq),
    .irq_timer (timer_irq),
    .cpu_irq   (cpu_irq)
  );

  // Register Interface and Launch UVM Test
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "*", "vif", intf);
    run_test("soc_uvm_test");
  end

endmodule : tb_uvm_top
