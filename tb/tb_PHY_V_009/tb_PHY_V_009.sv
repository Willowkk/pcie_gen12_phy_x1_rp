`timescale 1ns/1ps
module tb_PHY_V_009;
  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;
  import phy_tb_pkg::*;

  phy_ltssm_tb_fixture h();
  logic test_done;
  logic history_valid_q;

  phy_watchdog #(.MAX_CTRL_CYCLES(5000), .TEST_ID("PHY-V-009")) watchdog (
    .ctrl_clk_i(h.ctrl_clk_i), .ctrl_rst_ni(h.ctrl_rst_ni), .done_i(test_done)
  );

  default clocking cb @(posedge h.ctrl_clk_i); endclocking

  always_ff @(posedge h.ctrl_clk_i or negedge h.ctrl_rst_ni or negedge h.port_reset_ni) begin
    if (!h.ctrl_rst_ni || !h.port_reset_ni)
      history_valid_q <= 1'b0;
    else
      history_valid_q <= 1'b1;
  end

  property p_rate_request_is_recovery_speed;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      h.lt_gt_rate_req_o |-> ((h.lt_state_o == LTSSM_RECOVERY) &&
                              (h.lt_substate_o == LTSSM_SS_RECOVERY_SPEED) &&
                              h.tx_quiesced_i);
  endproperty
  assert property (p_rate_request_is_recovery_speed)
    else tb_check(1'b0, "rate request issued outside quiesced Recovery.Speed");

  property p_actual_rate_only_follows_crr;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni ||
                                        !history_valid_q)
      $changed(h.lt_current_rate_o) |-> $past(h.crr_rate_done_i);
  endproperty
  assert property (p_actual_rate_only_follows_crr)
    else tb_check(1'b0, "current rate changed before normalized CRR completion");

  task automatic reach_speed_request;
    begin
      h.wait_substate(LTSSM_SS_RECOVERY_RCVRLOCK, 32, "rate flow enters RcvrLock");
      h.pulse_ts1_step();
      h.wait_substate(LTSSM_SS_RECOVERY_RCVRCFG, 16, "rate flow enters RcvrCfg");
      h.pulse_ts2_step();
      h.wait_substate(LTSSM_SS_RECOVERY_SPEED, 16, "rate flow enters Recovery.Speed");
      tb_check_eq1(h.lt_gt_rate_req_o, 1'b0,
                   "rate request waits for EIOS and Electrical Idle");
      h.pulse_os_done();
      repeat (2) @(posedge h.ctrl_clk_i);
      tb_check_eq1(h.lt_gt_rate_req_o, 1'b0,
                   "EIOS alone does not complete the rate boundary");
      @(negedge h.ctrl_clk_i); h.crr_tx_electrical_idle_active_i = 1'b1;
      h.wait_rate_request(16);
    end
  endtask

  task automatic finish_rate_success(input logic target_rate);
    begin
      @(negedge h.ctrl_clk_i);
      h.crr_current_rate_i = target_rate;
      h.crr_rate_done_i = 1'b1;
      @(negedge h.ctrl_clk_i);
      h.crr_rate_done_i = 1'b0;
      h.crr_tx_electrical_idle_active_i = 1'b0;
      h.wait_substate(LTSSM_SS_RECOVERY_RCVRLOCK, 16,
                      "rate completion retrains at the new symbol rate");
      h.pulse_ts1_step();
      h.wait_substate(LTSSM_SS_RECOVERY_RCVRCFG, 16, "post-rate RcvrCfg");
      h.pulse_ts2_step();
      h.wait_substate(LTSSM_SS_RECOVERY_IDLE, 16, "post-rate Recovery.Idle");
      h.pulse_idle_pair();
      h.wait_state(LTSSM_L0, 16, "post-rate training returns to L0");
    end
  endtask

  initial begin
    logic [3:0] response;
    tb_start("PHY-V-009", 64'h0000_0000_0000_003f);
    test_done = 1'b0;
    h.reset_and_enter_l0();
    tb_check_eq1(h.lt_current_rate_o, 1'b0, "baseline link is 2.5 GT/s");
    tb_hit(0);

    h.issue_mgmt(PHY_CMD_SET_RATE, 8'h01);
    h.wait_state(LTSSM_RECOVERY, 16, "Gen2 request enters Recovery");
    reach_speed_request();
    tb_check_eq1(h.lt_gt_rate_target_gen2_o, 1'b1, "normalized target is Gen2");
    tb_check_eq1(h.lt_current_rate_o, 1'b0, "request does not pre-commit current rate");
    finish_rate_success(1'b1);
    h.wait_mgmt_response(response, 32);
    tb_check_eq4(response, MGMT_RSP_OK, "Gen1-to-Gen2 command completes at L0");
    tb_check_eq1(h.lt_current_rate_o, 1'b1, "current rate commits to 5.0 GT/s");
    tb_hit(1);

    h.issue_mgmt(PHY_CMD_SET_RATE, 8'h00);
    h.wait_state(LTSSM_RECOVERY, 16, "Gen1 request enters Recovery");
    reach_speed_request();
    tb_check_eq1(h.lt_gt_rate_target_gen2_o, 1'b0, "normalized target is Gen1");
    finish_rate_success(1'b0);
    h.wait_mgmt_response(response, 32);
    tb_check_eq4(response, MGMT_RSP_OK, "Gen2-to-Gen1 command completes at L0");
    tb_check_eq1(h.lt_current_rate_o, 1'b0, "current rate commits to 2.5 GT/s");
    tb_hit(2);

    h.issue_mgmt(PHY_CMD_SET_RATE, 8'h01);
    h.wait_state(LTSSM_RECOVERY, 16, "Gen1-only peer attempt enters Recovery");
    reach_speed_request();
    @(negedge h.ctrl_clk_i); h.crr_rate_fail_i = 1'b1;
    @(negedge h.ctrl_clk_i);
    h.crr_rate_fail_i = 1'b0;
    h.crr_tx_electrical_idle_active_i = 1'b0;
    h.wait_substate(LTSSM_SS_RECOVERY_RCVRLOCK, 16,
                    "failed Gen2 transaction falls back through RcvrLock");
    h.wait_mgmt_response(response, 32);
    tb_check_eq4(response, MGMT_RSP_FAILED, "Gen1-only peer reports failed Gen2 request");
    tb_check_eq1(h.lt_target_rate_o, 1'b0, "rate failure selects bounded Gen1 fallback");
    tb_check_eq1(h.lt_current_rate_o, 1'b0, "failed request never changes actual rate");
    tb_hit(3);
    h.recovery_training_to_idle();

    h.issue_mgmt(PHY_CMD_SET_RATE, 8'h01);
    h.wait_state(LTSSM_RECOVERY, 16, "timeout attempt enters Recovery");
    reach_speed_request();
    h.pulse_timeout(TIMER_RECOVERY_SPEED);
    h.wait_substate(LTSSM_SS_RECOVERY_RCVRLOCK, 16,
                    "rate timeout takes bounded Gen1 fallback");
    h.wait_mgmt_response(response, 32);
    tb_check_eq4(response, MGMT_RSP_TIMEOUT, "rate timeout terminates command");
    tb_check_eq1(h.lt_current_rate_o, 1'b0, "timeout cannot pre-commit target rate");
    tb_hit(4);
    h.crr_tx_electrical_idle_active_i = 1'b0;
    h.recovery_training_to_idle();

    h.issue_mgmt(PHY_CMD_SET_RATE, 8'h01);
    h.wait_state(LTSSM_RECOVERY, 16, "clock/reset fault attempt enters Recovery");
    @(negedge h.ctrl_clk_i);
    h.crr_fault_code_i = ERR_GT_RESET_TIMEOUT;
    h.crr_fault_i = 1'b1;
    @(negedge h.ctrl_clk_i);
    h.crr_fault_i = 1'b0;
    h.crr_fault_code_i = ERR_NONE;
    h.wait_state(LTSSM_DETECT, 16, "fatal CRR fault returns to Detect");
    tb_check(h.lt_status_evt_valid_o && h.lt_status_evt_fatal_o &&
             (h.lt_status_evt_code_o == ERR_GT_RESET_TIMEOUT),
             "clock/reset failure emits fatal normalized status");
    h.wait_mgmt_response(response, 32);
    tb_check_eq4(response, MGMT_RSP_FAILED, "clock/reset failure terminates rate command");
    tb_check_eq1(h.lt_current_rate_o, 1'b0, "clock/reset failure preserves actual Gen1 rate");
    tb_hit(5);

    test_done = 1'b1;
    tb_finish("PHY-V-009");
  end
endmodule
