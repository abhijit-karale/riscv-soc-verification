//=============================================================================
// File: tb_soc_top.sv
// Description: Top-Level System Testbench for RV32I SoC (VR-SOC-01).
// Loads firmware into SRAM, simulates end-to-end CPU execution, decodes
// serial UART output, monitors GPIO activity, and checks PASS signature.
//=============================================================================

`timescale 1ns/1ps

module tb_soc_top;
  import soc_pkg::*;

  logic       clk;
  logic       rst_n;

  logic [7:0] gpio_in;
  logic [7:0] gpio_out;
  logic [7:0] gpio_oe;

  logic       uart_rx;
  logic       uart_tx;

  int test_count  = 0;
  int pass_count  = 0;
  int error_count = 0;

  // Clock generation (50 MHz, 20ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // DUT Instance
  soc_top u_soc (
    .clk           (clk),
    .rst_n         (rst_n),
    .gpio_pins_in  (gpio_in),
    .gpio_pins_out (gpio_out),
    .gpio_pins_oe  (gpio_oe),
    .uart_rx       (uart_rx),
    .uart_tx       (uart_tx)
  );

  // Helper task to preload firmware into SRAM byte arrays
  task automatic load_firmware(input string hex_path);
    int fd, status;
    logic [31:0] word_data;
    int addr = 0;
    string line;

    fd = $fopen(hex_path, "r");
    if (fd == 0) begin
      $display("[FATAL] Could not open firmware file: %s", hex_path);
      $finish;
    end

    while (!$feof(fd)) begin
      status = $fscanf(fd, "%h", word_data);
      if (status == 1) begin
        u_soc.u_sram.mem0[addr] = word_data[7:0];
        u_soc.u_sram.mem1[addr] = word_data[15:8];
        u_soc.u_sram.mem2[addr] = word_data[23:16];
        u_soc.u_sram.mem3[addr] = word_data[31:24];
        addr++;
      end else begin
        // Skip comment line
        void'($fgets(line, fd));
      end
    end
    $fclose(fd);
    $display("[TB] Preloaded %0d instruction words from %s into SRAM.", addr, hex_path);
  endtask

  // UART Serial Output Monitor
  initial begin
    int baud_period_ns;
    logic [7:0] rx_char;

    baud_period_ns = 20 * 5; // Baud divisor = 4 (counts 4..0 = 5 clocks @ 20ns = 100ns/bit)

    forever begin
      // Wait for start bit falling edge
      @(negedge uart_tx);
      #(baud_period_ns * 1.5); // Sample mid of bit 0

      for (int i = 0; i < 8; i++) begin
        rx_char[i] = uart_tx;
        #(baud_period_ns);
      end

      $display("[UART CONSOLE] Received: '%c' (0x%02h)", rx_char, rx_char);
    end
  end

  // Main Test Sequence
  initial begin
    $display("=================================================================");
    $display("       DAY 26-29: RV32I SoC End-to-End System Test (VR-SOC-01)   ");
    $display("=================================================================");

    rst_n   = 0;
    gpio_in = 8'h00;
    uart_rx = 1'b1;

    // Preload firmware before releasing reset
    load_firmware("firmware/diag_tests.hex");

    #40;
    @(negedge clk);
    rst_n = 1;
    $display("[TB] Reset released. RV32I Core executing from SRAM 0x00000000...");

    // Run processor execution for 350 cycles to allow all UART transmissions and memory tests
    repeat (350) @(posedge clk);

    // 1. Verify GPIO Pin Output
    test_count++;
    if (gpio_out === 8'hA5 && gpio_oe === 8'hFF) begin
      $display("[PASS] GPIO Pins Driven Correctly: Pattern = 0xA5, OE = 0xFF");
      pass_count++;
    end else begin
      $display("[FAIL] GPIO Pins mismatch: Got Output=0x%02h, OE=0x%02h", gpio_out, gpio_oe);
      error_count++;
    end

    // 2. Verify Success Signature written to SRAM address 0x200 (word addr = 0x200 / 4 = 128)
    test_count++;
    begin
      logic [31:0] sig;
      sig = {u_soc.u_sram.mem3[128], u_soc.u_sram.mem2[128],
             u_soc.u_sram.mem1[128], u_soc.u_sram.mem0[128]};
      if (sig === 32'hCAFE_BABE) begin
        $display("[PASS] Firmware PASS Signature Found in SRAM [0x200] : 0x%08h", sig);
        pass_count++;
      end else begin
        $display("[FAIL] Firmware Signature mismatch in SRAM [0x200] : Got 0x%08h (Expected 0xCAFEBABE)", sig);
        error_count++;
      end
    end

    // 3. Verify SRAM Local Memory Test Data at 0x100 (word addr = 0x100 / 4 = 64)
    test_count++;
    begin
      logic [31:0] data_val;
      data_val = {u_soc.u_sram.mem3[64], u_soc.u_sram.mem2[64],
                  u_soc.u_sram.mem1[64], u_soc.u_sram.mem0[64]};
      if (data_val === 32'd30) begin
        $display("[PASS] SRAM Data Store & Load Verified at [0x100] : %0d", data_val);
        pass_count++;
      end else begin
        $display("[FAIL] SRAM Data mismatch at [0x100] : Got %0d (Expected 30)", data_val);
        error_count++;
      end
    end

    $display("-----------------------------------------------------------------");
    $display("                       TEST EXECUTION SUMMARY                    ");
    $display("-----------------------------------------------------------------");
    $display(" Total System Checks     : %0d", test_count);
    $display(" Passed Checks           : %0d", pass_count);
    $display(" Failed Checks           : %0d", error_count);
    $display("-----------------------------------------------------------------");

    if (error_count == 0) begin
      $display("[RESULT] SUCCESS: Full RV32I SoC End-to-End System Test PASSED!");
      $display("         VR-SOC-01 (Firmware Execution & Peripherals) PASSED.");
    end else begin
      $display("[RESULT] FAILURE: SoC System Test encountered errors!");
    end
    $display("=================================================================");
    $finish;
  end

endmodule : tb_soc_top
