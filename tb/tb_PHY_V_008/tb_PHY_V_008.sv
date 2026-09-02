`timescale 1ns/1ps

// Shared control-plane fixture for PHY-V-008 through PHY-V-012.  The fixture
// drives only frozen LTSSM inputs: qualified protocol events, normalized CRR
// completions, management/PM handshakes, and the real timer bank.  It does not
// alter an internal state hierarchically.
module phy_ltssm_tb_fixture;
  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;
  import phy_tb_pkg::*;

  logic ctrl_clk_i = 1'b0;
  logic ctrl_rst_ni = 1'b0;
  logic port_reset_ni = 1'b0;
  always #5ns ctrl_clk_i = ~ctrl_clk_i;

  logic mgmt_cmd_valid_i;
  logic mgmt_cmd_ready_o;
  logic [3:0] mgmt_cmd_opcode_i;
  logic [7:0] mgmt_cmd_arg_i;
  logic mgmt_rsp_valid_o;
  logic mgmt_rsp_ready_i;
  logic [3:0] mgmt_rsp_status_o;

  logic port_pm_req_valid_i;
  logic port_pm_req_ready_o;
  logic [1:0] port_pm_req_state_i;
  logic port_pm_req_exit_i;
  logic port_pm_done_o;
  logic port_pm_fail_o;
  logic port_pm_rsp_ready_i;

  logic crr_ready_i;
  logic crr_current_rate_i;
  logic crr_detect_done_i;
  logic crr_receiver_present_i;
  logic crr_rate_done_i;
  logic crr_rate_fail_i;
  logic crr_power_done_i;
  logic crr_power_fail_i;
  logic crr_tx_electrical_idle_active_i;
  logic crr_rx_electrical_idle_i;
  logic crr_rx_aligned_i;
  logic crr_fault_i;
  logic [7:0] crr_fault_code_i;

  logic os_tx_req_ready_i;
  logic os_tx_done_i;
  logic tx_logical_idle_qualified_evt_i;
  logic os_rx_ts1_qualified_evt_i;
  logic os_rx_ts2_qualified_evt_i;
  logic os_rx_fts_evt_i;
  logic os_rx_skp_evt_i;
  logic os_rx_eios_evt_i;
  logic os_rx_eieos_evt_i;
  logic rx_logical_idle_qualified_evt_i;
  logic os_rx_hot_reset_evt_i;
  logic os_rx_loopback_evt_i;
  logic os_rx_speed_change_evt_i;
  pcie_ts_fields_t os_rx_fields_i;
  logic [7:0] os_rx_error_i;

  logic tx_quiesced_i;
  logic rx_packet_active_i;
  logic rx_align_loss_evt_i;
  logic rx_frame_error_evt_i;
  logic rx_buffer_fault_evt_i;
  logic datapath_recovery_req_i;

  logic lt_gt_detect_req_o;
  logic lt_gt_rate_req_o;
  logic lt_gt_rate_target_gen2_o;
  logic lt_gt_power_req_o;
  logic [1:0] lt_gt_power_state_o;
  logic lt_gt_tx_electrical_idle_o;
  logic lt_gt_rx_polarity_invert_o;
  logic lt_gt_tx_deemphasis_o;
  logic lt_gt_tx_swing_o;
  logic [2:0] lt_gt_tx_margin_o;
  logic lt_gt_compliance_enable_o;
  logic [2:0] lt_gt_loopback_mode_o;
  logic lt_os_req_valid_o;
  logic [2:0] lt_os_kind_o;
  pcie_ts_fields_t lt_os_fields_o;
  logic [2:0] lt_os_repeat_mode_o;
  logic [3:0] lt_tx_mode_o;
  logic lt_packet_enable_o;
  logic lt_packet_flush_o;
  logic lt_packet_drop_o;

  logic timer_start_o;
  logic timer_stop_o;
  logic [5:0] timer_id_o;
  logic [31:0] timer_limit_o;
  logic retry_update_o;
  logic retry_clear_o;
  logic timer_expired_i;
  logic [5:0] timer_id_i;
  logic [7:0] retry_count_i;
  logic timer_active;
  logic [31:0] timer_count;
  logic timer_expired_from_bank;
  logic [5:0] timer_id_from_bank;
  logic inject_timeout;
  logic [5:0] injected_timeout_id;

  logic [5:0] lt_state_o;
  logic [5:0] lt_substate_o;
  logic [7:0] lt_entry_reason_o;
  logic lt_link_up_o;
  logic lt_data_active_o;
  logic lt_current_rate_o;
  logic lt_target_rate_o;
  logic lt_clear_error_o;
  logic lt_status_evt_valid_o;
  logic [7:0] lt_status_evt_code_o;
  logic [31:0] lt_status_evt_info_o;
  logic lt_status_evt_fatal_o;

  assign timer_expired_i = timer_expired_from_bank | inject_timeout;
  assign timer_id_i = inject_timeout ? injected_timeout_id : timer_id_from_bank;

  phy_timer_bank timer_bank (
    .ctrl_clk_i(ctrl_clk_i), .ctrl_rst_ni(ctrl_rst_ni),
    .port_reset_ni(port_reset_ni), .timer_start_i(timer_start_o),
    .timer_stop_i(timer_stop_o), .timer_id_i(timer_id_o),
    .timer_limit_i(timer_limit_o), .retry_update_i(retry_update_o),
    .retry_clear_i(retry_clear_o), .timer_expired_o(timer_expired_from_bank),
    .timer_id_o(timer_id_from_bank), .retry_count_o(retry_count_i),
    .timer_active_o(timer_active), .timer_count_o(timer_count)
  );

  phy_ltssm_ctrl dut (
    .ctrl_clk_i(ctrl_clk_i), .ctrl_rst_ni(ctrl_rst_ni),
    .port_reset_ni(port_reset_ni),
    .mgmt_cmd_valid_i(mgmt_cmd_valid_i), .mgmt_cmd_ready_o(mgmt_cmd_ready_o),
    .mgmt_cmd_opcode_i(mgmt_cmd_opcode_i), .mgmt_cmd_arg_i(mgmt_cmd_arg_i),
    .mgmt_rsp_valid_o(mgmt_rsp_valid_o), .mgmt_rsp_ready_i(mgmt_rsp_ready_i),
    .mgmt_rsp_status_o(mgmt_rsp_status_o),
    .port_pm_req_valid_i(port_pm_req_valid_i), .port_pm_req_ready_o(port_pm_req_ready_o),
    .port_pm_req_state_i(port_pm_req_state_i), .port_pm_req_exit_i(port_pm_req_exit_i),
    .port_pm_done_o(port_pm_done_o), .port_pm_fail_o(port_pm_fail_o),
    .port_pm_rsp_ready_i(port_pm_rsp_ready_i),
    .crr_ready_i(crr_ready_i), .crr_current_rate_i(crr_current_rate_i),
    .crr_detect_done_i(crr_detect_done_i), .crr_receiver_present_i(crr_receiver_present_i),
    .crr_rate_done_i(crr_rate_done_i), .crr_rate_fail_i(crr_rate_fail_i),
    .crr_power_done_i(crr_power_done_i), .crr_power_fail_i(crr_power_fail_i),
    .crr_tx_electrical_idle_active_i(crr_tx_electrical_idle_active_i),
    .crr_rx_electrical_idle_i(crr_rx_electrical_idle_i),
    .crr_rx_aligned_i(crr_rx_aligned_i), .crr_fault_i(crr_fault_i),
    .crr_fault_code_i(crr_fault_code_i), .os_tx_req_ready_i(os_tx_req_ready_i),
    .os_tx_done_i(os_tx_done_i),
    .tx_logical_idle_qualified_evt_i(tx_logical_idle_qualified_evt_i),
    .os_rx_ts1_qualified_evt_i(os_rx_ts1_qualified_evt_i),
    .os_rx_ts2_qualified_evt_i(os_rx_ts2_qualified_evt_i),
    .os_rx_fts_evt_i(os_rx_fts_evt_i), .os_rx_skp_evt_i(os_rx_skp_evt_i),
    .os_rx_eios_evt_i(os_rx_eios_evt_i), .os_rx_eieos_evt_i(os_rx_eieos_evt_i),
    .rx_logical_idle_qualified_evt_i(rx_logical_idle_qualified_evt_i),
    .os_rx_hot_reset_evt_i(os_rx_hot_reset_evt_i),
    .os_rx_loopback_evt_i(os_rx_loopback_evt_i),
    .os_rx_speed_change_evt_i(os_rx_speed_change_evt_i),
    .os_rx_fields_i(os_rx_fields_i), .os_rx_error_i(os_rx_error_i),
    .tx_quiesced_i(tx_quiesced_i), .rx_packet_active_i(rx_packet_active_i),
    .rx_align_loss_evt_i(rx_align_loss_evt_i),
    .rx_frame_error_evt_i(rx_frame_error_evt_i),
    .rx_buffer_fault_evt_i(rx_buffer_fault_evt_i),
    .datapath_recovery_req_i(datapath_recovery_req_i),
    .timer_expired_i(timer_expired_i), .timer_id_i(timer_id_i),
    .retry_count_i(retry_count_i), .lt_gt_detect_req_o(lt_gt_detect_req_o),
    .lt_gt_rate_req_o(lt_gt_rate_req_o),
    .lt_gt_rate_target_gen2_o(lt_gt_rate_target_gen2_o),
    .lt_gt_power_req_o(lt_gt_power_req_o), .lt_gt_power_state_o(lt_gt_power_state_o),
    .lt_gt_tx_electrical_idle_o(lt_gt_tx_electrical_idle_o),
    .lt_gt_rx_polarity_invert_o(lt_gt_rx_polarity_invert_o),
    .lt_gt_tx_deemphasis_o(lt_gt_tx_deemphasis_o),
    .lt_gt_tx_swing_o(lt_gt_tx_swing_o), .lt_gt_tx_margin_o(lt_gt_tx_margin_o),
    .lt_gt_compliance_enable_o(lt_gt_compliance_enable_o),
    .lt_gt_loopback_mode_o(lt_gt_loopback_mode_o),
    .lt_os_req_valid_o(lt_os_req_valid_o), .lt_os_kind_o(lt_os_kind_o),
    .lt_os_fields_o(lt_os_fields_o), .lt_os_repeat_mode_o(lt_os_repeat_mode_o),
    .lt_tx_mode_o(lt_tx_mode_o), .lt_packet_enable_o(lt_packet_enable_o),
    .lt_packet_flush_o(lt_packet_flush_o), .lt_packet_drop_o(lt_packet_drop_o),
    .timer_start_o(timer_start_o), .timer_stop_o(timer_stop_o),
    .timer_id_o(timer_id_o), .timer_limit_o(timer_limit_o),
    .retry_update_o(retry_update_o), .retry_clear_o(retry_clear_o),
    .lt_state_o(lt_state_o), .lt_substate_o(lt_substate_o),
    .lt_entry_reason_o(lt_entry_reason_o), .lt_link_up_o(lt_link_up_o),
    .lt_data_active_o(lt_data_active_o), .lt_current_rate_o(lt_current_rate_o),
    .lt_target_rate_o(lt_target_rate_o), .lt_clear_error_o(lt_clear_error_o),
    .lt_status_evt_valid_o(lt_status_evt_valid_o),
    .lt_status_evt_code_o(lt_status_evt_code_o),
    .lt_status_evt_info_o(lt_status_evt_info_o),
    .lt_status_evt_fatal_o(lt_status_evt_fatal_o)
  );

  task automatic drive_quiet_inputs;
    begin
      mgmt_cmd_valid_i = 1'b0;
      mgmt_cmd_opcode_i = PHY_CMD_ENABLE;
      mgmt_cmd_arg_i = '0;
      mgmt_rsp_ready_i = 1'b1;
      port_pm_req_valid_i = 1'b0;
      port_pm_req_state_i = PM_REQ_L0S;
      port_pm_req_exit_i = 1'b0;
      port_pm_rsp_ready_i = 1'b1;
      crr_ready_i = 1'b1;
      crr_current_rate_i = 1'b0;
      crr_detect_done_i = 1'b0;
      crr_receiver_present_i = 1'b0;
      crr_rate_done_i = 1'b0;
      crr_rate_fail_i = 1'b0;
      crr_power_done_i = 1'b0;
      crr_power_fail_i = 1'b0;
      crr_tx_electrical_idle_active_i = 1'b0;
      crr_rx_electrical_idle_i = 1'b0;
      crr_rx_aligned_i = 1'b1;
      crr_fault_i = 1'b0;
      crr_fault_code_i = ERR_NONE;
      os_tx_req_ready_i = 1'b1;
      os_tx_done_i = 1'b0;
      tx_logical_idle_qualified_evt_i = 1'b0;
      os_rx_ts1_qualified_evt_i = 1'b0;
      os_rx_ts2_qualified_evt_i = 1'b0;
      os_rx_fts_evt_i = 1'b0;
      os_rx_skp_evt_i = 1'b0;
      os_rx_eios_evt_i = 1'b0;
      os_rx_eieos_evt_i = 1'b0;
      rx_logical_idle_qualified_evt_i = 1'b0;
      os_rx_hot_reset_evt_i = 1'b0;
      os_rx_loopback_evt_i = 1'b0;
      os_rx_speed_change_evt_i = 1'b0;
      os_rx_fields_i = '0;
      os_rx_fields_i.valid = 1'b1;
      os_rx_fields_i.link_num_is_pad = 1'b0;
      os_rx_fields_i.lane_num_is_pad = 1'b0;
      os_rx_fields_i.link_num = 8'd0;
      os_rx_fields_i.lane_num = 5'd0;
      os_rx_fields_i.n_fts = 8'd32;
      os_rx_fields_i.rate_id = RATE_ID_GEN1_SUPPORTED;
      os_rx_error_i = ERR_NONE;
      tx_quiesced_i = 1'b1;
      rx_packet_active_i = 1'b0;
      rx_align_loss_evt_i = 1'b0;
      rx_frame_error_evt_i = 1'b0;
      rx_buffer_fault_evt_i = 1'b0;
      datapath_recovery_req_i = 1'b0;
      inject_timeout = 1'b0;
      injected_timeout_id = TIMER_NONE;
    end
  endtask

  task automatic reset_dut;
    begin
      ctrl_rst_ni = 1'b0;
      port_reset_ni = 1'b0;
      drive_quiet_inputs();
      repeat (4) @(posedge ctrl_clk_i);
      @(negedge ctrl_clk_i);
      ctrl_rst_ni = 1'b1;
      port_reset_ni = 1'b1;
      repeat (2) @(posedge ctrl_clk_i);
    end
  endtask

  task automatic wait_state(input logic [5:0] expected,
                            input int unsigned bound,
                            input string description);
    int unsigned age;
    begin
      age = 0;
      while ((lt_state_o !== expected) && (age < bound)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check_eq6(lt_state_o, expected, description);
    end
  endtask

  task automatic wait_substate(input logic [5:0] expected,
                               input int unsigned bound,
                               input string description);
    int unsigned age;
    begin
      age = 0;
      while ((lt_substate_o !== expected) && (age < bound)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check_eq6(lt_substate_o, expected, description);
    end
  endtask

  task automatic wait_rate_request(input int unsigned bound);
    int unsigned age;
    begin
      age = 0;
      while (!lt_gt_rate_req_o && (age < bound)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check(lt_gt_rate_req_o, "bounded normalized rate request");
    end
  endtask

  task automatic wait_power_request(input logic [1:0] expected,
                                    input int unsigned bound);
    int unsigned age;
    begin
      age = 0;
      while (!(lt_gt_power_req_o && (lt_gt_power_state_o == expected)) &&
             (age < bound)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check(lt_gt_power_req_o && (lt_gt_power_state_o == expected),
               $sformatf("bounded power request state=%0d", expected));
    end
  endtask

  task automatic issue_mgmt(input logic [3:0] opcode,
                            input logic [7:0] argument);
    int unsigned age;
    begin
      mgmt_rsp_ready_i = 1'b0;
      age = 0;
      while (!mgmt_cmd_ready_o && (age < 64)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check(mgmt_cmd_ready_o, "management request accepted within bound");
      @(negedge ctrl_clk_i);
      mgmt_cmd_opcode_i = opcode;
      mgmt_cmd_arg_i = argument;
      mgmt_cmd_valid_i = 1'b1;
      @(negedge ctrl_clk_i);
      mgmt_cmd_valid_i = 1'b0;
    end
  endtask

  task automatic wait_mgmt_response(output logic [3:0] status,
                                    input int unsigned bound);
    int unsigned age;
    begin
      age = 0;
      while (!mgmt_rsp_valid_o && (age < bound)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check(mgmt_rsp_valid_o, "management response returned within bound");
      status = mgmt_rsp_status_o;
      @(negedge ctrl_clk_i);
      mgmt_rsp_ready_i = 1'b1;
      @(posedge ctrl_clk_i);
    end
  endtask

  task automatic transact_mgmt(input logic [3:0] opcode,
                               input logic [7:0] argument,
                               output logic [3:0] status);
    begin
      issue_mgmt(opcode, argument);
      wait_mgmt_response(status, 128);
    end
  endtask

  task automatic issue_pm(input logic [1:0] requested_state,
                          input logic exit_request);
    int unsigned age;
    begin
      port_pm_rsp_ready_i = 1'b0;
      age = 0;
      while (!port_pm_req_ready_o && (age < 64)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check(port_pm_req_ready_o, "PM request accepted within bound");
      @(negedge ctrl_clk_i);
      port_pm_req_state_i = requested_state;
      port_pm_req_exit_i = exit_request;
      port_pm_req_valid_i = 1'b1;
      @(negedge ctrl_clk_i);
      port_pm_req_valid_i = 1'b0;
      port_pm_req_exit_i = 1'b0;
    end
  endtask

  task automatic wait_pm_result(output logic done,
                                output logic failed,
                                input int unsigned bound);
    int unsigned age;
    begin
      age = 0;
      while (!(port_pm_done_o || port_pm_fail_o) && (age < bound)) begin
        @(posedge ctrl_clk_i);
        age = age + 1;
      end
      tb_check(port_pm_done_o || port_pm_fail_o, "PM result returned within bound");
      done = port_pm_done_o;
      failed = port_pm_fail_o;
      tb_check(!(done && failed), "PM done and fail are mutually exclusive");
    end
  endtask

  task automatic acknowledge_pm_result;
    begin
      @(negedge ctrl_clk_i);
      port_pm_rsp_ready_i = 1'b1;
      @(posedge ctrl_clk_i);
    end
  endtask

  task automatic pulse_timeout(input logic [5:0] timeout_id);
    begin
      @(negedge ctrl_clk_i);
      injected_timeout_id = timeout_id;
      inject_timeout = 1'b1;
      @(negedge ctrl_clk_i);
      inject_timeout = 1'b0;
      injected_timeout_id = TIMER_NONE;
    end
  endtask

  task automatic pulse_detect_result(input logic present);
    begin
      @(negedge ctrl_clk_i);
      crr_receiver_present_i = present;
      crr_detect_done_i = 1'b1;
      @(negedge ctrl_clk_i);
      crr_detect_done_i = 1'b0;
      crr_receiver_present_i = 1'b0;
    end
  endtask

  task automatic pulse_ts1_step;
    begin
      @(negedge ctrl_clk_i);
      os_rx_fields_i.valid = 1'b1;
      os_rx_fields_i.is_ts2 = 1'b0;
      os_tx_done_i = 1'b1;
      os_rx_ts1_qualified_evt_i = 1'b1;
      @(negedge ctrl_clk_i);
      os_tx_done_i = 1'b0;
      os_rx_ts1_qualified_evt_i = 1'b0;
    end
  endtask

  task automatic pulse_ts2_step;
    begin
      @(negedge ctrl_clk_i);
      os_rx_fields_i.valid = 1'b1;
      os_rx_fields_i.is_ts2 = 1'b1;
      os_tx_done_i = 1'b1;
      os_rx_ts2_qualified_evt_i = 1'b1;
      @(negedge ctrl_clk_i);
      os_tx_done_i = 1'b0;
      os_rx_ts2_qualified_evt_i = 1'b0;
    end
  endtask

  task automatic pulse_os_done;
    begin
      @(negedge ctrl_clk_i);
      os_tx_done_i = 1'b1;
      @(negedge ctrl_clk_i);
      os_tx_done_i = 1'b0;
    end
  endtask

  task automatic pulse_idle_pair;
    begin
      @(negedge ctrl_clk_i);
      tx_logical_idle_qualified_evt_i = 1'b1;
      rx_logical_idle_qualified_evt_i = 1'b1;
      @(negedge ctrl_clk_i);
      tx_logical_idle_qualified_evt_i = 1'b0;
      rx_logical_idle_qualified_evt_i = 1'b0;
    end
  endtask

  task automatic drive_detect_to_l0;
    begin
      wait_state(LTSSM_DETECT, 64, "training begins in Detect");
      wait_substate(LTSSM_SS_DETECT_QUIET, 16, "Detect.Quiet reached");
      pulse_timeout(TIMER_DETECT_QUIET);
      wait_substate(LTSSM_SS_DETECT_ACTIVE, 16, "Detect.Active reached");
      pulse_detect_result(1'b1);
      wait_state(LTSSM_POLLING, 16, "receiver present enters Polling");
      wait_substate(LTSSM_SS_POLLING_ACTIVE, 16, "Polling.Active reached");
      pulse_ts1_step();
      wait_substate(LTSSM_SS_POLLING_CONFIGURATION, 16,
                    "qualified TS1 enters Polling.Configuration");
      pulse_ts2_step();
      wait_state(LTSSM_CONFIGURATION, 16, "qualified TS2 enters Configuration");
      wait_substate(LTSSM_SS_CFG_LINKWIDTH_START, 16, "Configuration.Linkwidth.Start");
      pulse_ts1_step();
      wait_substate(LTSSM_SS_CFG_LINKWIDTH_ACCEPT, 16, "Configuration.Linkwidth.Accept");
      pulse_ts1_step();
      wait_substate(LTSSM_SS_CFG_LANENUM_WAIT, 16, "Configuration.Lanenum.Wait");
      pulse_ts1_step();
      wait_substate(LTSSM_SS_CFG_LANENUM_ACCEPT, 16, "Configuration.Lanenum.Accept");
      pulse_ts2_step();
      wait_substate(LTSSM_SS_CFG_COMPLETE, 16, "Configuration.Complete");
      pulse_ts2_step();
      wait_substate(LTSSM_SS_CFG_IDLE, 16, "Configuration.Idle");
      pulse_idle_pair();
      wait_state(LTSSM_L0, 16, "Configuration.Idle enters L0");
    end
  endtask

  task automatic reset_and_enter_l0;
    logic [3:0] response;
    begin
      reset_dut();
      transact_mgmt(PHY_CMD_ENABLE, 8'h00, response);
      tb_check_eq4(response, MGMT_RSP_OK, "ENABLE accepted");
      drive_detect_to_l0();
    end
  endtask

  task automatic recovery_training_to_idle;
    begin
      wait_state(LTSSM_RECOVERY, 32, "Recovery reached");
      wait_substate(LTSSM_SS_RECOVERY_RCVRLOCK, 32, "Recovery.RcvrLock reached");
      pulse_ts1_step();
      wait_substate(LTSSM_SS_RECOVERY_RCVRCFG, 32, "Recovery.RcvrCfg reached");
      pulse_ts2_step();
      wait_substate(LTSSM_SS_RECOVERY_IDLE, 32, "Recovery.Idle reached");
      pulse_idle_pair();
      wait_state(LTSSM_L0, 32, "Recovery.Idle returns to L0");
    end
  endtask

  initial drive_quiet_inputs();
endmodule

module tb_PHY_V_008;
  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;
  import phy_tb_pkg::*;

  phy_ltssm_tb_fixture h();
  logic test_done;
  logic history_valid_q;

  phy_watchdog #(.MAX_CTRL_CYCLES(5000), .TEST_ID("PHY-V-008")) watchdog (
    .ctrl_clk_i(h.ctrl_clk_i), .ctrl_rst_ni(h.ctrl_rst_ni), .done_i(test_done)
  );

  default clocking cb @(posedge h.ctrl_clk_i); endclocking

  always_ff @(posedge h.ctrl_clk_i or negedge h.ctrl_rst_ni or negedge h.port_reset_ni) begin
    if (!h.ctrl_rst_ni || !h.port_reset_ni)
      history_valid_q <= 1'b0;
    else
      history_valid_q <= 1'b1;
  end

  property p_detect_request_scope;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      h.lt_gt_detect_req_o |->
        ((h.lt_state_o == LTSSM_DETECT) &&
         (h.lt_substate_o == LTSSM_SS_DETECT_ACTIVE));
  endproperty
  assert property (p_detect_request_scope)
    else tb_check(1'b0, "Receiver Detect request escaped Detect.Active");

  property p_legal_main_state_edge;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni ||
                                        !history_valid_q)
      legal_main_transition($past(h.lt_state_o), h.lt_state_o);
  endproperty
  assert property (p_legal_main_state_edge)
    else tb_check(1'b0, "illegal LTSSM main-state transition");

  property p_packet_enable_only_in_l0;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      h.lt_packet_enable_o |-> (h.lt_state_o == LTSSM_L0);
  endproperty
  assert property (p_packet_enable_only_in_l0)
    else tb_check(1'b0, "packet enable asserted outside L0");

  initial begin
    logic [3:0] response;
    logic [7:0] retries_before;
    tb_start("PHY-V-008", 64'h0000_0000_0000_00ff);
    test_done = 1'b0;
    h.reset_dut();

    repeat (6) @(posedge h.ctrl_clk_i);
    tb_check_eq6(h.lt_state_o, LTSSM_RESET, "ready alone does not leave Reset");
    tb_check_eq1(h.lt_gt_tx_electrical_idle_o, 1'b1, "Reset holds TX Electrical Idle");
    tb_check_eq1(h.lt_packet_enable_o, 1'b0, "Reset blocks packet traffic");
    tb_hit(0);

    h.transact_mgmt(PHY_CMD_ENABLE, 8'h00, response);
    tb_check_eq4(response, MGMT_RSP_OK, "ENABLE response");
    h.wait_state(LTSSM_DETECT, 16, "ENABLE enters Detect");
    h.wait_substate(LTSSM_SS_DETECT_QUIET, 8, "Detect starts in Quiet");
    tb_check(h.timer_active && (h.timer_id_from_bank == TIMER_DETECT_QUIET),
             "Detect.Quiet owns an active centralized timer");
    h.pulse_timeout(TIMER_DETECT_ACTIVE);
    repeat (2) @(posedge h.ctrl_clk_i);
    tb_check_eq6(h.lt_substate_o, LTSSM_SS_DETECT_QUIET,
                 "mismatched timeout ID cannot advance Detect");
    tb_hit(1);

    h.pulse_timeout(TIMER_DETECT_QUIET);
    h.wait_substate(LTSSM_SS_DETECT_ACTIVE, 8, "quiet timeout enters Detect.Active");
    tb_check_eq1(h.lt_gt_detect_req_o, 1'b1, "Detect.Active requests Receiver Detect");
    retries_before = h.retry_count_i;
    h.pulse_detect_result(1'b0);
    h.wait_substate(LTSSM_SS_DETECT_QUIET, 8, "absent receiver falls back to Quiet");
    repeat (2) @(posedge h.ctrl_clk_i);
    tb_check(h.retry_count_i == retries_before + 1'b1,
             "absent receiver consumes one bounded retry");
    tb_hit(2);

    h.pulse_timeout(TIMER_DETECT_QUIET);
    h.wait_substate(LTSSM_SS_DETECT_ACTIVE, 8, "second Detect.Active attempt");
    h.pulse_timeout(TIMER_DETECT_ACTIVE);
    h.wait_substate(LTSSM_SS_DETECT_QUIET, 8, "Detect.Active timeout returns to Quiet");
    tb_check(h.lt_status_evt_valid_o && (h.lt_status_evt_code_o == ERR_DETECT_TIMEOUT),
             "Detect timeout emits the specified error event");
    tb_hit(3);

    h.pulse_timeout(TIMER_DETECT_QUIET);
    h.wait_substate(LTSSM_SS_DETECT_ACTIVE, 8, "third Detect.Active attempt");
    h.pulse_detect_result(1'b1);
    h.wait_substate(LTSSM_SS_POLLING_ACTIVE, 8, "present receiver enters Polling.Active");
    h.pulse_timeout(TIMER_POLLING_ACTIVE);
    h.wait_substate(LTSSM_SS_DETECT_QUIET, 8,
                    "Polling.Active timeout falls back to Detect.Quiet");
    tb_check(h.lt_status_evt_valid_o && (h.lt_status_evt_code_o == ERR_LTSSM_TIMEOUT),
             "Polling timeout emits LTSSM timeout status");
    h.pulse_timeout(TIMER_DETECT_QUIET);
    h.wait_substate(LTSSM_SS_DETECT_ACTIVE, 8, "post-timeout Detect.Active");
    h.pulse_detect_result(1'b1);
    h.wait_substate(LTSSM_SS_POLLING_ACTIVE, 8,
                    "post-timeout receiver detect returns to Polling.Active");
    repeat (3) @(posedge h.ctrl_clk_i);
    tb_check_eq6(h.lt_substate_o, LTSSM_SS_POLLING_ACTIVE,
                 "Polling.Active holds without local and remote completion");
    @(negedge h.ctrl_clk_i); h.os_tx_done_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.os_tx_done_i = 1'b0;
    repeat (2) @(posedge h.ctrl_clk_i);
    tb_check_eq6(h.lt_substate_o, LTSSM_SS_POLLING_ACTIVE,
                 "local TS1 completion alone cannot advance Polling.Active");
    h.pulse_ts1_step();
    h.wait_substate(LTSSM_SS_POLLING_CONFIGURATION, 8,
                    "remote qualified TS1 completes Polling.Active");
    tb_hit(4);

    h.pulse_ts2_step();
    h.wait_state(LTSSM_CONFIGURATION, 8, "Polling.Configuration enters Configuration");
    tb_check_eq6(h.lt_substate_o, LTSSM_SS_CFG_LINKWIDTH_START,
                 "Configuration preserves Linkwidth.Start");
    h.pulse_ts1_step();
    h.wait_substate(LTSSM_SS_CFG_LINKWIDTH_ACCEPT, 8, "Linkwidth.Accept observed");
    h.pulse_ts1_step();
    h.wait_substate(LTSSM_SS_CFG_LANENUM_WAIT, 8, "Lanenum.Wait observed");
    h.pulse_ts1_step();
    h.wait_substate(LTSSM_SS_CFG_LANENUM_ACCEPT, 8, "Lanenum.Accept observed");
    h.pulse_ts2_step();
    h.wait_substate(LTSSM_SS_CFG_COMPLETE, 8, "Configuration.Complete observed");
    h.pulse_ts2_step();
    h.wait_substate(LTSSM_SS_CFG_IDLE, 8, "Configuration.Idle observed");
    tb_hit(5);

    @(negedge h.ctrl_clk_i); h.rx_logical_idle_qualified_evt_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.rx_logical_idle_qualified_evt_i = 1'b0;
    repeat (2) @(posedge h.ctrl_clk_i);
    tb_check_eq6(h.lt_state_o, LTSSM_CONFIGURATION,
                 "remote idle alone cannot enter L0");
    @(negedge h.ctrl_clk_i); h.tx_logical_idle_qualified_evt_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.tx_logical_idle_qualified_evt_i = 1'b0;
    h.wait_state(LTSSM_L0, 8, "both idle directions enter L0");
    tb_hit(6);

    tb_check_eq1(h.lt_link_up_o, 1'b1, "L0 reports established link context");
    tb_check_eq1(h.lt_data_active_o, 1'b1, "L0 enables DLL packet traffic");
    tb_check_eq1(h.lt_packet_enable_o, 1'b1, "L0 packet gate is open");
    tb_check_eq1(h.lt_current_rate_o, 1'b0, "initial link is Gen1");
    tb_hit(7);

    test_done = 1'b1;
    tb_finish("PHY-V-008");
  end
endmodule
