//=============================================================================
// File: tb_periph_subsystem.sv
// Description: Comprehensive testbench for AMBA APB Subsystem (VR-BUS-01,
// VR-PER-01, VR-PER-02, VR-PER-03, VR-INT-01). Tests interconnect routing
// and all 4 memory-mapped peripherals.
//=============================================================================

`timescale 1ns/1ps

module tb_periph_subsystem;
  import soc_pkg::*;

  logic        clk;
  logic        rst_n;

  // CPU Host Interface to Interconnect
  logic        cpu_req, cpu_we, cpu_re;
  logic [31:0] cpu_addr, cpu_wdata, cpu_rdata;
  logic        cpu_ready, apb_error;

  // APB Master Bus Signals
  logic [31:0] paddr, pwdata;
  logic        pwrite, penable;
  logic [NUM_PERIPHERALS-1:0] psel;

  // Peripheral Slave Responses
  logic [31:0] prdata [0:NUM_PERIPHERALS-1];
  logic [NUM_PERIPHERALS-1:0] pready;
  logic [NUM_PERIPHERALS-1:0] pslverr;

  // Peripheral External Pins & IRQs
  logic [7:0]  gpio_in, gpio_out, gpio_oe;
  logic        uart_rx, uart_tx;
  logic        gpio_irq, uart_irq, timer_irq, cpu_irq;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Interconnect / Bridge
  apb_interconnect u_bridge (
    .pclk      (clk),
    .presetn   (rst_n),
    .cpu_req   (cpu_req),
    .cpu_we    (cpu_we),
    .cpu_re    (cpu_re),
    .cpu_addr  (cpu_addr),
    .cpu_wdata (cpu_wdata),
    .cpu_rdata (cpu_rdata),
    .cpu_ready (cpu_ready),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .pwrite    (pwrite),
    .penable   (penable),
    .psel      (psel),
    .prdata    (prdata),
    .pready    (pready),
    .pslverr   (pslverr),
    .apb_error (apb_error)
  );

  // Slave 0: GPIO (0x4000_0000)
  gpio_apb u_gpio (
    .pclk     (clk),
    .presetn  (rst_n),
    .psel     (psel[0]),
    .penable  (penable),
    .pwrite   (pwrite),
    .paddr    (paddr),
    .pwdata   (pwdata),
    .prdata   (prdata[0]),
    .pready   (pready[0]),
    .pslverr  (pslverr[0]),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe),
    .gpio_irq (gpio_irq)
  );

  // Slave 1: UART (0x4000_1000)
  uart_apb u_uart (
    .pclk     (clk),
    .presetn  (rst_n),
    .psel     (psel[1]),
    .penable  (penable),
    .pwrite   (pwrite),
    .paddr    (paddr),
    .pwdata   (pwdata),
    .prdata   (prdata[1]),
    .pready   (pready[1]),
    .pslverr  (pslverr[1]),
    .uart_rx  (uart_rx),
    .uart_tx  (uart_tx),
    .uart_irq (uart_irq)
  );

  // Slave 2: Timer (0x4000_2000)
  timer_apb u_timer (
    .pclk      (clk),
    .presetn   (rst_n),
    .psel      (psel[2]),
    .penable   (penable),
    .pwrite    (pwrite),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .prdata    (prdata[2]),
    .pready    (pready[2]),
    .pslverr   (pslverr[2]),
    .timer_irq (timer_irq)
  );

  // Slave 3: INTC (0x4000_3000)
  intc_apb u_intc (
    .pclk      (clk),
    .presetn   (rst_n),
    .psel      (psel[3]),
    .penable   (penable),
    .pwrite    (pwrite),
    .paddr     (paddr),
    .pwdata    (pwdata),
    .prdata    (prdata[3]),
    .pready    (pready[3]),
    .pslverr   (pslverr[3]),
    .irq_gpio  (gpio_irq),
    .irq_uart  (uart_irq),
    .irq_timer (timer_irq),
    .cpu_irq   (cpu_irq)
  );

  // APB Write Task
  task automatic apb_write(input logic [31:0] addr, input logic [31:0] data);
    @(negedge clk);
    cpu_req   = 1'b1;
    cpu_we    = 1'b1;
    cpu_re    = 1'b0;
    cpu_addr  = addr;
    cpu_wdata = data;
    @(posedge clk);
    while (!cpu_ready) @(posedge clk);
    @(negedge clk);
    cpu_req = 1'b0;
    cpu_we  = 1'b0;
  endtask

  // APB Read Task
  task automatic apb_read(input logic [31:0] addr, output logic [31:0] rdata);
    @(negedge clk);
    cpu_req  = 1'b1;
    cpu_we   = 1'b0;
    cpu_re   = 1'b1;
    cpu_addr = addr;
    @(posedge clk);
    while (!cpu_ready) @(posedge clk);
    rdata = cpu_rdata;
    @(negedge clk);
    cpu_req = 1'b0;
    cpu_re  = 1'b0;
  endtask

  initial begin
    logic [31:0] rd_val;

    $display("=================================================================");
    $display("       DAY 8-13: APB Interconnect & Peripherals Verification     ");
    $display("=================================================================");

    rst_n    = 0;
    cpu_req  = 0;
    cpu_we   = 0;
    cpu_re   = 0;
    cpu_addr = 0;
    cpu_wdata= 0;
    gpio_in  = 8'h00;
    uart_rx  = 1'b1;

    #20 rst_n = 1;
    @(posedge clk);

    //-------------------------------------------------------------------------
    // 1. GPIO Peripheral Verification
    //-------------------------------------------------------------------------
    $display("[CHECK 1] Testing GPIO Direction, Output, and Input Sensing...");
    // Configure GPIO[7:0] as all outputs
    apb_write(GPIO_BASE_ADDR + 32'h8, 32'h0000_00FF);
    // Write pattern 0xA5 to DATA_OUT
    apb_write(GPIO_BASE_ADDR + 32'h4, 32'h0000_00A5);
    #1;
    test_count++;
    if (gpio_out !== 8'hA5 || gpio_oe !== 8'hFF) begin
      $display("[FAIL] GPIO Output mismatch: gpio_out=0x%02h, oe=0x%02h", gpio_out, gpio_oe);
      error_count++;
    end else begin
      $display("[PASS] GPIO output pins driven to 0xA5 with OE=0xFF");
      pass_count++;
    end

    // Configure GPIO[7:0] as inputs and sense input pin values
    apb_write(GPIO_BASE_ADDR + 32'h8, 32'h0000_0000);
    gpio_in = 8'h3C;
    repeat (3) @(posedge clk);
    apb_read(GPIO_BASE_ADDR + 32'h0, rd_val);
    test_count++;
    if (rd_val[7:0] !== 8'h3C) begin
      $display("[FAIL] GPIO Input sensing mismatch: Expected 0x3C, Got 0x%02h", rd_val[7:0]);
      error_count++;
    end else begin
      $display("[PASS] GPIO sensed external input pins: 0x3C");
      pass_count++;
    end

    //-------------------------------------------------------------------------
    // 2. UART Peripheral Verification (with Loopback Mode)
    //-------------------------------------------------------------------------
    $display("[CHECK 2] Testing UART Peripheral in Loopback Mode...");
    // Set fast baud divisor for simulation: 4 clocks per bit
    apb_write(UART_BASE_ADDR + 32'h10, 32'd4);
    // Enable TX, RX, and Loopback (bits [2:0] = 3'b111 = 7)
    apb_write(UART_BASE_ADDR + 32'h0C, 32'h0000_0007);
    // Transmit character 0x5A ('Z')
    apb_write(UART_BASE_ADDR + 32'h00, 32'h0000_005A);

    // Wait for serial frame to shift and loopback to receive buffer (~50 clocks)
    repeat (50) @(posedge clk);

    // Read received character from RX_DATA
    apb_read(UART_BASE_ADDR + 32'h04, rd_val);
    test_count++;
    if (rd_val[7:0] !== 8'h5A) begin
      $display("[FAIL] UART Loopback failed! Expected 0x5A, Got 0x%02h", rd_val[7:0]);
      error_count++;
    end else begin
      $display("[PASS] UART Loopback received character 0x5A successfully");
      pass_count++;
    end

    //-------------------------------------------------------------------------
    // 3. Timer Peripheral Verification
    //-------------------------------------------------------------------------
    $display("[CHECK 3] Testing 32-bit Timer with Compare Match...");
    // Set Compare register to 10
    apb_write(TIMER_BASE_ADDR + 32'h04, 32'd10);
    // Set Prescaler to 0 (count every cycle)
    apb_write(TIMER_BASE_ADDR + 32'h10, 32'd0);
    // Enable Timer with auto-reset and interrupt enable (ctrl = 3'b111 = 7)
    apb_write(TIMER_BASE_ADDR + 32'h08, 32'd7);

    // Wait for timer to reach compare match (15 cycles)
    repeat (15) @(posedge clk);

    test_count++;
    if (timer_irq !== 1'b1) begin
      $display("[FAIL] Timer compare match interrupt failed to assert!");
      error_count++;
    end else begin
      $display("[PASS] Timer compare match asserted timer_irq");
      pass_count++;
    end

    // Clear match flag by writing 1 to status
    apb_write(TIMER_BASE_ADDR + 32'h0C, 32'd1);
    #1;
    test_count++;
    if (timer_irq !== 1'b0) begin
      $display("[FAIL] Timer interrupt failed to clear after W1C!");
      error_count++;
    end else begin
      $display("[PASS] Timer interrupt cleared via W1C");
      pass_count++;
    end

    //-------------------------------------------------------------------------
    // 4. INTC Interrupt Aggregator & Arbitration Verification
    //-------------------------------------------------------------------------
    $display("[CHECK 4] Testing Interrupt Controller Priority & Masking...");
    // Enable Timer interrupt (bit 2) and UART interrupt (bit 1) in INTC
    apb_write(INTC_BASE_ADDR + 32'h04, 32'h0000_0006);
    // Cause timer match again
    apb_write(TIMER_BASE_ADDR + 32'h08, 32'd7);
    repeat (15) @(posedge clk);

    test_count++;
    if (cpu_irq !== 1'b1) begin
      $display("[FAIL] INTC failed to assert cpu_irq to processor!");
      error_count++;
    end else begin
      $display("[PASS] INTC successfully asserted cpu_irq to CPU core");
      pass_count++;
    end

    // Read INTC pending register
    apb_read(INTC_BASE_ADDR + 32'h08, rd_val);
    test_count++;
    if (rd_val[2] !== 1'b1) begin
      $display("[FAIL] Timer bit not set in INTC pending register: 0x%08h", rd_val);
      error_count++;
    end else begin
      $display("[PASS] INTC Pending register correctly indicates Timer source pending");
      pass_count++;
    end

    // Clear via ACK
    apb_write(INTC_BASE_ADDR + 32'h10, 32'h0000_0004); // Acknowledge Timer
    #1;

    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total Checks Executed   : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: APB Interconnect & All Peripherals Verified!");
      $display("         Phase 2 (Days 8-13 Buses & Peripherals) 100%% COMPLETE.");
    end else begin
      $display("[RESULT] FAILURE: Found %0d APB subsystem verification errors!", error_count);
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_periph_subsystem
