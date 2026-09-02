`timescale 1ns/1ps
module tb_PHY_V_012;
  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;
  import phy_tb_pkg::*;

  phy_ltssm_tb_fixture h();
  logic test_done;

  phy_watchdog #(.MAX_CTRL_CYCLES(5000), .TEST_ID("PHY-V-012")) watchdog (
    .ctrl_clk_i(h.ctrl_clk_i), .ctrl_rst_ni(h.ctrl_rst_ni), .done_i(test_done)
  );

  property p_maintenance_blocks_packets;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      ((h.lt_state_o == LTSSM_HOT_RESET) ||
       (h.lt_state_o == LTSSM_DISABLED) ||
       (h.lt_state_o == LTSSM_LOOPBACK) ||
       ((h.lt_state_o == LTSSM_POLLING) &&
        (h.lt_substate_o == LTSSM_SS_POLLING_COMPLIANCE)))
      |-> (!h.lt_packet_enable_o && !h.lt_data_active_o);
  endproperty
  assert property (p_maintenance_blocks_packets)
    else tb_check(1'b0, "maintenance state exposed normal packet traffic");

  property p_protocol_loopback_not_gt_diagnostic;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      ((h.lt_state_o == LTSSM_LOOPBACK) &&
       (h.lt_substate_o == LTSSM_SS_LOOPBACK_ACTIVE))
      |-> (h.lt_gt_loopback_mode_o == 3'b000);
  endproperty
  assert property (p_protocol_loopback_not_gt_diagnostic)
    else tb_check(1'b0, "protocol Loopback enabled GT diagnostic loopback");

  initial begin
    logic [3:0] response;
    tb_start("PHY-V-012", 64'h0000_0000_0000_001f);
    test_done = 1'b0;
    h.reset_and_enter_l0();

    h.issue_mgmt(PHY_CMD_HOT_RESET, 8'h00);
    h.wait_substate(LTSSM_SS_HOT_RESET_ENTRY, 16, "Hot Reset.Entry reached");
    tb_check_eq4(h.lt_tx_mode_o, TX_MODE_TS1, "Hot Reset uses TS1");
    tb_check((h.lt_os_fields_o.training_ctrl & TS_CTRL_HOT_RESET) != 0,
             "Hot Reset is encoded in TS1 Training Control");
    @(negedge h.ctrl_clk_i);
    h.os_tx_done_i = 1'b1;
    h.os_rx_fields_i.valid = 1'b1;
    h.os_rx_fields_i.is_ts2 = 1'b0;
    h.os_rx_fields_i.training_ctrl = TS_CTRL_HOT_RESET;
    h.os_rx_ts1_qualified_evt_i = 1'b1;
    h.os_rx_hot_reset_evt_i = 1'b1;
    @(negedge h.ctrl_clk_i);
    h.os_tx_done_i = 1'b0;
    h.os_rx_ts1_qualified_evt_i = 1'b0;
    h.os_rx_hot_reset_evt_i = 1'b0;
    h.os_rx_fields_i.training_ctrl = 8'h00;
    h.wait_substate(LTSSM_SS_HOT_RESET_ACTIVE, 16, "Hot Reset.Active reached");
    h.pulse_timeout(TIMER_LOOPBACK_ENTRY);
    repeat (2) @(posedge h.ctrl_clk_i);
    tb_check_eq6(h.lt_substate_o, LTSSM_SS_HOT_RESET_ACTIVE,
                 "wrong timer cannot shorten Hot Reset hold");
    h.pulse_timeout(TIMER_HOT_RESET);
    h.wait_substate(LTSSM_SS_HOT_RESET_EXIT, 16, "Hot Reset hold reaches Exit");
    tb_check((h.lt_os_fields_o.training_ctrl & TS_CTRL_HOT_RESET) == 0,
             "Hot Reset bit clears in exit training");
    h.pulse_ts1_step();
    h.wait_state(LTSSM_DETECT, 16, "Hot Reset exits through Detect");
    h.wait_mgmt_response(response, 32);
    tb_check_eq4(response, MGMT_RSP_OK, "Hot Reset command completes after protocol exit");
    tb_hit(0);

    h.drive_detect_to_l0();
    h.transact_mgmt(PHY_CMD_DISABLE, 8'h00, response);
    tb_check_eq4(response, MGMT_RSP_OK, "Disable command accepted");
    h.wait_state(LTSSM_DISABLED, 16, "Disabled state reached");
    tb_check_eq1(h.lt_gt_tx_electrical_idle_o, 1'b1, "Disabled holds Electrical Idle");
    h.pulse_timeout(TIMER_DISABLED_HOLD);
    repeat (2) @(posedge h.ctrl_clk_i);
    tb_check_eq6(h.lt_state_o, LTSSM_DISABLED,
                 "Disabled cannot leave without a new ENABLE");
    h.transact_mgmt(PHY_CMD_ENABLE, 8'h00, response);
    tb_check_eq4(response, MGMT_RSP_OK, "Disabled accepts re-enable");
    h.pulse_timeout(TIMER_DISABLED_HOLD);
    h.wait_state(LTSSM_DETECT, 16, "re-enabled Disabled returns to Detect");
    tb_hit(1);

    h.drive_detect_to_l0();
    h.issue_mgmt(PHY_CMD_LOOPBACK, {5'b0, PHY_CMD_LOOPBACK_ARG_NEAR});
    h.wait_substate(LTSSM_SS_LOOPBACK_ENTRY, 16, "Loopback.Entry reached");
    tb_check((h.lt_os_fields_o.training_ctrl & TS_CTRL_LOOPBACK) != 0,
             "Loopback is encoded in TS1 Training Control");
    @(negedge h.ctrl_clk_i);
    h.os_tx_done_i = 1'b1;
    h.os_rx_loopback_evt_i = 1'b1;
    @(negedge h.ctrl_clk_i);
    h.os_tx_done_i = 1'b0;
    h.os_rx_loopback_evt_i = 1'b0;
    h.wait_substate(LTSSM_SS_LOOPBACK_ACTIVE, 16, "Loopback.Active reached");
    h.wait_mgmt_response(response, 16);
    tb_check_eq4(response, MGMT_RSP_OK, "Loopback entry command completes in Active");
    tb_check_eq4(h.lt_tx_mode_o, TX_MODE_LOOPBACK, "protocol loopback owns symbol route");
    tb_check_eq1(|h.lt_gt_loopback_mode_o, 1'b0,
                 "GT diagnostic loopback remains independently disabled");

    h.issue_mgmt(PHY_CMD_LOOPBACK, {5'b0, PHY_CMD_LOOPBACK_ARG_DISABLE});
    h.wait_substate(LTSSM_SS_LOOPBACK_EXIT, 16, "Loopback.Exit reached");
    h.pulse_ts1_step();
    h.wait_state(LTSSM_RECOVERY, 16, "Loopback exit returns through Recovery");
    h.wait_mgmt_response(response, 16);
    tb_check_eq4(response, MGMT_RSP_OK, "Loopback exit command accepted");
    tb_hit(2);

    h.recovery_training_to_idle();
    h.reset_dut();
    h.transact_mgmt(PHY_CMD_COMPLIANCE, 8'h00, response);
    tb_check_eq4(response, MGMT_RSP_OK, "Compliance command accepted from Reset");
    h.wait_substate(LTSSM_SS_POLLING_COMPLIANCE, 16, "Polling.Compliance reached");
    tb_check_eq4(h.lt_tx_mode_o, TX_MODE_COMPLIANCE, "Compliance selects pattern source");
    tb_check_eq1(h.lt_gt_compliance_enable_o, 1'b1,
                 "Compliance requests matching GT electrical mode");
    tb_check_eq1(h.lt_packet_enable_o, 1'b0, "Compliance never sends normal packets");
    tb_hit(3);

    h.transact_mgmt(PHY_CMD_RETRAIN, 8'h00, response);
    tb_check_eq4(response, MGMT_RSP_REJECTED,
                 "illegal retrain request in Compliance is rejected");
    tb_check_eq6(h.lt_substate_o, LTSSM_SS_POLLING_COMPLIANCE,
                 "rejected maintenance command leaves mode unchanged");
    tb_hit(4);

    test_done = 1'b1;
    tb_finish("PHY-V-012");
  end
endmodule
