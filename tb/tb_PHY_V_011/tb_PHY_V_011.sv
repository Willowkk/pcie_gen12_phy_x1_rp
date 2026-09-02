`timescale 1ns/1ps
module tb_PHY_V_011;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;

  phy_ltssm_tb_fixture h();
  logic test_done;

  phy_watchdog #(.MAX_CTRL_CYCLES(5000), .TEST_ID("PHY-V-011")) watchdog (
    .ctrl_clk_i(h.ctrl_clk_i), .ctrl_rst_ni(h.ctrl_rst_ni), .done_i(test_done)
  );

  property p_pm_result_exclusive;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      !(h.port_pm_done_o && h.port_pm_fail_o);
  endproperty
  assert property (p_pm_result_exclusive)
    else tb_check(1'b0, "PM done and fail asserted together");

  property p_l23_is_not_link_up;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      (h.lt_state_o == LTSSM_L2_L3_READY) |->
        (!h.lt_link_up_o && !h.lt_data_active_o && h.lt_gt_tx_electrical_idle_o);
  endproperty
  assert property (p_l23_is_not_link_up)
    else tb_check(1'b0, "L2/L3 Ready exposed an active link");

  property p_power_mapping;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      h.lt_gt_power_req_o |->
        (((h.lt_state_o == LTSSM_L0S) &&
          ((h.lt_gt_power_state_o == PHY_POWER_P0S) ||
           (h.lt_gt_power_state_o == PHY_POWER_P0))) ||
         ((h.lt_state_o == LTSSM_L1) &&
          ((h.lt_gt_power_state_o == PHY_POWER_P1) ||
           (h.lt_gt_power_state_o == PHY_POWER_P0))) ||
         ((h.lt_state_o == LTSSM_L2_L3_READY) &&
          ((h.lt_gt_power_state_o == PHY_POWER_P2) ||
           (h.lt_gt_power_state_o == PHY_POWER_P0))));
  endproperty
  assert property (p_power_mapping)
    else tb_check(1'b0, "GT P-state request was confused with LTSSM state");

  initial begin
    logic done;
    logic failed;
    tb_start("PHY-V-011", 64'h0000_0000_0000_001f);
    test_done = 1'b0;
    h.reset_and_enter_l0();

    h.issue_pm(PM_REQ_L0S, 1'b0);
    h.wait_substate(LTSSM_SS_L0S_TX_ENTRY, 16, "local TX L0s.Entry");
    tb_check_eq4(h.lt_tx_mode_o, TX_MODE_EIOS, "L0s entry sends EIOS");
    h.pulse_os_done();
    h.wait_substate(LTSSM_SS_L0S_TX_IDLE, 16, "local TX L0s.Idle");
    h.wait_power_request(PHY_POWER_P0S, 16);
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b0;
    h.wait_pm_result(done, failed, 32);
    tb_check(done && !failed, "L0s entry reports success");
    repeat (3) begin
      @(posedge h.ctrl_clk_i);
      tb_check_eq1(h.port_pm_done_o, 1'b1, "PM result holds under response backpressure");
    end
    h.acknowledge_pm_result();
    tb_check_eq1(h.lt_link_up_o, 1'b1, "L0s retains established link context");
    tb_check_eq1(h.lt_data_active_o, 1'b0, "L0s blocks packet traffic");

    h.issue_pm(PM_REQ_L0S, 1'b1);
    h.wait_substate(LTSSM_SS_L0S_TX_FTS, 16, "local TX L0s.FTS exit");
    h.wait_power_request(PHY_POWER_P0, 16);
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b0;
    repeat (2) @(posedge h.ctrl_clk_i);
    tb_check_eq4(h.lt_tx_mode_o, TX_MODE_FTS, "L0s exit transmits saved-N_FTS sequence");
    h.pulse_os_done();
    h.wait_state(LTSSM_L0, 16, "FTS completion exits local L0s");
    h.wait_pm_result(done, failed, 16);
    tb_check(done && !failed, "L0s exit reports success");
    h.acknowledge_pm_result();
    tb_hit(0);

    @(negedge h.ctrl_clk_i); h.os_rx_eios_evt_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.os_rx_eios_evt_i = 1'b0;
    h.wait_substate(LTSSM_SS_L0S_RX_ENTRY, 16, "RX L0s has an independent Entry state");
    @(negedge h.ctrl_clk_i); h.crr_rx_electrical_idle_i = 1'b1;
    h.wait_substate(LTSSM_SS_L0S_RX_IDLE, 16, "RX Electrical Idle enters RX L0s.Idle");
    @(negedge h.ctrl_clk_i); h.crr_rx_electrical_idle_i = 1'b0;
    h.wait_substate(LTSSM_SS_L0S_RX_FTS, 16, "RX Electrical Idle exit waits for FTS");
    @(negedge h.ctrl_clk_i); h.os_rx_fts_evt_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.os_rx_fts_evt_i = 1'b0;
    h.wait_state(LTSSM_L0, 16, "qualified RX FTS exits RX L0s");
    tb_hit(1);

    h.issue_pm(PM_REQ_L1, 1'b0);
    h.wait_substate(LTSSM_SS_L1_ENTRY, 16, "L1.Entry reached");
    h.pulse_os_done();
    @(negedge h.ctrl_clk_i); h.crr_tx_electrical_idle_active_i = 1'b1;
    h.wait_power_request(PHY_POWER_P1, 16);
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b0;
    h.wait_substate(LTSSM_SS_L1_IDLE, 16, "P1 completion enters L1.Idle");
    h.wait_pm_result(done, failed, 16);
    tb_check(done && !failed, "L1 entry reports success");
    h.acknowledge_pm_result();

    h.issue_pm(PM_REQ_L1, 1'b1);
    h.wait_substate(LTSSM_SS_L1_EXIT, 16, "L1.Exit reached");
    h.wait_power_request(PHY_POWER_P0, 16);
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b1;
    @(negedge h.ctrl_clk_i);
    h.crr_power_done_i = 1'b0;
    h.crr_tx_electrical_idle_active_i = 1'b0;
    h.recovery_training_to_idle();
    h.wait_pm_result(done, failed, 16);
    tb_check(done && !failed, "L1 exit completes only after link recovery");
    h.acknowledge_pm_result();
    tb_hit(2);

    h.issue_pm(PM_REQ_L2_L3_READY, 1'b0);
    h.wait_state(LTSSM_L2_L3_READY, 16, "L2/L3 Ready entry accepted");
    h.pulse_os_done();
    @(negedge h.ctrl_clk_i); h.crr_tx_electrical_idle_active_i = 1'b1;
    h.wait_power_request(PHY_POWER_P2, 16);
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b0;
    h.wait_pm_result(done, failed, 16);
    tb_check(done && !failed, "L2/L3 Ready entry reports success");
    h.acknowledge_pm_result();
    tb_check_eq1(h.lt_link_up_o, 1'b0, "L2/L3 Ready is not project link-up");

    h.issue_pm(PM_REQ_L2_L3_READY, 1'b1);
    h.wait_substate(LTSSM_SS_L2_READY_RESTART, 16, "L2/L3 restart substate reached");
    h.wait_power_request(PHY_POWER_P0, 16);
    @(negedge h.ctrl_clk_i); h.crr_power_done_i = 1'b1;
    @(negedge h.ctrl_clk_i);
    h.crr_power_done_i = 1'b0;
    h.crr_tx_electrical_idle_active_i = 1'b0;
    h.wait_state(LTSSM_DETECT, 16, "L2/L3 restart returns through Detect");
    h.wait_pm_result(done, failed, 16);
    tb_check(done && !failed, "L2/L3 exit reports success");
    h.acknowledge_pm_result();
    tb_hit(3);

    h.drive_detect_to_l0();
    h.issue_pm(2'b11, 1'b0);
    h.wait_pm_result(done, failed, 16);
    tb_check(!done && failed, "reserved PM encoding is rejected");
    tb_check_eq6(h.lt_state_o, LTSSM_L0, "illegal PM request leaves L0 unchanged");
    h.acknowledge_pm_result();
    tb_hit(4);

    test_done = 1'b1;
    tb_finish("PHY-V-011");
  end
endmodule
