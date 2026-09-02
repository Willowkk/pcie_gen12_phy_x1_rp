module pcie_gen12_phy_x1_rp #(
  parameter int unsigned SIM_TIME_SCALE = 1,
  parameter logic [2:0] BEHAV_DETECT_STATUS = 3'b011,
  parameter bit BEHAV_DETECT_TIMEOUT = 1'b0,
  parameter bit BEHAV_RATE_FAIL = 1'b0,
  parameter bit BEHAV_POWER_FAIL = 1'b0,
  parameter bit BEHAV_LINK_POLARITY_INVERTED = 1'b0,
  parameter int unsigned BEHAV_ELASTIC_CORRECTION_MODE = 0,
  parameter bit BEHAV_INJECT_CODE_ERROR = 1'b0,
  parameter bit BEHAV_INJECT_DISPARITY_ERROR = 1'b0,
  parameter bit BEHAV_INJECT_RXBUF_UNDERFLOW = 1'b0,
  parameter bit BEHAV_INJECT_RXBUF_OVERFLOW = 1'b0,
  parameter bit BEHAV_INJECT_TXBUF_FAULT = 1'b0
) (
  input  logic        ctrl_clk_i,
  input  logic        ctrl_rst_ni,
  input  logic        link_clk_i,
  input  logic        link_rst_ni,
  input  logic        port_reset_ni,
  input  logic        pcie_refclk_p_i,
  input  logic        pcie_refclk_n_i,
  input  logic        pcie_rx_p_i,
  input  logic        pcie_rx_n_i,
  output logic        pcie_tx_p_o,
  output logic        pcie_tx_n_o,
  output logic        phy_sym_clk_o,
  output logic        phy_sym_rst_no,
  output logic        phy_dll_link_up_o,
  output logic        phy_dll_data_active_o,
  output logic        phy_dll_current_rate_o,
  output logic        phy_dll_link_down_evt_o,
  input  logic        dll_tx_valid_i,
  output logic        dll_tx_ready_o,
  input  logic [15:0] dll_tx_data_i,
  input  logic [1:0]  dll_tx_keep_i,
  input  logic        dll_tx_sop_i,
  input  logic        dll_tx_eop_i,
  input  logic        dll_tx_kind_i,
  input  logic        dll_tx_abort_i,
  output logic        dll_rx_valid_o,
  input  logic        dll_rx_ready_i,
  output logic [15:0] dll_rx_data_o,
  output logic [1:0]  dll_rx_keep_o,
  output logic        dll_rx_sop_o,
  output logic        dll_rx_eop_o,
  output logic        dll_rx_kind_o,
  output logic        dll_rx_abort_o,
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
  output logic        phy_ready_o,
  output logic        phy_link_up_o,
  output logic        phy_data_active_o,
  output logic        phy_current_rate_o,
  output logic [5:0]  phy_ltssm_state_o,
  output logic [5:0]  phy_ltssm_substate_o,
  output logic [7:0]  phy_state_reason_o,
  output logic        phy_rx_locked_o,
  output logic        phy_err_valid_o,
  input  logic        phy_err_ready_i,
  output logic [7:0]  phy_err_code_o,
  output logic [31:0] phy_err_info_o,
  input  logic        phy_csr_req_valid_i,
  output logic        phy_csr_req_ready_o,
  input  logic        phy_csr_req_write_i,
  input  logic [11:0] phy_csr_req_addr_i,
  input  logic [31:0] phy_csr_req_wdata_i,
  input  logic [3:0]  phy_csr_req_wstrb_i,
  output logic        phy_csr_rsp_valid_o,
  input  logic        phy_csr_rsp_ready_i,
  output logic [31:0] phy_csr_rsp_rdata_o,
  output logic        phy_csr_rsp_error_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

  localparam int unsigned OS_REQUEST_WIDTH = 3 + $bits(pcie_ts_fields_t) + 3;
  localparam int unsigned OS_EVENT_WIDTH   = 8 + $bits(pcie_ts_fields_t) + 10;
  localparam int unsigned CTRL_SNAPSHOT_WIDTH = 20;
  localparam int unsigned DECODE_STREAK_WIDTH =
      (RX_DECODE_ERROR_THRESHOLD <= 1) ? 1 : $clog2(RX_DECODE_ERROR_THRESHOLD + 1);

  // port_reset_ni is an asynchronous assertion source.  These local reset
  // nets release only after two clocks in their respective infrastructure
  // domains; the GT/CRR owns the independent symbol-domain release.
  (* ASYNC_REG = "TRUE" *) logic [1:0] ctrl_reset_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] link_reset_sync_q;
  logic ctrl_local_rst_ni;
  logic link_local_rst_ni;

  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni or negedge port_reset_ni) begin
    if (!ctrl_rst_ni || !port_reset_ni)
      ctrl_reset_sync_q <= 2'b00;
    else
      ctrl_reset_sync_q <= {ctrl_reset_sync_q[0], 1'b1};
  end

  always_ff @(posedge link_clk_i or negedge link_rst_ni or negedge port_reset_ni) begin
    if (!link_rst_ni || !port_reset_ni)
      link_reset_sync_q <= 2'b00;
    else
      link_reset_sync_q <= {link_reset_sync_q[0], 1'b1};
  end

  assign ctrl_local_rst_ni = ctrl_reset_sync_q[1];
  assign link_local_rst_ni = link_reset_sync_q[1];

  // ------------------------------------------------------------------------
  // GT adapter and Clock/Reset/Rate controller
  // ------------------------------------------------------------------------
  logic gt_sym_clk;
  logic gt_sym_rst_n;
  logic gt_sym_clk_stable;
  logic gt_buffer_reinit_done;
  logic [15:0] gt_rx_symbol_data;
  logic [1:0] gt_rx_symbol_is_k;
  logic [1:0] gt_rx_symbol_disparity_error;
  logic [1:0] gt_rx_symbol_code_error;
  logic [1:0] gt_rx_symbol_is_comma;
  logic gt_rx_symbol_valid;
  logic gt_rx_byte_aligned;
  logic gt_rx_realign_event;
  logic [1:0] gt_rx_clkcor_count;
  logic [2:0] gt_rx_buffer_status;
  logic gt_tx_buffer_fault;

  logic gt_detect_req;
  logic gt_detect_busy;
  logic gt_detect_done;
  logic gt_receiver_present;
  logic gt_rate_req;
  logic gt_rate_target_gen2;
  logic gt_rate_busy;
  logic gt_rate_done;
  logic gt_rate_fail;
  logic gt_tx_electrical_idle;
  logic gt_tx_electrical_idle_active;
  logic gt_rx_electrical_idle;
  logic gt_power_req;
  logic [1:0] gt_power_state;
  logic gt_power_busy;
  logic gt_power_done;
  logic gt_power_fail;
  logic gt_rx_polarity_invert;
  logic gt_tx_deemphasis;
  logic gt_tx_swing;
  logic [2:0] gt_tx_margin;
  logic gt_compliance_enable;
  logic [2:0] gt_loopback_mode;
  logic gt_ready;
  logic gt_fault;
  logic [7:0] gt_fault_code;

  logic crr_ready;
  logic crr_current_rate;
  logic crr_detect_done;
  logic crr_receiver_present;
  logic crr_rate_done;
  logic crr_rate_fail;
  logic crr_power_done;
  logic crr_power_fail;
  logic crr_tx_electrical_idle_active;
  logic crr_rx_electrical_idle;
  logic crr_rx_aligned;
  logic crr_fault;
  logic [7:0] crr_fault_code;
  logic crr_sym_path_reset;
  logic crr_packet_admission_enable;
  logic crr_packet_buffer_flush;

  // ------------------------------------------------------------------------
  // LTSSM, timer and control-plane signals
  // ------------------------------------------------------------------------
  logic lt_gt_detect_req;
  logic lt_gt_rate_req;
  logic lt_gt_rate_target_gen2;
  logic lt_gt_power_req;
  logic [1:0] lt_gt_power_state;
  logic lt_gt_tx_electrical_idle;
  logic lt_gt_rx_polarity_invert;
  logic lt_gt_tx_deemphasis;
  logic lt_gt_tx_swing;
  logic [2:0] lt_gt_tx_margin;
  logic lt_gt_compliance_enable;
  logic [2:0] lt_gt_loopback_mode;
  logic lt_os_req_valid;
  logic lt_os_req_ready;
  logic [2:0] lt_os_kind;
  pcie_ts_fields_t lt_os_fields;
  logic [2:0] lt_os_repeat_mode;
  logic [3:0] lt_tx_mode;
  logic lt_packet_enable;
  logic lt_packet_flush;
  logic lt_packet_drop;
  logic timer_start;
  logic timer_stop;
  logic [5:0] timer_command_id;
  logic [31:0] timer_limit;
  logic retry_update;
  logic retry_clear;
  logic timer_expired;
  logic [5:0] timer_expired_id;
  logic [7:0] retry_count;
  logic timer_active;
  logic [31:0] timer_count;
  logic [5:0] lt_state;
  logic [5:0] lt_substate;
  logic [7:0] lt_entry_reason;
  logic lt_link_up;
  logic lt_data_active;
  logic lt_current_rate;
  logic lt_target_rate;
  logic lt_clear_error;
  logic lt_status_evt_valid;
  logic [7:0] lt_status_evt_code;
  logic [31:0] lt_status_evt_info;
  logic lt_status_evt_fatal;

  // ------------------------------------------------------------------------
  // TX/RX packet and character datapath signals
  // ------------------------------------------------------------------------
  logic txbuf_pkt_valid;
  logic txbuf_pkt_ready;
  logic [15:0] txbuf_pkt_data;
  logic [1:0] txbuf_pkt_keep;
  logic txbuf_pkt_sop;
  logic txbuf_pkt_eop;
  logic txbuf_pkt_kind;
  logic txbuf_pkt_abort;
  logic txbuf_capture_active_link;
  logic txbuf_pending_sym;
  logic txbuf_error_evt_link;
  logic [7:0] txbuf_error_code_link;
  logic [7:0] txbuf_level_sym;

  logic [15:0] tx_selected_data;
  logic [1:0] tx_selected_is_k;
  logic [3:0] tx_selected_class;
  logic [1:0] tx_lfsr_action;
  logic tx_packet_active_sym;
  logic tx_quiesced_sym;
  logic tx_logical_idle_evt_sym;
  logic tx_scheduler_error_evt_sym;
  logic [7:0] tx_scheduler_error_code_sym;
  logic [15:0] tx_scrambled_data;
  logic [1:0] tx_scrambled_is_k;
  logic [15:0] tx_scrambler_state;
  logic [15:0] rx_descrambler_state;
  logic scrambler_sync_error_sym;

  logic [15:0] os_rx_candidate_data;
  logic [1:0] os_rx_candidate_is_k;
  logic os_rx_candidate_valid;
  logic [3:0] os_rx_candidate_error;
  logic [15:0] rx_descr_data;
  logic [1:0] rx_descr_is_k;
  logic rx_descr_valid;
  logic [3:0] rx_descr_class;
  logic [3:0] rx_descr_lfsr_action;
  logic [15:0] rx_descrambled_data;
  logic rx_descrambled_valid;
  logic rxbuf_pkt_valid;
  logic rxbuf_pkt_ready;
  logic [15:0] rxbuf_pkt_data;
  logic [1:0] rxbuf_pkt_keep;
  logic rxbuf_pkt_sop;
  logic rxbuf_pkt_eop;
  logic rxbuf_pkt_kind;
  logic rxbuf_pkt_abort;
  logic rxbuf_pkt_drop;
  logic rx_logical_idle_valid;
  logic [1:0] rx_logical_idle_char_mask;
  logic rx_align_loss_evt_sym;
  logic rx_invalid_k_evt_sym;
  logic rx_code_error_evt_sym;
  logic rx_disparity_error_evt_sym;
  logic rx_frame_error_evt_sym;
  logic rx_packet_buffer_error_evt_sym;
  logic rx_packet_drop_evt_sym;
  logic rx_packet_active_sym;
  logic rxbuf_overflow_evt_sym;
  logic rxbuf_candidate_drop_evt_sym;
  logic rxbuf_backpressure_timeout_evt_link;
  logic [7:0] rxbuf_level_sym;

  // ------------------------------------------------------------------------
  // Ordered-set and SKP scheduler signals
  // ------------------------------------------------------------------------
  logic os_req_valid_sym;
  logic os_req_ready_sym;
  logic [2:0] os_req_kind_sym;
  pcie_ts_fields_t os_req_fields_sym;
  logic [2:0] os_req_repeat_sym;
  logic [15:0] os_tx_data;
  logic [1:0] os_tx_is_k;
  logic [3:0] os_tx_class;
  logic os_tx_valid;
  logic os_tx_done_sym;
  logic os_tx_consume;
  logic os_tx_skp_start;
  logic os_tx_skp_done;
  logic os_rx_ts1_evt_sym;
  logic os_rx_ts2_evt_sym;
  logic os_rx_fts_evt_sym;
  logic os_rx_skp_evt_sym;
  logic os_rx_eios_evt_sym;
  logic os_rx_eieos_evt_sym;
  logic rx_logical_idle_qualified_evt_sym;
  logic os_rx_hot_reset_evt_sym;
  logic os_rx_loopback_evt_sym;
  logic os_rx_speed_change_evt_sym;
  pcie_ts_fields_t os_rx_fields_sym;
  logic [7:0] os_rx_error_sym;
  logic skp_due_sym;
  logic [15:0] skp_deadline_sym;
  logic skp_deadline_missed_evt_sym;
  logic skp_rx_add_evt_sym;
  logic [1:0] skp_rx_skip_count_sym;
  logic skp_rx_buffer_fault_evt_sym;
  logic skp_rx_underflow_evt_sym;
  logic skp_rx_overflow_evt_sym;
  logic skp_rx_status_invalid_evt_sym;

  // ------------------------------------------------------------------------
  // Coherent control snapshot: LTSSM/CRR ctrl_clk -> sym_clk
  // ------------------------------------------------------------------------
  logic [CTRL_SNAPSHOT_WIDTH-1:0] ctrl_snapshot_source;
  logic [CTRL_SNAPSHOT_WIDTH-1:0] ctrl_snapshot_sym;
  logic crr_ready_sym;
  logic crr_admission_sym;
  logic current_rate_sym;
  logic [5:0] lt_substate_sym;
  logic [5:0] lt_state_sym;
  logic lt_packet_enable_snapshot_sym;
  logic [3:0] lt_tx_mode_sym;
  logic lt_packet_enable_sym;

  assign ctrl_snapshot_source = {
    crr_ready,
    crr_packet_admission_enable,
    crr_current_rate,
    lt_substate,
    lt_state,
    lt_packet_enable,
    lt_tx_mode
  };
  assign {
    crr_ready_sym,
    crr_admission_sym,
    current_rate_sym,
    lt_substate_sym,
    lt_state_sym,
    lt_packet_enable_snapshot_sym,
    lt_tx_mode_sym
  } = ctrl_snapshot_sym;
  assign lt_packet_enable_sym = lt_packet_enable_snapshot_sym && crr_admission_sym;

  phy_cdc_snapshot #(
    .WIDTH(CTRL_SNAPSHOT_WIDTH)
  ) u_ctrl_to_sym_snapshot (
    .s_clk_i(ctrl_clk_i),
    .s_rst_ni(ctrl_local_rst_ni),
    .s_data_i(ctrl_snapshot_source),
    .d_clk_i(phy_sym_clk_o),
    .d_rst_ni(phy_sym_rst_no),
    .d_data_o(ctrl_snapshot_sym)
  );

  // Complete packet admission is coherent in link_clk.  The CRR gate is an
  // additional single-bit safety level; the status module transfers the
  // state/rate/data-active tuple coherently.
  (* ASYNC_REG = "TRUE" *) logic [1:0] crr_admission_link_sync_q;
  always_ff @(posedge link_clk_i or negedge link_local_rst_ni) begin
    if (!link_local_rst_ni)
      crr_admission_link_sync_q <= 2'b00;
    else
      crr_admission_link_sync_q <= {
        crr_admission_link_sync_q[0], crr_packet_admission_enable
      };
  end

  // ------------------------------------------------------------------------
  // Coordinated whole-packet buffer flush
  // ------------------------------------------------------------------------
  typedef enum logic [1:0] {
    FLUSH_WAIT_ASSERT,
    FLUSH_WAIT_RELEASE,
    FLUSH_IDLE
  } flush_state_t;
  flush_state_t flush_state_q;
  logic flush_hold_ctrl_q;
  logic flush_retrigger_q;
  logic flush_request_ctrl;
  (* ASYNC_REG = "TRUE" *) logic [1:0] flush_link_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] flush_sym_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] flush_link_ack_ctrl_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] flush_sym_ack_ctrl_sync_q;

  assign flush_request_ctrl = crr_packet_buffer_flush || lt_packet_flush;

  always_ff @(posedge link_clk_i or negedge link_local_rst_ni) begin
    if (!link_local_rst_ni)
      flush_link_sync_q <= 2'b00;
    else
      flush_link_sync_q <= {flush_link_sync_q[0], flush_hold_ctrl_q};
  end

  always_ff @(posedge phy_sym_clk_o or negedge phy_sym_rst_no) begin
    if (!phy_sym_rst_no)
      flush_sym_sync_q <= 2'b00;
    else
      flush_sym_sync_q <= {flush_sym_sync_q[0], flush_hold_ctrl_q};
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni) begin
    if (!ctrl_local_rst_ni) begin
      flush_link_ack_ctrl_sync_q <= 2'b00;
      flush_sym_ack_ctrl_sync_q  <= 2'b00;
    end else begin
      flush_link_ack_ctrl_sync_q <= {
        flush_link_ack_ctrl_sync_q[0], flush_link_sync_q[1]
      };
      flush_sym_ack_ctrl_sync_q <= {
        flush_sym_ack_ctrl_sync_q[0], flush_sym_sync_q[1]
      };
    end
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni) begin
    if (!ctrl_local_rst_ni) begin
      flush_state_q    <= FLUSH_WAIT_ASSERT;
      flush_hold_ctrl_q <= 1'b1;
      flush_retrigger_q <= 1'b0;
    end else begin
      unique case (flush_state_q)
        FLUSH_WAIT_ASSERT: begin
          flush_hold_ctrl_q <= 1'b1;
          if (flush_link_ack_ctrl_sync_q[1] &&
              flush_sym_ack_ctrl_sync_q[1] && !flush_request_ctrl) begin
            flush_hold_ctrl_q <= 1'b0;
            flush_state_q     <= FLUSH_WAIT_RELEASE;
          end
        end
        FLUSH_WAIT_RELEASE: begin
          flush_hold_ctrl_q <= 1'b0;
          if (flush_request_ctrl)
            flush_retrigger_q <= 1'b1;
          if (!flush_link_ack_ctrl_sync_q[1] &&
              !flush_sym_ack_ctrl_sync_q[1]) begin
            if (flush_retrigger_q || flush_request_ctrl) begin
              flush_retrigger_q <= 1'b0;
              flush_hold_ctrl_q <= 1'b1;
              flush_state_q     <= FLUSH_WAIT_ASSERT;
            end else begin
              flush_state_q <= FLUSH_IDLE;
            end
          end
        end
        default: begin // FLUSH_IDLE
          flush_retrigger_q <= 1'b0;
          if (flush_request_ctrl) begin
            flush_hold_ctrl_q <= 1'b1;
            flush_state_q     <= FLUSH_WAIT_ASSERT;
          end
        end
      endcase
    end
  end

  // ------------------------------------------------------------------------
  // LTSSM ordered-set request uses a held bundled-data request/ack crossing.
  // ------------------------------------------------------------------------
  logic [OS_REQUEST_WIDTH-1:0] os_request_ctrl_payload;
  logic [OS_REQUEST_WIDTH-1:0] os_request_sym_payload;
  logic [OS_REQUEST_WIDTH:0] os_request_ctrl_level;
  logic [OS_REQUEST_WIDTH:0] os_request_sym_level;
  assign os_request_ctrl_payload = {
    lt_os_repeat_mode, lt_os_fields, lt_os_kind
  };
  assign os_request_ctrl_level = {
    lt_os_req_valid, os_request_ctrl_payload
  };
  assign {
    os_req_valid_sym, os_request_sym_payload
  } = os_request_sym_level;
  assign {
    os_req_repeat_sym, os_req_fields_sym, os_req_kind_sym
  } = os_request_sym_payload;
  // LTSSM presents a desired OS stream level; it does not issue transient
  // pulses.  The coherent latest-value crossing lets the symbol-domain
  // generator repeat training sets without CDC round-trip gaps and switch
  // only at a complete ordered-set boundary.
  assign lt_os_req_ready = 1'b1;

  phy_cdc_snapshot #(
    .WIDTH(OS_REQUEST_WIDTH + 1),
    .RESET_VALUE('0)
  ) u_os_request_cdc (
    .s_clk_i(ctrl_clk_i),
    .s_rst_ni(ctrl_local_rst_ni),
    .s_data_i(os_request_ctrl_level),
    .d_clk_i(phy_sym_clk_o),
    .d_rst_ni(phy_sym_rst_no),
    .d_data_o(os_request_sym_level)
  );

  // ------------------------------------------------------------------------
  // Datapath instances
  // ------------------------------------------------------------------------
  phy_tx_packet_buffer_cdc u_phy_tx_packet_buffer_cdc (
    .link_clk_i(link_clk_i),
    .link_rst_ni(link_rst_ni),
    .port_reset_ni(port_reset_ni),
    .sym_clk_i(phy_sym_clk_o),
    .sym_rst_ni(phy_sym_rst_no),
    .dll_tx_valid_i(dll_tx_valid_i),
    .dll_tx_ready_o(dll_tx_ready_o),
    .dll_tx_data_i(dll_tx_data_i),
    .dll_tx_keep_i(dll_tx_keep_i),
    .dll_tx_sop_i(dll_tx_sop_i),
    .dll_tx_eop_i(dll_tx_eop_i),
    .dll_tx_kind_i(dll_tx_kind_i),
    .dll_tx_abort_i(dll_tx_abort_i),
    .txbuf_admission_enable_i(
      phy_dll_data_active_o && crr_admission_link_sync_q[1]
    ),
    .txbuf_flush_i(flush_hold_ctrl_q),
    .txbuf_pkt_valid_o(txbuf_pkt_valid),
    .txbuf_pkt_ready_i(txbuf_pkt_ready),
    .txbuf_pkt_data_o(txbuf_pkt_data),
    .txbuf_pkt_keep_o(txbuf_pkt_keep),
    .txbuf_pkt_sop_o(txbuf_pkt_sop),
    .txbuf_pkt_eop_o(txbuf_pkt_eop),
    .txbuf_pkt_kind_o(txbuf_pkt_kind),
    .txbuf_pkt_abort_o(txbuf_pkt_abort),
    .txbuf_capture_active_o(txbuf_capture_active_link),
    .txbuf_pending_o(txbuf_pending_sym),
    .txbuf_error_evt_o(txbuf_error_evt_link),
    .txbuf_error_code_o(txbuf_error_code_link),
    .txbuf_level_o(txbuf_level_sym)
  );

  phy_tx_framer_scheduler u_phy_tx_framer_scheduler (
    .sym_clk_i(phy_sym_clk_o),
    .sym_rst_ni(phy_sym_rst_no),
    .txbuf_pkt_valid_i(txbuf_pkt_valid),
    .txbuf_pkt_ready_o(txbuf_pkt_ready),
    .txbuf_pkt_data_i(txbuf_pkt_data),
    .txbuf_pkt_keep_i(txbuf_pkt_keep),
    .txbuf_pkt_sop_i(txbuf_pkt_sop),
    .txbuf_pkt_eop_i(txbuf_pkt_eop),
    .txbuf_pkt_kind_i(txbuf_pkt_kind),
    .txbuf_pkt_abort_i(txbuf_pkt_abort),
    .txbuf_pending_i(txbuf_pending_sym),
    .lt_tx_mode_i(lt_tx_mode_sym),
    .lt_tx_quiesce_i(!crr_admission_sym),
    .lt_packet_enable_i(lt_packet_enable_sym),
    .lt_state_i(lt_state_sym),
    .lt_substate_i(lt_substate_sym),
    .os_tx_data_i(os_tx_data),
    .os_tx_is_k_i(os_tx_is_k),
    .os_tx_class_i(os_tx_class),
    .os_tx_valid_i(os_tx_valid),
    .os_tx_done_i(os_tx_done_sym),
    .os_tx_consume_o(os_tx_consume),
    .skp_due_i(skp_due_sym),
    .skp_deadline_i(skp_deadline_sym),
    .tx_sel_data_o(tx_selected_data),
    .tx_sel_is_k_o(tx_selected_is_k),
    .tx_symbol_class_o(tx_selected_class),
    .tx_lfsr_action_o(tx_lfsr_action),
    .tx_packet_active_o(tx_packet_active_sym),
    .tx_quiesced_o(tx_quiesced_sym),
    .tx_logical_idle_qualified_evt_o(tx_logical_idle_evt_sym),
    .tx_scheduler_error_evt_o(tx_scheduler_error_evt_sym),
    .tx_scheduler_error_code_o(tx_scheduler_error_code_sym)
  );

  phy_scrambler_descrambler u_phy_scrambler_descrambler (
    .sym_clk_i(phy_sym_clk_o),
    .sym_rst_ni(phy_sym_rst_no),
    .tx_scr_data_i(tx_selected_data),
    .tx_scr_is_k_i(tx_selected_is_k),
    .tx_scr_class_i(tx_selected_class),
    .tx_scr_lfsr_action_i(tx_lfsr_action),
    .tx_scr_data_o(tx_scrambled_data),
    .tx_scr_is_k_o(tx_scrambled_is_k),
    .rx_descr_data_i(rx_descr_data),
    .rx_descr_is_k_i(rx_descr_is_k),
    .rx_descr_valid_i(rx_descr_valid),
    .rx_descr_class_i(rx_descr_class),
    .rx_descr_lfsr_action_i(rx_descr_lfsr_action),
    .rx_descr_data_o(rx_descrambled_data),
    .rx_descr_valid_o(rx_descrambled_valid),
    .tx_scrambler_state_o(tx_scrambler_state),
    .rx_descrambler_state_o(rx_descrambler_state),
    .scrambler_sync_error_o(scrambler_sync_error_sym)
  );

  phy_rx_classifier_deframer u_phy_rx_classifier_deframer (
    .sym_clk_i(phy_sym_clk_o),
    .sym_rst_ni(phy_sym_rst_no),
    .rx_symbol_data_i(gt_rx_symbol_data),
    .rx_symbol_is_k_i(gt_rx_symbol_is_k),
    .rx_symbol_valid_i(gt_rx_symbol_valid),
    .rx_symbol_is_comma_i(gt_rx_symbol_is_comma),
    .rx_symbol_code_error_i(gt_rx_symbol_code_error),
    .rx_symbol_disparity_error_i(gt_rx_symbol_disparity_error),
    .rx_byte_aligned_i(gt_rx_byte_aligned),
    .os_rx_candidate_data_o(os_rx_candidate_data),
    .os_rx_candidate_is_k_o(os_rx_candidate_is_k),
    .os_rx_candidate_valid_o(os_rx_candidate_valid),
    .os_rx_candidate_error_o(os_rx_candidate_error),
    .rx_descr_data_o(rx_descr_data),
    .rx_descr_is_k_o(rx_descr_is_k),
    .rx_descr_valid_o(rx_descr_valid),
    .rx_descr_class_o(rx_descr_class),
    .rx_descr_lfsr_action_o(rx_descr_lfsr_action),
    .rx_descrambled_data_i(rx_descrambled_data),
    .rx_descrambled_valid_i(rx_descrambled_valid),
    .rxbuf_pkt_valid_o(rxbuf_pkt_valid),
    .rxbuf_pkt_ready_i(rxbuf_pkt_ready),
    .rxbuf_pkt_data_o(rxbuf_pkt_data),
    .rxbuf_pkt_keep_o(rxbuf_pkt_keep),
    .rxbuf_pkt_sop_o(rxbuf_pkt_sop),
    .rxbuf_pkt_eop_o(rxbuf_pkt_eop),
    .rxbuf_pkt_kind_o(rxbuf_pkt_kind),
    .rxbuf_pkt_abort_o(rxbuf_pkt_abort),
    .rxbuf_pkt_drop_o(rxbuf_pkt_drop),
    .rx_logical_idle_valid_o(rx_logical_idle_valid),
    .rx_logical_idle_char_mask_o(rx_logical_idle_char_mask),
    .rx_align_loss_evt_o(rx_align_loss_evt_sym),
    .rx_invalid_k_evt_o(rx_invalid_k_evt_sym),
    .rx_code_error_evt_o(rx_code_error_evt_sym),
    .rx_disparity_error_evt_o(rx_disparity_error_evt_sym),
    .rx_frame_error_evt_o(rx_frame_error_evt_sym),
    .rx_packet_buffer_error_evt_o(rx_packet_buffer_error_evt_sym),
    .rx_packet_drop_evt_o(rx_packet_drop_evt_sym),
    .rx_packet_active_o(rx_packet_active_sym)
  );

  logic lt_packet_drop_sym;
  logic lt_packet_drop_cdc_overflow;
  phy_cdc_event_bus #(.WIDTH(1)) u_lt_packet_drop_cdc (
    .s_clk_i(ctrl_clk_i),
    .s_rst_ni(ctrl_local_rst_ni),
    .s_event_i(lt_packet_drop),
    .s_data_i(1'b1),
    .s_overflow_event_o(lt_packet_drop_cdc_overflow),
    .d_clk_i(phy_sym_clk_o),
    .d_rst_ni(phy_sym_rst_no),
    .d_event_o(lt_packet_drop_sym),
    .d_data_o(),
    .d_overflow_event_o()
  );

  phy_rx_packet_buffer_cdc u_phy_rx_packet_buffer_cdc (
    .sym_clk_i(phy_sym_clk_o),
    .sym_rst_ni(phy_sym_rst_no),
    .port_reset_ni(port_reset_ni),
    .link_clk_i(link_clk_i),
    .link_rst_ni(link_rst_ni),
    .rxbuf_pkt_valid_i(rxbuf_pkt_valid),
    .rxbuf_pkt_ready_o(rxbuf_pkt_ready),
    .rxbuf_pkt_data_i(rxbuf_pkt_data),
    .rxbuf_pkt_keep_i(rxbuf_pkt_keep),
    .rxbuf_pkt_sop_i(rxbuf_pkt_sop),
    .rxbuf_pkt_eop_i(rxbuf_pkt_eop),
    .rxbuf_pkt_kind_i(rxbuf_pkt_kind),
    .rxbuf_pkt_abort_i(rxbuf_pkt_abort),
    .rxbuf_drop_i(rxbuf_pkt_drop || lt_packet_drop_sym),
    .rxbuf_flush_i(flush_hold_ctrl_q),
    .dll_rx_valid_o(dll_rx_valid_o),
    .dll_rx_ready_i(dll_rx_ready_i),
    .dll_rx_data_o(dll_rx_data_o),
    .dll_rx_keep_o(dll_rx_keep_o),
    .dll_rx_sop_o(dll_rx_sop_o),
    .dll_rx_eop_o(dll_rx_eop_o),
    .dll_rx_kind_o(dll_rx_kind_o),
    .dll_rx_abort_o(dll_rx_abort_o),
    .rxbuf_overflow_evt_o(rxbuf_overflow_evt_sym),
    .rxbuf_candidate_drop_evt_o(rxbuf_candidate_drop_evt_sym),
    .rxbuf_backpressure_timeout_evt_o(rxbuf_backpressure_timeout_evt_link),
    .rxbuf_level_o(rxbuf_level_sym)
  );

  phy_ordered_set u_phy_ordered_set (
    .sym_clk_i(phy_sym_clk_o),
    .sym_rst_ni(phy_sym_rst_no),
    .os_tx_req_valid_i(os_req_valid_sym),
    .os_tx_req_ready_o(os_req_ready_sym),
    .os_tx_kind_i(os_req_kind_sym),
    .os_tx_link_num_i(os_req_fields_sym.link_num),
    .os_tx_lane_num_i(os_req_fields_sym.lane_num),
    .os_tx_n_fts_i(os_req_fields_sym.n_fts),
    .os_tx_rate_id_i(os_req_fields_sym.rate_id),
    .os_tx_training_ctrl_i(os_req_fields_sym.training_ctrl),
    .os_tx_link_num_is_pad_i(os_req_fields_sym.link_num_is_pad),
    .os_tx_lane_num_is_pad_i(os_req_fields_sym.lane_num_is_pad),
    .os_tx_repeat_mode_i(os_req_repeat_sym),
    .skp_tx_req_i(skp_due_sym),
    // The LTSSM selects the Gen2 Recovery.RcvrLock context; the symbol-domain
    // generator owns the exact gap-free 32*TS1/EIEOS cadence inside it.
    .os_tx_gen2_rcvrlock_i(
      current_rate_sym && (lt_substate_sym == LTSSM_SS_RECOVERY_RCVRLOCK)
    ),
    .os_tx_consume_i(os_tx_consume),
    .os_tx_skp_start_o(os_tx_skp_start),
    .os_tx_skp_done_o(os_tx_skp_done),
    .os_tx_data_o(os_tx_data),
    .os_tx_is_k_o(os_tx_is_k),
    .os_tx_class_o(os_tx_class),
    .os_tx_valid_o(os_tx_valid),
    .os_tx_done_o(os_tx_done_sym),
    .os_rx_data_i(os_rx_candidate_data),
    .os_rx_is_k_i(os_rx_candidate_is_k),
    .os_rx_valid_i(os_rx_candidate_valid),
    .os_rx_error_i(os_rx_candidate_error),
    .os_rx_expected_state_i(lt_substate_sym),
    .rx_logical_idle_valid_i(rx_logical_idle_valid),
    .rx_logical_idle_char_mask_i(rx_logical_idle_char_mask),
    .os_rx_ts1_qualified_evt_o(os_rx_ts1_evt_sym),
    .os_rx_ts2_qualified_evt_o(os_rx_ts2_evt_sym),
    .os_rx_fts_evt_o(os_rx_fts_evt_sym),
    .os_rx_skp_evt_o(os_rx_skp_evt_sym),
    .os_rx_eios_evt_o(os_rx_eios_evt_sym),
    .os_rx_eieos_evt_o(os_rx_eieos_evt_sym),
    .rx_logical_idle_qualified_evt_o(rx_logical_idle_qualified_evt_sym),
    .os_rx_hot_reset_evt_o(os_rx_hot_reset_evt_sym),
    .os_rx_loopback_evt_o(os_rx_loopback_evt_sym),
    .os_rx_speed_change_evt_o(os_rx_speed_change_evt_sym),
    .os_rx_fields_o(os_rx_fields_sym),
    .os_rx_error_o(os_rx_error_sym)
  );

  logic [1:0] skp_tx_char_advance;
  assign skp_tx_char_advance =
      (crr_ready_sym && (lt_tx_mode_sym != TX_MODE_ELECTRICAL_IDLE)) ?
      2'd2 : 2'd0;

  phy_skp_clock_comp u_phy_skp_clock_comp (
    .sym_clk_i(phy_sym_clk_o),
    .sym_rst_ni(phy_sym_rst_no),
    .skp_current_rate_i(current_rate_sym),
    .skp_tx_char_advance_i(skp_tx_char_advance),
    .skp_packet_boundary_i(!tx_packet_active_sym),
    .skp_os_busy_i(os_tx_valid),
    // Restart the insertion deadline only after all four SKP characters have
    // crossed the no-backpressure character interface.
    .skp_tx_accept_i(os_tx_skp_done),
    .skp_due_o(skp_due_sym),
    .skp_deadline_o(skp_deadline_sym),
    .skp_deadline_missed_evt_o(skp_deadline_missed_evt_sym),
    .gt_rx_clkcor_count_i(gt_rx_clkcor_count),
    .gt_rx_buffer_status_i(gt_rx_buffer_status),
    .skp_rx_add_evt_o(skp_rx_add_evt_sym),
    .skp_rx_skip_count_o(skp_rx_skip_count_sym),
    .skp_rx_buffer_fault_evt_o(skp_rx_buffer_fault_evt_sym),
    .skp_rx_underflow_evt_o(skp_rx_underflow_evt_sym),
    .skp_rx_overflow_evt_o(skp_rx_overflow_evt_sym),
    .skp_rx_status_invalid_evt_o(skp_rx_status_invalid_evt_sym)
  );

  // ------------------------------------------------------------------------
  // GT / control instances
  // ------------------------------------------------------------------------
  pcie_gty_adapter_x1 #(
    .SIM_TIME_SCALE(SIM_TIME_SCALE),
    .BEHAV_DETECT_STATUS(BEHAV_DETECT_STATUS),
    .BEHAV_DETECT_TIMEOUT(BEHAV_DETECT_TIMEOUT),
    .BEHAV_RATE_FAIL(BEHAV_RATE_FAIL),
    .BEHAV_POWER_FAIL(BEHAV_POWER_FAIL),
    .BEHAV_LINK_POLARITY_INVERTED(BEHAV_LINK_POLARITY_INVERTED),
    .BEHAV_ELASTIC_CORRECTION_MODE(BEHAV_ELASTIC_CORRECTION_MODE),
    .BEHAV_INJECT_CODE_ERROR(BEHAV_INJECT_CODE_ERROR),
    .BEHAV_INJECT_DISPARITY_ERROR(BEHAV_INJECT_DISPARITY_ERROR),
    .BEHAV_INJECT_RXBUF_UNDERFLOW(BEHAV_INJECT_RXBUF_UNDERFLOW),
    .BEHAV_INJECT_RXBUF_OVERFLOW(BEHAV_INJECT_RXBUF_OVERFLOW),
    .BEHAV_INJECT_TXBUF_FAULT(BEHAV_INJECT_TXBUF_FAULT)
  ) u_pcie_gty_adapter_x1 (
    .ctrl_clk_i(ctrl_clk_i),
    .ctrl_rst_ni(ctrl_local_rst_ni),
    .pcie_refclk_p_i(pcie_refclk_p_i),
    .pcie_refclk_n_i(pcie_refclk_n_i),
    .pcie_rx_p_i(pcie_rx_p_i),
    .pcie_rx_n_i(pcie_rx_n_i),
    .pcie_tx_p_o(pcie_tx_p_o),
    .pcie_tx_n_o(pcie_tx_n_o),
    .gt_sym_clk_o(gt_sym_clk),
    .gt_sym_rst_no(gt_sym_rst_n),
    .gt_sym_clk_stable_o(gt_sym_clk_stable),
    .gt_buffer_reinit_done_o(gt_buffer_reinit_done),
    .tx_symbol_data_i(tx_scrambled_data),
    .tx_symbol_is_k_i(tx_scrambled_is_k),
    .rx_symbol_data_o(gt_rx_symbol_data),
    .rx_symbol_is_k_o(gt_rx_symbol_is_k),
    .rx_symbol_disparity_error_o(gt_rx_symbol_disparity_error),
    .rx_symbol_code_error_o(gt_rx_symbol_code_error),
    .rx_symbol_is_comma_o(gt_rx_symbol_is_comma),
    .rx_symbol_valid_o(gt_rx_symbol_valid),
    .rx_byte_aligned_o(gt_rx_byte_aligned),
    .rx_realign_event_o(gt_rx_realign_event),
    .gt_rx_clkcor_count_o(gt_rx_clkcor_count),
    .gt_rx_buffer_status_o(gt_rx_buffer_status),
    .gt_tx_buffer_fault_o(gt_tx_buffer_fault),
    .gt_detect_req_i(gt_detect_req),
    .gt_detect_busy_o(gt_detect_busy),
    .gt_detect_done_o(gt_detect_done),
    .gt_receiver_present_o(gt_receiver_present),
    .gt_rate_req_i(gt_rate_req),
    .gt_rate_target_gen2_i(gt_rate_target_gen2),
    .gt_rate_busy_o(gt_rate_busy),
    .gt_rate_done_o(gt_rate_done),
    .gt_rate_fail_o(gt_rate_fail),
    .gt_tx_electrical_idle_i(gt_tx_electrical_idle),
    .gt_tx_electrical_idle_active_o(gt_tx_electrical_idle_active),
    .gt_rx_electrical_idle_o(gt_rx_electrical_idle),
    .gt_power_req_i(gt_power_req),
    .gt_power_state_i(gt_power_state),
    .gt_power_busy_o(gt_power_busy),
    .gt_power_done_o(gt_power_done),
    .gt_power_fail_o(gt_power_fail),
    .gt_rx_polarity_invert_i(gt_rx_polarity_invert),
    .gt_tx_deemphasis_i(gt_tx_deemphasis),
    .gt_tx_swing_i(gt_tx_swing),
    .gt_tx_margin_i(gt_tx_margin),
    .gt_compliance_enable_i(gt_compliance_enable),
    .gt_loopback_mode_i(gt_loopback_mode),
    .gt_ready_o(gt_ready),
    .gt_fault_o(gt_fault),
    .gt_fault_code_o(gt_fault_code)
  );

  // Synchronize the two packet-in-flight levels before quiesce decisions.
  (* ASYNC_REG = "TRUE" *) logic [1:0] tx_quiesced_ctrl_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] tx_capture_ctrl_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rx_active_ctrl_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rx_aligned_ctrl_sync_q;
  logic tx_path_quiesced_ctrl;

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni) begin
    if (!ctrl_local_rst_ni) begin
      tx_quiesced_ctrl_sync_q <= 2'b00;
      tx_capture_ctrl_sync_q  <= 2'b00;
      rx_active_ctrl_sync_q   <= 2'b00;
      rx_aligned_ctrl_sync_q  <= 2'b00;
    end else begin
      tx_quiesced_ctrl_sync_q <= {
        tx_quiesced_ctrl_sync_q[0], tx_quiesced_sym
      };
      tx_capture_ctrl_sync_q <= {
        tx_capture_ctrl_sync_q[0], txbuf_capture_active_link
      };
      rx_active_ctrl_sync_q <= {
        rx_active_ctrl_sync_q[0], rx_packet_active_sym
      };
      rx_aligned_ctrl_sync_q <= {
        rx_aligned_ctrl_sync_q[0], gt_rx_byte_aligned
      };
    end
  end
  assign tx_path_quiesced_ctrl =
      tx_quiesced_ctrl_sync_q[1] && !tx_capture_ctrl_sync_q[1];

  phy_clock_reset_rate_ctrl #(
    .SIM_TIME_SCALE(SIM_TIME_SCALE)
  ) u_phy_clock_reset_rate_ctrl (
    .ctrl_clk_i(ctrl_clk_i),
    // The top-level reset tree performs asynchronous assertion and
    // ctrl-domain synchronous release before feeding control-plane blocks.
    .ctrl_rst_ni(ctrl_local_rst_ni),
    .port_reset_ni(1'b1),
    .pcie_refclk_p_i(pcie_refclk_p_i),
    .pcie_refclk_n_i(pcie_refclk_n_i),
    .gt_sym_clk_i(gt_sym_clk),
    .gt_sym_rst_ni(gt_sym_rst_n),
    .gt_sym_clk_stable_i(gt_sym_clk_stable),
    .gt_buffer_reinit_done_i(gt_buffer_reinit_done),
    .phy_sym_clk_o(phy_sym_clk_o),
    .phy_sym_rst_no(phy_sym_rst_no),
    .crr_ready_o(crr_ready),
    .crr_current_rate_o(crr_current_rate),
    .lt_gt_detect_req_i(lt_gt_detect_req),
    .lt_gt_rate_req_i(lt_gt_rate_req),
    .lt_gt_rate_target_gen2_i(lt_gt_rate_target_gen2),
    .lt_gt_power_req_i(lt_gt_power_req),
    .lt_gt_power_state_i(lt_gt_power_state),
    .lt_gt_tx_electrical_idle_i(lt_gt_tx_electrical_idle),
    .lt_gt_rx_polarity_invert_i(lt_gt_rx_polarity_invert),
    .lt_gt_tx_deemphasis_i(lt_gt_tx_deemphasis),
    .lt_gt_tx_swing_i(lt_gt_tx_swing),
    .lt_gt_tx_margin_i(lt_gt_tx_margin),
    .lt_gt_compliance_enable_i(lt_gt_compliance_enable),
    .lt_gt_loopback_mode_i(lt_gt_loopback_mode),
    .crr_detect_done_o(crr_detect_done),
    .crr_receiver_present_o(crr_receiver_present),
    .crr_rate_done_o(crr_rate_done),
    .crr_rate_fail_o(crr_rate_fail),
    .crr_power_done_o(crr_power_done),
    .crr_power_fail_o(crr_power_fail),
    .crr_tx_electrical_idle_active_o(crr_tx_electrical_idle_active),
    .crr_rx_electrical_idle_o(crr_rx_electrical_idle),
    .crr_rx_aligned_o(crr_rx_aligned),
    .crr_fault_o(crr_fault),
    .crr_fault_code_o(crr_fault_code),
    .gt_detect_busy_i(gt_detect_busy),
    .gt_detect_done_i(gt_detect_done),
    .gt_receiver_present_i(gt_receiver_present),
    .gt_rate_busy_i(gt_rate_busy),
    .gt_rate_done_i(gt_rate_done),
    .gt_rate_fail_i(gt_rate_fail),
    .gt_tx_electrical_idle_active_i(gt_tx_electrical_idle_active),
    .gt_rx_electrical_idle_i(gt_rx_electrical_idle),
    .gt_power_busy_i(gt_power_busy),
    .gt_power_done_i(gt_power_done),
    .gt_power_fail_i(gt_power_fail),
    .gt_ready_i(gt_ready),
    .gt_fault_i(gt_fault),
    .gt_fault_code_i(gt_fault_code),
    .rx_byte_aligned_i(rx_aligned_ctrl_sync_q[1]),
    .tx_quiesced_i(tx_path_quiesced_ctrl),
    .rx_packet_active_i(rx_active_ctrl_sync_q[1]),
    .gt_detect_req_o(gt_detect_req),
    .gt_rate_req_o(gt_rate_req),
    .gt_rate_target_gen2_o(gt_rate_target_gen2),
    .gt_tx_electrical_idle_o(gt_tx_electrical_idle),
    .gt_power_req_o(gt_power_req),
    .gt_power_state_o(gt_power_state),
    .gt_rx_polarity_invert_o(gt_rx_polarity_invert),
    .gt_tx_deemphasis_o(gt_tx_deemphasis),
    .gt_tx_swing_o(gt_tx_swing),
    .gt_tx_margin_o(gt_tx_margin),
    .gt_compliance_enable_o(gt_compliance_enable),
    .gt_loopback_mode_o(gt_loopback_mode),
    .sym_path_reset_o(crr_sym_path_reset),
    .packet_admission_enable_o(crr_packet_admission_enable),
    .packet_buffer_flush_o(crr_packet_buffer_flush)
  );

  phy_timer_bank u_phy_timer_bank (
    .ctrl_clk_i(ctrl_clk_i),
    .ctrl_rst_ni(ctrl_local_rst_ni),
    .port_reset_ni(1'b1),
    .timer_start_i(timer_start),
    .timer_stop_i(timer_stop),
    .timer_id_i(timer_command_id),
    .timer_limit_i(timer_limit),
    .retry_update_i(retry_update),
    .retry_clear_i(retry_clear),
    .timer_expired_o(timer_expired),
    .timer_id_o(timer_expired_id),
    .retry_count_o(retry_count),
    .timer_active_o(timer_active),
    .timer_count_o(timer_count)
  );

  // ------------------------------------------------------------------------
  // Qualified OS fields/events and selected datapath events cross to ctrl.
  // ------------------------------------------------------------------------
  logic [OS_EVENT_WIDTH-1:0] os_event_sym_payload;
  logic [OS_EVENT_WIDTH-1:0] os_event_ctrl_payload;
  logic os_event_any_sym;
  logic os_event_ctrl;
  logic os_event_cdc_overflow;
  logic os_rx_ts1_evt_ctrl;
  logic os_rx_ts2_evt_ctrl;
  logic os_rx_fts_evt_ctrl;
  logic os_rx_skp_evt_ctrl;
  logic os_rx_eios_evt_ctrl;
  logic os_rx_eieos_evt_ctrl;
  logic rx_logical_idle_evt_ctrl;
  logic os_rx_hot_reset_evt_ctrl;
  logic os_rx_loopback_evt_ctrl;
  logic os_rx_speed_change_evt_ctrl;
  pcie_ts_fields_t os_rx_fields_ctrl;
  logic [7:0] os_rx_error_ctrl_payload;
  logic [7:0] os_rx_error_ctrl;

  assign os_event_any_sym =
      os_rx_ts1_evt_sym || os_rx_ts2_evt_sym || os_rx_fts_evt_sym ||
      os_rx_skp_evt_sym || os_rx_eios_evt_sym || os_rx_eieos_evt_sym ||
      rx_logical_idle_qualified_evt_sym || os_rx_hot_reset_evt_sym ||
      os_rx_loopback_evt_sym || os_rx_speed_change_evt_sym ||
      (os_rx_error_sym != ERR_NONE);
  assign os_event_sym_payload = {
    os_rx_error_sym,
    os_rx_fields_sym,
    os_rx_speed_change_evt_sym,
    os_rx_loopback_evt_sym,
    os_rx_hot_reset_evt_sym,
    rx_logical_idle_qualified_evt_sym,
    os_rx_eieos_evt_sym,
    os_rx_eios_evt_sym,
    os_rx_skp_evt_sym,
    os_rx_fts_evt_sym,
    os_rx_ts2_evt_sym,
    os_rx_ts1_evt_sym
  };

  phy_cdc_event_bus #(.WIDTH(OS_EVENT_WIDTH)) u_os_event_cdc (
    .s_clk_i(phy_sym_clk_o),
    .s_rst_ni(phy_sym_rst_no),
    .s_event_i(os_event_any_sym),
    .s_data_i(os_event_sym_payload),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i),
    .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(os_event_ctrl),
    .d_data_o(os_event_ctrl_payload),
    .d_overflow_event_o(os_event_cdc_overflow)
  );

  assign {
    os_rx_error_ctrl_payload,
    os_rx_fields_ctrl,
    os_rx_speed_change_evt_ctrl,
    os_rx_loopback_evt_ctrl,
    os_rx_hot_reset_evt_ctrl,
    rx_logical_idle_evt_ctrl,
    os_rx_eieos_evt_ctrl,
    os_rx_eios_evt_ctrl,
    os_rx_skp_evt_ctrl,
    os_rx_fts_evt_ctrl,
    os_rx_ts2_evt_ctrl,
    os_rx_ts1_evt_ctrl
  } = os_event_ctrl_payload;
  assign os_rx_error_ctrl = os_event_ctrl ? os_rx_error_ctrl_payload : ERR_NONE;

  logic os_tx_done_ctrl;
  logic os_tx_done_cdc_overflow;
  phy_cdc_event_bus #(.WIDTH(1)) u_os_done_cdc (
    .s_clk_i(phy_sym_clk_o),
    .s_rst_ni(phy_sym_rst_no),
    .s_event_i(os_tx_done_sym),
    .s_data_i(1'b1),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i),
    .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(os_tx_done_ctrl),
    .d_data_o(),
    .d_overflow_event_o(os_tx_done_cdc_overflow)
  );

  logic tx_logical_idle_evt_ctrl;
  logic tx_idle_cdc_overflow;
  phy_cdc_event_bus #(.WIDTH(1)) u_tx_idle_cdc (
    .s_clk_i(phy_sym_clk_o),
    .s_rst_ni(phy_sym_rst_no),
    .s_event_i(tx_logical_idle_evt_sym),
    .s_data_i(1'b1),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i),
    .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(tx_logical_idle_evt_ctrl),
    .d_data_o(),
    .d_overflow_event_o(tx_idle_cdc_overflow)
  );

  // Sustained decode errors request Recovery only after the centralized
  // threshold, while every individual symbol error remains observable.
  logic [DECODE_STREAK_WIDTH-1:0] decode_error_streak_q;
  logic decode_error_threshold_evt_sym;
  always_ff @(posedge phy_sym_clk_o or negedge phy_sym_rst_no) begin
    if (!phy_sym_rst_no) begin
      decode_error_streak_q        <= '0;
      decode_error_threshold_evt_sym <= 1'b0;
    end else begin
      decode_error_threshold_evt_sym <= 1'b0;
      if (rx_code_error_evt_sym || rx_disparity_error_evt_sym) begin
        if (decode_error_streak_q >= RX_DECODE_ERROR_THRESHOLD-1) begin
          decode_error_streak_q          <= '0;
          decode_error_threshold_evt_sym <= 1'b1;
        end else begin
          decode_error_streak_q <= decode_error_streak_q + 1'b1;
        end
      end else begin
        decode_error_streak_q <= '0;
      end
    end
  end

  // Source-domain error category selection.  If two sources of one category
  // collide, the event bridge reports its sticky overflow to the ctrl domain.
  logic sym_buffer_evt;
  logic [39:0] sym_buffer_payload;
  logic sym_alignment_evt;
  logic [39:0] sym_alignment_payload;
  logic sym_framing_evt;
  logic [39:0] sym_framing_payload;
  logic sym_correctable_evt;
  logic [39:0] sym_correctable_payload;
  logic sym_misc_evt;
  logic [39:0] sym_misc_payload;

  always_comb begin
    sym_buffer_evt     = 1'b0;
    sym_buffer_payload = {ERR_NONE, 32'd0};
    if (skp_rx_underflow_evt_sym) begin
      sym_buffer_evt     = 1'b1;
      sym_buffer_payload = {ERR_RXBUF_UNDERFLOW,
                            txbuf_level_sym, rxbuf_level_sym, 11'd0,
                            gt_rx_buffer_status, gt_rx_clkcor_count};
    end else if (skp_rx_overflow_evt_sym || skp_rx_status_invalid_evt_sym) begin
      sym_buffer_evt     = 1'b1;
      sym_buffer_payload = {ERR_RXBUF_OVERFLOW,
                            txbuf_level_sym, rxbuf_level_sym, 11'd0,
                            gt_rx_buffer_status, gt_rx_clkcor_count};
    end else if (rxbuf_overflow_evt_sym || rx_packet_buffer_error_evt_sym) begin
      sym_buffer_evt     = 1'b1;
      sym_buffer_payload = {ERR_RX_PACKET_BUFFER_OVERFLOW,
                            txbuf_level_sym, rxbuf_level_sym, 14'd0,
                            rxbuf_overflow_evt_sym,
                            rx_packet_buffer_error_evt_sym};
    end

    sym_alignment_evt     = rx_align_loss_evt_sym;
    sym_alignment_payload = {
      ERR_RX_ALIGN_LOSS,
      19'd0, gt_rx_symbol_code_error, gt_rx_symbol_disparity_error,
      gt_rx_symbol_is_comma, gt_rx_byte_aligned, gt_rx_realign_event,
      gt_rx_buffer_status, gt_rx_clkcor_count
    };

    sym_framing_evt     = 1'b0;
    sym_framing_payload = {ERR_NONE, 32'd0};
    if (tx_scheduler_error_evt_sym) begin
      sym_framing_evt     = 1'b1;
      sym_framing_payload = {
        tx_scheduler_error_code_sym,
        8'd0, tx_scheduler_error_code_sym, 8'd0,
        rx_invalid_k_evt_sym, rx_frame_error_evt_sym,
        rx_packet_drop_evt_sym, rxbuf_candidate_drop_evt_sym, 4'd0
      };
    end else if (rx_frame_error_evt_sym || rx_invalid_k_evt_sym ||
                 rx_packet_drop_evt_sym || rxbuf_candidate_drop_evt_sym) begin
      sym_framing_evt     = 1'b1;
      sym_framing_payload = {
        ERR_RX_FRAMING,
        8'd0, ERR_RX_FRAMING, 8'd0,
        rx_invalid_k_evt_sym, rx_frame_error_evt_sym,
        rx_packet_drop_evt_sym, rxbuf_candidate_drop_evt_sym, 4'd0
      };
    end

    sym_correctable_evt     = 1'b0;
    sym_correctable_payload = {ERR_NONE, 32'd0};
    if (rx_code_error_evt_sym) begin
      sym_correctable_evt     = 1'b1;
      sym_correctable_payload = {
        ERR_RX_CODE, 24'd0, 4'd0,
        gt_rx_symbol_code_error, gt_rx_symbol_disparity_error
      };
    end else if (rx_disparity_error_evt_sym) begin
      sym_correctable_evt     = 1'b1;
      sym_correctable_payload = {
        ERR_RX_DISPARITY, 24'd0, 4'd0,
        gt_rx_symbol_code_error, gt_rx_symbol_disparity_error
      };
    end

    sym_misc_evt     = 1'b0;
    sym_misc_payload = {ERR_NONE, 32'd0};
    if (scrambler_sync_error_sym) begin
      sym_misc_evt     = 1'b1;
      sym_misc_payload = {
        ERR_SCRAMBLER_SYNC, 16'd0, lt_substate_sym, lt_state_sym,
        scrambler_sync_error_sym, skp_deadline_missed_evt_sym,
        decode_error_threshold_evt_sym, rx_packet_drop_evt_sym
      };
    end else if (skp_deadline_missed_evt_sym) begin
      sym_misc_evt     = 1'b1;
      sym_misc_payload = {
        ERR_SKP_DEADLINE, 16'd0, lt_substate_sym, lt_state_sym,
        scrambler_sync_error_sym, skp_deadline_missed_evt_sym,
        decode_error_threshold_evt_sym, rx_packet_drop_evt_sym
      };
    end else if (decode_error_threshold_evt_sym) begin
      sym_misc_evt     = 1'b1;
      sym_misc_payload = {
        ERR_RX_CODE, 16'd0, lt_substate_sym, lt_state_sym,
        scrambler_sync_error_sym, skp_deadline_missed_evt_sym,
        decode_error_threshold_evt_sym, rx_packet_drop_evt_sym
      };
    end
  end

  logic sym_buffer_evt_ctrl;
  logic [39:0] sym_buffer_payload_ctrl;
  logic sym_buffer_cdc_overflow;
  logic sym_alignment_evt_ctrl;
  logic [39:0] sym_alignment_payload_ctrl;
  logic sym_alignment_cdc_overflow;
  logic sym_framing_evt_ctrl;
  logic [39:0] sym_framing_payload_ctrl;
  logic sym_framing_cdc_overflow;
  logic sym_correctable_evt_ctrl;
  logic [39:0] sym_correctable_payload_ctrl;
  logic sym_correctable_cdc_overflow;
  logic sym_misc_evt_ctrl;
  logic [39:0] sym_misc_payload_ctrl;
  logic sym_misc_cdc_overflow;

  phy_cdc_event_bus #(.WIDTH(40)) u_sym_buffer_error_cdc (
    .s_clk_i(phy_sym_clk_o), .s_rst_ni(phy_sym_rst_no),
    .s_event_i(sym_buffer_evt), .s_data_i(sym_buffer_payload),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i), .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(sym_buffer_evt_ctrl), .d_data_o(sym_buffer_payload_ctrl),
    .d_overflow_event_o(sym_buffer_cdc_overflow)
  );

  phy_cdc_event_bus #(.WIDTH(40)) u_sym_alignment_error_cdc (
    .s_clk_i(phy_sym_clk_o), .s_rst_ni(phy_sym_rst_no),
    .s_event_i(sym_alignment_evt), .s_data_i(sym_alignment_payload),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i), .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(sym_alignment_evt_ctrl), .d_data_o(sym_alignment_payload_ctrl),
    .d_overflow_event_o(sym_alignment_cdc_overflow)
  );

  phy_cdc_event_bus #(.WIDTH(40)) u_sym_framing_error_cdc (
    .s_clk_i(phy_sym_clk_o), .s_rst_ni(phy_sym_rst_no),
    .s_event_i(sym_framing_evt), .s_data_i(sym_framing_payload),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i), .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(sym_framing_evt_ctrl), .d_data_o(sym_framing_payload_ctrl),
    .d_overflow_event_o(sym_framing_cdc_overflow)
  );

  phy_cdc_event_bus #(.WIDTH(40)) u_sym_correctable_error_cdc (
    .s_clk_i(phy_sym_clk_o), .s_rst_ni(phy_sym_rst_no),
    .s_event_i(sym_correctable_evt), .s_data_i(sym_correctable_payload),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i), .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(sym_correctable_evt_ctrl), .d_data_o(sym_correctable_payload_ctrl),
    .d_overflow_event_o(sym_correctable_cdc_overflow)
  );

  phy_cdc_event_bus #(.WIDTH(40)) u_sym_misc_error_cdc (
    .s_clk_i(phy_sym_clk_o), .s_rst_ni(phy_sym_rst_no),
    .s_event_i(sym_misc_evt), .s_data_i(sym_misc_payload),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i), .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(sym_misc_evt_ctrl), .d_data_o(sym_misc_payload_ctrl),
    .d_overflow_event_o(sym_misc_cdc_overflow)
  );

  logic link_buffer_evt;
  logic [39:0] link_buffer_payload;
  logic link_buffer_evt_ctrl;
  logic [39:0] link_buffer_payload_ctrl;
  logic link_buffer_cdc_overflow;
  logic link_framing_evt_ctrl;
  logic [39:0] link_framing_payload_ctrl;
  logic link_framing_cdc_overflow;

  assign link_buffer_evt = rxbuf_backpressure_timeout_evt_link;
  assign link_buffer_payload = {
    ERR_RX_PACKET_BUFFER_OVERFLOW, 16'd0, 15'd0,
    rxbuf_backpressure_timeout_evt_link
  };

  phy_cdc_event_bus #(.WIDTH(40)) u_link_buffer_error_cdc (
    .s_clk_i(link_clk_i), .s_rst_ni(link_local_rst_ni),
    .s_event_i(link_buffer_evt), .s_data_i(link_buffer_payload),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i), .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(link_buffer_evt_ctrl), .d_data_o(link_buffer_payload_ctrl),
    .d_overflow_event_o(link_buffer_cdc_overflow)
  );

  phy_cdc_event_bus #(.WIDTH(40)) u_link_framing_error_cdc (
    .s_clk_i(link_clk_i), .s_rst_ni(link_local_rst_ni),
    .s_event_i(txbuf_error_evt_link),
    .s_data_i({
      txbuf_error_code_link,
      16'd0, txbuf_error_code_link, 7'd0, txbuf_capture_active_link
    }),
    .s_overflow_event_o(),
    .d_clk_i(ctrl_clk_i), .d_rst_ni(ctrl_local_rst_ni),
    .d_event_o(link_framing_evt_ctrl), .d_data_o(link_framing_payload_ctrl),
    .d_overflow_event_o(link_framing_cdc_overflow)
  );

  // Coherent debug occupancy snapshot.
  logic [15:0] buffer_level_ctrl;
  phy_cdc_snapshot #(.WIDTH(16)) u_buffer_level_snapshot (
    .s_clk_i(phy_sym_clk_o),
    .s_rst_ni(phy_sym_rst_no),
    .s_data_i({txbuf_level_sym, rxbuf_level_sym}),
    .d_clk_i(ctrl_clk_i),
    .d_rst_ni(ctrl_local_rst_ni),
    .d_data_o(buffer_level_ctrl)
  );

  // ------------------------------------------------------------------------
  // LTSSM instance.  It consumes only qualified/CDC-normalized events.
  // ------------------------------------------------------------------------
  logic rx_align_loss_evt_ctrl;
  logic rx_frame_error_evt_ctrl;
  logic rx_buffer_fault_evt_ctrl;
  logic datapath_recovery_req_ctrl;
  logic cdc_overflow_emit_ctrl;

  assign rx_align_loss_evt_ctrl = sym_alignment_evt_ctrl;
  assign rx_frame_error_evt_ctrl = sym_framing_evt_ctrl;
  assign rx_buffer_fault_evt_ctrl = sym_buffer_evt_ctrl || link_buffer_evt_ctrl;
  assign datapath_recovery_req_ctrl = sym_misc_evt_ctrl || cdc_overflow_emit_ctrl;

  phy_ltssm_ctrl #(
    .SIM_TIME_SCALE(SIM_TIME_SCALE)
  ) u_phy_ltssm_ctrl (
    .ctrl_clk_i(ctrl_clk_i),
    .ctrl_rst_ni(ctrl_local_rst_ni),
    .port_reset_ni(1'b1),
    .mgmt_cmd_valid_i(mgmt_cmd_valid_i),
    .mgmt_cmd_ready_o(mgmt_cmd_ready_o),
    .mgmt_cmd_opcode_i(mgmt_cmd_opcode_i),
    .mgmt_cmd_arg_i(mgmt_cmd_arg_i),
    .mgmt_rsp_valid_o(mgmt_rsp_valid_o),
    .mgmt_rsp_ready_i(mgmt_rsp_ready_i),
    .mgmt_rsp_status_o(mgmt_rsp_status_o),
    .port_pm_req_valid_i(port_pm_req_valid_i),
    .port_pm_req_ready_o(port_pm_req_ready_o),
    .port_pm_req_state_i(port_pm_req_state_i),
    .port_pm_req_exit_i(port_pm_req_exit_i),
    .port_pm_done_o(port_pm_done_o),
    .port_pm_fail_o(port_pm_fail_o),
    .port_pm_rsp_ready_i(port_pm_rsp_ready_i),
    .crr_ready_i(crr_ready),
    .crr_current_rate_i(crr_current_rate),
    .crr_detect_done_i(crr_detect_done),
    .crr_receiver_present_i(crr_receiver_present),
    .crr_rate_done_i(crr_rate_done),
    .crr_rate_fail_i(crr_rate_fail),
    .crr_power_done_i(crr_power_done),
    .crr_power_fail_i(crr_power_fail),
    .crr_tx_electrical_idle_active_i(crr_tx_electrical_idle_active),
    .crr_rx_electrical_idle_i(crr_rx_electrical_idle),
    .crr_rx_aligned_i(crr_rx_aligned),
    .crr_fault_i(crr_fault),
    .crr_fault_code_i(crr_fault_code),
    .os_tx_req_ready_i(lt_os_req_ready),
    .os_tx_done_i(os_tx_done_ctrl),
    .tx_logical_idle_qualified_evt_i(tx_logical_idle_evt_ctrl),
    .os_rx_ts1_qualified_evt_i(os_event_ctrl && os_rx_ts1_evt_ctrl),
    .os_rx_ts2_qualified_evt_i(os_event_ctrl && os_rx_ts2_evt_ctrl),
    .os_rx_fts_evt_i(os_event_ctrl && os_rx_fts_evt_ctrl),
    .os_rx_skp_evt_i(os_event_ctrl && os_rx_skp_evt_ctrl),
    .os_rx_eios_evt_i(os_event_ctrl && os_rx_eios_evt_ctrl),
    .os_rx_eieos_evt_i(os_event_ctrl && os_rx_eieos_evt_ctrl),
    .rx_logical_idle_qualified_evt_i(
      os_event_ctrl && rx_logical_idle_evt_ctrl
    ),
    .os_rx_hot_reset_evt_i(os_event_ctrl && os_rx_hot_reset_evt_ctrl),
    .os_rx_loopback_evt_i(os_event_ctrl && os_rx_loopback_evt_ctrl),
    .os_rx_speed_change_evt_i(
      os_event_ctrl && os_rx_speed_change_evt_ctrl
    ),
    .os_rx_fields_i(os_rx_fields_ctrl),
    .os_rx_error_i(os_rx_error_ctrl),
    .tx_quiesced_i(tx_path_quiesced_ctrl),
    .rx_packet_active_i(rx_active_ctrl_sync_q[1]),
    .rx_align_loss_evt_i(rx_align_loss_evt_ctrl),
    .rx_frame_error_evt_i(rx_frame_error_evt_ctrl),
    .rx_buffer_fault_evt_i(rx_buffer_fault_evt_ctrl),
    .datapath_recovery_req_i(datapath_recovery_req_ctrl),
    .timer_expired_i(timer_expired),
    .timer_id_i(timer_expired_id),
    .retry_count_i(retry_count),
    .lt_gt_detect_req_o(lt_gt_detect_req),
    .lt_gt_rate_req_o(lt_gt_rate_req),
    .lt_gt_rate_target_gen2_o(lt_gt_rate_target_gen2),
    .lt_gt_power_req_o(lt_gt_power_req),
    .lt_gt_power_state_o(lt_gt_power_state),
    .lt_gt_tx_electrical_idle_o(lt_gt_tx_electrical_idle),
    .lt_gt_rx_polarity_invert_o(lt_gt_rx_polarity_invert),
    .lt_gt_tx_deemphasis_o(lt_gt_tx_deemphasis),
    .lt_gt_tx_swing_o(lt_gt_tx_swing),
    .lt_gt_tx_margin_o(lt_gt_tx_margin),
    .lt_gt_compliance_enable_o(lt_gt_compliance_enable),
    .lt_gt_loopback_mode_o(lt_gt_loopback_mode),
    .lt_os_req_valid_o(lt_os_req_valid),
    .lt_os_kind_o(lt_os_kind),
    .lt_os_fields_o(lt_os_fields),
    .lt_os_repeat_mode_o(lt_os_repeat_mode),
    .lt_tx_mode_o(lt_tx_mode),
    .lt_packet_enable_o(lt_packet_enable),
    .lt_packet_flush_o(lt_packet_flush),
    .lt_packet_drop_o(lt_packet_drop),
    .timer_start_o(timer_start),
    .timer_stop_o(timer_stop),
    .timer_id_o(timer_command_id),
    .timer_limit_o(timer_limit),
    .retry_update_o(retry_update),
    .retry_clear_o(retry_clear),
    .lt_state_o(lt_state),
    .lt_substate_o(lt_substate),
    .lt_entry_reason_o(lt_entry_reason),
    .lt_link_up_o(lt_link_up),
    .lt_data_active_o(lt_data_active),
    .lt_current_rate_o(lt_current_rate),
    .lt_target_rate_o(lt_target_rate),
    .lt_clear_error_o(lt_clear_error),
    .lt_status_evt_valid_o(lt_status_evt_valid),
    .lt_status_evt_code_o(lt_status_evt_code),
    .lt_status_evt_info_o(lt_status_evt_info),
    .lt_status_evt_fatal_o(lt_status_evt_fatal)
  );

  // ------------------------------------------------------------------------
  // Error/status merge in ctrl_clk.  Same-category collisions and any source
  // bridge overrun are converted into ERR_CDC_EVENT_OVERFLOW rather than lost.
  // ------------------------------------------------------------------------
  localparam int unsigned OVERFLOW_PENDING_COUNT_WIDTH = 8;
  logic [9:0] cdc_overflow_evt_ctrl;
  logic [1:0] buffer_category_source_count_ctrl;
  logic [1:0] framing_category_source_count_ctrl;
  logic [1:0] category_collision_count_ctrl;
  logic [2:0] general_collision_count_ctrl;
  logic general_queue_drop_ctrl;
  logic [4:0] overflow_arrival_count_ctrl;
  logic [OVERFLOW_PENDING_COUNT_WIDTH-1:0] overflow_pending_count_q;
  logic [OVERFLOW_PENDING_COUNT_WIDTH-1:0] overflow_pending_after_emit;
  logic [OVERFLOW_PENDING_COUNT_WIDTH:0] overflow_pending_sum;
  logic [OVERFLOW_PENDING_COUNT_WIDTH-1:0] overflow_pending_count_next;

  // Every bit is already a one-cycle ctrl-domain event produced by the
  // corresponding bridge's Gray-counter delta replay.
  assign cdc_overflow_evt_ctrl = {
    link_framing_cdc_overflow,
    link_buffer_cdc_overflow,
    sym_misc_cdc_overflow,
    sym_correctable_cdc_overflow,
    sym_framing_cdc_overflow,
    sym_alignment_cdc_overflow,
    sym_buffer_cdc_overflow,
    tx_idle_cdc_overflow,
    os_tx_done_cdc_overflow,
    os_event_cdc_overflow
  };

  logic general_evt_valid_q;
  logic [3:0] general_evt_source_q;
  logic [7:0] general_evt_code_q;
  logic [31:0] general_evt_info_q;
  logic general_evt_fatal_q;
  logic general_new_valid;
  logic [3:0] general_new_source;
  logic [7:0] general_new_code;
  logic [31:0] general_new_info;
  logic general_new_fatal;
  logic [2:0] general_new_count;
  logic [2:0] general_best_priority;
  logic status_evt_ready;
  logic crr_nonfatal_evt;
  logic os_error_general_evt;

  assign crr_nonfatal_evt = crr_fault &&
      !error_is_fatal(pcie_phy_error_code_t'(crr_fault_code));
  assign os_error_general_evt = os_event_ctrl &&
      (os_rx_error_ctrl_payload != ERR_NONE);

  always_comb begin
    general_new_valid  = 1'b0;
    general_new_source = EVT_SRC_LTSSM;
    general_new_code   = ERR_NONE;
    general_new_info   = 32'd0;
    general_new_fatal  = 1'b0;
    general_best_priority = 3'd7;
    general_new_count  =
      {2'd0, crr_nonfatal_evt} + {2'd0, lt_status_evt_valid} +
      {2'd0, sym_misc_evt_ctrl};

    // Select nonzero error records using the frozen error-priority function.
    // Informational LTSSM transition records (ERR_NONE) are considered only
    // when there is no real error in the same cycle.
    if (crr_nonfatal_evt && (crr_fault_code != ERR_NONE)) begin
      general_new_valid  = 1'b1;
      general_new_source = EVT_SRC_GTY;
      general_new_code   = crr_fault_code;
      general_new_info   = {
        8'd0, crr_fault_code, lt_state, lt_substate,
        crr_current_rate, crr_ready, 2'd0
      };
      general_new_fatal  = 1'b0;
      general_best_priority = error_priority(
          pcie_phy_error_code_t'(crr_fault_code));
    end
    if (lt_status_evt_valid && (lt_status_evt_code != ERR_NONE) &&
        (!general_new_valid ||
         (error_priority(pcie_phy_error_code_t'(lt_status_evt_code)) <
          general_best_priority))) begin
      general_new_valid  = 1'b1;
      general_new_source = EVT_SRC_LTSSM;
      general_new_code   = lt_status_evt_code;
      general_new_info   = lt_status_evt_info;
      general_new_fatal  = lt_status_evt_fatal;
      general_best_priority = error_priority(
          pcie_phy_error_code_t'(lt_status_evt_code));
    end
    if (sym_misc_evt_ctrl && (sym_misc_payload_ctrl[39:32] != ERR_NONE) &&
        (!general_new_valid ||
         (error_priority(pcie_phy_error_code_t'(
             sym_misc_payload_ctrl[39:32])) < general_best_priority))) begin
      general_new_valid  = 1'b1;
      general_new_source = EVT_SRC_SKP;
      general_new_code   = sym_misc_payload_ctrl[39:32];
      general_new_info   = sym_misc_payload_ctrl[31:0];
      general_new_fatal  =
          error_is_fatal(pcie_phy_error_code_t'(sym_misc_payload_ctrl[39:32]));
      general_best_priority = error_priority(
          pcie_phy_error_code_t'(sym_misc_payload_ctrl[39:32]));
    end
    if (!general_new_valid && lt_status_evt_valid) begin
      general_new_valid  = 1'b1;
      general_new_source = EVT_SRC_LTSSM;
      general_new_code   = ERR_NONE;
      general_new_info   = lt_status_evt_info;
      general_new_fatal  = 1'b0;
    end
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni) begin
    if (!ctrl_local_rst_ni) begin
      general_evt_valid_q  <= 1'b0;
      general_evt_source_q <= EVT_SRC_LTSSM;
      general_evt_code_q   <= ERR_NONE;
      general_evt_info_q   <= 32'd0;
      general_evt_fatal_q  <= 1'b0;
    end else if (!general_evt_valid_q || status_evt_ready) begin
      general_evt_valid_q <= general_new_valid;
      if (general_new_valid) begin
        general_evt_source_q <= general_new_source;
        general_evt_code_q   <= general_new_code;
        general_evt_info_q   <= general_new_info;
        general_evt_fatal_q  <= general_new_fatal;
      end
    end
  end

  assign buffer_category_source_count_ctrl =
      {1'b0, sym_buffer_evt_ctrl} + {1'b0, link_buffer_evt_ctrl};
  assign framing_category_source_count_ctrl =
      {1'b0, sym_framing_evt_ctrl} +
      {1'b0, link_framing_evt_ctrl} +
      {1'b0, os_error_general_evt};
  assign category_collision_count_ctrl =
      ((buffer_category_source_count_ctrl > 0) ?
       (buffer_category_source_count_ctrl - 2'd1) : 2'd0) +
      ((framing_category_source_count_ctrl > 0) ?
       (framing_category_source_count_ctrl - 2'd1) : 2'd0);
  assign general_collision_count_ctrl = (general_new_count > 1) ?
      (general_new_count - 3'd1) : 3'd0;
  assign general_queue_drop_ctrl =
      general_new_valid && general_evt_valid_q && !status_evt_ready;

  // Count every independently observed loss. The packet-drop bridge originates
  // in ctrl_clk, so its source pulse is consumed directly; all other bridge
  // pulses have already crossed through their per-source Gray counters.
  always_comb begin
    overflow_arrival_count_ctrl =
        {4'd0, cdc_overflow_evt_ctrl[0]} +
        {4'd0, cdc_overflow_evt_ctrl[1]} +
        {4'd0, cdc_overflow_evt_ctrl[2]} +
        {4'd0, cdc_overflow_evt_ctrl[3]} +
        {4'd0, cdc_overflow_evt_ctrl[4]} +
        {4'd0, cdc_overflow_evt_ctrl[5]} +
        {4'd0, cdc_overflow_evt_ctrl[6]} +
        {4'd0, cdc_overflow_evt_ctrl[7]} +
        {4'd0, cdc_overflow_evt_ctrl[8]} +
        {4'd0, cdc_overflow_evt_ctrl[9]} +
        {4'd0, lt_packet_drop_cdc_overflow} +
        {3'd0, category_collision_count_ctrl} +
        {2'd0, general_collision_count_ctrl} +
        {4'd0, general_queue_drop_ctrl};
  end

  assign cdc_overflow_emit_ctrl = (overflow_pending_count_q != '0) &&
      !sym_buffer_evt_ctrl && !link_buffer_evt_ctrl;

  always_comb begin
    overflow_pending_after_emit = overflow_pending_count_q;
    if (cdc_overflow_emit_ctrl)
      overflow_pending_after_emit = overflow_pending_count_q - 1'b1;
    overflow_pending_sum =
        {1'b0, overflow_pending_after_emit} +
        {{(OVERFLOW_PENDING_COUNT_WIDTH+1-5){1'b0}},
         overflow_arrival_count_ctrl};
    if (overflow_pending_sum[OVERFLOW_PENDING_COUNT_WIDTH])
      overflow_pending_count_next = '1;
    else
      overflow_pending_count_next =
          overflow_pending_sum[OVERFLOW_PENDING_COUNT_WIDTH-1:0];
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni) begin
    if (!ctrl_local_rst_ni)
      overflow_pending_count_q <= '0;
    else
      overflow_pending_count_q <= overflow_pending_count_next;
  end

  logic status_buffer_evt_valid;
  logic [7:0] status_buffer_evt_code;
  logic [31:0] status_buffer_evt_info;
  logic status_framing_evt_valid;
  logic [7:0] status_framing_evt_code;
  logic [31:0] status_framing_evt_info;

  always_comb begin
    status_buffer_evt_valid = 1'b0;
    status_buffer_evt_code  = ERR_NONE;
    status_buffer_evt_info  = 32'd0;
    if (sym_buffer_evt_ctrl) begin
      status_buffer_evt_valid = 1'b1;
      status_buffer_evt_code  = sym_buffer_payload_ctrl[39:32];
      status_buffer_evt_info  = sym_buffer_payload_ctrl[31:0];
    end else if (link_buffer_evt_ctrl) begin
      status_buffer_evt_valid = 1'b1;
      status_buffer_evt_code  = link_buffer_payload_ctrl[39:32];
      status_buffer_evt_info  = link_buffer_payload_ctrl[31:0];
    end else if (cdc_overflow_emit_ctrl) begin
      status_buffer_evt_valid = 1'b1;
      status_buffer_evt_code  = ERR_CDC_EVENT_OVERFLOW;
      status_buffer_evt_info  = {
        lt_state, lt_substate, retry_count, timer_expired_id,
        overflow_pending_count_q[5:0]
      };
    end

    status_framing_evt_valid = 1'b0;
    status_framing_evt_code  = ERR_NONE;
    status_framing_evt_info  = 32'd0;
    if (sym_framing_evt_ctrl) begin
      status_framing_evt_valid = 1'b1;
      status_framing_evt_code  = sym_framing_payload_ctrl[39:32];
      status_framing_evt_info  = sym_framing_payload_ctrl[31:0];
    end else if (link_framing_evt_ctrl) begin
      status_framing_evt_valid = 1'b1;
      status_framing_evt_code  = link_framing_payload_ctrl[39:32];
      status_framing_evt_info  = link_framing_payload_ctrl[31:0];
    end else if (os_error_general_evt) begin
      // The parser's 0x41..0x46 values are context subcodes, not public error
      // codes.  Publish the frozen ERR_RX_OS_INVALID code and retain the local
      // subcode plus decoded fields in the info word.
      status_framing_evt_valid = 1'b1;
      status_framing_evt_code  = ERR_RX_OS_INVALID;
      status_framing_evt_info  = {
        os_rx_error_ctrl_payload,
        os_rx_fields_ctrl.link_num,
        os_rx_fields_ctrl.n_fts,
        os_rx_fields_ctrl.rate_id,
        os_rx_fields_ctrl.lane_num,
        1'b0
      };
    end
  end

  phy_status_error u_phy_status_error (
    .ctrl_clk_i(ctrl_clk_i),
    .ctrl_rst_ni(ctrl_local_rst_ni),
    .port_reset_ni(1'b1),
    .link_clk_i(link_clk_i),
    .link_rst_ni(link_local_rst_ni),
    .status_ready_i(crr_ready && gt_ready && gt_sym_rst_n &&
                    gt_sym_clk_stable && gt_buffer_reinit_done &&
                    phy_sym_rst_no),
    .status_state_i(lt_state),
    .status_substate_i(lt_substate),
    .status_reason_i(lt_entry_reason),
    .status_rate_i(crr_current_rate),
    .status_link_up_i(lt_link_up),
    .status_data_active_i(lt_data_active && crr_packet_admission_enable),
    .status_rx_lock_i(crr_rx_aligned),
    .status_buffer_level_i(buffer_level_ctrl),
    .status_timer_id_i(timer_expired_id),
    .status_timer_value_i(timer_count),
    .status_retry_count_i(retry_count),
    .status_clear_i(lt_clear_error),
    .status_debug_counter_seed_valid_i(1'b0),
    .status_debug_counter_seed_index_i('0),
    .status_debug_counter_seed_value_i('0),
    .status_evt_valid_i(general_evt_valid_q),
    .status_evt_source_i(general_evt_source_q),
    .status_evt_code_i(general_evt_code_q),
    .status_evt_info_i(general_evt_info_q),
    .status_evt_fatal_i(general_evt_fatal_q),
    .status_evt_ready_o(status_evt_ready),
    .status_gt_fatal_evt_valid_i(
      crr_fault && error_is_fatal(pcie_phy_error_code_t'(crr_fault_code))
    ),
    .status_gt_fatal_evt_code_i(crr_fault_code),
    .status_gt_fatal_evt_info_i({
      8'd0, crr_fault_code, lt_state, lt_substate,
      crr_current_rate, crr_ready, 2'd0
    }),
    .status_buffer_fatal_evt_valid_i(status_buffer_evt_valid),
    .status_buffer_fatal_evt_code_i(status_buffer_evt_code),
    .status_buffer_fatal_evt_info_i(status_buffer_evt_info),
    .status_alignment_evt_valid_i(sym_alignment_evt_ctrl),
    .status_alignment_evt_code_i(sym_alignment_payload_ctrl[39:32]),
    .status_alignment_evt_info_i(sym_alignment_payload_ctrl[31:0]),
    .status_framing_evt_valid_i(status_framing_evt_valid),
    .status_framing_evt_code_i(status_framing_evt_code),
    .status_framing_evt_info_i(status_framing_evt_info),
    .status_correctable_evt_valid_i(sym_correctable_evt_ctrl),
    .status_correctable_evt_code_i(sym_correctable_payload_ctrl[39:32]),
    .status_correctable_evt_info_i(sym_correctable_payload_ctrl[31:0]),
    .phy_ready_o(phy_ready_o),
    .phy_link_up_o(phy_link_up_o),
    .phy_data_active_o(phy_data_active_o),
    .phy_current_rate_o(phy_current_rate_o),
    .phy_ltssm_state_o(phy_ltssm_state_o),
    .phy_ltssm_substate_o(phy_ltssm_substate_o),
    .phy_state_reason_o(phy_state_reason_o),
    .phy_rx_locked_o(phy_rx_locked_o),
    .phy_dll_link_up_o(phy_dll_link_up_o),
    .phy_dll_data_active_o(phy_dll_data_active_o),
    .phy_dll_current_rate_o(phy_dll_current_rate_o),
    .phy_dll_link_down_evt_o(phy_dll_link_down_evt_o),
    .phy_err_valid_o(phy_err_valid_o),
    .phy_err_ready_i(phy_err_ready_i),
    .phy_err_code_o(phy_err_code_o),
    .phy_err_info_o(phy_err_info_o),
    .phy_csr_req_valid_i(phy_csr_req_valid_i),
    .phy_csr_req_ready_o(phy_csr_req_ready_o),
    .phy_csr_req_write_i(phy_csr_req_write_i),
    .phy_csr_req_addr_i(phy_csr_req_addr_i),
    .phy_csr_req_wdata_i(phy_csr_req_wdata_i),
    .phy_csr_req_wstrb_i(phy_csr_req_wstrb_i),
    .phy_csr_rsp_valid_o(phy_csr_rsp_valid_o),
    .phy_csr_rsp_ready_i(phy_csr_rsp_ready_i),
    .phy_csr_rsp_rdata_o(phy_csr_rsp_rdata_o),
    .phy_csr_rsp_error_o(phy_csr_rsp_error_o)
  );

endmodule


// One-entry loss-detecting event bridge. Data remains held from request toggle
// until acknowledgement returns. Every additional source event is counted in
// Gray code and replayed as an individual destination-domain overflow pulse.
// The source-domain pulse is also exposed for the ctrl->sym packet-drop bridge,
// whose overflow consumer already resides in the source ctrl clock domain.
module phy_cdc_event_bus #(
  parameter int unsigned WIDTH = 1,
  parameter int unsigned OVERFLOW_COUNT_WIDTH = 8
) (
  input  logic             s_clk_i,
  input  logic             s_rst_ni,
  input  logic             s_event_i,
  input  logic [WIDTH-1:0] s_data_i,
  output logic             s_overflow_event_o,
  input  logic             d_clk_i,
  input  logic             d_rst_ni,
  output logic             d_event_o,
  output logic [WIDTH-1:0] d_data_o,
  output logic             d_overflow_event_o
);
  timeunit 1ns;
  timeprecision 1ps;

  logic [WIDTH-1:0] s_data_hold_q;
  logic s_request_toggle_q;
  logic d_ack_toggle_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] d_ack_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] s_request_sync_q;
  logic s_busy;

  logic [OVERFLOW_COUNT_WIDTH-1:0] s_overflow_bin_q;
  logic [OVERFLOW_COUNT_WIDTH-1:0] s_overflow_gray_q;
  (* ASYNC_REG = "TRUE" *)
  logic [OVERFLOW_COUNT_WIDTH-1:0] d_overflow_gray_meta_q;
  (* ASYNC_REG = "TRUE" *)
  logic [OVERFLOW_COUNT_WIDTH-1:0] d_overflow_gray_sync_q;
  (* ASYNC_REG = "TRUE" *)
  logic [OVERFLOW_COUNT_WIDTH-1:0] d_overflow_gray_guard_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] d_source_reset_sync_q;
  logic [1:0] d_source_live_guard_q;
  logic [OVERFLOW_COUNT_WIDTH-1:0] d_overflow_bin_sync;
  logic [OVERFLOW_COUNT_WIDTH-1:0] d_overflow_seen_q;
  logic [OVERFLOW_COUNT_WIDTH-1:0] d_overflow_delta;
  logic [OVERFLOW_COUNT_WIDTH:0] d_overflow_pending_q;
  logic [OVERFLOW_COUNT_WIDTH:0] d_overflow_pending_after_emit;
  logic [OVERFLOW_COUNT_WIDTH+1:0] d_overflow_pending_sum;
  logic [OVERFLOW_COUNT_WIDTH:0] d_overflow_pending_next;

  function automatic logic [OVERFLOW_COUNT_WIDTH-1:0] overflow_bin_to_gray(
    input logic [OVERFLOW_COUNT_WIDTH-1:0] binary_value
  );
    return (binary_value >> 1) ^ binary_value;
  endfunction

  function automatic logic [OVERFLOW_COUNT_WIDTH-1:0] overflow_gray_to_bin(
    input logic [OVERFLOW_COUNT_WIDTH-1:0] gray_value
  );
    logic [OVERFLOW_COUNT_WIDTH-1:0] binary_value;
    integer bit_index;
    begin
      binary_value[OVERFLOW_COUNT_WIDTH-1] =
          gray_value[OVERFLOW_COUNT_WIDTH-1];
      for (bit_index = OVERFLOW_COUNT_WIDTH-2; bit_index >= 0;
           bit_index = bit_index - 1)
        binary_value[bit_index] =
            binary_value[bit_index+1] ^ gray_value[bit_index];
      return binary_value;
    end
  endfunction

  assign s_busy = s_request_toggle_q != d_ack_sync_q[1];
  assign d_overflow_bin_sync = overflow_gray_to_bin(d_overflow_gray_guard_q);
  assign d_overflow_delta = d_overflow_bin_sync - d_overflow_seen_q;

  always_comb begin
    d_overflow_pending_after_emit = d_overflow_pending_q;
    if (d_overflow_pending_q != '0)
      d_overflow_pending_after_emit = d_overflow_pending_q - 1'b1;
    d_overflow_pending_sum =
        {1'b0, d_overflow_pending_after_emit} +
        {{2{1'b0}}, d_overflow_delta};
    if (d_overflow_pending_sum[OVERFLOW_COUNT_WIDTH+1])
      d_overflow_pending_next = '1;
    else
      d_overflow_pending_next =
          d_overflow_pending_sum[OVERFLOW_COUNT_WIDTH:0];
  end

  always_ff @(posedge s_clk_i or negedge s_rst_ni) begin
    if (!s_rst_ni) begin
      s_data_hold_q          <= '0;
      s_request_toggle_q     <= 1'b0;
      d_ack_sync_q           <= 2'b00;
      s_overflow_event_o     <= 1'b0;
      s_overflow_bin_q       <= '0;
      s_overflow_gray_q      <= '0;
    end else begin
      d_ack_sync_q <= {d_ack_sync_q[0], d_ack_toggle_q};
      s_overflow_event_o <= 1'b0;
      if (s_event_i) begin
        if (!s_busy) begin
          s_data_hold_q      <= s_data_i;
          s_request_toggle_q <= !s_request_toggle_q;
        end else begin
          s_overflow_event_o <= 1'b1;
          s_overflow_bin_q   <= s_overflow_bin_q + 1'b1;
          s_overflow_gray_q  <= overflow_bin_to_gray(
              s_overflow_bin_q + 1'b1);
        end
      end
    end
  end

  always_ff @(posedge d_clk_i or negedge d_rst_ni) begin
    if (!d_rst_ni) begin
      s_request_sync_q <= 2'b00;
      d_ack_toggle_q   <= 1'b0;
      d_event_o        <= 1'b0;
      d_data_o         <= '0;
      d_overflow_gray_meta_q  <= '0;
      d_overflow_gray_sync_q  <= '0;
      d_overflow_gray_guard_q <= '0;
      d_source_reset_sync_q   <= 2'b00;
      d_source_live_guard_q   <= 2'b00;
      d_overflow_seen_q       <= '0;
      d_overflow_pending_q    <= '0;
      d_overflow_event_o      <= 1'b0;
    end else begin
      s_request_sync_q <= {s_request_sync_q[0], s_request_toggle_q};
      d_event_o        <= 1'b0;
      d_overflow_event_o <= 1'b0;
      d_source_reset_sync_q <= {
        d_source_reset_sync_q[0], s_rst_ni
      };
      d_source_live_guard_q <= {
        d_source_live_guard_q[0], d_source_reset_sync_q[1]
      };
      d_overflow_gray_meta_q  <= s_overflow_gray_q;
      d_overflow_gray_sync_q  <= d_overflow_gray_meta_q;
      d_overflow_gray_guard_q <= d_overflow_gray_sync_q;

      if (s_request_sync_q[1] != d_ack_toggle_q) begin
        d_data_o       <= s_data_hold_q;
        d_event_o      <= 1'b1;
        d_ack_toggle_q <= s_request_sync_q[1];
      end

      // The reset synchronizer intentionally leads the three-stage Gray path.
      // Rebaseline while the source is reset and for two destination clocks
      // after release, so a counter reset cannot masquerade as wrapped losses.
      if (!d_source_reset_sync_q[1] || !(&d_source_live_guard_q)) begin
        d_overflow_seen_q    <= d_overflow_bin_sync;
        d_overflow_pending_q <= '0;
      end else begin
        d_overflow_seen_q    <= d_overflow_bin_sync;
        d_overflow_pending_q <= d_overflow_pending_next;
        d_overflow_event_o   <= (d_overflow_pending_q != '0);
      end
    end
  end
endmodule


// One outstanding ready/valid bundled-data request.  Source ready means the
// bridge can atomically accept a new request; destination valid is held until
// its consumer accepts the bundle.
module phy_cdc_req_ack #(
  parameter int unsigned WIDTH = 1
) (
  input  logic             s_clk_i,
  input  logic             s_rst_ni,
  input  logic             s_valid_i,
  output logic             s_ready_o,
  input  logic [WIDTH-1:0] s_data_i,
  input  logic             d_clk_i,
  input  logic             d_rst_ni,
  output logic             d_valid_o,
  input  logic             d_ready_i,
  output logic [WIDTH-1:0] d_data_o
);
  timeunit 1ns;
  timeprecision 1ps;

  logic [WIDTH-1:0] s_data_hold_q;
  logic s_request_toggle_q;
  logic d_ack_toggle_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] d_ack_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] s_request_sync_q;

  assign s_ready_o = s_request_toggle_q == d_ack_sync_q[1];

  always_ff @(posedge s_clk_i or negedge s_rst_ni) begin
    if (!s_rst_ni) begin
      s_data_hold_q      <= '0;
      s_request_toggle_q <= 1'b0;
      d_ack_sync_q       <= 2'b00;
    end else begin
      d_ack_sync_q <= {d_ack_sync_q[0], d_ack_toggle_q};
      if (s_valid_i && s_ready_o) begin
        s_data_hold_q      <= s_data_i;
        s_request_toggle_q <= !s_request_toggle_q;
      end
    end
  end

  always_ff @(posedge d_clk_i or negedge d_rst_ni) begin
    if (!d_rst_ni) begin
      s_request_sync_q <= 2'b00;
      d_ack_toggle_q   <= 1'b0;
      d_valid_o        <= 1'b0;
      d_data_o         <= '0;
    end else begin
      s_request_sync_q <= {s_request_sync_q[0], s_request_toggle_q};
      if (!d_valid_o && (s_request_sync_q[1] != d_ack_toggle_q)) begin
        d_data_o  <= s_data_hold_q;
        d_valid_o <= 1'b1;
      end else if (d_valid_o && d_ready_i) begin
        d_valid_o      <= 1'b0;
        d_ack_toggle_q <= s_request_sync_q[1];
      end
    end
  end
endmodule


// Latest-value coherent snapshot.  A changed packed value is held while its
// toggle crosses; if the source changes again in flight it is sent after the
// acknowledgement, never as independently synchronized bits.
module phy_cdc_snapshot #(
  parameter int unsigned WIDTH = 1,
  parameter logic [WIDTH-1:0] RESET_VALUE = '0
) (
  input  logic             s_clk_i,
  input  logic             s_rst_ni,
  input  logic [WIDTH-1:0] s_data_i,
  input  logic             d_clk_i,
  input  logic             d_rst_ni,
  output logic [WIDTH-1:0] d_data_o
);
  timeunit 1ns;
  timeprecision 1ps;

  logic [WIDTH-1:0] s_data_hold_q;
  logic [WIDTH-1:0] s_last_sent_q;
  logic s_request_toggle_q;
  logic d_ack_toggle_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] d_ack_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] s_request_sync_q;
  logic s_idle;

  assign s_idle = s_request_toggle_q == d_ack_sync_q[1];

  always_ff @(posedge s_clk_i or negedge s_rst_ni) begin
    if (!s_rst_ni) begin
      s_data_hold_q      <= RESET_VALUE;
      s_last_sent_q      <= RESET_VALUE;
      s_request_toggle_q <= 1'b0;
      d_ack_sync_q       <= 2'b00;
    end else begin
      d_ack_sync_q <= {d_ack_sync_q[0], d_ack_toggle_q};
      if (s_idle && (s_data_i != s_last_sent_q)) begin
        s_data_hold_q      <= s_data_i;
        s_last_sent_q      <= s_data_i;
        s_request_toggle_q <= !s_request_toggle_q;
      end
    end
  end

  always_ff @(posedge d_clk_i or negedge d_rst_ni) begin
    if (!d_rst_ni) begin
      s_request_sync_q <= 2'b00;
      d_ack_toggle_q   <= 1'b0;
      d_data_o         <= RESET_VALUE;
    end else begin
      s_request_sync_q <= {s_request_sync_q[0], s_request_toggle_q};
      if (s_request_sync_q[1] != d_ack_toggle_q) begin
        d_data_o       <= s_data_hold_q;
        d_ack_toggle_q <= s_request_sync_q[1];
      end
    end
  end
endmodule
