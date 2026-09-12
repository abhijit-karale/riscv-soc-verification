//=============================================================================
// File: apb_uvm_pkg.sv
// Description: Comprehensive UVM 1.2 Package for AMBA APB Subsystem Verification.
// Implements sequence items, sequencer, driver, monitor, agent, scoreboard,
// functional coverage subscriber, reference model, and environment.
//=============================================================================

`timescale 1ns/1ps

package apb_uvm_pkg;
  import uvm_pkg::*;
  import soc_pkg::*;
  `include "uvm_macros.svh"

  //---------------------------------------------------------------------------
  // 1. APB Sequence Item
  //---------------------------------------------------------------------------
  class apb_seq_item extends uvm_sequence_item;
    rand logic [31:0] addr;
    rand logic [31:0] data;
    rand bit          we; // 1 = Write, 0 = Read
    logic [31:0]      rdata;
    bit               error;

    `uvm_object_utils_begin(apb_seq_item)
      `uvm_field_int(addr,  UVM_ALL_ON)
      `uvm_field_int(data,  UVM_ALL_ON)
      `uvm_field_int(we,    UVM_ALL_ON)
      `uvm_field_int(rdata, UVM_ALL_ON)
      `uvm_field_int(error, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint c_periph_addr {
      addr inside {
        [GPIO_BASE_ADDR  : GPIO_BASE_ADDR  + 32'h0FF],
        [UART_BASE_ADDR  : UART_BASE_ADDR  + 32'h0FF],
        [TIMER_BASE_ADDR : TIMER_BASE_ADDR + 32'h0FF],
        [INTC_BASE_ADDR  : INTC_BASE_ADDR  + 32'h0FF]
      };
      addr[1:0] == 2'b00; // Word aligned
    }

    function new(string name = "apb_seq_item");
      super.new(name);
    endfunction
  endclass : apb_seq_item

  //---------------------------------------------------------------------------
  // 2. APB Agent Configuration Object
  //---------------------------------------------------------------------------
  class apb_config extends uvm_object;
    `uvm_object_utils(apb_config)
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "apb_config");
      super.new(name);
    endfunction
  endclass : apb_config

  //---------------------------------------------------------------------------
  // 3. APB Driver
  //---------------------------------------------------------------------------
  class apb_driver extends uvm_driver #(apb_seq_item);
    `uvm_component_utils(apb_driver)

    virtual apb_if vif;

    function new(string name = "apb_driver", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("DRV", "Virtual interface apb_if not found in config_db!")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      // Initialize bus to IDLE
      vif.psel    <= '0;
      vif.penable <= 1'b0;
      vif.pwrite  <= 1'b0;
      vif.paddr   <= 32'h0;
      vif.pwdata  <= 32'h0;

      forever begin
        seq_item_port.get_next_item(req);
        drive_transfer(req);
        seq_item_port.item_done();
      end
    endtask

    virtual task drive_transfer(apb_seq_item item);
      int slave_idx;

      // Decode slave index from address
      case (item.addr[15:12])
        4'h0: slave_idx = 0;
        4'h1: slave_idx = 1;
        4'h2: slave_idx = 2;
        4'h3: slave_idx = 3;
        default: slave_idx = 0;
      endcase

      // SETUP Phase
      @(posedge vif.pclk);
      vif.paddr       <= item.addr;
      vif.pwrite      <= item.we;
      vif.pwdata      <= item.data;
      vif.psel        <= '0;
      vif.psel[slave_idx] <= 1'b1;
      vif.penable     <= 1'b0;

      // ACCESS Phase
      @(posedge vif.pclk);
      vif.penable <= 1'b1;

      // Wait for PREADY
      while (!vif.pready) @(posedge vif.pclk);

      // Sample Read Data and Error
      if (!item.we) begin
        item.rdata = vif.prdata;
      end
      item.error = vif.pslverr;

      // Return to IDLE
      @(posedge vif.pclk);
      vif.psel    <= '0;
      vif.penable <= 1'b0;
    endtask
  endclass : apb_driver

  //---------------------------------------------------------------------------
  // 4. APB Sequencer
  //---------------------------------------------------------------------------
  typedef uvm_sequencer #(apb_seq_item) apb_sequencer;

  //---------------------------------------------------------------------------
  // 5. APB Monitor
  //---------------------------------------------------------------------------
  class apb_monitor extends uvm_monitor;
    `uvm_component_utils(apb_monitor)

    virtual apb_if vif;
    uvm_analysis_port #(apb_seq_item) mon_ap;

    function new(string name = "apb_monitor", uvm_component parent = null);
      super.new(name, parent);
      mon_ap = new("mon_ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
        `uvm_fatal("MON", "Virtual interface apb_if not found in config_db!")
      end
    endfunction

    virtual task run_phase(uvm_phase phase);
      apb_seq_item item;

      forever begin
        @(posedge vif.pclk);
        if (|vif.psel && vif.penable && vif.pready) begin
          item = apb_seq_item::type_id::create("mon_item");
          item.addr  = vif.paddr;
          item.we    = vif.pwrite;
          item.data  = vif.pwdata;
          item.rdata = vif.prdata;
          item.error = vif.pslverr;
          mon_ap.write(item);
        end
      end
    endtask
  endclass : apb_monitor

  //---------------------------------------------------------------------------
  // 6. APB Functional Coverage Subscriber
  //---------------------------------------------------------------------------
  class apb_coverage extends uvm_subscriber #(apb_seq_item);
    `uvm_component_utils(apb_coverage)

    apb_seq_item item_cov;

    covergroup apb_cg;
      option.per_instance = 1;

      cp_addr_periph: coverpoint item_cov.addr[15:12] {
        bins gpio  = {4'h0};
        bins uart  = {4'h1};
        bins timer = {4'h2};
        bins intc  = {4'h3};
      }

      cp_rw: coverpoint item_cov.we {
        bins read  = {1'b0};
        bins write = {1'b1};
      }

      cross_periph_rw: cross cp_addr_periph, cp_rw;
    endgroup

    function new(string name = "apb_coverage", uvm_component parent = null);
      super.new(name, parent);
      apb_cg = new();
    endfunction

    virtual function void write(apb_seq_item t);
      item_cov = t;
      apb_cg.sample();
    endfunction
  endclass : apb_coverage

  //---------------------------------------------------------------------------
  // 7. APB Agent
  //---------------------------------------------------------------------------
  class apb_agent extends uvm_agent;
    `uvm_component_utils(apb_agent)

    apb_driver    drv;
    apb_sequencer seqr;
    apb_monitor   mon;
    apb_coverage  cov;
    apb_config    cfg;

    function new(string name = "apb_agent", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      cfg = apb_config::type_id::create("cfg");
      mon = apb_monitor::type_id::create("mon", this);
      cov = apb_coverage::type_id::create("cov", this);

      if (cfg.is_active == UVM_ACTIVE) begin
        drv  = apb_driver::type_id::create("drv", this);
        seqr = apb_sequencer::type_id::create("seqr", this);
      end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (cfg.is_active == UVM_ACTIVE) begin
        drv.seq_item_port.connect(seqr.seq_item_export);
      end
      mon.mon_ap.connect(cov.analysis_export);
    endfunction
  endclass : apb_agent

  //---------------------------------------------------------------------------
  // 8. Behavioral Reference Model
  //---------------------------------------------------------------------------
  class soc_ref_model extends uvm_component;
    `uvm_component_utils(soc_ref_model)

    logic [31:0] shadow_reg [logic [31:0]];

    function new(string name = "soc_ref_model", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    function void write_reg(logic [31:0] addr, logic [31:0] val);
      shadow_reg[addr] = val;
    endfunction

    function logic [31:0] get_reg(logic [31:0] addr);
      if (shadow_reg.exists(addr)) return shadow_reg[addr];
      return 32'h0000_0000;
    endfunction
  endclass : soc_ref_model

  //---------------------------------------------------------------------------
  // 9. Scoreboard
  //---------------------------------------------------------------------------
  class soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soc_scoreboard)

    uvm_analysis_imp #(apb_seq_item, soc_scoreboard) sb_imp;
    soc_ref_model ref_model;

    int match_count = 0;
    int mismatch_count = 0;

    function new(string name = "soc_scoreboard", uvm_component parent = null);
      super.new(name, parent);
      sb_imp = new("sb_imp", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      ref_model = soc_ref_model::type_id::create("ref_model", this);
    endfunction

    virtual function void write(apb_seq_item item);
      if (item.we) begin
        ref_model.write_reg(item.addr, item.data);
      end else begin
        // Verify read back for configured registers (e.g. DATA_OUT or DIR)
        if (item.addr == (GPIO_BASE_ADDR + 32'h4) || item.addr == (GPIO_BASE_ADDR + 32'h8)) begin
          logic [31:0] exp = ref_model.get_reg(item.addr);
          if (item.rdata[7:0] !== exp[7:0]) begin
            `uvm_error("SB", $sformatf("Mismatch at 0x%08h! Exp: 0x%02h, Got: 0x%02h",
                       item.addr, exp[7:0], item.rdata[7:0]))
            mismatch_count++;
          end else begin
            match_count++;
          end
        end else begin
          match_count++;
        end
      end
    endfunction

    virtual function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("SB_REPORT", $sformatf("Matches: %0d, Mismatches: %0d", match_count, mismatch_count), UVM_LOW)
    endfunction
  endclass : soc_scoreboard

  //---------------------------------------------------------------------------
  // 10. UVM Environment
  //---------------------------------------------------------------------------
  class soc_env extends uvm_env;
    `uvm_component_utils(soc_env)

    apb_agent      agent;
    soc_scoreboard sb;

    function new(string name = "soc_env", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      agent = apb_agent::type_id::create("agent", this);
      sb    = soc_scoreboard::type_id::create("sb", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      agent.mon.mon_ap.connect(sb.sb_imp);
    endfunction
  endclass : soc_env

  //---------------------------------------------------------------------------
  // 11. Sequences
  //---------------------------------------------------------------------------
  class apb_directed_seq extends uvm_sequence #(apb_seq_item);
    `uvm_object_utils(apb_directed_seq)

    function new(string name = "apb_directed_seq");
      super.new(name);
    endfunction

    task write_reg(logic [31:0] addr, logic [31:0] data);
      req = apb_seq_item::type_id::create("req");
      start_item(req);
      req.addr = addr;
      req.data = data;
      req.we   = 1'b1;
      finish_item(req);
    endtask

    task read_reg(logic [31:0] addr);
      req = apb_seq_item::type_id::create("req");
      start_item(req);
      req.addr = addr;
      req.we   = 1'b0;
      finish_item(req);
    endtask

    virtual task body();
      `uvm_info("SEQ", "Executing Directed UVM Sequence to all peripherals...", UVM_LOW)

      // 1. GPIO: Set Direction & Write Data Out
      write_reg(GPIO_BASE_ADDR + 32'h08, 32'h0000_00FF);
      write_reg(GPIO_BASE_ADDR + 32'h04, 32'h0000_0055);
      read_reg(GPIO_BASE_ADDR + 32'h04);

      // 2. UART: Configure Baud & Control
      write_reg(UART_BASE_ADDR + 32'h10, 32'd4);
      write_reg(UART_BASE_ADDR + 32'h0C, 32'h0000_0007);
      read_reg(UART_BASE_ADDR + 32'h0C);

      // 3. Timer: Configure Compare & Control
      write_reg(TIMER_BASE_ADDR + 32'h04, 32'd100);
      write_reg(TIMER_BASE_ADDR + 32'h08, 32'd7);
      read_reg(TIMER_BASE_ADDR + 32'h08);

      // 4. INTC: Configure Enable & Priority
      write_reg(INTC_BASE_ADDR + 32'h04, 32'h0000_0007);
      read_reg(INTC_BASE_ADDR + 32'h04);
    endtask
  endclass : apb_directed_seq

  class apb_random_seq extends uvm_sequence #(apb_seq_item);
    `uvm_object_utils(apb_random_seq)

    function new(string name = "apb_random_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info("SEQ", "Executing 50 Random APB Transactions...", UVM_LOW)
      repeat (50) begin
        req = apb_seq_item::type_id::create("rand_req");
        start_item(req);
        if (!req.randomize()) `uvm_fatal("RAND", "Randomization failed!")
        finish_item(req);
      end
    endtask
  endclass : apb_random_seq

  //---------------------------------------------------------------------------
  // 12. Top UVM Test
  //---------------------------------------------------------------------------
  class soc_uvm_test extends uvm_test;
    `uvm_component_utils(soc_uvm_test)

    soc_env env;

    function new(string name = "soc_uvm_test", uvm_component parent = null);
      super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = soc_env::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
      apb_directed_seq dir_seq;
      apb_random_seq   rnd_seq;

      phase.raise_objection(this);
      `uvm_info("TEST", "Starting UVM Verification Test for APB Subsystem", UVM_LOW)

      dir_seq = apb_directed_seq::type_id::create("dir_seq");
      dir_seq.start(env.agent.seqr);

      rnd_seq = apb_random_seq::type_id::create("rnd_seq");
      rnd_seq.start(env.agent.seqr);

      #100;
      `uvm_info("TEST", "Completed UVM Verification Test for APB Subsystem", UVM_LOW)
      phase.drop_objection(this);
    endtask
  endclass : soc_uvm_test

endpackage : apb_uvm_pkg
