`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module pcie_gen12_phy_x1_rp (
	ctrl_clk_i,
	ctrl_rst_ni,
	link_clk_i,
	link_rst_ni,
	port_reset_ni,
	pcie_refclk_p_i,
	pcie_refclk_n_i,
	pcie_rx_p_i,
	pcie_rx_n_i,
	pcie_tx_p_o,
	pcie_tx_n_o,
	phy_sym_clk_o,
	phy_sym_rst_no,
	phy_dll_link_up_o,
	phy_dll_data_active_o,
	phy_dll_current_rate_o,
	phy_dll_link_down_evt_o,
	dll_tx_valid_i,
	dll_tx_ready_o,
	dll_tx_data_i,
	dll_tx_keep_i,
	dll_tx_sop_i,
	dll_tx_eop_i,
	dll_tx_kind_i,
	dll_tx_abort_i,
	dll_rx_valid_o,
	dll_rx_ready_i,
	dll_rx_data_o,
	dll_rx_keep_o,
	dll_rx_sop_o,
	dll_rx_eop_o,
	dll_rx_kind_o,
	dll_rx_abort_o,
	mgmt_cmd_valid_i,
	mgmt_cmd_ready_o,
	mgmt_cmd_opcode_i,
	mgmt_cmd_arg_i,
	mgmt_rsp_valid_o,
	mgmt_rsp_ready_i,
	mgmt_rsp_status_o,
	port_pm_req_valid_i,
	port_pm_req_ready_o,
	port_pm_req_state_i,
	port_pm_req_exit_i,
	port_pm_done_o,
	port_pm_fail_o,
	port_pm_rsp_ready_i,
	phy_ready_o,
	phy_link_up_o,
	phy_data_active_o,
	phy_current_rate_o,
	phy_ltssm_state_o,
	phy_ltssm_substate_o,
	phy_state_reason_o,
	phy_rx_locked_o,
	phy_err_valid_o,
	phy_err_ready_i,
	phy_err_code_o,
	phy_err_info_o,
	phy_csr_req_valid_i,
	phy_csr_req_ready_o,
	phy_csr_req_write_i,
	phy_csr_req_addr_i,
	phy_csr_req_wdata_i,
	phy_csr_req_wstrb_i,
	phy_csr_rsp_valid_o,
	phy_csr_rsp_ready_i,
	phy_csr_rsp_rdata_o,
	phy_csr_rsp_error_o
);
	reg _sv2v_0;
	parameter [31:0] SIM_TIME_SCALE = 1;
	parameter [2:0] BEHAV_DETECT_STATUS = 3'b011;
	parameter [0:0] BEHAV_DETECT_TIMEOUT = 1'b0;
	parameter [0:0] BEHAV_RATE_FAIL = 1'b0;
	parameter [0:0] BEHAV_POWER_FAIL = 1'b0;
	parameter [0:0] BEHAV_LINK_POLARITY_INVERTED = 1'b0;
	parameter [31:0] BEHAV_ELASTIC_CORRECTION_MODE = 0;
	parameter [0:0] BEHAV_INJECT_CODE_ERROR = 1'b0;
	parameter [0:0] BEHAV_INJECT_DISPARITY_ERROR = 1'b0;
	parameter [0:0] BEHAV_INJECT_RXBUF_UNDERFLOW = 1'b0;
	parameter [0:0] BEHAV_INJECT_RXBUF_OVERFLOW = 1'b0;
	parameter [0:0] BEHAV_INJECT_TXBUF_FAULT = 1'b0;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	input wire link_clk_i;
	input wire link_rst_ni;
	input wire port_reset_ni;
	input wire pcie_refclk_p_i;
	input wire pcie_refclk_n_i;
	input wire pcie_rx_p_i;
	input wire pcie_rx_n_i;
	output wire pcie_tx_p_o;
	output wire pcie_tx_n_o;
	output wire phy_sym_clk_o;
	output wire phy_sym_rst_no;
	output wire phy_dll_link_up_o;
	output wire phy_dll_data_active_o;
	output wire phy_dll_current_rate_o;
	output wire phy_dll_link_down_evt_o;
	input wire dll_tx_valid_i;
	output wire dll_tx_ready_o;
	input wire [15:0] dll_tx_data_i;
	input wire [1:0] dll_tx_keep_i;
	input wire dll_tx_sop_i;
	input wire dll_tx_eop_i;
	input wire dll_tx_kind_i;
	input wire dll_tx_abort_i;
	output wire dll_rx_valid_o;
	input wire dll_rx_ready_i;
	output wire [15:0] dll_rx_data_o;
	output wire [1:0] dll_rx_keep_o;
	output wire dll_rx_sop_o;
	output wire dll_rx_eop_o;
	output wire dll_rx_kind_o;
	output wire dll_rx_abort_o;
	input wire mgmt_cmd_valid_i;
	output wire mgmt_cmd_ready_o;
	input wire [3:0] mgmt_cmd_opcode_i;
	input wire [7:0] mgmt_cmd_arg_i;
	output wire mgmt_rsp_valid_o;
	input wire mgmt_rsp_ready_i;
	output wire [3:0] mgmt_rsp_status_o;
	input wire port_pm_req_valid_i;
	output wire port_pm_req_ready_o;
	input wire [1:0] port_pm_req_state_i;
	input wire port_pm_req_exit_i;
	output wire port_pm_done_o;
	output wire port_pm_fail_o;
	input wire port_pm_rsp_ready_i;
	output wire phy_ready_o;
	output wire phy_link_up_o;
	output wire phy_data_active_o;
	output wire phy_current_rate_o;
	output wire [5:0] phy_ltssm_state_o;
	output wire [5:0] phy_ltssm_substate_o;
	output wire [7:0] phy_state_reason_o;
	output wire phy_rx_locked_o;
	output wire phy_err_valid_o;
	input wire phy_err_ready_i;
	output wire [7:0] phy_err_code_o;
	output wire [31:0] phy_err_info_o;
	input wire phy_csr_req_valid_i;
	output wire phy_csr_req_ready_o;
	input wire phy_csr_req_write_i;
	input wire [11:0] phy_csr_req_addr_i;
	input wire [31:0] phy_csr_req_wdata_i;
	input wire [3:0] phy_csr_req_wstrb_i;
	output wire phy_csr_rsp_valid_o;
	input wire phy_csr_rsp_ready_i;
	output wire [31:0] phy_csr_rsp_rdata_o;
	output wire phy_csr_rsp_error_o;
	localparam [31:0] OS_REQUEST_WIDTH = 41;
	localparam [31:0] OS_EVENT_WIDTH = 53;
	localparam [31:0] CTRL_SNAPSHOT_WIDTH = 20;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_DECODE_ERROR_THRESHOLD = 8;
	localparam [31:0] DECODE_STREAK_WIDTH = 4;
	(* ASYNC_REG = "TRUE" *) reg [1:0] ctrl_reset_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] link_reset_sync_q;
	wire ctrl_local_rst_ni;
	wire link_local_rst_ni;
	always @(posedge ctrl_clk_i or negedge ctrl_rst_ni or negedge port_reset_ni)
		if (!ctrl_rst_ni || !port_reset_ni)
			ctrl_reset_sync_q <= 2'b00;
		else
			ctrl_reset_sync_q <= {ctrl_reset_sync_q[0], 1'b1};
	always @(posedge link_clk_i or negedge link_rst_ni or negedge port_reset_ni)
		if (!link_rst_ni || !port_reset_ni)
			link_reset_sync_q <= 2'b00;
		else
			link_reset_sync_q <= {link_reset_sync_q[0], 1'b1};
	assign ctrl_local_rst_ni = ctrl_reset_sync_q[1];
	assign link_local_rst_ni = link_reset_sync_q[1];
	wire gt_sym_clk;
	wire gt_sym_rst_n;
	wire gt_sym_clk_stable;
	wire gt_buffer_reinit_done;
	wire [15:0] gt_rx_symbol_data;
	wire [1:0] gt_rx_symbol_is_k;
	wire [1:0] gt_rx_symbol_disparity_error;
	wire [1:0] gt_rx_symbol_code_error;
	wire [1:0] gt_rx_symbol_is_comma;
	wire gt_rx_symbol_valid;
	wire gt_rx_byte_aligned;
	wire gt_rx_realign_event;
	wire [1:0] gt_rx_clkcor_count;
	wire [2:0] gt_rx_buffer_status;
	wire gt_tx_buffer_fault;
	wire gt_detect_req;
	wire gt_detect_busy;
	wire gt_detect_done;
	wire gt_receiver_present;
	wire gt_rate_req;
	wire gt_rate_target_gen2;
	wire gt_rate_busy;
	wire gt_rate_done;
	wire gt_rate_fail;
	wire gt_tx_electrical_idle;
	wire gt_tx_electrical_idle_active;
	wire gt_rx_electrical_idle;
	wire gt_power_req;
	wire [1:0] gt_power_state;
	wire gt_power_busy;
	wire gt_power_done;
	wire gt_power_fail;
	wire gt_rx_polarity_invert;
	wire gt_tx_deemphasis;
	wire gt_tx_swing;
	wire [2:0] gt_tx_margin;
	wire gt_compliance_enable;
	wire [2:0] gt_loopback_mode;
	wire gt_ready;
	wire gt_fault;
	wire [7:0] gt_fault_code;
	wire crr_ready;
	wire crr_current_rate;
	wire crr_detect_done;
	wire crr_receiver_present;
	wire crr_rate_done;
	wire crr_rate_fail;
	wire crr_power_done;
	wire crr_power_fail;
	wire crr_tx_electrical_idle_active;
	wire crr_rx_electrical_idle;
	wire crr_rx_aligned;
	wire crr_fault;
	wire [7:0] crr_fault_code;
	wire crr_sym_path_reset;
	wire crr_packet_admission_enable;
	wire crr_packet_buffer_flush;
	wire lt_gt_detect_req;
	wire lt_gt_rate_req;
	wire lt_gt_rate_target_gen2;
	wire lt_gt_power_req;
	wire [1:0] lt_gt_power_state;
	wire lt_gt_tx_electrical_idle;
	wire lt_gt_rx_polarity_invert;
	wire lt_gt_tx_deemphasis;
	wire lt_gt_tx_swing;
	wire [2:0] lt_gt_tx_margin;
	wire lt_gt_compliance_enable;
	wire [2:0] lt_gt_loopback_mode;
	wire lt_os_req_valid;
	wire lt_os_req_ready;
	wire [2:0] lt_os_kind;
	wire [34:0] lt_os_fields;
	wire [2:0] lt_os_repeat_mode;
	wire [3:0] lt_tx_mode;
	wire lt_packet_enable;
	wire lt_packet_flush;
	wire lt_packet_drop;
	wire timer_start;
	wire timer_stop;
	wire [5:0] timer_command_id;
	wire [31:0] timer_limit;
	wire retry_update;
	wire retry_clear;
	wire timer_expired;
	wire [5:0] timer_expired_id;
	wire [7:0] retry_count;
	wire timer_active;
	wire [31:0] timer_count;
	wire [5:0] lt_state;
	wire [5:0] lt_substate;
	wire [7:0] lt_entry_reason;
	wire lt_link_up;
	wire lt_data_active;
	wire lt_current_rate;
	wire lt_target_rate;
	wire lt_clear_error;
	wire lt_status_evt_valid;
	wire [7:0] lt_status_evt_code;
	wire [31:0] lt_status_evt_info;
	wire lt_status_evt_fatal;
	wire txbuf_pkt_valid;
	wire txbuf_pkt_ready;
	wire [15:0] txbuf_pkt_data;
	wire [1:0] txbuf_pkt_keep;
	wire txbuf_pkt_sop;
	wire txbuf_pkt_eop;
	wire txbuf_pkt_kind;
	wire txbuf_pkt_abort;
	wire txbuf_capture_active_link;
	wire txbuf_pending_sym;
	wire txbuf_error_evt_link;
	wire [7:0] txbuf_error_code_link;
	wire [7:0] txbuf_level_sym;
	wire [15:0] tx_selected_data;
	wire [1:0] tx_selected_is_k;
	wire [3:0] tx_selected_class;
	wire [1:0] tx_lfsr_action;
	wire tx_packet_active_sym;
	wire tx_quiesced_sym;
	wire tx_logical_idle_evt_sym;
	wire tx_scheduler_error_evt_sym;
	wire [7:0] tx_scheduler_error_code_sym;
	wire [15:0] tx_scrambled_data;
	wire [1:0] tx_scrambled_is_k;
	wire [15:0] tx_scrambler_state;
	wire [15:0] rx_descrambler_state;
	wire scrambler_sync_error_sym;
	wire [15:0] os_rx_candidate_data;
	wire [1:0] os_rx_candidate_is_k;
	wire os_rx_candidate_valid;
	wire [3:0] os_rx_candidate_error;
	wire [15:0] rx_descr_data;
	wire [1:0] rx_descr_is_k;
	wire rx_descr_valid;
	wire [3:0] rx_descr_class;
	wire [3:0] rx_descr_lfsr_action;
	wire [15:0] rx_descrambled_data;
	wire rx_descrambled_valid;
	wire rxbuf_pkt_valid;
	wire rxbuf_pkt_ready;
	wire [15:0] rxbuf_pkt_data;
	wire [1:0] rxbuf_pkt_keep;
	wire rxbuf_pkt_sop;
	wire rxbuf_pkt_eop;
	wire rxbuf_pkt_kind;
	wire rxbuf_pkt_abort;
	wire rxbuf_pkt_drop;
	wire rx_logical_idle_valid;
	wire [1:0] rx_logical_idle_char_mask;
	wire rx_align_loss_evt_sym;
	wire rx_invalid_k_evt_sym;
	wire rx_code_error_evt_sym;
	wire rx_disparity_error_evt_sym;
	wire rx_frame_error_evt_sym;
	wire rx_packet_buffer_error_evt_sym;
	wire rx_packet_drop_evt_sym;
	wire rx_packet_active_sym;
	wire rxbuf_overflow_evt_sym;
	wire rxbuf_candidate_drop_evt_sym;
	wire rxbuf_backpressure_timeout_evt_link;
	wire [7:0] rxbuf_level_sym;
	wire os_req_valid_sym;
	wire os_req_ready_sym;
	wire [2:0] os_req_kind_sym;
	wire [34:0] os_req_fields_sym;
	wire [2:0] os_req_repeat_sym;
	wire [15:0] os_tx_data;
	wire [1:0] os_tx_is_k;
	wire [3:0] os_tx_class;
	wire os_tx_valid;
	wire os_tx_done_sym;
	wire os_tx_consume;
	wire os_tx_skp_start;
	wire os_tx_skp_done;
	wire os_rx_ts1_evt_sym;
	wire os_rx_ts2_evt_sym;
	wire os_rx_fts_evt_sym;
	wire os_rx_skp_evt_sym;
	wire os_rx_eios_evt_sym;
	wire os_rx_eieos_evt_sym;
	wire rx_logical_idle_qualified_evt_sym;
	wire os_rx_hot_reset_evt_sym;
	wire os_rx_loopback_evt_sym;
	wire os_rx_speed_change_evt_sym;
	wire [34:0] os_rx_fields_sym;
	wire [7:0] os_rx_error_sym;
	wire skp_due_sym;
	wire [15:0] skp_deadline_sym;
	wire skp_deadline_missed_evt_sym;
	wire skp_rx_add_evt_sym;
	wire [1:0] skp_rx_skip_count_sym;
	wire skp_rx_buffer_fault_evt_sym;
	wire skp_rx_underflow_evt_sym;
	wire skp_rx_overflow_evt_sym;
	wire skp_rx_status_invalid_evt_sym;
	wire [19:0] ctrl_snapshot_source;
	wire [19:0] ctrl_snapshot_sym;
	wire crr_ready_sym;
	wire crr_admission_sym;
	wire current_rate_sym;
	wire [5:0] lt_substate_sym;
	wire [5:0] lt_state_sym;
	wire lt_packet_enable_snapshot_sym;
	wire [3:0] lt_tx_mode_sym;
	wire lt_packet_enable_sym;
	assign ctrl_snapshot_source = {crr_ready, crr_packet_admission_enable, crr_current_rate, lt_substate, lt_state, lt_packet_enable, lt_tx_mode};
	assign {crr_ready_sym, crr_admission_sym, current_rate_sym, lt_substate_sym, lt_state_sym, lt_packet_enable_snapshot_sym, lt_tx_mode_sym} = ctrl_snapshot_sym;
	assign lt_packet_enable_sym = lt_packet_enable_snapshot_sym && crr_admission_sym;
	phy_cdc_snapshot #(.WIDTH(CTRL_SNAPSHOT_WIDTH)) u_ctrl_to_sym_snapshot(
		.s_clk_i(ctrl_clk_i),
		.s_rst_ni(ctrl_local_rst_ni),
		.s_data_i(ctrl_snapshot_source),
		.d_clk_i(phy_sym_clk_o),
		.d_rst_ni(phy_sym_rst_no),
		.d_data_o(ctrl_snapshot_sym)
	);
	(* ASYNC_REG = "TRUE" *) reg [1:0] crr_admission_link_sync_q;
	always @(posedge link_clk_i or negedge link_local_rst_ni)
		if (!link_local_rst_ni)
			crr_admission_link_sync_q <= 2'b00;
		else
			crr_admission_link_sync_q <= {crr_admission_link_sync_q[0], crr_packet_admission_enable};
	reg [1:0] flush_state_q;
	reg flush_hold_ctrl_q;
	reg flush_retrigger_q;
	wire flush_request_ctrl;
	(* ASYNC_REG = "TRUE" *) reg [1:0] flush_link_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] flush_sym_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] flush_link_ack_ctrl_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] flush_sym_ack_ctrl_sync_q;
	assign flush_request_ctrl = crr_packet_buffer_flush || lt_packet_flush;
	always @(posedge link_clk_i or negedge link_local_rst_ni)
		if (!link_local_rst_ni)
			flush_link_sync_q <= 2'b00;
		else
			flush_link_sync_q <= {flush_link_sync_q[0], flush_hold_ctrl_q};
	always @(posedge phy_sym_clk_o or negedge phy_sym_rst_no)
		if (!phy_sym_rst_no)
			flush_sym_sync_q <= 2'b00;
		else
			flush_sym_sync_q <= {flush_sym_sync_q[0], flush_hold_ctrl_q};
	always @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni)
		if (!ctrl_local_rst_ni) begin
			flush_link_ack_ctrl_sync_q <= 2'b00;
			flush_sym_ack_ctrl_sync_q <= 2'b00;
		end
		else begin
			flush_link_ack_ctrl_sync_q <= {flush_link_ack_ctrl_sync_q[0], flush_link_sync_q[1]};
			flush_sym_ack_ctrl_sync_q <= {flush_sym_ack_ctrl_sync_q[0], flush_sym_sync_q[1]};
		end
	always @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni)
		if (!ctrl_local_rst_ni) begin
			flush_state_q <= 2'd0;
			flush_hold_ctrl_q <= 1'b1;
			flush_retrigger_q <= 1'b0;
		end
		else
			(* full_case, parallel_case *)
			case (flush_state_q)
				2'd0: begin
					flush_hold_ctrl_q <= 1'b1;
					if ((flush_link_ack_ctrl_sync_q[1] && flush_sym_ack_ctrl_sync_q[1]) && !flush_request_ctrl) begin
						flush_hold_ctrl_q <= 1'b0;
						flush_state_q <= 2'd1;
					end
				end
				2'd1: begin
					flush_hold_ctrl_q <= 1'b0;
					if (flush_request_ctrl)
						flush_retrigger_q <= 1'b1;
					if (!flush_link_ack_ctrl_sync_q[1] && !flush_sym_ack_ctrl_sync_q[1]) begin
						if (flush_retrigger_q || flush_request_ctrl) begin
							flush_retrigger_q <= 1'b0;
							flush_hold_ctrl_q <= 1'b1;
							flush_state_q <= 2'd0;
						end
						else
							flush_state_q <= 2'd2;
					end
				end
				default: begin
					flush_retrigger_q <= 1'b0;
					if (flush_request_ctrl) begin
						flush_hold_ctrl_q <= 1'b1;
						flush_state_q <= 2'd0;
					end
				end
			endcase
	wire [40:0] os_request_ctrl_payload;
	wire [40:0] os_request_sym_payload;
	wire [OS_REQUEST_WIDTH:0] os_request_ctrl_level;
	wire [OS_REQUEST_WIDTH:0] os_request_sym_level;
	assign os_request_ctrl_payload = {lt_os_repeat_mode, lt_os_fields, lt_os_kind};
	assign os_request_ctrl_level = {lt_os_req_valid, os_request_ctrl_payload};
	assign {os_req_valid_sym, os_request_sym_payload} = os_request_sym_level;
	assign {os_req_repeat_sym, os_req_fields_sym, os_req_kind_sym} = os_request_sym_payload;
	assign lt_os_req_ready = 1'b1;
	phy_cdc_snapshot #(
		.WIDTH(42),
		.RESET_VALUE(1'sb0)
	) u_os_request_cdc(
		.s_clk_i(ctrl_clk_i),
		.s_rst_ni(ctrl_local_rst_ni),
		.s_data_i(os_request_ctrl_level),
		.d_clk_i(phy_sym_clk_o),
		.d_rst_ni(phy_sym_rst_no),
		.d_data_o(os_request_sym_level)
	);
	phy_tx_packet_buffer_cdc u_phy_tx_packet_buffer_cdc(
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
		.txbuf_admission_enable_i(phy_dll_data_active_o && crr_admission_link_sync_q[1]),
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
	phy_tx_framer_scheduler u_phy_tx_framer_scheduler(
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
	phy_scrambler_descrambler u_phy_scrambler_descrambler(
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
	phy_rx_classifier_deframer u_phy_rx_classifier_deframer(
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
	wire lt_packet_drop_sym;
	wire lt_packet_drop_cdc_overflow;
	phy_cdc_event_bus #(.WIDTH(1)) u_lt_packet_drop_cdc(
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
	phy_rx_packet_buffer_cdc u_phy_rx_packet_buffer_cdc(
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
	phy_ordered_set u_phy_ordered_set(
		.sym_clk_i(phy_sym_clk_o),
		.sym_rst_ni(phy_sym_rst_no),
		.os_tx_req_valid_i(os_req_valid_sym),
		.os_tx_req_ready_o(os_req_ready_sym),
		.os_tx_kind_i(os_req_kind_sym),
		.os_tx_link_num_i(os_req_fields_sym[30-:8]),
		.os_tx_lane_num_i(os_req_fields_sym[22-:5]),
		.os_tx_n_fts_i(os_req_fields_sym[17-:8]),
		.os_tx_rate_id_i(os_req_fields_sym[9-:2]),
		.os_tx_training_ctrl_i(os_req_fields_sym[7-:8]),
		.os_tx_link_num_is_pad_i(os_req_fields_sym[32]),
		.os_tx_lane_num_is_pad_i(os_req_fields_sym[31]),
		.os_tx_repeat_mode_i(os_req_repeat_sym),
		.skp_tx_req_i(skp_due_sym),
		.os_tx_gen2_rcvrlock_i(current_rate_sym && (lt_substate_sym == 6'h0d)),
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
	wire [1:0] skp_tx_char_advance;
	assign skp_tx_char_advance = (crr_ready_sym && (lt_tx_mode_sym != 4'h0) ? 2'd2 : 2'd0);
	phy_skp_clock_comp u_phy_skp_clock_comp(
		.sym_clk_i(phy_sym_clk_o),
		.sym_rst_ni(phy_sym_rst_no),
		.skp_current_rate_i(current_rate_sym),
		.skp_tx_char_advance_i(skp_tx_char_advance),
		.skp_packet_boundary_i(!tx_packet_active_sym),
		.skp_os_busy_i(os_tx_valid),
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
	) u_pcie_gty_adapter_x1(
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
	(* ASYNC_REG = "TRUE" *) reg [1:0] tx_quiesced_ctrl_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] tx_capture_ctrl_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] rx_active_ctrl_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] rx_aligned_ctrl_sync_q;
	wire tx_path_quiesced_ctrl;
	always @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni)
		if (!ctrl_local_rst_ni) begin
			tx_quiesced_ctrl_sync_q <= 2'b00;
			tx_capture_ctrl_sync_q <= 2'b00;
			rx_active_ctrl_sync_q <= 2'b00;
			rx_aligned_ctrl_sync_q <= 2'b00;
		end
		else begin
			tx_quiesced_ctrl_sync_q <= {tx_quiesced_ctrl_sync_q[0], tx_quiesced_sym};
			tx_capture_ctrl_sync_q <= {tx_capture_ctrl_sync_q[0], txbuf_capture_active_link};
			rx_active_ctrl_sync_q <= {rx_active_ctrl_sync_q[0], rx_packet_active_sym};
			rx_aligned_ctrl_sync_q <= {rx_aligned_ctrl_sync_q[0], gt_rx_byte_aligned};
		end
	assign tx_path_quiesced_ctrl = tx_quiesced_ctrl_sync_q[1] && !tx_capture_ctrl_sync_q[1];
	phy_clock_reset_rate_ctrl #(.SIM_TIME_SCALE(SIM_TIME_SCALE)) u_phy_clock_reset_rate_ctrl(
		.ctrl_clk_i(ctrl_clk_i),
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
	phy_timer_bank u_phy_timer_bank(
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
	wire [52:0] os_event_sym_payload;
	wire [52:0] os_event_ctrl_payload;
	wire os_event_any_sym;
	wire os_event_ctrl;
	wire os_event_cdc_overflow;
	wire os_rx_ts1_evt_ctrl;
	wire os_rx_ts2_evt_ctrl;
	wire os_rx_fts_evt_ctrl;
	wire os_rx_skp_evt_ctrl;
	wire os_rx_eios_evt_ctrl;
	wire os_rx_eieos_evt_ctrl;
	wire rx_logical_idle_evt_ctrl;
	wire os_rx_hot_reset_evt_ctrl;
	wire os_rx_loopback_evt_ctrl;
	wire os_rx_speed_change_evt_ctrl;
	wire [34:0] os_rx_fields_ctrl;
	wire [7:0] os_rx_error_ctrl_payload;
	wire [7:0] os_rx_error_ctrl;
	assign os_event_any_sym = (((((((((os_rx_ts1_evt_sym || os_rx_ts2_evt_sym) || os_rx_fts_evt_sym) || os_rx_skp_evt_sym) || os_rx_eios_evt_sym) || os_rx_eieos_evt_sym) || rx_logical_idle_qualified_evt_sym) || os_rx_hot_reset_evt_sym) || os_rx_loopback_evt_sym) || os_rx_speed_change_evt_sym) || (os_rx_error_sym != 8'h00);
	assign os_event_sym_payload = {os_rx_error_sym, os_rx_fields_sym, os_rx_speed_change_evt_sym, os_rx_loopback_evt_sym, os_rx_hot_reset_evt_sym, rx_logical_idle_qualified_evt_sym, os_rx_eieos_evt_sym, os_rx_eios_evt_sym, os_rx_skp_evt_sym, os_rx_fts_evt_sym, os_rx_ts2_evt_sym, os_rx_ts1_evt_sym};
	phy_cdc_event_bus #(.WIDTH(OS_EVENT_WIDTH)) u_os_event_cdc(
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
	assign {os_rx_error_ctrl_payload, os_rx_fields_ctrl, os_rx_speed_change_evt_ctrl, os_rx_loopback_evt_ctrl, os_rx_hot_reset_evt_ctrl, rx_logical_idle_evt_ctrl, os_rx_eieos_evt_ctrl, os_rx_eios_evt_ctrl, os_rx_skp_evt_ctrl, os_rx_fts_evt_ctrl, os_rx_ts2_evt_ctrl, os_rx_ts1_evt_ctrl} = os_event_ctrl_payload;
	assign os_rx_error_ctrl = (os_event_ctrl ? os_rx_error_ctrl_payload : 8'h00);
	wire os_tx_done_ctrl;
	wire os_tx_done_cdc_overflow;
	phy_cdc_event_bus #(.WIDTH(1)) u_os_done_cdc(
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
	wire tx_logical_idle_evt_ctrl;
	wire tx_idle_cdc_overflow;
	phy_cdc_event_bus #(.WIDTH(1)) u_tx_idle_cdc(
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
	reg [3:0] decode_error_streak_q;
	reg decode_error_threshold_evt_sym;
	always @(posedge phy_sym_clk_o or negedge phy_sym_rst_no)
		if (!phy_sym_rst_no) begin
			decode_error_streak_q <= 1'sb0;
			decode_error_threshold_evt_sym <= 1'b0;
		end
		else begin
			decode_error_threshold_evt_sym <= 1'b0;
			if (rx_code_error_evt_sym || rx_disparity_error_evt_sym) begin
				if (decode_error_streak_q >= 7) begin
					decode_error_streak_q <= 1'sb0;
					decode_error_threshold_evt_sym <= 1'b1;
				end
				else
					decode_error_streak_q <= decode_error_streak_q + 1'b1;
			end
			else
				decode_error_streak_q <= 1'sb0;
		end
	reg sym_buffer_evt;
	reg [39:0] sym_buffer_payload;
	reg sym_alignment_evt;
	reg [39:0] sym_alignment_payload;
	reg sym_framing_evt;
	reg [39:0] sym_framing_payload;
	reg sym_correctable_evt;
	reg [39:0] sym_correctable_payload;
	reg sym_misc_evt;
	reg [39:0] sym_misc_payload;
	always @(*) begin
		if (_sv2v_0)
			;
		sym_buffer_evt = 1'b0;
		sym_buffer_payload = 40'h0000000000;
		if (skp_rx_underflow_evt_sym) begin
			sym_buffer_evt = 1'b1;
			sym_buffer_payload = {8'h07, txbuf_level_sym, rxbuf_level_sym, 11'd0, gt_rx_buffer_status, gt_rx_clkcor_count};
		end
		else if (skp_rx_overflow_evt_sym || skp_rx_status_invalid_evt_sym) begin
			sym_buffer_evt = 1'b1;
			sym_buffer_payload = {8'h08, txbuf_level_sym, rxbuf_level_sym, 11'd0, gt_rx_buffer_status, gt_rx_clkcor_count};
		end
		else if (rxbuf_overflow_evt_sym || rx_packet_buffer_error_evt_sym) begin
			sym_buffer_evt = 1'b1;
			sym_buffer_payload = {8'h10, txbuf_level_sym, rxbuf_level_sym, 14'd0, rxbuf_overflow_evt_sym, rx_packet_buffer_error_evt_sym};
		end
		sym_alignment_evt = rx_align_loss_evt_sym;
		sym_alignment_payload = {27'h0180000, gt_rx_symbol_code_error, gt_rx_symbol_disparity_error, gt_rx_symbol_is_comma, gt_rx_byte_aligned, gt_rx_realign_event, gt_rx_buffer_status, gt_rx_clkcor_count};
		sym_framing_evt = 1'b0;
		sym_framing_payload = 40'h0000000000;
		if (tx_scheduler_error_evt_sym) begin
			sym_framing_evt = 1'b1;
			sym_framing_payload = {tx_scheduler_error_code_sym, 8'd0, tx_scheduler_error_code_sym, 8'd0, rx_invalid_k_evt_sym, rx_frame_error_evt_sym, rx_packet_drop_evt_sym, rxbuf_candidate_drop_evt_sym, 4'd0};
		end
		else if (((rx_frame_error_evt_sym || rx_invalid_k_evt_sym) || rx_packet_drop_evt_sym) || rxbuf_candidate_drop_evt_sym) begin
			sym_framing_evt = 1'b1;
			sym_framing_payload = {32'h0f000f00, rx_invalid_k_evt_sym, rx_frame_error_evt_sym, rx_packet_drop_evt_sym, rxbuf_candidate_drop_evt_sym, 4'd0};
		end
		sym_correctable_evt = 1'b0;
		sym_correctable_payload = 40'h0000000000;
		if (rx_code_error_evt_sym) begin
			sym_correctable_evt = 1'b1;
			sym_correctable_payload = {36'h020000000, gt_rx_symbol_code_error, gt_rx_symbol_disparity_error};
		end
		else if (rx_disparity_error_evt_sym) begin
			sym_correctable_evt = 1'b1;
			sym_correctable_payload = {36'h010000000, gt_rx_symbol_code_error, gt_rx_symbol_disparity_error};
		end
		sym_misc_evt = 1'b0;
		sym_misc_payload = 40'h0000000000;
		if (scrambler_sync_error_sym) begin
			sym_misc_evt = 1'b1;
			sym_misc_payload = {24'h050000, lt_substate_sym, lt_state_sym, scrambler_sync_error_sym, skp_deadline_missed_evt_sym, decode_error_threshold_evt_sym, rx_packet_drop_evt_sym};
		end
		else if (skp_deadline_missed_evt_sym) begin
			sym_misc_evt = 1'b1;
			sym_misc_payload = {24'h060000, lt_substate_sym, lt_state_sym, scrambler_sync_error_sym, skp_deadline_missed_evt_sym, decode_error_threshold_evt_sym, rx_packet_drop_evt_sym};
		end
		else if (decode_error_threshold_evt_sym) begin
			sym_misc_evt = 1'b1;
			sym_misc_payload = {24'h020000, lt_substate_sym, lt_state_sym, scrambler_sync_error_sym, skp_deadline_missed_evt_sym, decode_error_threshold_evt_sym, rx_packet_drop_evt_sym};
		end
	end
	wire sym_buffer_evt_ctrl;
	wire [39:0] sym_buffer_payload_ctrl;
	wire sym_buffer_cdc_overflow;
	wire sym_alignment_evt_ctrl;
	wire [39:0] sym_alignment_payload_ctrl;
	wire sym_alignment_cdc_overflow;
	wire sym_framing_evt_ctrl;
	wire [39:0] sym_framing_payload_ctrl;
	wire sym_framing_cdc_overflow;
	wire sym_correctable_evt_ctrl;
	wire [39:0] sym_correctable_payload_ctrl;
	wire sym_correctable_cdc_overflow;
	wire sym_misc_evt_ctrl;
	wire [39:0] sym_misc_payload_ctrl;
	wire sym_misc_cdc_overflow;
	phy_cdc_event_bus #(.WIDTH(40)) u_sym_buffer_error_cdc(
		.s_clk_i(phy_sym_clk_o),
		.s_rst_ni(phy_sym_rst_no),
		.s_event_i(sym_buffer_evt),
		.s_data_i(sym_buffer_payload),
		.s_overflow_event_o(),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_event_o(sym_buffer_evt_ctrl),
		.d_data_o(sym_buffer_payload_ctrl),
		.d_overflow_event_o(sym_buffer_cdc_overflow)
	);
	phy_cdc_event_bus #(.WIDTH(40)) u_sym_alignment_error_cdc(
		.s_clk_i(phy_sym_clk_o),
		.s_rst_ni(phy_sym_rst_no),
		.s_event_i(sym_alignment_evt),
		.s_data_i(sym_alignment_payload),
		.s_overflow_event_o(),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_event_o(sym_alignment_evt_ctrl),
		.d_data_o(sym_alignment_payload_ctrl),
		.d_overflow_event_o(sym_alignment_cdc_overflow)
	);
	phy_cdc_event_bus #(.WIDTH(40)) u_sym_framing_error_cdc(
		.s_clk_i(phy_sym_clk_o),
		.s_rst_ni(phy_sym_rst_no),
		.s_event_i(sym_framing_evt),
		.s_data_i(sym_framing_payload),
		.s_overflow_event_o(),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_event_o(sym_framing_evt_ctrl),
		.d_data_o(sym_framing_payload_ctrl),
		.d_overflow_event_o(sym_framing_cdc_overflow)
	);
	phy_cdc_event_bus #(.WIDTH(40)) u_sym_correctable_error_cdc(
		.s_clk_i(phy_sym_clk_o),
		.s_rst_ni(phy_sym_rst_no),
		.s_event_i(sym_correctable_evt),
		.s_data_i(sym_correctable_payload),
		.s_overflow_event_o(),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_event_o(sym_correctable_evt_ctrl),
		.d_data_o(sym_correctable_payload_ctrl),
		.d_overflow_event_o(sym_correctable_cdc_overflow)
	);
	phy_cdc_event_bus #(.WIDTH(40)) u_sym_misc_error_cdc(
		.s_clk_i(phy_sym_clk_o),
		.s_rst_ni(phy_sym_rst_no),
		.s_event_i(sym_misc_evt),
		.s_data_i(sym_misc_payload),
		.s_overflow_event_o(),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_event_o(sym_misc_evt_ctrl),
		.d_data_o(sym_misc_payload_ctrl),
		.d_overflow_event_o(sym_misc_cdc_overflow)
	);
	wire link_buffer_evt;
	wire [39:0] link_buffer_payload;
	wire link_buffer_evt_ctrl;
	wire [39:0] link_buffer_payload_ctrl;
	wire link_buffer_cdc_overflow;
	wire link_framing_evt_ctrl;
	wire [39:0] link_framing_payload_ctrl;
	wire link_framing_cdc_overflow;
	assign link_buffer_evt = rxbuf_backpressure_timeout_evt_link;
	assign link_buffer_payload = {39'h0800000000, rxbuf_backpressure_timeout_evt_link};
	phy_cdc_event_bus #(.WIDTH(40)) u_link_buffer_error_cdc(
		.s_clk_i(link_clk_i),
		.s_rst_ni(link_local_rst_ni),
		.s_event_i(link_buffer_evt),
		.s_data_i(link_buffer_payload),
		.s_overflow_event_o(),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_event_o(link_buffer_evt_ctrl),
		.d_data_o(link_buffer_payload_ctrl),
		.d_overflow_event_o(link_buffer_cdc_overflow)
	);
	phy_cdc_event_bus #(.WIDTH(40)) u_link_framing_error_cdc(
		.s_clk_i(link_clk_i),
		.s_rst_ni(link_local_rst_ni),
		.s_event_i(txbuf_error_evt_link),
		.s_data_i({txbuf_error_code_link, 16'd0, txbuf_error_code_link, 7'd0, txbuf_capture_active_link}),
		.s_overflow_event_o(),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_event_o(link_framing_evt_ctrl),
		.d_data_o(link_framing_payload_ctrl),
		.d_overflow_event_o(link_framing_cdc_overflow)
	);
	wire [15:0] buffer_level_ctrl;
	phy_cdc_snapshot #(.WIDTH(16)) u_buffer_level_snapshot(
		.s_clk_i(phy_sym_clk_o),
		.s_rst_ni(phy_sym_rst_no),
		.s_data_i({txbuf_level_sym, rxbuf_level_sym}),
		.d_clk_i(ctrl_clk_i),
		.d_rst_ni(ctrl_local_rst_ni),
		.d_data_o(buffer_level_ctrl)
	);
	wire rx_align_loss_evt_ctrl;
	wire rx_frame_error_evt_ctrl;
	wire rx_buffer_fault_evt_ctrl;
	wire datapath_recovery_req_ctrl;
	wire cdc_overflow_emit_ctrl;
	assign rx_align_loss_evt_ctrl = sym_alignment_evt_ctrl;
	assign rx_frame_error_evt_ctrl = sym_framing_evt_ctrl;
	assign rx_buffer_fault_evt_ctrl = sym_buffer_evt_ctrl || link_buffer_evt_ctrl;
	assign datapath_recovery_req_ctrl = sym_misc_evt_ctrl || cdc_overflow_emit_ctrl;
	phy_ltssm_ctrl #(.SIM_TIME_SCALE(SIM_TIME_SCALE)) u_phy_ltssm_ctrl(
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
		.rx_logical_idle_qualified_evt_i(os_event_ctrl && rx_logical_idle_evt_ctrl),
		.os_rx_hot_reset_evt_i(os_event_ctrl && os_rx_hot_reset_evt_ctrl),
		.os_rx_loopback_evt_i(os_event_ctrl && os_rx_loopback_evt_ctrl),
		.os_rx_speed_change_evt_i(os_event_ctrl && os_rx_speed_change_evt_ctrl),
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
	localparam [31:0] OVERFLOW_PENDING_COUNT_WIDTH = 8;
	wire [9:0] cdc_overflow_evt_ctrl;
	wire [1:0] buffer_category_source_count_ctrl;
	wire [1:0] framing_category_source_count_ctrl;
	wire [1:0] category_collision_count_ctrl;
	wire [2:0] general_collision_count_ctrl;
	wire general_queue_drop_ctrl;
	reg [4:0] overflow_arrival_count_ctrl;
	reg [7:0] overflow_pending_count_q;
	reg [7:0] overflow_pending_after_emit;
	reg [OVERFLOW_PENDING_COUNT_WIDTH:0] overflow_pending_sum;
	reg [7:0] overflow_pending_count_next;
	assign cdc_overflow_evt_ctrl = {link_framing_cdc_overflow, link_buffer_cdc_overflow, sym_misc_cdc_overflow, sym_correctable_cdc_overflow, sym_framing_cdc_overflow, sym_alignment_cdc_overflow, sym_buffer_cdc_overflow, tx_idle_cdc_overflow, os_tx_done_cdc_overflow, os_event_cdc_overflow};
	reg general_evt_valid_q;
	reg [3:0] general_evt_source_q;
	reg [7:0] general_evt_code_q;
	reg [31:0] general_evt_info_q;
	reg general_evt_fatal_q;
	reg general_new_valid;
	reg [3:0] general_new_source;
	reg [7:0] general_new_code;
	reg [31:0] general_new_info;
	reg general_new_fatal;
	reg [2:0] general_new_count;
	reg [2:0] general_best_priority;
	wire status_evt_ready;
	wire crr_nonfatal_evt;
	wire os_error_general_evt;
	function automatic [2:0] pcie_gen12_phy_pkg_error_severity;
		input reg [7:0] code;
		(* full_case, parallel_case *)
		case (code)
			8'h01, 8'h02: pcie_gen12_phy_pkg_error_severity = 3'd1;
			8'h0e, 8'h13: pcie_gen12_phy_pkg_error_severity = 3'd2;
			8'h04, 8'h0f: pcie_gen12_phy_pkg_error_severity = 3'd3;
			8'h03, 8'h05, 8'h06, 8'h09, 8'h0a, 8'h0b, 8'h11: pcie_gen12_phy_pkg_error_severity = 3'd4;
			8'h07, 8'h08, 8'h0c, 8'h0d, 8'h10, 8'h12: pcie_gen12_phy_pkg_error_severity = 3'd5;
			default: pcie_gen12_phy_pkg_error_severity = 3'd0;
		endcase
	endfunction
	function automatic pcie_gen12_phy_pkg_error_is_fatal;
		input reg [7:0] code;
		pcie_gen12_phy_pkg_error_is_fatal = pcie_gen12_phy_pkg_error_severity(code) == 3'd5;
	endfunction
	assign crr_nonfatal_evt = crr_fault && !pcie_gen12_phy_pkg_error_is_fatal(crr_fault_code);
	assign os_error_general_evt = os_event_ctrl && (os_rx_error_ctrl_payload != 8'h00);
	function automatic [2:0] pcie_gen12_phy_pkg_error_priority;
		input reg [7:0] code;
		(* full_case, parallel_case *)
		case (code)
			8'h0c, 8'h0d: pcie_gen12_phy_pkg_error_priority = 3'd0;
			8'h07, 8'h08, 8'h10, 8'h12: pcie_gen12_phy_pkg_error_priority = 3'd1;
			8'h03, 8'h11: pcie_gen12_phy_pkg_error_priority = 3'd2;
			8'h0e, 8'h0f, 8'h04, 8'h13: pcie_gen12_phy_pkg_error_priority = 3'd3;
			8'h02, 8'h01, 8'h05, 8'h06, 8'h09, 8'h0a, 8'h0b: pcie_gen12_phy_pkg_error_priority = 3'd4;
			default: pcie_gen12_phy_pkg_error_priority = 3'd7;
		endcase
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		general_new_valid = 1'b0;
		general_new_source = 4'h0;
		general_new_code = 8'h00;
		general_new_info = 32'd0;
		general_new_fatal = 1'b0;
		general_best_priority = 3'd7;
		general_new_count = ({2'd0, crr_nonfatal_evt} + {2'd0, lt_status_evt_valid}) + {2'd0, sym_misc_evt_ctrl};
		if (crr_nonfatal_evt && (crr_fault_code != 8'h00)) begin
			general_new_valid = 1'b1;
			general_new_source = 4'h6;
			general_new_code = crr_fault_code;
			general_new_info = {8'd0, crr_fault_code, lt_state, lt_substate, crr_current_rate, crr_ready, 2'd0};
			general_new_fatal = 1'b0;
			general_best_priority = pcie_gen12_phy_pkg_error_priority(crr_fault_code);
		end
		if ((lt_status_evt_valid && (lt_status_evt_code != 8'h00)) && (!general_new_valid || (pcie_gen12_phy_pkg_error_priority(lt_status_evt_code) < general_best_priority))) begin
			general_new_valid = 1'b1;
			general_new_source = 4'h0;
			general_new_code = lt_status_evt_code;
			general_new_info = lt_status_evt_info;
			general_new_fatal = lt_status_evt_fatal;
			general_best_priority = pcie_gen12_phy_pkg_error_priority(lt_status_evt_code);
		end
		if ((sym_misc_evt_ctrl && (sym_misc_payload_ctrl[39:32] != 8'h00)) && (!general_new_valid || (pcie_gen12_phy_pkg_error_priority(sym_misc_payload_ctrl[39:32]) < general_best_priority))) begin
			general_new_valid = 1'b1;
			general_new_source = 4'h5;
			general_new_code = sym_misc_payload_ctrl[39:32];
			general_new_info = sym_misc_payload_ctrl[31:0];
			general_new_fatal = pcie_gen12_phy_pkg_error_is_fatal(sym_misc_payload_ctrl[39:32]);
			general_best_priority = pcie_gen12_phy_pkg_error_priority(sym_misc_payload_ctrl[39:32]);
		end
		if (!general_new_valid && lt_status_evt_valid) begin
			general_new_valid = 1'b1;
			general_new_source = 4'h0;
			general_new_code = 8'h00;
			general_new_info = lt_status_evt_info;
			general_new_fatal = 1'b0;
		end
	end
	always @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni)
		if (!ctrl_local_rst_ni) begin
			general_evt_valid_q <= 1'b0;
			general_evt_source_q <= 4'h0;
			general_evt_code_q <= 8'h00;
			general_evt_info_q <= 32'd0;
			general_evt_fatal_q <= 1'b0;
		end
		else if (!general_evt_valid_q || status_evt_ready) begin
			general_evt_valid_q <= general_new_valid;
			if (general_new_valid) begin
				general_evt_source_q <= general_new_source;
				general_evt_code_q <= general_new_code;
				general_evt_info_q <= general_new_info;
				general_evt_fatal_q <= general_new_fatal;
			end
		end
	assign buffer_category_source_count_ctrl = {1'b0, sym_buffer_evt_ctrl} + {1'b0, link_buffer_evt_ctrl};
	assign framing_category_source_count_ctrl = ({1'b0, sym_framing_evt_ctrl} + {1'b0, link_framing_evt_ctrl}) + {1'b0, os_error_general_evt};
	assign category_collision_count_ctrl = (buffer_category_source_count_ctrl > 0 ? buffer_category_source_count_ctrl - 2'd1 : 2'd0) + (framing_category_source_count_ctrl > 0 ? framing_category_source_count_ctrl - 2'd1 : 2'd0);
	assign general_collision_count_ctrl = (general_new_count > 1 ? general_new_count - 3'd1 : 3'd0);
	assign general_queue_drop_ctrl = (general_new_valid && general_evt_valid_q) && !status_evt_ready;
	always @(*) begin
		if (_sv2v_0)
			;
		overflow_arrival_count_ctrl = (((((((((((({4'd0, cdc_overflow_evt_ctrl[0]} + {4'd0, cdc_overflow_evt_ctrl[1]}) + {4'd0, cdc_overflow_evt_ctrl[2]}) + {4'd0, cdc_overflow_evt_ctrl[3]}) + {4'd0, cdc_overflow_evt_ctrl[4]}) + {4'd0, cdc_overflow_evt_ctrl[5]}) + {4'd0, cdc_overflow_evt_ctrl[6]}) + {4'd0, cdc_overflow_evt_ctrl[7]}) + {4'd0, cdc_overflow_evt_ctrl[8]}) + {4'd0, cdc_overflow_evt_ctrl[9]}) + {4'd0, lt_packet_drop_cdc_overflow}) + {3'd0, category_collision_count_ctrl}) + {2'd0, general_collision_count_ctrl}) + {4'd0, general_queue_drop_ctrl};
	end
	assign cdc_overflow_emit_ctrl = ((overflow_pending_count_q != {8 {1'sb0}}) && !sym_buffer_evt_ctrl) && !link_buffer_evt_ctrl;
	always @(*) begin
		if (_sv2v_0)
			;
		overflow_pending_after_emit = overflow_pending_count_q;
		if (cdc_overflow_emit_ctrl)
			overflow_pending_after_emit = overflow_pending_count_q - 1'b1;
		overflow_pending_sum = {1'b0, overflow_pending_after_emit} + {{4 {1'b0}}, overflow_arrival_count_ctrl};
		if (overflow_pending_sum[OVERFLOW_PENDING_COUNT_WIDTH])
			overflow_pending_count_next = 1'sb1;
		else
			overflow_pending_count_next = overflow_pending_sum[7:0];
	end
	always @(posedge ctrl_clk_i or negedge ctrl_local_rst_ni)
		if (!ctrl_local_rst_ni)
			overflow_pending_count_q <= 1'sb0;
		else
			overflow_pending_count_q <= overflow_pending_count_next;
	reg status_buffer_evt_valid;
	reg [7:0] status_buffer_evt_code;
	reg [31:0] status_buffer_evt_info;
	reg status_framing_evt_valid;
	reg [7:0] status_framing_evt_code;
	reg [31:0] status_framing_evt_info;
	always @(*) begin
		if (_sv2v_0)
			;
		status_buffer_evt_valid = 1'b0;
		status_buffer_evt_code = 8'h00;
		status_buffer_evt_info = 32'd0;
		if (sym_buffer_evt_ctrl) begin
			status_buffer_evt_valid = 1'b1;
			status_buffer_evt_code = sym_buffer_payload_ctrl[39:32];
			status_buffer_evt_info = sym_buffer_payload_ctrl[31:0];
		end
		else if (link_buffer_evt_ctrl) begin
			status_buffer_evt_valid = 1'b1;
			status_buffer_evt_code = link_buffer_payload_ctrl[39:32];
			status_buffer_evt_info = link_buffer_payload_ctrl[31:0];
		end
		else if (cdc_overflow_emit_ctrl) begin
			status_buffer_evt_valid = 1'b1;
			status_buffer_evt_code = 8'h12;
			status_buffer_evt_info = {lt_state, lt_substate, retry_count, timer_expired_id, overflow_pending_count_q[5:0]};
		end
		status_framing_evt_valid = 1'b0;
		status_framing_evt_code = 8'h00;
		status_framing_evt_info = 32'd0;
		if (sym_framing_evt_ctrl) begin
			status_framing_evt_valid = 1'b1;
			status_framing_evt_code = sym_framing_payload_ctrl[39:32];
			status_framing_evt_info = sym_framing_payload_ctrl[31:0];
		end
		else if (link_framing_evt_ctrl) begin
			status_framing_evt_valid = 1'b1;
			status_framing_evt_code = link_framing_payload_ctrl[39:32];
			status_framing_evt_info = link_framing_payload_ctrl[31:0];
		end
		else if (os_error_general_evt) begin
			status_framing_evt_valid = 1'b1;
			status_framing_evt_code = 8'h04;
			status_framing_evt_info = {os_rx_error_ctrl_payload, os_rx_fields_ctrl[30-:8], os_rx_fields_ctrl[17-:8], os_rx_fields_ctrl[9-:2], os_rx_fields_ctrl[22-:5], 1'b0};
		end
	end
	localparam [4:0] sv2v_uu_u_phy_status_error_ext_status_debug_counter_seed_index_i_0 = 1'sb0;
	localparam [31:0] sv2v_uu_u_phy_status_error_ext_status_debug_counter_seed_value_i_0 = 1'sb0;
	phy_status_error u_phy_status_error(
		.ctrl_clk_i(ctrl_clk_i),
		.ctrl_rst_ni(ctrl_local_rst_ni),
		.port_reset_ni(1'b1),
		.link_clk_i(link_clk_i),
		.link_rst_ni(link_local_rst_ni),
		.status_ready_i(((((crr_ready && gt_ready) && gt_sym_rst_n) && gt_sym_clk_stable) && gt_buffer_reinit_done) && phy_sym_rst_no),
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
		.status_debug_counter_seed_index_i(sv2v_uu_u_phy_status_error_ext_status_debug_counter_seed_index_i_0),
		.status_debug_counter_seed_value_i(sv2v_uu_u_phy_status_error_ext_status_debug_counter_seed_value_i_0),
		.status_evt_valid_i(general_evt_valid_q),
		.status_evt_source_i(general_evt_source_q),
		.status_evt_code_i(general_evt_code_q),
		.status_evt_info_i(general_evt_info_q),
		.status_evt_fatal_i(general_evt_fatal_q),
		.status_evt_ready_o(status_evt_ready),
		.status_gt_fatal_evt_valid_i(crr_fault && pcie_gen12_phy_pkg_error_is_fatal(crr_fault_code)),
		.status_gt_fatal_evt_code_i(crr_fault_code),
		.status_gt_fatal_evt_info_i({8'd0, crr_fault_code, lt_state, lt_substate, crr_current_rate, crr_ready, 2'd0}),
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
	initial _sv2v_0 = 0;
endmodule

module phy_cdc_event_bus (
	s_clk_i,
	s_rst_ni,
	s_event_i,
	s_data_i,
	s_overflow_event_o,
	d_clk_i,
	d_rst_ni,
	d_event_o,
	d_data_o,
	d_overflow_event_o
);
	reg _sv2v_0;
	parameter [31:0] WIDTH = 1;
	parameter [31:0] OVERFLOW_COUNT_WIDTH = 8;
	input wire s_clk_i;
	input wire s_rst_ni;
	input wire s_event_i;
	input wire [WIDTH - 1:0] s_data_i;
	output reg s_overflow_event_o;
	input wire d_clk_i;
	input wire d_rst_ni;
	output reg d_event_o;
	output reg [WIDTH - 1:0] d_data_o;
	output reg d_overflow_event_o;
	reg [WIDTH - 1:0] s_data_hold_q;
	reg s_request_toggle_q;
	reg d_ack_toggle_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] d_ack_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] s_request_sync_q;
	wire s_busy;
	reg [OVERFLOW_COUNT_WIDTH - 1:0] s_overflow_bin_q;
	reg [OVERFLOW_COUNT_WIDTH - 1:0] s_overflow_gray_q;
	(* ASYNC_REG = "TRUE" *) reg [OVERFLOW_COUNT_WIDTH - 1:0] d_overflow_gray_meta_q;
	(* ASYNC_REG = "TRUE" *) reg [OVERFLOW_COUNT_WIDTH - 1:0] d_overflow_gray_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [OVERFLOW_COUNT_WIDTH - 1:0] d_overflow_gray_guard_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] d_source_reset_sync_q;
	reg [1:0] d_source_live_guard_q;
	wire [OVERFLOW_COUNT_WIDTH - 1:0] d_overflow_bin_sync;
	reg [OVERFLOW_COUNT_WIDTH - 1:0] d_overflow_seen_q;
	wire [OVERFLOW_COUNT_WIDTH - 1:0] d_overflow_delta;
	reg [OVERFLOW_COUNT_WIDTH:0] d_overflow_pending_q;
	reg [OVERFLOW_COUNT_WIDTH:0] d_overflow_pending_after_emit;
	reg [OVERFLOW_COUNT_WIDTH + 1:0] d_overflow_pending_sum;
	reg [OVERFLOW_COUNT_WIDTH:0] d_overflow_pending_next;
	function automatic [OVERFLOW_COUNT_WIDTH - 1:0] overflow_bin_to_gray;
		input reg [OVERFLOW_COUNT_WIDTH - 1:0] binary_value;
		overflow_bin_to_gray = (binary_value >> 1) ^ binary_value;
	endfunction
	function automatic [OVERFLOW_COUNT_WIDTH - 1:0] overflow_gray_to_bin;
		input reg [OVERFLOW_COUNT_WIDTH - 1:0] gray_value;
		reg [OVERFLOW_COUNT_WIDTH - 1:0] binary_value;
		integer bit_index;
		begin
			binary_value[OVERFLOW_COUNT_WIDTH - 1] = gray_value[OVERFLOW_COUNT_WIDTH - 1];
			for (bit_index = OVERFLOW_COUNT_WIDTH - 2; bit_index >= 0; bit_index = bit_index - 1)
				binary_value[bit_index] = binary_value[bit_index + 1] ^ gray_value[bit_index];
			overflow_gray_to_bin = binary_value;
		end
	endfunction
	assign s_busy = s_request_toggle_q != d_ack_sync_q[1];
	assign d_overflow_bin_sync = overflow_gray_to_bin(d_overflow_gray_guard_q);
	assign d_overflow_delta = d_overflow_bin_sync - d_overflow_seen_q;
	always @(*) begin
		if (_sv2v_0)
			;
		d_overflow_pending_after_emit = d_overflow_pending_q;
		if (d_overflow_pending_q != {(OVERFLOW_COUNT_WIDTH >= 0 ? OVERFLOW_COUNT_WIDTH + 1 : 1 - OVERFLOW_COUNT_WIDTH) {1'sb0}})
			d_overflow_pending_after_emit = d_overflow_pending_q - 1'b1;
		d_overflow_pending_sum = {1'b0, d_overflow_pending_after_emit} + {{2 {1'b0}}, d_overflow_delta};
		if (d_overflow_pending_sum[OVERFLOW_COUNT_WIDTH + 1])
			d_overflow_pending_next = 1'sb1;
		else
			d_overflow_pending_next = d_overflow_pending_sum[OVERFLOW_COUNT_WIDTH:0];
	end
	always @(posedge s_clk_i or negedge s_rst_ni)
		if (!s_rst_ni) begin
			s_data_hold_q <= 1'sb0;
			s_request_toggle_q <= 1'b0;
			d_ack_sync_q <= 2'b00;
			s_overflow_event_o <= 1'b0;
			s_overflow_bin_q <= 1'sb0;
			s_overflow_gray_q <= 1'sb0;
		end
		else begin
			d_ack_sync_q <= {d_ack_sync_q[0], d_ack_toggle_q};
			s_overflow_event_o <= 1'b0;
			if (s_event_i) begin
				if (!s_busy) begin
					s_data_hold_q <= s_data_i;
					s_request_toggle_q <= !s_request_toggle_q;
				end
				else begin
					s_overflow_event_o <= 1'b1;
					s_overflow_bin_q <= s_overflow_bin_q + 1'b1;
					s_overflow_gray_q <= overflow_bin_to_gray(s_overflow_bin_q + 1'b1);
				end
			end
		end
	always @(posedge d_clk_i or negedge d_rst_ni)
		if (!d_rst_ni) begin
			s_request_sync_q <= 2'b00;
			d_ack_toggle_q <= 1'b0;
			d_event_o <= 1'b0;
			d_data_o <= 1'sb0;
			d_overflow_gray_meta_q <= 1'sb0;
			d_overflow_gray_sync_q <= 1'sb0;
			d_overflow_gray_guard_q <= 1'sb0;
			d_source_reset_sync_q <= 2'b00;
			d_source_live_guard_q <= 2'b00;
			d_overflow_seen_q <= 1'sb0;
			d_overflow_pending_q <= 1'sb0;
			d_overflow_event_o <= 1'b0;
		end
		else begin
			s_request_sync_q <= {s_request_sync_q[0], s_request_toggle_q};
			d_event_o <= 1'b0;
			d_overflow_event_o <= 1'b0;
			d_source_reset_sync_q <= {d_source_reset_sync_q[0], s_rst_ni};
			d_source_live_guard_q <= {d_source_live_guard_q[0], d_source_reset_sync_q[1]};
			d_overflow_gray_meta_q <= s_overflow_gray_q;
			d_overflow_gray_sync_q <= d_overflow_gray_meta_q;
			d_overflow_gray_guard_q <= d_overflow_gray_sync_q;
			if (s_request_sync_q[1] != d_ack_toggle_q) begin
				d_data_o <= s_data_hold_q;
				d_event_o <= 1'b1;
				d_ack_toggle_q <= s_request_sync_q[1];
			end
			if (!d_source_reset_sync_q[1] || !(&d_source_live_guard_q)) begin
				d_overflow_seen_q <= d_overflow_bin_sync;
				d_overflow_pending_q <= 1'sb0;
			end
			else begin
				d_overflow_seen_q <= d_overflow_bin_sync;
				d_overflow_pending_q <= d_overflow_pending_next;
				d_overflow_event_o <= d_overflow_pending_q != {(OVERFLOW_COUNT_WIDTH >= 0 ? OVERFLOW_COUNT_WIDTH + 1 : 1 - OVERFLOW_COUNT_WIDTH) {1'sb0}};
			end
		end
	initial _sv2v_0 = 0;
endmodule

module phy_cdc_req_ack (
	s_clk_i,
	s_rst_ni,
	s_valid_i,
	s_ready_o,
	s_data_i,
	d_clk_i,
	d_rst_ni,
	d_valid_o,
	d_ready_i,
	d_data_o
);
	parameter [31:0] WIDTH = 1;
	input wire s_clk_i;
	input wire s_rst_ni;
	input wire s_valid_i;
	output wire s_ready_o;
	input wire [WIDTH - 1:0] s_data_i;
	input wire d_clk_i;
	input wire d_rst_ni;
	output reg d_valid_o;
	input wire d_ready_i;
	output reg [WIDTH - 1:0] d_data_o;
	reg [WIDTH - 1:0] s_data_hold_q;
	reg s_request_toggle_q;
	reg d_ack_toggle_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] d_ack_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] s_request_sync_q;
	assign s_ready_o = s_request_toggle_q == d_ack_sync_q[1];
	always @(posedge s_clk_i or negedge s_rst_ni)
		if (!s_rst_ni) begin
			s_data_hold_q <= 1'sb0;
			s_request_toggle_q <= 1'b0;
			d_ack_sync_q <= 2'b00;
		end
		else begin
			d_ack_sync_q <= {d_ack_sync_q[0], d_ack_toggle_q};
			if (s_valid_i && s_ready_o) begin
				s_data_hold_q <= s_data_i;
				s_request_toggle_q <= !s_request_toggle_q;
			end
		end
	always @(posedge d_clk_i or negedge d_rst_ni)
		if (!d_rst_ni) begin
			s_request_sync_q <= 2'b00;
			d_ack_toggle_q <= 1'b0;
			d_valid_o <= 1'b0;
			d_data_o <= 1'sb0;
		end
		else begin
			s_request_sync_q <= {s_request_sync_q[0], s_request_toggle_q};
			if (!d_valid_o && (s_request_sync_q[1] != d_ack_toggle_q)) begin
				d_data_o <= s_data_hold_q;
				d_valid_o <= 1'b1;
			end
			else if (d_valid_o && d_ready_i) begin
				d_valid_o <= 1'b0;
				d_ack_toggle_q <= s_request_sync_q[1];
			end
		end
endmodule

module phy_cdc_snapshot (
	s_clk_i,
	s_rst_ni,
	s_data_i,
	d_clk_i,
	d_rst_ni,
	d_data_o
);
	parameter [31:0] WIDTH = 1;
	parameter [WIDTH - 1:0] RESET_VALUE = 1'sb0;
	input wire s_clk_i;
	input wire s_rst_ni;
	input wire [WIDTH - 1:0] s_data_i;
	input wire d_clk_i;
	input wire d_rst_ni;
	output reg [WIDTH - 1:0] d_data_o;
	reg [WIDTH - 1:0] s_data_hold_q;
	reg [WIDTH - 1:0] s_last_sent_q;
	reg s_request_toggle_q;
	reg d_ack_toggle_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] d_ack_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] s_request_sync_q;
	wire s_idle;
	assign s_idle = s_request_toggle_q == d_ack_sync_q[1];
	always @(posedge s_clk_i or negedge s_rst_ni)
		if (!s_rst_ni) begin
			s_data_hold_q <= RESET_VALUE;
			s_last_sent_q <= RESET_VALUE;
			s_request_toggle_q <= 1'b0;
			d_ack_sync_q <= 2'b00;
		end
		else begin
			d_ack_sync_q <= {d_ack_sync_q[0], d_ack_toggle_q};
			if (s_idle && (s_data_i != s_last_sent_q)) begin
				s_data_hold_q <= s_data_i;
				s_last_sent_q <= s_data_i;
				s_request_toggle_q <= !s_request_toggle_q;
			end
		end
	always @(posedge d_clk_i or negedge d_rst_ni)
		if (!d_rst_ni) begin
			s_request_sync_q <= 2'b00;
			d_ack_toggle_q <= 1'b0;
			d_data_o <= RESET_VALUE;
		end
		else begin
			s_request_sync_q <= {s_request_sync_q[0], s_request_toggle_q};
			if (s_request_sync_q[1] != d_ack_toggle_q) begin
				d_data_o <= s_data_hold_q;
				d_ack_toggle_q <= s_request_sync_q[1];
			end
		end
endmodule
