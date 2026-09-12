//=============================================================================
// File: apb_protocol_sva.sv
// Description: AMBA APB Protocol Assertions Checker (VR-BUS-01).
// Verifies signal stability across SETUP and ACCESS phases, PENABLE delay,
// and PREADY handshake termination rules.
//=============================================================================

`timescale 1ns/1ps

module apb_protocol_sva
  import soc_pkg::*;
(
  input logic                      pclk,
  input logic                      presetn,
  input logic [31:0]               paddr,
  input logic [31:0]               pwdata,
  input logic                      pwrite,
  input logic                      penable,
  input logic [NUM_PERIPHERALS-1:0] psel,
  input logic [31:0]               prdata,
  input logic                      pready,
  input logic                      pslverr
);

  // 1. PENABLE must be LOW when PSEL rises (SETUP Phase)
  property p_setup_penable_low;
    @(posedge pclk) disable iff (!presetn)
    ($rose(|psel)) |-> (!penable);
  endproperty
  a_setup_penable_low: assert property (p_setup_penable_low)
    else $error("[APB SVA FAIL] PENABLE was high during SETUP phase!");

  // 2. PENABLE must assert exactly one cycle after PSEL rises
  property p_enable_delay;
    @(posedge pclk) disable iff (!presetn)
    ($rose(|psel)) |=> (penable);
  endproperty
  a_enable_delay: assert property (p_enable_delay)
    else $error("[APB SVA FAIL] PENABLE did not assert one cycle after PSEL!");

  // 3. PADDR, PWRITE, PSEL must remain stable while PENABLE is asserted until PREADY
  property p_addr_stable_until_ready;
    @(posedge pclk) disable iff (!presetn)
    (penable && !pready) |=> $stable(paddr) && $stable(pwrite) && $stable(psel);
  endproperty
  a_addr_stable_until_ready: assert property (p_addr_stable_until_ready)
    else $error("[APB SVA FAIL] PADDR/PWRITE/PSEL mutated before PREADY!");

  // 4. PWDATA must remain stable during write transfer
  property p_wdata_stable_during_write;
    @(posedge pclk) disable iff (!presetn)
    (penable && pwrite && !pready) |=> $stable(pwdata);
  endproperty
  a_wdata_stable_during_write: assert property (p_wdata_stable_during_write)
    else $error("[APB SVA FAIL] PWDATA mutated during write transfer before PREADY!");

  // 5. Transfer completes when PENABLE && PREADY is high
  property p_transfer_completion;
    @(posedge pclk) disable iff (!presetn)
    (penable && pready) |=> (!penable);
  endproperty
  a_transfer_completion: assert property (p_transfer_completion)
    else $error("[APB SVA FAIL] PENABLE remained high after transfer completion!");

endmodule : apb_protocol_sva
