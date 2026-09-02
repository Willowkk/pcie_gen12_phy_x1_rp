`timescale 1ns/1ps
module tb_PHY_V_001;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;

  phy_top_harness h();
  logic test_done;

  phy_assertions #(.REQUEST_BOUND(512)) safety (
    .ctrl_clk_i(h.ctrl_clk), .ctrl_rst_ni(h.ctrl_rst_n),
    .link_clk_i(h.link_clk), .link_rst_ni(h.link_rst_n),
    .port_reset_ni(h.port_reset_n), .phy_ready_i(h.phy_ready),
    .phy_link_up_i(h.phy_link_up), .phy_data_active_i(h.phy_dll_data_active),
    .dll_tx_valid_i(h.dll_tx_valid), .dll_tx_ready_i(h.dll_tx_ready),
    .dll_tx_data_i(h.dll_tx_data), .dll_tx_keep_i(h.dll_tx_keep),
    .dll_tx_sop_i(h.dll_tx_sop), .dll_tx_eop_i(h.dll_tx_eop),
    .dll_tx_kind_i(h.dll_tx_kind), .dll_tx_abort_i(h.dll_tx_abort),
    .dll_rx_valid_i(h.dll_rx_valid), .dll_rx_ready_i(h.dll_rx_ready),
    .dll_rx_data_i(h.dll_rx_data), .dll_rx_keep_i(h.dll_rx_keep),
    .dll_rx_sop_i(h.dll_rx_sop), .dll_rx_eop_i(h.dll_rx_eop),
    .dll_rx_kind_i(h.dll_rx_kind), .dll_rx_abort_i(h.dll_rx_abort),
    .request_i(1'b0), .done_i(1'b0), .fail_i(1'b0)
  );

  phy_watchdog #(.MAX_CTRL_CYCLES(2000), .TEST_ID("PHY-V-001")) watchdog (
    .ctrl_clk_i(h.ctrl_clk), .ctrl_rst_ni(h.ctrl_rst_n), .done_i(test_done)
  );

  initial begin
    tb_start("PHY-V-001", 64'h0000_0000_0000_001f);
    test_done = 1'b0;
    repeat (4) @(posedge h.ctrl_clk);
    tb_check_eq1(h.phy_link_up, 1'b0, "link is down during reset");
    tb_check_eq1(h.phy_data_active, 1'b0, "data path is inactive during reset");
    tb_check_eq1(h.dll_rx_valid, 1'b0, "no packet is submitted during reset");
    tb_hit(0);

    h.release_resets();
    repeat (80) @(posedge h.ctrl_clk);
    tb_check_eq1(h.phy_link_up, 1'b0, "ready does not auto-start Detect");
    tb_check_eq6(h.phy_state, LTSSM_RESET, "state remains Reset before ENABLE");
    tb_hit(1);

    @(negedge h.link_clk);
    h.dll_tx_valid=1; h.dll_tx_sop=1; h.dll_tx_eop=1;
    h.dll_tx_keep=2'b01; h.dll_tx_data=16'h00a5;
    @(posedge h.link_clk);
    tb_check_eq1(h.dll_tx_ready, 1'b0, "TX SOP is not accepted while inactive");
    @(negedge h.link_clk); h.dll_tx_valid=0; h.dll_tx_sop=0; h.dll_tx_eop=0;
    tb_hit(2);

    h.send_mgmt(PHY_CMD_ENABLE, 8'h00, 64);
    repeat (16) @(posedge h.ctrl_clk);
    tb_check((h.phy_state == LTSSM_DETECT) || (h.phy_state == LTSSM_RESET),
             "ENABLE moves only toward Detect and never directly to a trained state");
    tb_check_eq1(h.phy_data_active, 1'b0, "Detect cannot expose packet traffic");
    tb_hit(3);

    h.clocks.pulse_port_reset(3, 3ns);
    repeat (6) @(posedge h.ctrl_clk);
    tb_check_eq6(h.phy_state, LTSSM_RESET, "port reset returns the LTSSM to Reset");
    tb_check_eq1(h.phy_link_up, 1'b0, "port reset clears link context");
    repeat (16) @(posedge h.ctrl_clk);
    tb_check_eq6(h.phy_state, LTSSM_RESET, "port reset cleared the enable latch");
    tb_hit(4);

    h.clocks.pulse_link_reset(2, 1ns);
    repeat (4) @(posedge h.link_clk);
    tb_check_eq1(h.dll_rx_valid, 1'b0, "link reset clears RX valid");
    tb_check_eq1(h.phy_dll_data_active, 1'b0, "link-domain active view is safe");

    test_done = 1'b1;
    tb_finish("PHY-V-001");
  end
endmodule
