module phy_ltssm_ctrl #(
  parameter int unsigned SIM_TIME_SCALE =
      pcie_gen12_phy_timing_pkg::SIM_TIME_SCALE
) (
  input  logic        ctrl_clk_i,
  input  logic        ctrl_rst_ni,
  input  logic        port_reset_ni,
  input  logic        mgmt_cmd_valid_i,
  output logic        mgmt_cmd_ready_o,
  input  logic [3:0]  mgmt_cmd_opcode_i,
  input  logic [7:0]  mgmt_cmd_arg_i,
  output logic        mgmt_rsp_valid_o,
  input  logic        mgmt_rsp_ready_i,
  output logic [3:0]  mgmt_rsp_status_o,
  input  logic        port_pm_req_valid_i,
  output logic        port_pm_req_ready_o,
  input  logic [1:0]  port_pm_req_state_i,
  input  logic        port_pm_req_exit_i,
  output logic        port_pm_done_o,
  output logic        port_pm_fail_o,
  input  logic        port_pm_rsp_ready_i,
  input  logic        crr_ready_i,
  input  logic        crr_current_rate_i,
  input  logic        crr_detect_done_i,
  input  logic        crr_receiver_present_i,
  input  logic        crr_rate_done_i,
  input  logic        crr_rate_fail_i,
  input  logic        crr_power_done_i,
  input  logic        crr_power_fail_i,
  input  logic        crr_tx_electrical_idle_active_i,
  input  logic        crr_rx_electrical_idle_i,
  input  logic        crr_rx_aligned_i,
  input  logic        crr_fault_i,
  input  logic [7:0]  crr_fault_code_i,
  input  logic        os_tx_req_ready_i,
  input  logic        os_tx_done_i,
  input  logic        tx_logical_idle_qualified_evt_i,
  input  logic        os_rx_ts1_qualified_evt_i,
  input  logic        os_rx_ts2_qualified_evt_i,
  input  logic        os_rx_fts_evt_i,
  input  logic        os_rx_skp_evt_i,
  input  logic        os_rx_eios_evt_i,
  input  logic        os_rx_eieos_evt_i,
  input  logic        rx_logical_idle_qualified_evt_i,
  input  logic        os_rx_hot_reset_evt_i,
  input  logic        os_rx_loopback_evt_i,
  input  logic        os_rx_speed_change_evt_i,
  input  pcie_gen12_phy_pkg::pcie_ts_fields_t os_rx_fields_i,
  input  logic [7:0]  os_rx_error_i,
  input  logic        tx_quiesced_i,
  input  logic        rx_packet_active_i,
  input  logic        rx_align_loss_evt_i,
  input  logic        rx_frame_error_evt_i,
  input  logic        rx_buffer_fault_evt_i,
  input  logic        datapath_recovery_req_i,
  input  logic        timer_expired_i,
  input  logic [5:0]  timer_id_i,
  input  logic [7:0]  retry_count_i,
  output logic        lt_gt_detect_req_o,
  output logic        lt_gt_rate_req_o,
  output logic        lt_gt_rate_target_gen2_o,
  output logic        lt_gt_power_req_o,
  output logic [1:0]  lt_gt_power_state_o,
  output logic        lt_gt_tx_electrical_idle_o,
  output logic        lt_gt_rx_polarity_invert_o,
  output logic        lt_gt_tx_deemphasis_o,
  output logic        lt_gt_tx_swing_o,
  output logic [2:0]  lt_gt_tx_margin_o,
  output logic        lt_gt_compliance_enable_o,
  output logic [2:0]  lt_gt_loopback_mode_o,
  output logic        lt_os_req_valid_o,
  output logic [2:0]  lt_os_kind_o,
  output pcie_gen12_phy_pkg::pcie_ts_fields_t lt_os_fields_o,
  output logic [2:0]  lt_os_repeat_mode_o,
  output logic [3:0]  lt_tx_mode_o,
  output logic        lt_packet_enable_o,
  output logic        lt_packet_flush_o,
  output logic        lt_packet_drop_o,
  output logic        timer_start_o,
  output logic        timer_stop_o,
  output logic [5:0]  timer_id_o,
  output logic [31:0] timer_limit_o,
  output logic        retry_update_o,
  output logic        retry_clear_o,
  output logic [5:0]  lt_state_o,
  output logic [5:0]  lt_substate_o,
  output logic [7:0]  lt_entry_reason_o,
  output logic        lt_link_up_o,
  output logic        lt_data_active_o,
  output logic        lt_current_rate_o,
  output logic        lt_target_rate_o,
  output logic        lt_clear_error_o,
  output logic        lt_status_evt_valid_o,
  output logic [7:0]  lt_status_evt_code_o,
  output logic [31:0] lt_status_evt_info_o,
  output logic        lt_status_evt_fatal_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

  typedef enum logic [1:0] {
    SPEED_SEND_EIOS,
    SPEED_WAIT_EIDLE,
    SPEED_REQUEST_RATE
  } speed_phase_t;

  typedef enum logic [1:0] {
    PM_SEND_EIOS,
    PM_WAIT_EIDLE,
    PM_REQUEST_POWER,
    PM_POWER_COMPLETE
  } pm_phase_t;

  wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;

  pcie_ltssm_state_t    state_q, state_d;
  pcie_ltssm_substate_t substate_q, substate_d;
  pcie_state_reason_t   reason_q, reason_d;
  pcie_ts_fields_t      peer_fields_q, peer_fields_d;
  pcie_ts_fields_t      tx_fields_q, tx_fields_d;
  speed_phase_t         speed_phase_q, speed_phase_d;
  pm_phase_t            pm_phase_q, pm_phase_d;

  logic enable_latched_q, enable_latched_d;
  logic target_rate_q, target_rate_d;
  logic peer_gen2_capable_q, peer_gen2_capable_d;
  logic link_context_q, link_context_d;
  logic recovery_fallback_q, recovery_fallback_d;
  logic [1:0] pm_policy_q, pm_policy_d;
  logic [2:0] protocol_loopback_mode_q, protocol_loopback_mode_d;
  logic local_train_done_q, local_train_done_d;
  logic remote_train_done_q, remote_train_done_d;
  logic local_idle_done_q, local_idle_done_d;
  logic remote_idle_done_q, remote_idle_done_d;
  logic low_power_entered_q, low_power_entered_d;
  logic disabled_hold_done_q, disabled_hold_done_d;

  logic cmd_pending_q, cmd_pending_d;
  logic cmd_started_q, cmd_started_d;
  pcie_mgmt_opcode_t cmd_opcode_q, cmd_opcode_d;
  logic [7:0] cmd_arg_q, cmd_arg_d;
  logic mgmt_rsp_valid_q, mgmt_rsp_valid_d;
  pcie_mgmt_rsp_status_t mgmt_rsp_status_q, mgmt_rsp_status_d;

  logic pm_pending_q, pm_pending_d;
  logic pm_started_q, pm_started_d;
  logic [1:0] pm_state_q, pm_state_d;
  logic pm_exit_q, pm_exit_d;
  logic pm_rsp_valid_q, pm_rsp_valid_d;
  logic pm_rsp_success_q, pm_rsp_success_d;

  logic timer_restart;
  logic fsm_error_valid;
  logic [7:0] fsm_error_code;
  logic [31:0] fsm_error_info;
  logic fsm_error_fatal;
  logic fsm_timeout;
  logic fsm_failed;
  logic transition;
  pcie_timer_id_t current_timer_id;
  pcie_timer_id_t next_timer_id;

  function automatic pcie_timer_id_t state_timer_id(
    input pcie_ltssm_state_t state,
    input pcie_ltssm_substate_t substate
  );
    unique case (state)
      LTSSM_DETECT: begin
        if (substate == LTSSM_SS_DETECT_QUIET) return TIMER_DETECT_QUIET;
        return TIMER_DETECT_ACTIVE;
      end
      LTSSM_POLLING: begin
        if (substate == LTSSM_SS_POLLING_ACTIVE) return TIMER_POLLING_ACTIVE;
        if (substate == LTSSM_SS_POLLING_CONFIGURATION) return TIMER_POLLING_CONFIG;
        return TIMER_NONE;
      end
      LTSSM_CONFIGURATION: return TIMER_CONFIGURATION;
      LTSSM_RECOVERY: begin
        unique case (substate)
          LTSSM_SS_RECOVERY_RCVRLOCK: return TIMER_RECOVERY_RCVRLOCK;
          LTSSM_SS_RECOVERY_RCVRCFG:  return TIMER_RECOVERY_RCVRCFG;
          LTSSM_SS_RECOVERY_SPEED:    return TIMER_RECOVERY_SPEED;
          default:                    return TIMER_RECOVERY_IDLE;
        endcase
      end
      LTSSM_L0S: begin
        if ((substate == LTSSM_SS_L0S_TX_IDLE) ||
            (substate == LTSSM_SS_L0S_RX_IDLE)) return TIMER_NONE;
        return TIMER_L0S_EXIT;
      end
      LTSSM_L1: begin
        if (substate == LTSSM_SS_L1_ENTRY) return TIMER_L1_ENTRY;
        if (substate == LTSSM_SS_L1_EXIT)  return TIMER_L1_EXIT;
        return TIMER_NONE;
      end
      LTSSM_L2_L3_READY: begin
        if (substate == LTSSM_SS_L2_READY_RESTART) return TIMER_L2_READY;
        return TIMER_NONE;
      end
      LTSSM_DISABLED: return TIMER_DISABLED_HOLD;
      LTSSM_LOOPBACK: begin
        if (substate == LTSSM_SS_LOOPBACK_ENTRY) return TIMER_LOOPBACK_ENTRY;
        if (substate == LTSSM_SS_LOOPBACK_EXIT)  return TIMER_LOOPBACK_EXIT;
        return TIMER_NONE;
      end
      LTSSM_HOT_RESET: return TIMER_HOT_RESET;
      default: return TIMER_NONE;
    endcase
  endfunction

  function automatic logic timer_matches_current(
    input logic expired,
    input logic [5:0] expired_id,
    input pcie_timer_id_t expected_id
  );
    return expired && (expected_id != TIMER_NONE) &&
           (pcie_timer_id_t'(expired_id) == expected_id);
  endfunction

  function automatic logic x1_training_fields_valid(input pcie_ts_fields_t fields);
    return fields.valid && (fields.lane_num_is_pad || (fields.lane_num == 5'd0));
  endfunction

  assign mgmt_cmd_ready_o = !cmd_pending_q && !mgmt_rsp_valid_q &&
                            !pm_pending_q && !pm_rsp_valid_q;
  assign mgmt_rsp_valid_o  = mgmt_rsp_valid_q;
  assign mgmt_rsp_status_o = mgmt_rsp_status_q;
  assign port_pm_req_ready_o = !pm_pending_q && !pm_rsp_valid_q &&
                               !cmd_pending_q && !mgmt_rsp_valid_q;
  assign port_pm_done_o = pm_rsp_valid_q && pm_rsp_success_q;
  assign port_pm_fail_o = pm_rsp_valid_q && !pm_rsp_success_q;

  assign lt_state_o          = state_q;
  assign lt_substate_o       = substate_q;
  assign lt_entry_reason_o   = reason_q;
  assign lt_current_rate_o   = crr_current_rate_i;
  assign lt_target_rate_o    = target_rate_q;
  assign lt_link_up_o = link_context_q && !recovery_fallback_q &&
                        ((state_q == LTSSM_L0) || (state_q == LTSSM_L0S) ||
                         (state_q == LTSSM_L1) || (state_q == LTSSM_RECOVERY));

  always_comb begin
    state_d                  = state_q;
    substate_d               = substate_q;
    reason_d                 = reason_q;
    peer_fields_d            = peer_fields_q;
    tx_fields_d              = tx_fields_q;
    speed_phase_d            = speed_phase_q;
    pm_phase_d               = pm_phase_q;
    enable_latched_d         = enable_latched_q;
    target_rate_d            = target_rate_q;
    peer_gen2_capable_d      = peer_gen2_capable_q;
    link_context_d           = link_context_q;
    recovery_fallback_d      = recovery_fallback_q;
    pm_policy_d              = pm_policy_q;
    protocol_loopback_mode_d = protocol_loopback_mode_q;
    local_train_done_d       = local_train_done_q;
    remote_train_done_d      = remote_train_done_q;
    local_idle_done_d        = local_idle_done_q;
    remote_idle_done_d       = remote_idle_done_q;
    low_power_entered_d      = low_power_entered_q;
    disabled_hold_done_d     = disabled_hold_done_q;

    cmd_pending_d            = cmd_pending_q;
    cmd_started_d            = cmd_started_q;
    cmd_opcode_d             = cmd_opcode_q;
    cmd_arg_d                = cmd_arg_q;
    mgmt_rsp_valid_d         = mgmt_rsp_valid_q;
    mgmt_rsp_status_d        = mgmt_rsp_status_q;
    pm_pending_d             = pm_pending_q;
    pm_started_d             = pm_started_q;
    pm_state_d               = pm_state_q;
    pm_exit_d                = pm_exit_q;
    pm_rsp_valid_d           = pm_rsp_valid_q;
    pm_rsp_success_d         = pm_rsp_success_q;

    lt_gt_detect_req_o         = 1'b0;
    lt_gt_rate_req_o           = 1'b0;
    lt_gt_rate_target_gen2_o   = target_rate_q;
    lt_gt_power_req_o          = 1'b0;
    lt_gt_power_state_o        = PHY_POWER_P0;
    lt_gt_tx_electrical_idle_o = 1'b0;
    lt_gt_rx_polarity_invert_o = 1'b0;
    lt_gt_tx_deemphasis_o      = 1'b0;
    lt_gt_tx_swing_o           = 1'b0;
    lt_gt_tx_margin_o          = '0;
    lt_gt_compliance_enable_o  = 1'b0;
    lt_gt_loopback_mode_o      = '0;
    lt_os_req_valid_o          = 1'b0;
    lt_os_kind_o               = OS_KIND_NONE;
    lt_os_fields_o             = tx_fields_q;
    lt_os_repeat_mode_o        = OS_REPEAT_SINGLE;
    lt_tx_mode_o               = TX_MODE_ELECTRICAL_IDLE;
    lt_packet_flush_o          = 1'b0;
    lt_packet_drop_o           = 1'b0;
    lt_clear_error_o           = 1'b0;
    retry_update_o             = 1'b0;
    retry_clear_o              = 1'b0;
    timer_restart              = 1'b0;
    fsm_error_valid            = 1'b0;
    fsm_error_code             = ERR_NONE;
    fsm_error_info             = {state_q, substate_q, timer_id_i, retry_count_i, 6'd0};
    fsm_error_fatal            = 1'b0;
    fsm_timeout                = 1'b0;
    fsm_failed                 = 1'b0;

    if (mgmt_rsp_valid_q && mgmt_rsp_ready_i) mgmt_rsp_valid_d = 1'b0;
    if (pm_rsp_valid_q && port_pm_rsp_ready_i) pm_rsp_valid_d = 1'b0;

    if (mgmt_cmd_valid_i && mgmt_cmd_ready_o) begin
      cmd_pending_d = 1'b1;
      cmd_started_d = 1'b0;
      cmd_opcode_d  = pcie_mgmt_opcode_t'(mgmt_cmd_opcode_i);
      cmd_arg_d     = mgmt_cmd_arg_i;
    end
    if (port_pm_req_valid_i && port_pm_req_ready_o) begin
      pm_pending_d = 1'b1;
      pm_started_d = 1'b0;
      pm_state_d   = port_pm_req_state_i;
      pm_exit_d    = port_pm_req_exit_i;
    end

    if (os_rx_fields_i.valid &&
        (os_rx_ts1_qualified_evt_i || os_rx_ts2_qualified_evt_i)) begin
      peer_fields_d       = os_rx_fields_i;
      peer_gen2_capable_d = |(os_rx_fields_i.rate_id & RATE_ID_GEN2_SUPPORTED);
      tx_fields_d.n_fts   = os_rx_fields_i.n_fts;
    end

    current_timer_id = state_timer_id(state_q, substate_q);

    unique case (state_q)
      LTSSM_RESET: begin
        lt_tx_mode_o               = TX_MODE_ELECTRICAL_IDLE;
        lt_gt_tx_electrical_idle_o = 1'b1;
        if (substate_q != LTSSM_SS_RESET_WAIT_READY) begin
          substate_d      = LTSSM_SS_RESET_WAIT_READY;
          reason_d        = REASON_PROTOCOL_ERROR;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
        end else if (crr_ready_i && enable_latched_q) begin
          state_d             = LTSSM_DETECT;
          substate_d          = LTSSM_SS_DETECT_QUIET;
          reason_d            = REASON_READY_AND_ENABLED;
          recovery_fallback_d = 1'b0;
          retry_clear_o       = 1'b1;
        end
      end

      LTSSM_DETECT: begin
        lt_tx_mode_o               = TX_MODE_ELECTRICAL_IDLE;
        lt_gt_tx_electrical_idle_o = 1'b1;
        link_context_d             = 1'b0;
        recovery_fallback_d        = 1'b0;
        if (substate_q == LTSSM_SS_DETECT_QUIET) begin
          if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
            state_d    = LTSSM_DETECT;
            substate_d = LTSSM_SS_DETECT_ACTIVE;
            reason_d   = REASON_TIMER_EXPIRED;
          end
        end else if (substate_q == LTSSM_SS_DETECT_ACTIVE) begin
          lt_gt_detect_req_o = 1'b1;
          if (crr_detect_done_i) begin
            if (crr_receiver_present_i) begin
              state_d           = LTSSM_POLLING;
              substate_d        = LTSSM_SS_POLLING_ACTIVE;
              reason_d          = REASON_RECEIVER_PRESENT;
              retry_clear_o     = 1'b1;
            end else if (retry_count_i + 1'b1 < DETECT_RETRY_MAX) begin
              state_d           = LTSSM_DETECT;
              substate_d        = LTSSM_SS_DETECT_QUIET;
              reason_d          = REASON_RECEIVER_ABSENT;
              retry_update_o    = 1'b1;
            end else begin
              state_d           = LTSSM_DISABLED;
              substate_d        = LTSSM_SS_DISABLED_IDLE;
              reason_d          = REASON_RETRY_EXHAUSTED;
              retry_clear_o     = 1'b1;
              fsm_failed        = 1'b1;
            end
          end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_DETECT_TIMEOUT;
            fsm_timeout     = 1'b1;
            if (retry_count_i + 1'b1 < DETECT_RETRY_MAX) begin
              state_d        = LTSSM_DETECT;
              substate_d     = LTSSM_SS_DETECT_QUIET;
              reason_d       = REASON_TIMER_EXPIRED;
              retry_update_o = 1'b1;
            end else begin
              state_d       = LTSSM_DISABLED;
              substate_d    = LTSSM_SS_DISABLED_IDLE;
              reason_d      = REASON_RETRY_EXHAUSTED;
              retry_clear_o = 1'b1;
            end
          end
        end else begin
          state_d         = LTSSM_DETECT;
          substate_d      = LTSSM_SS_DETECT_QUIET;
          reason_d        = REASON_PROTOCOL_ERROR;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
        end
      end

      LTSSM_POLLING: begin
        link_context_d = 1'b0;
        unique case (substate_q)
          LTSSM_SS_POLLING_ACTIVE: begin
            lt_tx_mode_o        = TX_MODE_TS1;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS1;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_1024;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q ||
                                  (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i);
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i))) begin
              state_d            = LTSSM_POLLING;
              substate_d         = LTSSM_SS_POLLING_CONFIGURATION;
              reason_d           = REASON_TS1_QUALIFIED;
            end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              state_d           = LTSSM_DETECT;
              substate_d        = LTSSM_SS_DETECT_QUIET;
              reason_d          = REASON_TIMER_EXPIRED;
              fsm_error_valid   = 1'b1;
              fsm_error_code    = ERR_LTSSM_TIMEOUT;
              fsm_timeout       = 1'b1;
              retry_update_o    = 1'b1;
            end
          end
          LTSSM_SS_POLLING_CONFIGURATION: begin
            lt_tx_mode_o        = TX_MODE_TS2;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS2;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_8;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts2_qualified_evt_i) &&
                x1_training_fields_valid(peer_fields_d)) begin
              state_d    = LTSSM_CONFIGURATION;
              substate_d = LTSSM_SS_CFG_LINKWIDTH_START;
              reason_d   = REASON_TS2_QUALIFIED;
            end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              state_d         = LTSSM_DETECT;
              substate_d      = LTSSM_SS_DETECT_QUIET;
              reason_d        = REASON_TIMER_EXPIRED;
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_LTSSM_TIMEOUT;
              fsm_timeout     = 1'b1;
            end
          end
          LTSSM_SS_POLLING_COMPLIANCE: begin
            lt_tx_mode_o                  = TX_MODE_COMPLIANCE;
            lt_gt_compliance_enable_o     = 1'b1;
            lt_gt_tx_electrical_idle_o    = 1'b0;
          end
          default: begin
            state_d         = LTSSM_DETECT;
            substate_d      = LTSSM_SS_DETECT_QUIET;
            reason_d        = REASON_PROTOCOL_ERROR;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
      end

      LTSSM_CONFIGURATION: begin
        unique case (substate_q)
          LTSSM_SS_CFG_LINKWIDTH_START: begin
            lt_tx_mode_o        = TX_MODE_TS1;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS1;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_2;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts1_qualified_evt_i) &&
                x1_training_fields_valid(peer_fields_d)) begin
              substate_d = LTSSM_SS_CFG_LINKWIDTH_ACCEPT;
              reason_d   = REASON_TS1_QUALIFIED;
            end
          end
          LTSSM_SS_CFG_LINKWIDTH_ACCEPT: begin
            lt_tx_mode_o        = TX_MODE_TS1;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS1;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_2;
            tx_fields_d.link_num_is_pad = 1'b0;
            tx_fields_d.link_num        = peer_fields_q.link_num;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts1_qualified_evt_i) &&
                x1_training_fields_valid(peer_fields_d)) begin
              substate_d = LTSSM_SS_CFG_LANENUM_WAIT;
              reason_d   = REASON_TS1_QUALIFIED;
            end
          end
          LTSSM_SS_CFG_LANENUM_WAIT: begin
            lt_tx_mode_o        = TX_MODE_TS1;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS1;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_2;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts1_qualified_evt_i) &&
                x1_training_fields_valid(peer_fields_d)) begin
              substate_d = LTSSM_SS_CFG_LANENUM_ACCEPT;
              reason_d   = REASON_TS1_QUALIFIED;
            end
          end
          LTSSM_SS_CFG_LANENUM_ACCEPT: begin
            lt_tx_mode_o        = TX_MODE_TS2;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS2;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_2;
            tx_fields_d.lane_num_is_pad = 1'b0;
            tx_fields_d.lane_num        = 5'd0;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts2_qualified_evt_i) &&
                x1_training_fields_valid(peer_fields_d)) begin
              substate_d = LTSSM_SS_CFG_COMPLETE;
              reason_d   = REASON_TS2_QUALIFIED;
            end
          end
          LTSSM_SS_CFG_COMPLETE: begin
            lt_tx_mode_o        = TX_MODE_TS2;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS2;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_8;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts2_qualified_evt_i) &&
                x1_training_fields_valid(peer_fields_d)) begin
              substate_d = LTSSM_SS_CFG_IDLE;
              reason_d   = REASON_TS2_QUALIFIED;
            end
          end
          LTSSM_SS_CFG_IDLE: begin
            lt_tx_mode_o       = TX_MODE_LOGICAL_IDLE;
            local_idle_done_d  = local_idle_done_q || tx_logical_idle_qualified_evt_i;
            remote_idle_done_d = remote_idle_done_q || rx_logical_idle_qualified_evt_i;
            if ((local_idle_done_q || tx_logical_idle_qualified_evt_i) &&
                (remote_idle_done_q || rx_logical_idle_qualified_evt_i) &&
                crr_rx_aligned_i && crr_ready_i) begin
              state_d             = LTSSM_L0;
              substate_d          = LTSSM_SS_L0_ACTIVE;
              reason_d            = REASON_IDLE_QUALIFIED;
              link_context_d      = 1'b1;
              recovery_fallback_d = 1'b0;
              target_rate_d       = peer_gen2_capable_q;
              retry_clear_o       = 1'b1;
            end
          end
          default: begin
            state_d         = LTSSM_DETECT;
            substate_d      = LTSSM_SS_DETECT_QUIET;
            reason_d        = REASON_PROTOCOL_ERROR;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
        if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) &&
            (substate_d == substate_q)) begin
          state_d         = LTSSM_DETECT;
          substate_d      = LTSSM_SS_DETECT_QUIET;
          reason_d        = REASON_TIMER_EXPIRED;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
          fsm_timeout     = 1'b1;
        end
      end

      LTSSM_L0: begin
        lt_tx_mode_o = TX_MODE_PACKET;
        if (os_rx_hot_reset_evt_i) begin
          state_d        = LTSSM_HOT_RESET;
          substate_d     = LTSSM_SS_HOT_RESET_ENTRY;
          reason_d       = REASON_HOT_RESET;
          link_context_d = 1'b0;
        end else if (os_rx_loopback_evt_i) begin
          state_d        = LTSSM_LOOPBACK;
          substate_d     = LTSSM_SS_LOOPBACK_ENTRY;
          reason_d       = REASON_LOOPBACK;
          link_context_d = 1'b0;
        end else if (is_ts_training_ctrl_set(os_rx_fields_i.training_ctrl, TS_CTRL_DISABLE_LINK) &&
                     (os_rx_ts1_qualified_evt_i || os_rx_ts2_qualified_evt_i)) begin
          state_d          = LTSSM_DISABLED;
          substate_d       = LTSSM_SS_DISABLED_IDLE;
          reason_d         = REASON_DISABLE_LINK;
          enable_latched_d = 1'b0;
          link_context_d   = 1'b0;
        end else if (rx_buffer_fault_evt_i) begin
          state_d           = LTSSM_DETECT;
          substate_d        = LTSSM_SS_DETECT_QUIET;
          reason_d          = REASON_FATAL_ERROR;
          link_context_d    = 1'b0;
          lt_packet_drop_o  = 1'b1;
          lt_packet_flush_o = 1'b1;
          fsm_error_valid   = 1'b1;
          fsm_error_code    = ERR_RXBUF_OVERFLOW;
          fsm_error_fatal   = 1'b1;
          fsm_failed        = 1'b1;
        end else if (rx_align_loss_evt_i || rx_frame_error_evt_i ||
                     datapath_recovery_req_i || crr_rx_electrical_idle_i) begin
          state_d          = LTSSM_RECOVERY;
          substate_d       = LTSSM_SS_RECOVERY_RCVRLOCK;
          reason_d         = REASON_LINK_LOSS;
          lt_packet_drop_o = rx_packet_active_i;
          fsm_error_valid  = 1'b1;
          fsm_error_code   = ERR_LINK_LOSS;
        end else if (os_rx_eios_evt_i && pm_policy_q[0]) begin
          state_d    = LTSSM_L0S;
          substate_d = LTSSM_SS_L0S_RX_ENTRY;
          reason_d   = REASON_RX_EIOS;
        end else if (target_rate_q != crr_current_rate_i) begin
          state_d             = LTSSM_RECOVERY;
          substate_d          = LTSSM_SS_RECOVERY_RCVRLOCK;
          reason_d            = REASON_RATE_REQUESTED;
          recovery_fallback_d = 1'b0;
        end
        if (substate_q != LTSSM_SS_L0_ACTIVE) begin
          state_d         = LTSSM_RECOVERY;
          substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
          reason_d        = REASON_PROTOCOL_ERROR;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
        end
      end

      LTSSM_RECOVERY: begin
        unique case (substate_q)
          LTSSM_SS_RECOVERY_RCVRLOCK: begin
            lt_tx_mode_o        = TX_MODE_TS1;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS1;
            lt_os_repeat_mode_o = crr_current_rate_i ?
                                  OS_REPEAT_FIXED_32 : OS_REPEAT_FIXED_8;
            // At Gen2 the symbol-domain ordered-set block inserts EIEOS at
            // the exact 32-TS1 boundary and reports completion for the TS1
            // batch.  Keeping one cadence owner avoids duplicate EIEOS and a
            // ctrl<->sym request gap.
            local_train_done_d = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q ||
                                  (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i);
            if ((local_train_done_q || local_train_done_d) &&
                (remote_train_done_q || (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i))) begin
              substate_d    = LTSSM_SS_RECOVERY_RCVRCFG;
              reason_d      = REASON_TS1_QUALIFIED;
              retry_clear_o = 1'b1;
            end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_LTSSM_TIMEOUT;
              fsm_timeout     = 1'b1;
              if (retry_count_i + 1'b1 < LTSSM_RETRY_MAX) begin
                retry_update_o = 1'b1;
                timer_restart  = 1'b1;
              end else if (crr_current_rate_i) begin
                target_rate_d       = 1'b0;
                recovery_fallback_d = 1'b1;
                substate_d          = LTSSM_SS_RECOVERY_SPEED;
                speed_phase_d       = SPEED_SEND_EIOS;
                reason_d            = REASON_FALLBACK_GEN1;
                retry_clear_o       = 1'b1;
              end else begin
                state_d        = LTSSM_DETECT;
                substate_d     = LTSSM_SS_DETECT_QUIET;
                reason_d       = REASON_RETRY_EXHAUSTED;
                link_context_d = 1'b0;
                retry_clear_o  = 1'b1;
              end
            end
          end

          LTSSM_SS_RECOVERY_RCVRCFG: begin
            lt_tx_mode_o        = TX_MODE_TS2;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS2;
            lt_os_repeat_mode_o = OS_REPEAT_FIXED_8;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts2_qualified_evt_i) &&
                x1_training_fields_valid(peer_fields_d)) begin
              if ((target_rate_q != crr_current_rate_i) || os_rx_speed_change_evt_i) begin
                substate_d    = LTSSM_SS_RECOVERY_SPEED;
                speed_phase_d = SPEED_SEND_EIOS;
                reason_d      = REASON_RATE_REQUESTED;
              end else begin
                substate_d = LTSSM_SS_RECOVERY_IDLE;
                reason_d   = REASON_TS2_QUALIFIED;
              end
            end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
              reason_d        = REASON_TIMER_EXPIRED;
              retry_update_o  = 1'b1;
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_LTSSM_TIMEOUT;
              fsm_timeout     = 1'b1;
            end
          end

          LTSSM_SS_RECOVERY_SPEED: begin
            unique case (speed_phase_q)
              SPEED_SEND_EIOS: begin
                lt_tx_mode_o        = TX_MODE_EIOS;
                lt_os_req_valid_o   = 1'b1;
                lt_os_kind_o        = OS_KIND_EIOS;
                lt_os_repeat_mode_o = OS_REPEAT_SINGLE;
                // A complete EIOS can only be acknowledged after the
                // scheduler has reached a packet boundary and consumed the
                // entire ordered set; requiring stream-quiesced in the same
                // cycle would be self-contradictory because EIOS is active.
                if (os_tx_done_i) speed_phase_d = SPEED_WAIT_EIDLE;
              end
              SPEED_WAIT_EIDLE: begin
                lt_tx_mode_o               = TX_MODE_ELECTRICAL_IDLE;
                lt_gt_tx_electrical_idle_o = 1'b1;
                if (crr_tx_electrical_idle_active_i) speed_phase_d = SPEED_REQUEST_RATE;
              end
              default: begin
                lt_tx_mode_o                  = TX_MODE_ELECTRICAL_IDLE;
                lt_gt_tx_electrical_idle_o    = 1'b1;
                lt_gt_rate_req_o              = 1'b1;
                lt_gt_rate_target_gen2_o      = target_rate_q;
                if (crr_rate_done_i && (crr_current_rate_i == target_rate_q)) begin
                  substate_d    = LTSSM_SS_RECOVERY_RCVRLOCK;
                  speed_phase_d = SPEED_SEND_EIOS;
                  reason_d      = REASON_RATE_COMPLETE;
                  retry_clear_o = 1'b1;
                end else if (crr_rate_fail_i) begin
                  fsm_error_valid = 1'b1;
                  fsm_error_code  = ERR_RATE_CHANGE;
                  fsm_failed      = 1'b1;
                  if (target_rate_q && !crr_current_rate_i) begin
                    target_rate_d       = 1'b0;
                    recovery_fallback_d = 1'b1;
                    substate_d          = LTSSM_SS_RECOVERY_RCVRLOCK;
                    reason_d            = REASON_FALLBACK_GEN1;
                    retry_clear_o       = 1'b1;
                  end else if (retry_count_i + 1'b1 < RATE_RETRY_MAX) begin
                    speed_phase_d   = SPEED_SEND_EIOS;
                    reason_d        = REASON_RATE_FAILED;
                    retry_update_o  = 1'b1;
                    timer_restart   = 1'b1;
                  end else begin
                    state_d        = LTSSM_DETECT;
                    substate_d     = LTSSM_SS_DETECT_QUIET;
                    reason_d       = REASON_RETRY_EXHAUSTED;
                    link_context_d = 1'b0;
                    retry_clear_o  = 1'b1;
                  end
                end
              end
            endcase
            if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) &&
                (substate_d == substate_q)) begin
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_RATE_CHANGE;
              fsm_timeout     = 1'b1;
              if (target_rate_q && !crr_current_rate_i) begin
                target_rate_d       = 1'b0;
                recovery_fallback_d = 1'b1;
                substate_d          = LTSSM_SS_RECOVERY_RCVRLOCK;
                speed_phase_d       = SPEED_SEND_EIOS;
                reason_d            = REASON_FALLBACK_GEN1;
                retry_clear_o       = 1'b1;
              end else begin
                state_d        = LTSSM_DETECT;
                substate_d     = LTSSM_SS_DETECT_QUIET;
                reason_d       = REASON_RETRY_EXHAUSTED;
                link_context_d = 1'b0;
                retry_clear_o  = 1'b1;
              end
            end
          end

          LTSSM_SS_RECOVERY_IDLE: begin
            lt_tx_mode_o       = TX_MODE_LOGICAL_IDLE;
            local_idle_done_d  = local_idle_done_q || tx_logical_idle_qualified_evt_i;
            remote_idle_done_d = remote_idle_done_q || rx_logical_idle_qualified_evt_i;
            if ((local_idle_done_q || tx_logical_idle_qualified_evt_i) &&
                (remote_idle_done_q || rx_logical_idle_qualified_evt_i) &&
                crr_ready_i && crr_rx_aligned_i &&
                (crr_current_rate_i == target_rate_q)) begin
              state_d             = LTSSM_L0;
              substate_d          = LTSSM_SS_L0_ACTIVE;
              reason_d            = REASON_IDLE_QUALIFIED;
              recovery_fallback_d = 1'b0;
              link_context_d      = 1'b1;
              retry_clear_o       = 1'b1;
            end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
              reason_d        = REASON_TIMER_EXPIRED;
              retry_update_o  = 1'b1;
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_LTSSM_TIMEOUT;
              fsm_timeout     = 1'b1;
            end
          end
          default: begin
            state_d         = LTSSM_DETECT;
            substate_d      = LTSSM_SS_DETECT_QUIET;
            reason_d        = REASON_PROTOCOL_ERROR;
            link_context_d  = 1'b0;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
      end

      LTSSM_L0S: begin
        unique case (substate_q)
          LTSSM_SS_L0S_TX_ENTRY: begin
            lt_tx_mode_o        = TX_MODE_EIOS;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_EIOS;
            lt_os_repeat_mode_o = OS_REPEAT_SINGLE;
            if (os_tx_done_i) begin
              substate_d          = LTSSM_SS_L0S_TX_IDLE;
              reason_d            = REASON_POWER_REQUEST;
              low_power_entered_d = 1'b0;
            end
          end
          LTSSM_SS_L0S_TX_IDLE: begin
            lt_tx_mode_o               = TX_MODE_ELECTRICAL_IDLE;
            lt_gt_tx_electrical_idle_o = 1'b1;
            if (!low_power_entered_q) begin
              lt_gt_power_req_o   = 1'b1;
              lt_gt_power_state_o = PHY_POWER_P0S;
              if (crr_power_done_i) begin
                low_power_entered_d = 1'b1;
                reason_d            = REASON_POWER_COMPLETE;
              end else if (crr_power_fail_i) begin
                state_d         = LTSSM_RECOVERY;
                substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
                reason_d        = REASON_RATE_FAILED;
                fsm_error_valid = 1'b1;
                fsm_error_code  = ERR_GT_RESET_TIMEOUT;
                fsm_failed      = 1'b1;
              end
            end
          end
          LTSSM_SS_L0S_TX_FTS: begin
            if (!low_power_entered_q) begin
              lt_gt_power_req_o   = 1'b1;
              lt_gt_power_state_o = PHY_POWER_P0;
              lt_gt_tx_electrical_idle_o = 1'b0;
              if (crr_power_done_i) low_power_entered_d = 1'b1;
            end else begin
              lt_tx_mode_o        = TX_MODE_FTS;
              lt_os_req_valid_o   = 1'b1;
              lt_os_kind_o        = OS_KIND_FTS;
              lt_os_repeat_mode_o = OS_REPEAT_UNTIL_ACCEPT;
              local_train_done_d  = local_train_done_q || os_tx_done_i;
              if ((local_train_done_q || os_tx_done_i) &&
                  crr_rx_aligned_i) begin
                state_d             = LTSSM_L0;
                substate_d          = LTSSM_SS_L0_ACTIVE;
                reason_d            = REASON_RX_FTS;
                low_power_entered_d = 1'b0;
              end
            end
          end
          LTSSM_SS_L0S_RX_ENTRY: begin
            lt_tx_mode_o = TX_MODE_LOGICAL_IDLE;
            if (crr_rx_electrical_idle_i) begin
              substate_d = LTSSM_SS_L0S_RX_IDLE;
              reason_d   = REASON_RX_EIOS;
            end
          end
          LTSSM_SS_L0S_RX_IDLE: begin
            lt_tx_mode_o = TX_MODE_LOGICAL_IDLE;
            if (!crr_rx_electrical_idle_i) begin
              substate_d = LTSSM_SS_L0S_RX_FTS;
              reason_d   = REASON_PM_EXIT;
            end
          end
          LTSSM_SS_L0S_RX_FTS: begin
            lt_tx_mode_o = TX_MODE_LOGICAL_IDLE;
            if (os_rx_fts_evt_i && crr_rx_aligned_i) begin
              state_d    = LTSSM_L0;
              substate_d = LTSSM_SS_L0_ACTIVE;
              reason_d   = REASON_RX_FTS;
            end
          end
          default: begin
            state_d         = LTSSM_RECOVERY;
            substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
            reason_d        = REASON_PROTOCOL_ERROR;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
        if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) &&
            (substate_d == substate_q)) begin
          state_d         = LTSSM_RECOVERY;
          substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
          reason_d        = REASON_TIMER_EXPIRED;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
          fsm_timeout     = 1'b1;
        end
      end

      LTSSM_L1: begin
        lt_gt_tx_electrical_idle_o = 1'b1;
        unique case (substate_q)
          LTSSM_SS_L1_ENTRY: begin
            unique case (pm_phase_q)
              PM_SEND_EIOS: begin
                lt_tx_mode_o        = TX_MODE_EIOS;
                lt_os_req_valid_o   = 1'b1;
                lt_os_kind_o        = OS_KIND_EIOS;
                lt_os_repeat_mode_o = OS_REPEAT_SINGLE;
                if (os_tx_done_i) pm_phase_d = PM_WAIT_EIDLE;
              end
              PM_WAIT_EIDLE: begin
                lt_tx_mode_o = TX_MODE_ELECTRICAL_IDLE;
                if (crr_tx_electrical_idle_active_i) pm_phase_d = PM_REQUEST_POWER;
              end
              default: begin
                lt_tx_mode_o        = TX_MODE_ELECTRICAL_IDLE;
                lt_gt_power_req_o   = 1'b1;
                lt_gt_power_state_o = PHY_POWER_P1;
                if (crr_power_done_i) begin
                  substate_d          = LTSSM_SS_L1_IDLE;
                  reason_d            = REASON_POWER_COMPLETE;
                  pm_phase_d          = PM_POWER_COMPLETE;
                  low_power_entered_d = 1'b1;
                end else if (crr_power_fail_i) begin
                  state_d         = LTSSM_RECOVERY;
                  substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
                  reason_d        = REASON_RATE_FAILED;
                  fsm_error_valid = 1'b1;
                  fsm_error_code  = ERR_GT_RESET_TIMEOUT;
                  fsm_failed      = 1'b1;
                end
              end
            endcase
          end
          LTSSM_SS_L1_IDLE: begin
            lt_tx_mode_o = TX_MODE_ELECTRICAL_IDLE;
          end
          LTSSM_SS_L1_EXIT: begin
            lt_tx_mode_o        = TX_MODE_ELECTRICAL_IDLE;
            lt_gt_power_req_o   = 1'b1;
            lt_gt_power_state_o = PHY_POWER_P0;
            if (crr_power_done_i) begin
              state_d             = LTSSM_RECOVERY;
              substate_d          = LTSSM_SS_RECOVERY_RCVRLOCK;
              reason_d            = REASON_PM_EXIT;
              low_power_entered_d = 1'b0;
              pm_phase_d          = PM_SEND_EIOS;
            end else if (crr_power_fail_i) begin
              state_d         = LTSSM_DETECT;
              substate_d      = LTSSM_SS_DETECT_QUIET;
              reason_d        = REASON_FATAL_ERROR;
              link_context_d  = 1'b0;
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_GT_RESET_TIMEOUT;
              fsm_error_fatal = 1'b1;
              fsm_failed      = 1'b1;
            end
          end
          default: begin
            state_d         = LTSSM_RECOVERY;
            substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
            reason_d        = REASON_PROTOCOL_ERROR;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
        if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) &&
            (substate_d == substate_q)) begin
          state_d         = LTSSM_RECOVERY;
          substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
          reason_d        = REASON_TIMER_EXPIRED;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
          fsm_timeout     = 1'b1;
        end
      end

      LTSSM_L2_L3_READY: begin
        lt_tx_mode_o               = TX_MODE_ELECTRICAL_IDLE;
        lt_gt_tx_electrical_idle_o = 1'b1;
        link_context_d             = 1'b0;
        unique case (substate_q)
          LTSSM_SS_L2_READY_IDLE: begin
          unique case (pm_phase_q)
            PM_SEND_EIOS: begin
              lt_tx_mode_o        = TX_MODE_EIOS;
              lt_os_req_valid_o   = 1'b1;
              lt_os_kind_o        = OS_KIND_EIOS;
              if (os_tx_done_i) pm_phase_d = PM_WAIT_EIDLE;
            end
            PM_WAIT_EIDLE: begin
              if (crr_tx_electrical_idle_active_i) pm_phase_d = PM_REQUEST_POWER;
            end
            default: begin
              if (!low_power_entered_q) begin
                lt_gt_power_req_o   = 1'b1;
                lt_gt_power_state_o = PHY_POWER_P2;
                if (crr_power_done_i) begin
                  low_power_entered_d = 1'b1;
                  pm_phase_d          = PM_POWER_COMPLETE;
                  reason_d            = REASON_POWER_COMPLETE;
                end else if (crr_power_fail_i) begin
                  state_d         = LTSSM_DISABLED;
                  substate_d      = LTSSM_SS_DISABLED_IDLE;
                  reason_d        = REASON_FATAL_ERROR;
                  fsm_error_valid = 1'b1;
                  fsm_error_code  = ERR_GT_RESET_TIMEOUT;
                  fsm_error_fatal = 1'b1;
                  fsm_failed      = 1'b1;
                end
              end
            end
            endcase
          end
          LTSSM_SS_L2_READY_RESTART: begin
            lt_gt_power_req_o   = 1'b1;
            lt_gt_power_state_o = PHY_POWER_P0;
            if (crr_power_done_i) begin
              state_d             = LTSSM_DETECT;
              substate_d          = LTSSM_SS_DETECT_QUIET;
              reason_d            = REASON_PM_EXIT;
              low_power_entered_d = 1'b0;
              pm_phase_d          = PM_SEND_EIOS;
              retry_clear_o       = 1'b1;
            end else if (crr_power_fail_i ||
                         timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              state_d         = LTSSM_DISABLED;
              substate_d      = LTSSM_SS_DISABLED_IDLE;
              reason_d        = REASON_FATAL_ERROR;
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_GT_RESET_TIMEOUT;
              fsm_error_fatal = 1'b1;
              fsm_failed      = 1'b1;
            end
          end
          default: begin
            state_d         = LTSSM_DISABLED;
            substate_d      = LTSSM_SS_DISABLED_IDLE;
            reason_d        = REASON_PROTOCOL_ERROR;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
      end

      LTSSM_DISABLED: begin
        lt_tx_mode_o               = TX_MODE_ELECTRICAL_IDLE;
        lt_gt_tx_electrical_idle_o = 1'b1;
        link_context_d             = 1'b0;
        if (substate_q != LTSSM_SS_DISABLED_IDLE) begin
          substate_d      = LTSSM_SS_DISABLED_IDLE;
          reason_d        = REASON_PROTOCOL_ERROR;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
        end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id))
          disabled_hold_done_d = 1'b1;
        if ((substate_q == LTSSM_SS_DISABLED_IDLE) && enable_latched_q && crr_ready_i &&
            (disabled_hold_done_q ||
             timer_matches_current(timer_expired_i, timer_id_i, current_timer_id))) begin
          state_d       = LTSSM_DETECT;
          substate_d    = LTSSM_SS_DETECT_QUIET;
          reason_d      = REASON_READY_AND_ENABLED;
          retry_clear_o = 1'b1;
        end
      end

      LTSSM_LOOPBACK: begin
        link_context_d = 1'b0;
        unique case (substate_q)
          LTSSM_SS_LOOPBACK_ENTRY: begin
            lt_tx_mode_o                  = TX_MODE_TS1;
            lt_os_req_valid_o             = 1'b1;
            lt_os_kind_o                  = OS_KIND_TS1;
            lt_os_repeat_mode_o           = OS_REPEAT_CONTINUOUS;
            lt_os_fields_o.training_ctrl  = tx_fields_q.training_ctrl | TS_CTRL_LOOPBACK;
            local_train_done_d            = local_train_done_q || os_tx_done_i;
            remote_train_done_d           = remote_train_done_q || os_rx_loopback_evt_i ||
                                            is_ts_training_ctrl_set(peer_fields_q.training_ctrl,
                                                                    TS_CTRL_LOOPBACK);
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_loopback_evt_i ||
                 is_ts_training_ctrl_set(peer_fields_q.training_ctrl, TS_CTRL_LOOPBACK))) begin
              substate_d = LTSSM_SS_LOOPBACK_ACTIVE;
              reason_d   = REASON_LOOPBACK;
            end
          end
          LTSSM_SS_LOOPBACK_ACTIVE: begin
            lt_tx_mode_o = TX_MODE_LOOPBACK;
            // Protocol Loopback owns the character route.  GT diagnostic
            // LOOPBACK remains disabled unless a separate diagnostic mode is
            // explicitly integrated.
            lt_gt_loopback_mode_o = 3'b000;
          end
          LTSSM_SS_LOOPBACK_EXIT: begin
            lt_tx_mode_o        = TX_MODE_TS1;
            lt_os_req_valid_o   = 1'b1;
            lt_os_kind_o        = OS_KIND_TS1;
            lt_os_repeat_mode_o = OS_REPEAT_UNTIL_ACCEPT;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q ||
                                  os_rx_ts1_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts1_qualified_evt_i)) begin
              state_d    = LTSSM_RECOVERY;
              substate_d = LTSSM_SS_RECOVERY_RCVRLOCK;
              reason_d   = REASON_LOOPBACK;
            end
          end
          default: begin
            state_d         = LTSSM_DETECT;
            substate_d      = LTSSM_SS_DETECT_QUIET;
            reason_d        = REASON_PROTOCOL_ERROR;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
        if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) &&
            (substate_d == substate_q)) begin
          state_d         = LTSSM_DETECT;
          substate_d      = LTSSM_SS_DETECT_QUIET;
          reason_d        = REASON_TIMER_EXPIRED;
          fsm_error_valid = 1'b1;
          fsm_error_code  = ERR_LTSSM_TIMEOUT;
          fsm_timeout     = 1'b1;
        end
      end

      LTSSM_HOT_RESET: begin
        link_context_d = 1'b0;
        unique case (substate_q)
          LTSSM_SS_HOT_RESET_ENTRY: begin
            lt_tx_mode_o                 = TX_MODE_TS1;
            lt_os_req_valid_o            = 1'b1;
            lt_os_kind_o                 = OS_KIND_TS1;
            lt_os_repeat_mode_o          = OS_REPEAT_CONTINUOUS;
            lt_os_fields_o.training_ctrl = tx_fields_q.training_ctrl | TS_CTRL_HOT_RESET;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q ||
                is_ts_training_ctrl_set(peer_fields_q.training_ctrl,
                                        TS_CTRL_HOT_RESET);
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q ||
                  is_ts_training_ctrl_set(peer_fields_q.training_ctrl,
                                          TS_CTRL_HOT_RESET))) begin
              substate_d = LTSSM_SS_HOT_RESET_ACTIVE;
              reason_d   = REASON_HOT_RESET;
            end
          end
          LTSSM_SS_HOT_RESET_ACTIVE: begin
            lt_tx_mode_o                 = TX_MODE_TS1;
            lt_os_req_valid_o            = 1'b1;
            lt_os_kind_o                 = OS_KIND_TS1;
            lt_os_repeat_mode_o          = OS_REPEAT_CONTINUOUS;
            lt_os_fields_o.training_ctrl = tx_fields_q.training_ctrl | TS_CTRL_HOT_RESET;
            if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              substate_d = LTSSM_SS_HOT_RESET_EXIT;
              reason_d   = REASON_TIMER_EXPIRED;
            end
          end
          LTSSM_SS_HOT_RESET_EXIT: begin
            lt_tx_mode_o                 = TX_MODE_TS1;
            lt_os_req_valid_o            = 1'b1;
            lt_os_kind_o                 = OS_KIND_TS1;
            lt_os_repeat_mode_o          = OS_REPEAT_UNTIL_ACCEPT;
            lt_os_fields_o.training_ctrl = tx_fields_q.training_ctrl & ~TS_CTRL_HOT_RESET;
            local_train_done_d  = local_train_done_q || os_tx_done_i;
            remote_train_done_d = remote_train_done_q ||
                                  os_rx_ts1_qualified_evt_i;
            if ((local_train_done_q || os_tx_done_i) &&
                (remote_train_done_q || os_rx_ts1_qualified_evt_i)) begin
              state_d         = LTSSM_DETECT;
              substate_d      = LTSSM_SS_DETECT_QUIET;
              reason_d        = REASON_HOT_RESET;
              lt_packet_flush_o = 1'b1;
              retry_clear_o   = 1'b1;
            end else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
              state_d         = LTSSM_DETECT;
              substate_d      = LTSSM_SS_DETECT_QUIET;
              reason_d        = REASON_TIMER_EXPIRED;
              fsm_error_valid = 1'b1;
              fsm_error_code  = ERR_LTSSM_TIMEOUT;
              fsm_timeout     = 1'b1;
            end
          end
          default: begin
            state_d         = LTSSM_DETECT;
            substate_d      = LTSSM_SS_DETECT_QUIET;
            reason_d        = REASON_PROTOCOL_ERROR;
            fsm_error_valid = 1'b1;
            fsm_error_code  = ERR_LTSSM_TIMEOUT;
          end
        endcase
      end

      default: begin
        state_d             = LTSSM_RESET;
        substate_d          = LTSSM_SS_RESET_WAIT_READY;
        reason_d            = REASON_PROTOCOL_ERROR;
        enable_latched_d    = 1'b0;
        link_context_d      = 1'b0;
        recovery_fallback_d = 1'b0;
        lt_packet_flush_o   = 1'b1;
        fsm_error_valid     = 1'b1;
        fsm_error_code      = ERR_LTSSM_TIMEOUT;
      end
    endcase

    // A newly accepted command is latched first and evaluated on the next
    // cycle.  Responses remain valid until mgmt_rsp_ready_i.
    if (cmd_pending_q && !cmd_started_q) begin
      unique case (cmd_opcode_q)
        PHY_CMD_ENABLE: begin
          if ((state_q == LTSSM_RESET) || (state_q == LTSSM_DISABLED)) begin
            enable_latched_d  = 1'b1;
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_OK;
          end else begin
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_REJECTED;
          end
        end
        PHY_CMD_DISABLE: begin
          enable_latched_d  = 1'b0;
          state_d           = LTSSM_DISABLED;
          substate_d        = LTSSM_SS_DISABLED_IDLE;
          reason_d          = REASON_DISABLE_LINK;
          link_context_d    = 1'b0;
          lt_packet_flush_o = 1'b1;
          cmd_pending_d     = 1'b0;
          mgmt_rsp_valid_d  = 1'b1;
          mgmt_rsp_status_d = MGMT_RSP_OK;
        end
        PHY_CMD_RETRAIN: begin
          if (state_q == LTSSM_L0) begin
            state_d         = LTSSM_RECOVERY;
            substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
            reason_d        = REASON_MANAGEMENT_REQUEST;
            cmd_started_d   = 1'b1;
          end else begin
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_REJECTED;
          end
        end
        PHY_CMD_SET_RATE: begin
          if ((cmd_arg_q[7:1] == 0) && (state_q == LTSSM_L0)) begin
            target_rate_d = cmd_arg_q[0];
            if (cmd_arg_q[0] == crr_current_rate_i) begin
              cmd_pending_d     = 1'b0;
              mgmt_rsp_valid_d  = 1'b1;
              mgmt_rsp_status_d = MGMT_RSP_OK;
            end else begin
              state_d         = LTSSM_RECOVERY;
              substate_d      = LTSSM_SS_RECOVERY_RCVRLOCK;
              reason_d        = REASON_RATE_REQUESTED;
              cmd_started_d   = 1'b1;
            end
          end else begin
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_REJECTED;
          end
        end
        PHY_CMD_HOT_RESET: begin
          if ((state_q == LTSSM_L0) || (state_q == LTSSM_RECOVERY)) begin
            state_d        = LTSSM_HOT_RESET;
            substate_d     = LTSSM_SS_HOT_RESET_ENTRY;
            reason_d       = REASON_HOT_RESET;
            link_context_d = 1'b0;
            cmd_started_d  = 1'b1;
          end else begin
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_REJECTED;
          end
        end
        PHY_CMD_LOOPBACK: begin
          if ((cmd_arg_q[2:0] == PHY_CMD_LOOPBACK_ARG_DISABLE) &&
              (state_q == LTSSM_LOOPBACK) &&
              (substate_q == LTSSM_SS_LOOPBACK_ACTIVE)) begin
            substate_d       = LTSSM_SS_LOOPBACK_EXIT;
            reason_d         = REASON_LOOPBACK;
            cmd_started_d    = 1'b1;
          end else if (((cmd_arg_q[2:0] == PHY_CMD_LOOPBACK_ARG_NEAR) ||
                        (cmd_arg_q[2:0] == PHY_CMD_LOOPBACK_ARG_FAR)) &&
                       (cmd_arg_q[7:3] == 0) && (state_q == LTSSM_L0)) begin
            protocol_loopback_mode_d = cmd_arg_q[2:0];
            state_d                  = LTSSM_LOOPBACK;
            substate_d               = LTSSM_SS_LOOPBACK_ENTRY;
            reason_d                 = REASON_LOOPBACK;
            link_context_d           = 1'b0;
            cmd_started_d            = 1'b1;
          end else begin
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_REJECTED;
          end
        end
        PHY_CMD_COMPLIANCE: begin
          if (crr_ready_i && ((state_q == LTSSM_RESET) || (state_q == LTSSM_DETECT) ||
                              (state_q == LTSSM_POLLING) || (state_q == LTSSM_L0))) begin
            state_d           = LTSSM_POLLING;
            substate_d        = LTSSM_SS_POLLING_COMPLIANCE;
            reason_d          = REASON_COMPLIANCE;
            link_context_d    = 1'b0;
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_OK;
          end else begin
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_REJECTED;
          end
        end
        PHY_CMD_CLEAR_ERROR: begin
          lt_clear_error_o   = 1'b1;
          cmd_pending_d      = 1'b0;
          mgmt_rsp_valid_d   = 1'b1;
          mgmt_rsp_status_d  = MGMT_RSP_OK;
        end
        PHY_CMD_SET_PM_POLICY: begin
          if (cmd_arg_q[7:2] == 0) begin
            pm_policy_d       = cmd_arg_q[1:0];
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_OK;
          end else begin
            cmd_pending_d     = 1'b0;
            mgmt_rsp_valid_d  = 1'b1;
            mgmt_rsp_status_d = MGMT_RSP_REJECTED;
          end
        end
        default: begin
          cmd_pending_d     = 1'b0;
          mgmt_rsp_valid_d  = 1'b1;
          mgmt_rsp_status_d = MGMT_RSP_REJECTED;
        end
      endcase
    end

    if (pm_pending_q && !pm_started_q) begin
      if (!pm_exit_q && (state_q == LTSSM_L0)) begin
        unique case (pcie_pm_request_state_t'(pm_state_q))
          PM_REQ_L0S: begin
            if (pm_policy_q[0]) begin
              state_d             = LTSSM_L0S;
              substate_d          = LTSSM_SS_L0S_TX_ENTRY;
              reason_d            = REASON_PM_REQUEST;
              pm_started_d        = 1'b1;
              low_power_entered_d = 1'b0;
            end else begin
              pm_pending_d     = 1'b0;
              pm_rsp_valid_d   = 1'b1;
              pm_rsp_success_d = 1'b0;
            end
          end
          PM_REQ_L1: begin
            if (pm_policy_q[1]) begin
              state_d             = LTSSM_L1;
              substate_d          = LTSSM_SS_L1_ENTRY;
              reason_d            = REASON_PM_REQUEST;
              pm_phase_d          = PM_SEND_EIOS;
              low_power_entered_d = 1'b0;
              pm_started_d        = 1'b1;
            end else begin
              pm_pending_d     = 1'b0;
              pm_rsp_valid_d   = 1'b1;
              pm_rsp_success_d = 1'b0;
            end
          end
          PM_REQ_L2_L3_READY: begin
            state_d             = LTSSM_L2_L3_READY;
            substate_d          = LTSSM_SS_L2_READY_IDLE;
            reason_d            = REASON_PM_REQUEST;
            pm_phase_d          = PM_SEND_EIOS;
            low_power_entered_d = 1'b0;
            link_context_d      = 1'b0;
            pm_started_d        = 1'b1;
          end
          default: begin
            pm_pending_d     = 1'b0;
            pm_rsp_valid_d   = 1'b1;
            pm_rsp_success_d = 1'b0;
          end
        endcase
      end else if (pm_exit_q) begin
        if ((pm_state_q == PM_REQ_L0S) && (state_q == LTSSM_L0S) &&
            (substate_q == LTSSM_SS_L0S_TX_IDLE)) begin
          substate_d          = LTSSM_SS_L0S_TX_FTS;
          reason_d            = REASON_PM_EXIT;
          low_power_entered_d = 1'b0;
          pm_started_d        = 1'b1;
        end else if ((pm_state_q == PM_REQ_L1) && (state_q == LTSSM_L1) &&
                     (substate_q == LTSSM_SS_L1_IDLE)) begin
          substate_d   = LTSSM_SS_L1_EXIT;
          reason_d     = REASON_PM_EXIT;
          pm_started_d = 1'b1;
        end else if ((pm_state_q == PM_REQ_L2_L3_READY) &&
                     (state_q == LTSSM_L2_L3_READY) &&
                     (substate_q == LTSSM_SS_L2_READY_IDLE) && low_power_entered_q) begin
          substate_d   = LTSSM_SS_L2_READY_RESTART;
          reason_d     = REASON_PM_EXIT;
          pm_started_d = 1'b1;
        end else begin
          pm_pending_d     = 1'b0;
          pm_rsp_valid_d   = 1'b1;
          pm_rsp_success_d = 1'b0;
        end
      end else begin
        pm_pending_d     = 1'b0;
        pm_rsp_valid_d   = 1'b1;
        pm_rsp_success_d = 1'b0;
      end
    end

    // Accepted commands complete at their architectural end point rather than
    // at request acceptance.  Timeout/failure terminates the response first.
    if (cmd_pending_q && cmd_started_q) begin
      if (fsm_timeout) begin
        cmd_pending_d     = 1'b0;
        cmd_started_d     = 1'b0;
        mgmt_rsp_valid_d  = 1'b1;
        mgmt_rsp_status_d = MGMT_RSP_TIMEOUT;
      end else if (fsm_failed || crr_fault_i) begin
        cmd_pending_d     = 1'b0;
        cmd_started_d     = 1'b0;
        mgmt_rsp_valid_d  = 1'b1;
        mgmt_rsp_status_d = MGMT_RSP_FAILED;
      end else begin
        unique case (cmd_opcode_q)
          PHY_CMD_RETRAIN: begin
            if ((state_d == LTSSM_L0) && (substate_d == LTSSM_SS_L0_ACTIVE)) begin
              cmd_pending_d     = 1'b0;
              cmd_started_d     = 1'b0;
              mgmt_rsp_valid_d  = 1'b1;
              mgmt_rsp_status_d = MGMT_RSP_OK;
            end
          end
          PHY_CMD_SET_RATE: begin
            if ((state_d == LTSSM_L0) && (substate_d == LTSSM_SS_L0_ACTIVE)) begin
              cmd_pending_d     = 1'b0;
              cmd_started_d     = 1'b0;
              mgmt_rsp_valid_d  = 1'b1;
              mgmt_rsp_status_d = (crr_current_rate_i == cmd_arg_q[0]) ? MGMT_RSP_OK : MGMT_RSP_FAILED;
            end
          end
          PHY_CMD_HOT_RESET: begin
            if ((state_d == LTSSM_DETECT) && (substate_d == LTSSM_SS_DETECT_QUIET)) begin
              cmd_pending_d     = 1'b0;
              cmd_started_d     = 1'b0;
              mgmt_rsp_valid_d  = 1'b1;
              mgmt_rsp_status_d = MGMT_RSP_OK;
            end
          end
          PHY_CMD_LOOPBACK: begin
            if (((cmd_arg_q[2:0] != PHY_CMD_LOOPBACK_ARG_DISABLE) &&
                 (state_d == LTSSM_LOOPBACK) && (substate_d == LTSSM_SS_LOOPBACK_ACTIVE)) ||
                ((cmd_arg_q[2:0] == PHY_CMD_LOOPBACK_ARG_DISABLE) &&
                 (state_d == LTSSM_RECOVERY))) begin
              cmd_pending_d     = 1'b0;
              cmd_started_d     = 1'b0;
              mgmt_rsp_valid_d  = 1'b1;
              mgmt_rsp_status_d = MGMT_RSP_OK;
            end
          end
          default: ;
        endcase
      end
    end

    if (pm_pending_q && pm_started_q) begin
      if (fsm_timeout || fsm_failed || crr_fault_i || crr_power_fail_i) begin
        pm_pending_d     = 1'b0;
        pm_started_d     = 1'b0;
        pm_rsp_valid_d   = 1'b1;
        pm_rsp_success_d = 1'b0;
      end else if (!pm_exit_q) begin
        if (((pm_state_q == PM_REQ_L0S) && (state_q == LTSSM_L0S) &&
             (substate_q == LTSSM_SS_L0S_TX_IDLE) && low_power_entered_d) ||
            ((pm_state_q == PM_REQ_L1) && (state_d == LTSSM_L1) &&
             (substate_d == LTSSM_SS_L1_IDLE)) ||
            ((pm_state_q == PM_REQ_L2_L3_READY) && (state_d == LTSSM_L2_L3_READY) &&
             low_power_entered_d)) begin
          pm_pending_d     = 1'b0;
          pm_started_d     = 1'b0;
          pm_rsp_valid_d   = 1'b1;
          pm_rsp_success_d = 1'b1;
        end
      end else begin
        if (((pm_state_q == PM_REQ_L0S) && (state_d == LTSSM_L0)) ||
            ((pm_state_q == PM_REQ_L1) && (state_d == LTSSM_L0)) ||
            ((pm_state_q == PM_REQ_L2_L3_READY) && (state_d == LTSSM_DETECT))) begin
          pm_pending_d     = 1'b0;
          pm_started_d     = 1'b0;
          pm_rsp_valid_d   = 1'b1;
          pm_rsp_success_d = 1'b1;
        end
      end
    end

    if (os_rx_error_i != ERR_NONE) begin
      fsm_error_valid = 1'b1;
      fsm_error_code  = ERR_RX_OS_INVALID;
      fsm_error_info  = {state_q, substate_q, os_rx_error_i, peer_fields_q.rate_id, 10'd0};
      if (rx_packet_active_i) lt_packet_drop_o = 1'b1;
    end

    // Highest-priority normalized GT/clock fault overrides every protocol or
    // management transition in this cycle.
    if (crr_fault_i) begin
      fsm_error_valid = 1'b1;
      fsm_error_code  = (crr_fault_code_i == ERR_NONE) ? ERR_GT_PLL_UNLOCK : crr_fault_code_i;
      fsm_error_fatal = error_is_fatal(pcie_phy_error_code_t'(fsm_error_code));
      fsm_error_info  = {state_q, substate_q, crr_fault_code_i, retry_count_i, 4'd0};
      lt_packet_drop_o  = rx_packet_active_i;
      lt_packet_flush_o = fsm_error_fatal;
      if (fsm_error_fatal) begin
        state_d        = LTSSM_DETECT;
        substate_d     = LTSSM_SS_DETECT_QUIET;
        reason_d       = REASON_FATAL_ERROR;
        link_context_d = 1'b0;
      end
    end

    transition = (state_d != state_q) || (substate_d != substate_q);
    if (state_d != LTSSM_DISABLED) disabled_hold_done_d = 1'b0;
    if (transition) begin
      local_train_done_d  = 1'b0;
      remote_train_done_d = 1'b0;
      local_idle_done_d   = 1'b0;
      remote_idle_done_d  = 1'b0;
    end

    next_timer_id = state_timer_id(state_d, substate_d);
    timer_start_o = 1'b0;
    timer_stop_o  = 1'b0;
    timer_id_o    = next_timer_id;
    timer_limit_o = timer_default_cycles(next_timer_id, SIM_TIME_SCALE);
    if (transition) begin
      timer_stop_o = 1'b1;
      if (next_timer_id != TIMER_NONE) timer_start_o = 1'b1;
    end else if (timer_restart) begin
      timer_start_o = 1'b1;
      timer_id_o    = current_timer_id;
      timer_limit_o = timer_default_cycles(current_timer_id, SIM_TIME_SCALE);
    end

    lt_data_active_o = (state_q == LTSSM_L0) && (state_d == LTSSM_L0) &&
                       crr_ready_i && crr_rx_aligned_i && !crr_fault_i &&
                       !cmd_pending_q && !pm_pending_q;
    lt_packet_enable_o = lt_data_active_o;
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani) begin
    if (!ctrl_local_reset_ani) begin
      state_q                  <= LTSSM_RESET;
      substate_q               <= LTSSM_SS_RESET_WAIT_READY;
      reason_q                 <= REASON_RESET_ASSERTED;
      peer_fields_q            <= '0;
      tx_fields_q              <= '0;
      tx_fields_q.valid        <= 1'b1;
      tx_fields_q.link_num_is_pad <= 1'b1;
      tx_fields_q.lane_num_is_pad <= 1'b1;
      tx_fields_q.rate_id      <= RATE_ID_GEN1_SUPPORTED | RATE_ID_GEN2_SUPPORTED;
      speed_phase_q            <= SPEED_SEND_EIOS;
      pm_phase_q               <= PM_SEND_EIOS;
      enable_latched_q         <= 1'b0;
      target_rate_q            <= 1'b0;
      peer_gen2_capable_q      <= 1'b0;
      link_context_q           <= 1'b0;
      recovery_fallback_q      <= 1'b0;
      pm_policy_q              <= 2'b11;
      protocol_loopback_mode_q <= PHY_CMD_LOOPBACK_ARG_DISABLE;
      local_train_done_q       <= 1'b0;
      remote_train_done_q      <= 1'b0;
      local_idle_done_q        <= 1'b0;
      remote_idle_done_q       <= 1'b0;
      low_power_entered_q      <= 1'b0;
      disabled_hold_done_q     <= 1'b0;
      cmd_pending_q            <= 1'b0;
      cmd_started_q            <= 1'b0;
      cmd_opcode_q             <= PHY_CMD_ENABLE;
      cmd_arg_q                <= '0;
      mgmt_rsp_valid_q         <= 1'b0;
      mgmt_rsp_status_q        <= MGMT_RSP_OK;
      pm_pending_q             <= 1'b0;
      pm_started_q             <= 1'b0;
      pm_state_q               <= PM_REQ_L0S;
      pm_exit_q                <= 1'b0;
      pm_rsp_valid_q           <= 1'b0;
      pm_rsp_success_q         <= 1'b0;
      lt_status_evt_valid_o    <= 1'b0;
      lt_status_evt_code_o     <= ERR_NONE;
      lt_status_evt_info_o     <= '0;
      lt_status_evt_fatal_o    <= 1'b0;
    end else begin
      state_q                  <= state_d;
      substate_q               <= substate_d;
      reason_q                 <= reason_d;
      peer_fields_q            <= peer_fields_d;
      tx_fields_q              <= tx_fields_d;
      speed_phase_q            <= speed_phase_d;
      pm_phase_q               <= pm_phase_d;
      enable_latched_q         <= enable_latched_d;
      target_rate_q            <= target_rate_d;
      peer_gen2_capable_q      <= peer_gen2_capable_d;
      link_context_q           <= link_context_d;
      recovery_fallback_q      <= recovery_fallback_d;
      pm_policy_q              <= pm_policy_d;
      protocol_loopback_mode_q <= protocol_loopback_mode_d;
      local_train_done_q       <= local_train_done_d;
      remote_train_done_q      <= remote_train_done_d;
      local_idle_done_q        <= local_idle_done_d;
      remote_idle_done_q       <= remote_idle_done_d;
      low_power_entered_q      <= low_power_entered_d;
      disabled_hold_done_q     <= disabled_hold_done_d;
      cmd_pending_q            <= cmd_pending_d;
      cmd_started_q            <= cmd_started_d;
      cmd_opcode_q             <= cmd_opcode_d;
      cmd_arg_q                <= cmd_arg_d;
      mgmt_rsp_valid_q         <= mgmt_rsp_valid_d;
      mgmt_rsp_status_q        <= mgmt_rsp_status_d;
      pm_pending_q             <= pm_pending_d;
      pm_started_q             <= pm_started_d;
      pm_state_q               <= pm_state_d;
      pm_exit_q                <= pm_exit_d;
      pm_rsp_valid_q           <= pm_rsp_valid_d;
      pm_rsp_success_q         <= pm_rsp_success_d;

      lt_status_evt_valid_o <= 1'b0;
      if (transition) begin
        lt_status_evt_valid_o <= 1'b1;
        lt_status_evt_code_o  <= ERR_NONE;
        lt_status_evt_info_o  <= {state_q, state_d, substate_q, substate_d, reason_d};
        lt_status_evt_fatal_o <= 1'b0;
      end
      if (fsm_error_valid) begin
        lt_status_evt_valid_o <= 1'b1;
        lt_status_evt_code_o  <= fsm_error_code;
        lt_status_evt_info_o  <= fsm_error_info;
        lt_status_evt_fatal_o <= fsm_error_fatal;
      end
    end
  end

endmodule
