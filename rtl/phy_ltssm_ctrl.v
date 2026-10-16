`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_ltssm_ctrl (
	ctrl_clk_i,
	ctrl_rst_ni,
	port_reset_ni,
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
	crr_ready_i,
	crr_current_rate_i,
	crr_detect_done_i,
	crr_receiver_present_i,
	crr_rate_done_i,
	crr_rate_fail_i,
	crr_power_done_i,
	crr_power_fail_i,
	crr_tx_electrical_idle_active_i,
	crr_rx_electrical_idle_i,
	crr_rx_aligned_i,
	crr_fault_i,
	crr_fault_code_i,
	os_tx_req_ready_i,
	os_tx_done_i,
	tx_logical_idle_qualified_evt_i,
	os_rx_ts1_qualified_evt_i,
	os_rx_ts2_qualified_evt_i,
	os_rx_fts_evt_i,
	os_rx_skp_evt_i,
	os_rx_eios_evt_i,
	os_rx_eieos_evt_i,
	rx_logical_idle_qualified_evt_i,
	os_rx_hot_reset_evt_i,
	os_rx_loopback_evt_i,
	os_rx_speed_change_evt_i,
	os_rx_fields_i,
	os_rx_error_i,
	tx_quiesced_i,
	rx_packet_active_i,
	rx_align_loss_evt_i,
	rx_frame_error_evt_i,
	rx_buffer_fault_evt_i,
	datapath_recovery_req_i,
	timer_expired_i,
	timer_id_i,
	retry_count_i,
	lt_gt_detect_req_o,
	lt_gt_rate_req_o,
	lt_gt_rate_target_gen2_o,
	lt_gt_power_req_o,
	lt_gt_power_state_o,
	lt_gt_tx_electrical_idle_o,
	lt_gt_rx_polarity_invert_o,
	lt_gt_tx_deemphasis_o,
	lt_gt_tx_swing_o,
	lt_gt_tx_margin_o,
	lt_gt_compliance_enable_o,
	lt_gt_loopback_mode_o,
	lt_os_req_valid_o,
	lt_os_kind_o,
	lt_os_fields_o,
	lt_os_repeat_mode_o,
	lt_tx_mode_o,
	lt_packet_enable_o,
	lt_packet_flush_o,
	lt_packet_drop_o,
	timer_start_o,
	timer_stop_o,
	timer_id_o,
	timer_limit_o,
	retry_update_o,
	retry_clear_o,
	lt_state_o,
	lt_substate_o,
	lt_entry_reason_o,
	lt_link_up_o,
	lt_data_active_o,
	lt_current_rate_o,
	lt_target_rate_o,
	lt_clear_error_o,
	lt_status_evt_valid_o,
	lt_status_evt_code_o,
	lt_status_evt_info_o,
	lt_status_evt_fatal_o
);
	reg _sv2v_0;
	localparam [31:0] pcie_gen12_phy_timing_pkg_SIM_TIME_SCALE = 1;
	parameter [31:0] SIM_TIME_SCALE = pcie_gen12_phy_timing_pkg_SIM_TIME_SCALE;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	input wire port_reset_ni;
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
	input wire crr_ready_i;
	input wire crr_current_rate_i;
	input wire crr_detect_done_i;
	input wire crr_receiver_present_i;
	input wire crr_rate_done_i;
	input wire crr_rate_fail_i;
	input wire crr_power_done_i;
	input wire crr_power_fail_i;
	input wire crr_tx_electrical_idle_active_i;
	input wire crr_rx_electrical_idle_i;
	input wire crr_rx_aligned_i;
	input wire crr_fault_i;
	input wire [7:0] crr_fault_code_i;
	input wire os_tx_req_ready_i;
	input wire os_tx_done_i;
	input wire tx_logical_idle_qualified_evt_i;
	input wire os_rx_ts1_qualified_evt_i;
	input wire os_rx_ts2_qualified_evt_i;
	input wire os_rx_fts_evt_i;
	input wire os_rx_skp_evt_i;
	input wire os_rx_eios_evt_i;
	input wire os_rx_eieos_evt_i;
	input wire rx_logical_idle_qualified_evt_i;
	input wire os_rx_hot_reset_evt_i;
	input wire os_rx_loopback_evt_i;
	input wire os_rx_speed_change_evt_i;
	input wire [34:0] os_rx_fields_i;
	input wire [7:0] os_rx_error_i;
	input wire tx_quiesced_i;
	input wire rx_packet_active_i;
	input wire rx_align_loss_evt_i;
	input wire rx_frame_error_evt_i;
	input wire rx_buffer_fault_evt_i;
	input wire datapath_recovery_req_i;
	input wire timer_expired_i;
	input wire [5:0] timer_id_i;
	input wire [7:0] retry_count_i;
	output reg lt_gt_detect_req_o;
	output reg lt_gt_rate_req_o;
	output reg lt_gt_rate_target_gen2_o;
	output reg lt_gt_power_req_o;
	output reg [1:0] lt_gt_power_state_o;
	output reg lt_gt_tx_electrical_idle_o;
	output reg lt_gt_rx_polarity_invert_o;
	output reg lt_gt_tx_deemphasis_o;
	output reg lt_gt_tx_swing_o;
	output reg [2:0] lt_gt_tx_margin_o;
	output reg lt_gt_compliance_enable_o;
	output reg [2:0] lt_gt_loopback_mode_o;
	output reg lt_os_req_valid_o;
	output reg [2:0] lt_os_kind_o;
	output reg [34:0] lt_os_fields_o;
	output reg [2:0] lt_os_repeat_mode_o;
	output reg [3:0] lt_tx_mode_o;
	output reg lt_packet_enable_o;
	output reg lt_packet_flush_o;
	output reg lt_packet_drop_o;
	output reg timer_start_o;
	output reg timer_stop_o;
	output reg [5:0] timer_id_o;
	output reg [31:0] timer_limit_o;
	output reg retry_update_o;
	output reg retry_clear_o;
	output wire [5:0] lt_state_o;
	output wire [5:0] lt_substate_o;
	output wire [7:0] lt_entry_reason_o;
	output wire lt_link_up_o;
	output reg lt_data_active_o;
	output wire lt_current_rate_o;
	output wire lt_target_rate_o;
	output reg lt_clear_error_o;
	output reg lt_status_evt_valid_o;
	output reg [7:0] lt_status_evt_code_o;
	output reg [31:0] lt_status_evt_info_o;
	output reg lt_status_evt_fatal_o;
	wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;
	reg [5:0] state_q;
	reg [5:0] state_d;
	reg [5:0] substate_q;
	reg [5:0] substate_d;
	reg [7:0] reason_q;
	reg [7:0] reason_d;
	reg [34:0] peer_fields_q;
	reg [34:0] peer_fields_d;
	reg [34:0] tx_fields_q;
	reg [34:0] tx_fields_d;
	reg [1:0] speed_phase_q;
	reg [1:0] speed_phase_d;
	reg [1:0] pm_phase_q;
	reg [1:0] pm_phase_d;
	reg enable_latched_q;
	reg enable_latched_d;
	reg target_rate_q;
	reg target_rate_d;
	reg peer_gen2_capable_q;
	reg peer_gen2_capable_d;
	reg link_context_q;
	reg link_context_d;
	reg recovery_fallback_q;
	reg recovery_fallback_d;
	reg [1:0] pm_policy_q;
	reg [1:0] pm_policy_d;
	reg [2:0] protocol_loopback_mode_q;
	reg [2:0] protocol_loopback_mode_d;
	reg local_train_done_q;
	reg local_train_done_d;
	reg remote_train_done_q;
	reg remote_train_done_d;
	reg local_idle_done_q;
	reg local_idle_done_d;
	reg remote_idle_done_q;
	reg remote_idle_done_d;
	reg low_power_entered_q;
	reg low_power_entered_d;
	reg disabled_hold_done_q;
	reg disabled_hold_done_d;
	reg cmd_pending_q;
	reg cmd_pending_d;
	reg cmd_started_q;
	reg cmd_started_d;
	reg [3:0] cmd_opcode_q;
	reg [3:0] cmd_opcode_d;
	reg [7:0] cmd_arg_q;
	reg [7:0] cmd_arg_d;
	reg mgmt_rsp_valid_q;
	reg mgmt_rsp_valid_d;
	reg [3:0] mgmt_rsp_status_q;
	reg [3:0] mgmt_rsp_status_d;
	reg pm_pending_q;
	reg pm_pending_d;
	reg pm_started_q;
	reg pm_started_d;
	reg [1:0] pm_state_q;
	reg [1:0] pm_state_d;
	reg pm_exit_q;
	reg pm_exit_d;
	reg pm_rsp_valid_q;
	reg pm_rsp_valid_d;
	reg pm_rsp_success_q;
	reg pm_rsp_success_d;
	reg timer_restart;
	reg fsm_error_valid;
	reg [7:0] fsm_error_code;
	reg [31:0] fsm_error_info;
	reg fsm_error_fatal;
	reg fsm_timeout;
	reg fsm_failed;
	reg transition;
	reg [5:0] current_timer_id;
	reg [5:0] next_timer_id;
	function automatic [5:0] state_timer_id;
		input reg [5:0] state;
		input reg [5:0] substate;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			(* full_case, parallel_case *)
			case (state)
				6'h01: begin
					if (substate == 6'h01) begin
						state_timer_id = 6'h01;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						state_timer_id = 6'h02;
						_sv2v_jump = 2'b11;
					end
				end
				6'h02: begin
					if (substate == 6'h03) begin
						state_timer_id = 6'h03;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						if (substate == 6'h05) begin
							state_timer_id = 6'h04;
							_sv2v_jump = 2'b11;
						end
						if (_sv2v_jump == 2'b00) begin
							state_timer_id = 6'h00;
							_sv2v_jump = 2'b11;
						end
					end
				end
				6'h03: begin
					state_timer_id = 6'h05;
					_sv2v_jump = 2'b11;
				end
				6'h05:
					(* full_case, parallel_case *)
					case (substate)
						6'h0d: begin
							state_timer_id = 6'h06;
							_sv2v_jump = 2'b11;
						end
						6'h0e: begin
							state_timer_id = 6'h07;
							_sv2v_jump = 2'b11;
						end
						6'h0f: begin
							state_timer_id = 6'h08;
							_sv2v_jump = 2'b11;
						end
						default: begin
							state_timer_id = 6'h09;
							_sv2v_jump = 2'b11;
						end
					endcase
				6'h06: begin
					if ((substate == 6'h12) || (substate == 6'h15)) begin
						state_timer_id = 6'h00;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						state_timer_id = 6'h0a;
						_sv2v_jump = 2'b11;
					end
				end
				6'h07: begin
					if (substate == 6'h17) begin
						state_timer_id = 6'h0b;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						if (substate == 6'h19) begin
							state_timer_id = 6'h0c;
							_sv2v_jump = 2'b11;
						end
						if (_sv2v_jump == 2'b00) begin
							state_timer_id = 6'h00;
							_sv2v_jump = 2'b11;
						end
					end
				end
				6'h08: begin
					if (substate == 6'h1b) begin
						state_timer_id = 6'h0d;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						state_timer_id = 6'h00;
						_sv2v_jump = 2'b11;
					end
				end
				6'h09: begin
					state_timer_id = 6'h11;
					_sv2v_jump = 2'b11;
				end
				6'h0a: begin
					if (substate == 6'h1d) begin
						state_timer_id = 6'h0f;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						if (substate == 6'h1f) begin
							state_timer_id = 6'h10;
							_sv2v_jump = 2'b11;
						end
						if (_sv2v_jump == 2'b00) begin
							state_timer_id = 6'h00;
							_sv2v_jump = 2'b11;
						end
					end
				end
				6'h0b: begin
					state_timer_id = 6'h0e;
					_sv2v_jump = 2'b11;
				end
				default: begin
					state_timer_id = 6'h00;
					_sv2v_jump = 2'b11;
				end
			endcase
		end
	endfunction
	function automatic timer_matches_current;
		input reg expired;
		input reg [5:0] expired_id;
		input reg [5:0] expected_id;
		timer_matches_current = (expired && (expected_id != 6'h00)) && (expired_id == expected_id);
	endfunction
	function automatic x1_training_fields_valid;
		input reg [34:0] fields;
		x1_training_fields_valid = fields[34] && (fields[31] || (fields[22-:5] == 5'd0));
	endfunction
	assign mgmt_cmd_ready_o = ((!cmd_pending_q && !mgmt_rsp_valid_q) && !pm_pending_q) && !pm_rsp_valid_q;
	assign mgmt_rsp_valid_o = mgmt_rsp_valid_q;
	assign mgmt_rsp_status_o = mgmt_rsp_status_q;
	assign port_pm_req_ready_o = ((!pm_pending_q && !pm_rsp_valid_q) && !cmd_pending_q) && !mgmt_rsp_valid_q;
	assign port_pm_done_o = pm_rsp_valid_q && pm_rsp_success_q;
	assign port_pm_fail_o = pm_rsp_valid_q && !pm_rsp_success_q;
	assign lt_state_o = state_q;
	assign lt_substate_o = substate_q;
	assign lt_entry_reason_o = reason_q;
	assign lt_current_rate_o = crr_current_rate_i;
	assign lt_target_rate_o = target_rate_q;
	assign lt_link_up_o = (link_context_q && !recovery_fallback_q) && ((((state_q == 6'h04) || (state_q == 6'h06)) || (state_q == 6'h07)) || (state_q == 6'h05));
	localparam [2:0] pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_DISABLE = 3'b000;
	localparam [2:0] pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_FAR = 3'b010;
	localparam [2:0] pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_NEAR = 3'b001;
	localparam [1:0] pcie_gen12_phy_pkg_RATE_ID_GEN2_SUPPORTED = 2'b10;
	localparam [7:0] pcie_gen12_phy_pkg_TS_CTRL_DISABLE_LINK = 8'h02;
	localparam [7:0] pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET = 8'h01;
	localparam [7:0] pcie_gen12_phy_pkg_TS_CTRL_LOOPBACK = 8'h04;
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
	function automatic pcie_gen12_phy_pkg_is_ts_training_ctrl_set;
		input reg [7:0] training_ctrl;
		input reg [7:0] mask;
		pcie_gen12_phy_pkg_is_ts_training_ctrl_set = (training_ctrl & mask) == mask;
	endfunction
	localparam [31:0] pcie_gen12_phy_timing_pkg_DETECT_RETRY_MAX = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_LTSSM_RETRY_MAX = 3;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RATE_RETRY_MAX = 2;
	localparam [31:0] pcie_gen12_phy_timing_pkg_CONFIGURATION_TIMEOUT_US = 48000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_DETECT_ACTIVE_TIMEOUT_US = 12000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_DETECT_QUIET_MIN_US = 12000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_DISABLED_MIN_HOLD_US = 2000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_DETECT_TIMEOUT_US = 12000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_POWER_TIMEOUT_US = 48000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_RATE_TIMEOUT_US = 1000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_RESET_TIMEOUT_US = 48000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_HOT_RESET_MIN_HOLD_US = 2000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_L0S_EXIT_TIMEOUT_US = 2000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_L1_ENTRY_TIMEOUT_US = 24000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_L1_EXIT_TIMEOUT_US = 48000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_L2_READY_TIMEOUT_US = 48000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_LOOPBACK_ENTRY_TIMEOUT_US = 24000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_LOOPBACK_EXIT_TIMEOUT_US = 24000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_POLLING_ACTIVE_TIMEOUT_US = 24000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_POLLING_CONFIG_TIMEOUT_US = 48000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RECOVERY_IDLE_TIMEOUT_US = 2000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RECOVERY_RCVRCFG_TIMEOUT_US = 48000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RECOVERY_RCVRLOCK_TIMEOUT_US = 24000;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RECOVERY_SPEED_TIMEOUT_US = 1000;
	function automatic [31:0] pcie_gen12_phy_timing_pkg_sim_scaled_cycles;
		input reg [31:0] base_cycles;
		input reg [31:0] sim_scale;
`ifdef SYNTHESIS
		pcie_gen12_phy_timing_pkg_sim_scaled_cycles = base_cycles;
`else
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if (sim_scale <= 1) begin
				pcie_gen12_phy_timing_pkg_sim_scaled_cycles = base_cycles;
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				pcie_gen12_phy_timing_pkg_sim_scaled_cycles = ((base_cycles + sim_scale) - 1) / sim_scale;
				_sv2v_jump = 2'b11;
			end
		end
`endif
	endfunction
	localparam [31:0] pcie_gen12_phy_timing_pkg_CTRL_CLK_HZ = 100000000;
	function automatic signed [63:0] sv2v_cast_64_signed;
		input reg signed [63:0] inp;
		sv2v_cast_64_signed = inp;
	endfunction
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic [31:0] pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles;
		input reg [31:0] usec_value;
		reg [63:0] product;
		begin
			product = sv2v_cast_64_signed(pcie_gen12_phy_timing_pkg_CTRL_CLK_HZ) * sv2v_cast_64_signed(usec_value);
			pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles = sv2v_cast_32_signed((product + 999999) / 1000000);
		end
	endfunction
	function automatic [31:0] pcie_gen12_phy_timing_pkg_timer_default_cycles;
		input reg [5:0] id;
		input reg [31:0] sim_scale;
		reg [31:0] cycles;
		begin
			(* full_case, parallel_case *)
			case (id)
				6'h01: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_DETECT_QUIET_MIN_US);
				6'h02: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_DETECT_ACTIVE_TIMEOUT_US);
				6'h03: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_POLLING_ACTIVE_TIMEOUT_US);
				6'h04: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_POLLING_CONFIG_TIMEOUT_US);
				6'h05: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_CONFIGURATION_TIMEOUT_US);
				6'h06: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_RECOVERY_RCVRLOCK_TIMEOUT_US);
				6'h07: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_RECOVERY_RCVRCFG_TIMEOUT_US);
				6'h08: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_RECOVERY_SPEED_TIMEOUT_US);
				6'h09: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_RECOVERY_IDLE_TIMEOUT_US);
				6'h0a: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_L0S_EXIT_TIMEOUT_US);
				6'h0b: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_L1_ENTRY_TIMEOUT_US);
				6'h0c: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_L1_EXIT_TIMEOUT_US);
				6'h0d: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_L2_READY_TIMEOUT_US);
				6'h0e: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_HOT_RESET_MIN_HOLD_US);
				6'h0f: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_LOOPBACK_ENTRY_TIMEOUT_US);
				6'h10: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_LOOPBACK_EXIT_TIMEOUT_US);
				6'h11: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_DISABLED_MIN_HOLD_US);
				6'h12: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_GT_RESET_TIMEOUT_US);
				6'h13: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_GT_DETECT_TIMEOUT_US);
				6'h14: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_GT_RATE_TIMEOUT_US);
				6'h15: cycles = pcie_gen12_phy_timing_pkg_usec_to_ctrl_cycles(pcie_gen12_phy_timing_pkg_GT_POWER_TIMEOUT_US);
				default: cycles = 1;
			endcase
			pcie_gen12_phy_timing_pkg_timer_default_cycles = pcie_gen12_phy_timing_pkg_sim_scaled_cycles(cycles, sim_scale);
		end
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		state_d = state_q;
		substate_d = substate_q;
		reason_d = reason_q;
		peer_fields_d = peer_fields_q;
		tx_fields_d = tx_fields_q;
		speed_phase_d = speed_phase_q;
		pm_phase_d = pm_phase_q;
		enable_latched_d = enable_latched_q;
		target_rate_d = target_rate_q;
		peer_gen2_capable_d = peer_gen2_capable_q;
		link_context_d = link_context_q;
		recovery_fallback_d = recovery_fallback_q;
		pm_policy_d = pm_policy_q;
		protocol_loopback_mode_d = protocol_loopback_mode_q;
		local_train_done_d = local_train_done_q;
		remote_train_done_d = remote_train_done_q;
		local_idle_done_d = local_idle_done_q;
		remote_idle_done_d = remote_idle_done_q;
		low_power_entered_d = low_power_entered_q;
		disabled_hold_done_d = disabled_hold_done_q;
		cmd_pending_d = cmd_pending_q;
		cmd_started_d = cmd_started_q;
		cmd_opcode_d = cmd_opcode_q;
		cmd_arg_d = cmd_arg_q;
		mgmt_rsp_valid_d = mgmt_rsp_valid_q;
		mgmt_rsp_status_d = mgmt_rsp_status_q;
		pm_pending_d = pm_pending_q;
		pm_started_d = pm_started_q;
		pm_state_d = pm_state_q;
		pm_exit_d = pm_exit_q;
		pm_rsp_valid_d = pm_rsp_valid_q;
		pm_rsp_success_d = pm_rsp_success_q;
		lt_gt_detect_req_o = 1'b0;
		lt_gt_rate_req_o = 1'b0;
		lt_gt_rate_target_gen2_o = target_rate_q;
		lt_gt_power_req_o = 1'b0;
		lt_gt_power_state_o = 2'b00;
		lt_gt_tx_electrical_idle_o = 1'b0;
		lt_gt_rx_polarity_invert_o = 1'b0;
		lt_gt_tx_deemphasis_o = 1'b0;
		lt_gt_tx_swing_o = 1'b0;
		lt_gt_tx_margin_o = 1'sb0;
		lt_gt_compliance_enable_o = 1'b0;
		lt_gt_loopback_mode_o = 1'sb0;
		lt_os_req_valid_o = 1'b0;
		lt_os_kind_o = 3'h7;
		lt_os_fields_o = tx_fields_q;
		lt_os_repeat_mode_o = 3'd0;
		lt_tx_mode_o = 4'h0;
		lt_packet_flush_o = 1'b0;
		lt_packet_drop_o = 1'b0;
		lt_clear_error_o = 1'b0;
		retry_update_o = 1'b0;
		retry_clear_o = 1'b0;
		timer_restart = 1'b0;
		fsm_error_valid = 1'b0;
		fsm_error_code = 8'h00;
		fsm_error_info = {state_q, substate_q, timer_id_i, retry_count_i, 6'd0};
		fsm_error_fatal = 1'b0;
		fsm_timeout = 1'b0;
		fsm_failed = 1'b0;
		if (mgmt_rsp_valid_q && mgmt_rsp_ready_i)
			mgmt_rsp_valid_d = 1'b0;
		if (pm_rsp_valid_q && port_pm_rsp_ready_i)
			pm_rsp_valid_d = 1'b0;
		if (mgmt_cmd_valid_i && mgmt_cmd_ready_o) begin
			cmd_pending_d = 1'b1;
			cmd_started_d = 1'b0;
			cmd_opcode_d = mgmt_cmd_opcode_i;
			cmd_arg_d = mgmt_cmd_arg_i;
		end
		if (port_pm_req_valid_i && port_pm_req_ready_o) begin
			pm_pending_d = 1'b1;
			pm_started_d = 1'b0;
			pm_state_d = port_pm_req_state_i;
			pm_exit_d = port_pm_req_exit_i;
		end
		if (os_rx_fields_i[34] && (os_rx_ts1_qualified_evt_i || os_rx_ts2_qualified_evt_i)) begin
			peer_fields_d = os_rx_fields_i;
			peer_gen2_capable_d = |(os_rx_fields_i[9-:2] & pcie_gen12_phy_pkg_RATE_ID_GEN2_SUPPORTED);
			tx_fields_d[17-:8] = os_rx_fields_i[17-:8];
		end
		current_timer_id = state_timer_id(state_q, substate_q);
		(* full_case, parallel_case *)
		case (state_q)
			6'h00: begin
				lt_tx_mode_o = 4'h0;
				lt_gt_tx_electrical_idle_o = 1'b1;
				if (substate_q != 6'h00) begin
					substate_d = 6'h00;
					reason_d = 8'h12;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
				end
				else if (crr_ready_i && enable_latched_q) begin
					state_d = 6'h01;
					substate_d = 6'h01;
					reason_d = 8'h01;
					recovery_fallback_d = 1'b0;
					retry_clear_o = 1'b1;
				end
			end
			6'h01: begin
				lt_tx_mode_o = 4'h0;
				lt_gt_tx_electrical_idle_o = 1'b1;
				link_context_d = 1'b0;
				recovery_fallback_d = 1'b0;
				if (substate_q == 6'h01) begin
					if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
						state_d = 6'h01;
						substate_d = 6'h02;
						reason_d = 8'h02;
					end
				end
				else if (substate_q == 6'h02) begin
					lt_gt_detect_req_o = 1'b1;
					if (crr_detect_done_i) begin
						if (crr_receiver_present_i) begin
							state_d = 6'h02;
							substate_d = 6'h03;
							reason_d = 8'h03;
							retry_clear_o = 1'b1;
						end
						else if ((retry_count_i + 1'b1) < pcie_gen12_phy_timing_pkg_DETECT_RETRY_MAX) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h04;
							retry_update_o = 1'b1;
						end
						else begin
							state_d = 6'h09;
							substate_d = 6'h1c;
							reason_d = 8'h14;
							retry_clear_o = 1'b1;
							fsm_failed = 1'b1;
						end
					end
					else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h0a;
						fsm_timeout = 1'b1;
						if ((retry_count_i + 1'b1) < pcie_gen12_phy_timing_pkg_DETECT_RETRY_MAX) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h02;
							retry_update_o = 1'b1;
						end
						else begin
							state_d = 6'h09;
							substate_d = 6'h1c;
							reason_d = 8'h14;
							retry_clear_o = 1'b1;
						end
					end
				end
				else begin
					state_d = 6'h01;
					substate_d = 6'h01;
					reason_d = 8'h12;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
				end
			end
			6'h02: begin
				link_context_d = 1'b0;
				(* full_case, parallel_case *)
				case (substate_q)
					6'h03: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd5;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i);
						if ((local_train_done_q || os_tx_done_i) && (remote_train_done_q || (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i))) begin
							state_d = 6'h02;
							substate_d = 6'h05;
							reason_d = 8'h05;
						end
						else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h02;
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h09;
							fsm_timeout = 1'b1;
							retry_update_o = 1'b1;
						end
					end
					6'h05: begin
						lt_tx_mode_o = 4'h3;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h1;
						lt_os_repeat_mode_o = 3'd4;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
						if (((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts2_qualified_evt_i)) && x1_training_fields_valid(peer_fields_d)) begin
							state_d = 6'h03;
							substate_d = 6'h06;
							reason_d = 8'h06;
						end
						else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h02;
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h09;
							fsm_timeout = 1'b1;
						end
					end
					6'h04: begin
						lt_tx_mode_o = 4'h8;
						lt_gt_compliance_enable_o = 1'b1;
						lt_gt_tx_electrical_idle_o = 1'b0;
					end
					default: begin
						state_d = 6'h01;
						substate_d = 6'h01;
						reason_d = 8'h12;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
			end
			6'h03: begin
				(* full_case, parallel_case *)
				case (substate_q)
					6'h06: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd3;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
						if (((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts1_qualified_evt_i)) && x1_training_fields_valid(peer_fields_d)) begin
							substate_d = 6'h07;
							reason_d = 8'h05;
						end
					end
					6'h07: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd3;
						tx_fields_d[32] = 1'b0;
						tx_fields_d[30-:8] = peer_fields_q[30-:8];
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
						if (((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts1_qualified_evt_i)) && x1_training_fields_valid(peer_fields_d)) begin
							substate_d = 6'h08;
							reason_d = 8'h05;
						end
					end
					6'h08: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd3;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
						if (((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts1_qualified_evt_i)) && x1_training_fields_valid(peer_fields_d)) begin
							substate_d = 6'h09;
							reason_d = 8'h05;
						end
					end
					6'h09: begin
						lt_tx_mode_o = 4'h3;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h1;
						lt_os_repeat_mode_o = 3'd3;
						tx_fields_d[31] = 1'b0;
						tx_fields_d[22-:5] = 5'd0;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
						if (((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts2_qualified_evt_i)) && x1_training_fields_valid(peer_fields_d)) begin
							substate_d = 6'h0a;
							reason_d = 8'h06;
						end
					end
					6'h0a: begin
						lt_tx_mode_o = 4'h3;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h1;
						lt_os_repeat_mode_o = 3'd4;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
						if (((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts2_qualified_evt_i)) && x1_training_fields_valid(peer_fields_d)) begin
							substate_d = 6'h0b;
							reason_d = 8'h06;
						end
					end
					6'h0b: begin
						lt_tx_mode_o = 4'h1;
						local_idle_done_d = local_idle_done_q || tx_logical_idle_qualified_evt_i;
						remote_idle_done_d = remote_idle_done_q || rx_logical_idle_qualified_evt_i;
						if ((((local_idle_done_q || tx_logical_idle_qualified_evt_i) && (remote_idle_done_q || rx_logical_idle_qualified_evt_i)) && crr_rx_aligned_i) && crr_ready_i) begin
							state_d = 6'h04;
							substate_d = 6'h0c;
							reason_d = 8'h07;
							link_context_d = 1'b1;
							recovery_fallback_d = 1'b0;
							target_rate_d = peer_gen2_capable_q;
							retry_clear_o = 1'b1;
						end
					end
					default: begin
						state_d = 6'h01;
						substate_d = 6'h01;
						reason_d = 8'h12;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
				if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) && (substate_d == substate_q)) begin
					state_d = 6'h01;
					substate_d = 6'h01;
					reason_d = 8'h02;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
					fsm_timeout = 1'b1;
				end
			end
			6'h04: begin
				lt_tx_mode_o = 4'h9;
				if (os_rx_hot_reset_evt_i) begin
					state_d = 6'h0b;
					substate_d = 6'h20;
					reason_d = 8'h0f;
					link_context_d = 1'b0;
				end
				else if (os_rx_loopback_evt_i) begin
					state_d = 6'h0a;
					substate_d = 6'h1d;
					reason_d = 8'h10;
					link_context_d = 1'b0;
				end
				else if (pcie_gen12_phy_pkg_is_ts_training_ctrl_set(os_rx_fields_i[7-:8], pcie_gen12_phy_pkg_TS_CTRL_DISABLE_LINK) && (os_rx_ts1_qualified_evt_i || os_rx_ts2_qualified_evt_i)) begin
					state_d = 6'h09;
					substate_d = 6'h1c;
					reason_d = 8'h11;
					enable_latched_d = 1'b0;
					link_context_d = 1'b0;
				end
				else if (rx_buffer_fault_evt_i) begin
					state_d = 6'h01;
					substate_d = 6'h01;
					reason_d = 8'h13;
					link_context_d = 1'b0;
					lt_packet_drop_o = 1'b1;
					lt_packet_flush_o = 1'b1;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h08;
					fsm_error_fatal = 1'b1;
					fsm_failed = 1'b1;
				end
				else if (((rx_align_loss_evt_i || rx_frame_error_evt_i) || datapath_recovery_req_i) || crr_rx_electrical_idle_i) begin
					state_d = 6'h05;
					substate_d = 6'h0d;
					reason_d = 8'h0b;
					lt_packet_drop_o = rx_packet_active_i;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h11;
				end
				else if (os_rx_eios_evt_i && pm_policy_q[0]) begin
					state_d = 6'h06;
					substate_d = 6'h14;
					reason_d = 8'h19;
				end
				else if (target_rate_q != crr_current_rate_i) begin
					state_d = 6'h05;
					substate_d = 6'h0d;
					reason_d = 8'h08;
					recovery_fallback_d = 1'b0;
				end
				if (substate_q != 6'h0c) begin
					state_d = 6'h05;
					substate_d = 6'h0d;
					reason_d = 8'h12;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
				end
			end
			6'h05:
				(* full_case, parallel_case *)
				case (substate_q)
					6'h0d: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = (crr_current_rate_i ? 3'd6 : 3'd4);
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i);
						if ((local_train_done_q || local_train_done_d) && (remote_train_done_q || (os_rx_ts1_qualified_evt_i && crr_rx_aligned_i))) begin
							substate_d = 6'h0e;
							reason_d = 8'h05;
							retry_clear_o = 1'b1;
						end
						else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h09;
							fsm_timeout = 1'b1;
							if ((retry_count_i + 1'b1) < pcie_gen12_phy_timing_pkg_LTSSM_RETRY_MAX) begin
								retry_update_o = 1'b1;
								timer_restart = 1'b1;
							end
							else if (crr_current_rate_i) begin
								target_rate_d = 1'b0;
								recovery_fallback_d = 1'b1;
								substate_d = 6'h0f;
								speed_phase_d = 2'd0;
								reason_d = 8'h15;
								retry_clear_o = 1'b1;
							end
							else begin
								state_d = 6'h01;
								substate_d = 6'h01;
								reason_d = 8'h14;
								link_context_d = 1'b0;
								retry_clear_o = 1'b1;
							end
						end
					end
					6'h0e: begin
						lt_tx_mode_o = 4'h3;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h1;
						lt_os_repeat_mode_o = 3'd4;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts2_qualified_evt_i;
						if (((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts2_qualified_evt_i)) && x1_training_fields_valid(peer_fields_d)) begin
							if ((target_rate_q != crr_current_rate_i) || os_rx_speed_change_evt_i) begin
								substate_d = 6'h0f;
								speed_phase_d = 2'd0;
								reason_d = 8'h08;
							end
							else begin
								substate_d = 6'h10;
								reason_d = 8'h06;
							end
						end
						else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							substate_d = 6'h0d;
							reason_d = 8'h02;
							retry_update_o = 1'b1;
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h09;
							fsm_timeout = 1'b1;
						end
					end
					6'h0f: begin
						(* full_case, parallel_case *)
						case (speed_phase_q)
							2'd0: begin
								lt_tx_mode_o = 4'h6;
								lt_os_req_valid_o = 1'b1;
								lt_os_kind_o = 3'h4;
								lt_os_repeat_mode_o = 3'd0;
								if (os_tx_done_i)
									speed_phase_d = 2'd1;
							end
							2'd1: begin
								lt_tx_mode_o = 4'h0;
								lt_gt_tx_electrical_idle_o = 1'b1;
								if (crr_tx_electrical_idle_active_i)
									speed_phase_d = 2'd2;
							end
							default: begin
								lt_tx_mode_o = 4'h0;
								lt_gt_tx_electrical_idle_o = 1'b1;
								lt_gt_rate_req_o = 1'b1;
								lt_gt_rate_target_gen2_o = target_rate_q;
								if (crr_rate_done_i && (crr_current_rate_i == target_rate_q)) begin
									substate_d = 6'h0d;
									speed_phase_d = 2'd0;
									reason_d = 8'h09;
									retry_clear_o = 1'b1;
								end
								else if (crr_rate_fail_i) begin
									fsm_error_valid = 1'b1;
									fsm_error_code = 8'h0b;
									fsm_failed = 1'b1;
									if (target_rate_q && !crr_current_rate_i) begin
										target_rate_d = 1'b0;
										recovery_fallback_d = 1'b1;
										substate_d = 6'h0d;
										reason_d = 8'h15;
										retry_clear_o = 1'b1;
									end
									else if ((retry_count_i + 1'b1) < pcie_gen12_phy_timing_pkg_RATE_RETRY_MAX) begin
										speed_phase_d = 2'd0;
										reason_d = 8'h0a;
										retry_update_o = 1'b1;
										timer_restart = 1'b1;
									end
									else begin
										state_d = 6'h01;
										substate_d = 6'h01;
										reason_d = 8'h14;
										link_context_d = 1'b0;
										retry_clear_o = 1'b1;
									end
								end
							end
						endcase
						if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) && (substate_d == substate_q)) begin
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h0b;
							fsm_timeout = 1'b1;
							if (target_rate_q && !crr_current_rate_i) begin
								target_rate_d = 1'b0;
								recovery_fallback_d = 1'b1;
								substate_d = 6'h0d;
								speed_phase_d = 2'd0;
								reason_d = 8'h15;
								retry_clear_o = 1'b1;
							end
							else begin
								state_d = 6'h01;
								substate_d = 6'h01;
								reason_d = 8'h14;
								link_context_d = 1'b0;
								retry_clear_o = 1'b1;
							end
						end
					end
					6'h10: begin
						lt_tx_mode_o = 4'h1;
						local_idle_done_d = local_idle_done_q || tx_logical_idle_qualified_evt_i;
						remote_idle_done_d = remote_idle_done_q || rx_logical_idle_qualified_evt_i;
						if (((((local_idle_done_q || tx_logical_idle_qualified_evt_i) && (remote_idle_done_q || rx_logical_idle_qualified_evt_i)) && crr_ready_i) && crr_rx_aligned_i) && (crr_current_rate_i == target_rate_q)) begin
							state_d = 6'h04;
							substate_d = 6'h0c;
							reason_d = 8'h07;
							recovery_fallback_d = 1'b0;
							link_context_d = 1'b1;
							retry_clear_o = 1'b1;
						end
						else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							substate_d = 6'h0d;
							reason_d = 8'h02;
							retry_update_o = 1'b1;
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h09;
							fsm_timeout = 1'b1;
						end
					end
					default: begin
						state_d = 6'h01;
						substate_d = 6'h01;
						reason_d = 8'h12;
						link_context_d = 1'b0;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
			6'h06: begin
				(* full_case, parallel_case *)
				case (substate_q)
					6'h11: begin
						lt_tx_mode_o = 4'h6;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h4;
						lt_os_repeat_mode_o = 3'd0;
						if (os_tx_done_i) begin
							substate_d = 6'h12;
							reason_d = 8'h0d;
							low_power_entered_d = 1'b0;
						end
					end
					6'h12: begin
						lt_tx_mode_o = 4'h0;
						lt_gt_tx_electrical_idle_o = 1'b1;
						if (!low_power_entered_q) begin
							lt_gt_power_req_o = 1'b1;
							lt_gt_power_state_o = 2'b01;
							if (crr_power_done_i) begin
								low_power_entered_d = 1'b1;
								reason_d = 8'h0e;
							end
							else if (crr_power_fail_i) begin
								state_d = 6'h05;
								substate_d = 6'h0d;
								reason_d = 8'h0a;
								fsm_error_valid = 1'b1;
								fsm_error_code = 8'h0d;
								fsm_failed = 1'b1;
							end
						end
					end
					6'h13:
						if (!low_power_entered_q) begin
							lt_gt_power_req_o = 1'b1;
							lt_gt_power_state_o = 2'b00;
							lt_gt_tx_electrical_idle_o = 1'b0;
							if (crr_power_done_i)
								low_power_entered_d = 1'b1;
						end
						else begin
							lt_tx_mode_o = 4'h5;
							lt_os_req_valid_o = 1'b1;
							lt_os_kind_o = 3'h3;
							lt_os_repeat_mode_o = 3'd2;
							local_train_done_d = local_train_done_q || os_tx_done_i;
							if ((local_train_done_q || os_tx_done_i) && crr_rx_aligned_i) begin
								state_d = 6'h04;
								substate_d = 6'h0c;
								reason_d = 8'h1b;
								low_power_entered_d = 1'b0;
							end
						end
					6'h14: begin
						lt_tx_mode_o = 4'h1;
						if (crr_rx_electrical_idle_i) begin
							substate_d = 6'h15;
							reason_d = 8'h19;
						end
					end
					6'h15: begin
						lt_tx_mode_o = 4'h1;
						if (!crr_rx_electrical_idle_i) begin
							substate_d = 6'h16;
							reason_d = 8'h17;
						end
					end
					6'h16: begin
						lt_tx_mode_o = 4'h1;
						if (os_rx_fts_evt_i && crr_rx_aligned_i) begin
							state_d = 6'h04;
							substate_d = 6'h0c;
							reason_d = 8'h1b;
						end
					end
					default: begin
						state_d = 6'h05;
						substate_d = 6'h0d;
						reason_d = 8'h12;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
				if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) && (substate_d == substate_q)) begin
					state_d = 6'h05;
					substate_d = 6'h0d;
					reason_d = 8'h02;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
					fsm_timeout = 1'b1;
				end
			end
			6'h07: begin
				lt_gt_tx_electrical_idle_o = 1'b1;
				(* full_case, parallel_case *)
				case (substate_q)
					6'h17:
						(* full_case, parallel_case *)
						case (pm_phase_q)
							2'd0: begin
								lt_tx_mode_o = 4'h6;
								lt_os_req_valid_o = 1'b1;
								lt_os_kind_o = 3'h4;
								lt_os_repeat_mode_o = 3'd0;
								if (os_tx_done_i)
									pm_phase_d = 2'd1;
							end
							2'd1: begin
								lt_tx_mode_o = 4'h0;
								if (crr_tx_electrical_idle_active_i)
									pm_phase_d = 2'd2;
							end
							default: begin
								lt_tx_mode_o = 4'h0;
								lt_gt_power_req_o = 1'b1;
								lt_gt_power_state_o = 2'b10;
								if (crr_power_done_i) begin
									substate_d = 6'h18;
									reason_d = 8'h0e;
									pm_phase_d = 2'd3;
									low_power_entered_d = 1'b1;
								end
								else if (crr_power_fail_i) begin
									state_d = 6'h05;
									substate_d = 6'h0d;
									reason_d = 8'h0a;
									fsm_error_valid = 1'b1;
									fsm_error_code = 8'h0d;
									fsm_failed = 1'b1;
								end
							end
						endcase
					6'h18: lt_tx_mode_o = 4'h0;
					6'h19: begin
						lt_tx_mode_o = 4'h0;
						lt_gt_power_req_o = 1'b1;
						lt_gt_power_state_o = 2'b00;
						if (crr_power_done_i) begin
							state_d = 6'h05;
							substate_d = 6'h0d;
							reason_d = 8'h17;
							low_power_entered_d = 1'b0;
							pm_phase_d = 2'd0;
						end
						else if (crr_power_fail_i) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h13;
							link_context_d = 1'b0;
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h0d;
							fsm_error_fatal = 1'b1;
							fsm_failed = 1'b1;
						end
					end
					default: begin
						state_d = 6'h05;
						substate_d = 6'h0d;
						reason_d = 8'h12;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
				if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) && (substate_d == substate_q)) begin
					state_d = 6'h05;
					substate_d = 6'h0d;
					reason_d = 8'h02;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
					fsm_timeout = 1'b1;
				end
			end
			6'h08: begin
				lt_tx_mode_o = 4'h0;
				lt_gt_tx_electrical_idle_o = 1'b1;
				link_context_d = 1'b0;
				(* full_case, parallel_case *)
				case (substate_q)
					6'h1a:
						(* full_case, parallel_case *)
						case (pm_phase_q)
							2'd0: begin
								lt_tx_mode_o = 4'h6;
								lt_os_req_valid_o = 1'b1;
								lt_os_kind_o = 3'h4;
								if (os_tx_done_i)
									pm_phase_d = 2'd1;
							end
							2'd1:
								if (crr_tx_electrical_idle_active_i)
									pm_phase_d = 2'd2;
							default:
								if (!low_power_entered_q) begin
									lt_gt_power_req_o = 1'b1;
									lt_gt_power_state_o = 2'b11;
									if (crr_power_done_i) begin
										low_power_entered_d = 1'b1;
										pm_phase_d = 2'd3;
										reason_d = 8'h0e;
									end
									else if (crr_power_fail_i) begin
										state_d = 6'h09;
										substate_d = 6'h1c;
										reason_d = 8'h13;
										fsm_error_valid = 1'b1;
										fsm_error_code = 8'h0d;
										fsm_error_fatal = 1'b1;
										fsm_failed = 1'b1;
									end
								end
						endcase
					6'h1b: begin
						lt_gt_power_req_o = 1'b1;
						lt_gt_power_state_o = 2'b00;
						if (crr_power_done_i) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h17;
							low_power_entered_d = 1'b0;
							pm_phase_d = 2'd0;
							retry_clear_o = 1'b1;
						end
						else if (crr_power_fail_i || timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							state_d = 6'h09;
							substate_d = 6'h1c;
							reason_d = 8'h13;
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h0d;
							fsm_error_fatal = 1'b1;
							fsm_failed = 1'b1;
						end
					end
					default: begin
						state_d = 6'h09;
						substate_d = 6'h1c;
						reason_d = 8'h12;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
			end
			6'h09: begin
				lt_tx_mode_o = 4'h0;
				lt_gt_tx_electrical_idle_o = 1'b1;
				link_context_d = 1'b0;
				if (substate_q != 6'h1c) begin
					substate_d = 6'h1c;
					reason_d = 8'h12;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
				end
				else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id))
					disabled_hold_done_d = 1'b1;
				if ((((substate_q == 6'h1c) && enable_latched_q) && crr_ready_i) && (disabled_hold_done_q || timer_matches_current(timer_expired_i, timer_id_i, current_timer_id))) begin
					state_d = 6'h01;
					substate_d = 6'h01;
					reason_d = 8'h01;
					retry_clear_o = 1'b1;
				end
			end
			6'h0a: begin
				link_context_d = 1'b0;
				(* full_case, parallel_case *)
				case (substate_q)
					6'h1d: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd1;
						lt_os_fields_o[7-:8] = tx_fields_q[7-:8] | pcie_gen12_phy_pkg_TS_CTRL_LOOPBACK;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = (remote_train_done_q || os_rx_loopback_evt_i) || pcie_gen12_phy_pkg_is_ts_training_ctrl_set(peer_fields_q[7-:8], pcie_gen12_phy_pkg_TS_CTRL_LOOPBACK);
						if ((local_train_done_q || os_tx_done_i) && ((remote_train_done_q || os_rx_loopback_evt_i) || pcie_gen12_phy_pkg_is_ts_training_ctrl_set(peer_fields_q[7-:8], pcie_gen12_phy_pkg_TS_CTRL_LOOPBACK))) begin
							substate_d = 6'h1e;
							reason_d = 8'h10;
						end
					end
					6'h1e: begin
						lt_tx_mode_o = 4'ha;
						lt_gt_loopback_mode_o = 3'b000;
					end
					6'h1f: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd2;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
						if ((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts1_qualified_evt_i)) begin
							state_d = 6'h05;
							substate_d = 6'h0d;
							reason_d = 8'h10;
						end
					end
					default: begin
						state_d = 6'h01;
						substate_d = 6'h01;
						reason_d = 8'h12;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
				if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id) && (substate_d == substate_q)) begin
					state_d = 6'h01;
					substate_d = 6'h01;
					reason_d = 8'h02;
					fsm_error_valid = 1'b1;
					fsm_error_code = 8'h09;
					fsm_timeout = 1'b1;
				end
			end
			6'h0b: begin
				link_context_d = 1'b0;
				(* full_case, parallel_case *)
				case (substate_q)
					6'h20: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd1;
						lt_os_fields_o[7-:8] = tx_fields_q[7-:8] | pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || pcie_gen12_phy_pkg_is_ts_training_ctrl_set(peer_fields_q[7-:8], pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET);
						if ((local_train_done_q || os_tx_done_i) && (remote_train_done_q || pcie_gen12_phy_pkg_is_ts_training_ctrl_set(peer_fields_q[7-:8], pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET))) begin
							substate_d = 6'h21;
							reason_d = 8'h0f;
						end
					end
					6'h21: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd1;
						lt_os_fields_o[7-:8] = tx_fields_q[7-:8] | pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET;
						if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							substate_d = 6'h22;
							reason_d = 8'h02;
						end
					end
					6'h22: begin
						lt_tx_mode_o = 4'h2;
						lt_os_req_valid_o = 1'b1;
						lt_os_kind_o = 3'h0;
						lt_os_repeat_mode_o = 3'd2;
						lt_os_fields_o[7-:8] = tx_fields_q[7-:8] & ~pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET;
						local_train_done_d = local_train_done_q || os_tx_done_i;
						remote_train_done_d = remote_train_done_q || os_rx_ts1_qualified_evt_i;
						if ((local_train_done_q || os_tx_done_i) && (remote_train_done_q || os_rx_ts1_qualified_evt_i)) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h0f;
							lt_packet_flush_o = 1'b1;
							retry_clear_o = 1'b1;
						end
						else if (timer_matches_current(timer_expired_i, timer_id_i, current_timer_id)) begin
							state_d = 6'h01;
							substate_d = 6'h01;
							reason_d = 8'h02;
							fsm_error_valid = 1'b1;
							fsm_error_code = 8'h09;
							fsm_timeout = 1'b1;
						end
					end
					default: begin
						state_d = 6'h01;
						substate_d = 6'h01;
						reason_d = 8'h12;
						fsm_error_valid = 1'b1;
						fsm_error_code = 8'h09;
					end
				endcase
			end
			default: begin
				state_d = 6'h00;
				substate_d = 6'h00;
				reason_d = 8'h12;
				enable_latched_d = 1'b0;
				link_context_d = 1'b0;
				recovery_fallback_d = 1'b0;
				lt_packet_flush_o = 1'b1;
				fsm_error_valid = 1'b1;
				fsm_error_code = 8'h09;
			end
		endcase
		if (cmd_pending_q && !cmd_started_q)
			(* full_case, parallel_case *)
			case (cmd_opcode_q)
				4'h0:
					if ((state_q == 6'h00) || (state_q == 6'h09)) begin
						enable_latched_d = 1'b1;
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h0;
					end
					else begin
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h2;
					end
				4'h1: begin
					enable_latched_d = 1'b0;
					state_d = 6'h09;
					substate_d = 6'h1c;
					reason_d = 8'h11;
					link_context_d = 1'b0;
					lt_packet_flush_o = 1'b1;
					cmd_pending_d = 1'b0;
					mgmt_rsp_valid_d = 1'b1;
					mgmt_rsp_status_d = 4'h0;
				end
				4'h2:
					if (state_q == 6'h04) begin
						state_d = 6'h05;
						substate_d = 6'h0d;
						reason_d = 8'h0c;
						cmd_started_d = 1'b1;
					end
					else begin
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h2;
					end
				4'h3:
					if ((cmd_arg_q[7:1] == 0) && (state_q == 6'h04)) begin
						target_rate_d = cmd_arg_q[0];
						if (cmd_arg_q[0] == crr_current_rate_i) begin
							cmd_pending_d = 1'b0;
							mgmt_rsp_valid_d = 1'b1;
							mgmt_rsp_status_d = 4'h0;
						end
						else begin
							state_d = 6'h05;
							substate_d = 6'h0d;
							reason_d = 8'h08;
							cmd_started_d = 1'b1;
						end
					end
					else begin
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h2;
					end
				4'h4:
					if ((state_q == 6'h04) || (state_q == 6'h05)) begin
						state_d = 6'h0b;
						substate_d = 6'h20;
						reason_d = 8'h0f;
						link_context_d = 1'b0;
						cmd_started_d = 1'b1;
					end
					else begin
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h2;
					end
				4'h5:
					if (((cmd_arg_q[2:0] == pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_DISABLE) && (state_q == 6'h0a)) && (substate_q == 6'h1e)) begin
						substate_d = 6'h1f;
						reason_d = 8'h10;
						cmd_started_d = 1'b1;
					end
					else if ((((cmd_arg_q[2:0] == pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_NEAR) || (cmd_arg_q[2:0] == pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_FAR)) && (cmd_arg_q[7:3] == 0)) && (state_q == 6'h04)) begin
						protocol_loopback_mode_d = cmd_arg_q[2:0];
						state_d = 6'h0a;
						substate_d = 6'h1d;
						reason_d = 8'h10;
						link_context_d = 1'b0;
						cmd_started_d = 1'b1;
					end
					else begin
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h2;
					end
				4'h6:
					if (crr_ready_i && ((((state_q == 6'h00) || (state_q == 6'h01)) || (state_q == 6'h02)) || (state_q == 6'h04))) begin
						state_d = 6'h02;
						substate_d = 6'h04;
						reason_d = 8'h18;
						link_context_d = 1'b0;
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h0;
					end
					else begin
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h2;
					end
				4'h7: begin
					lt_clear_error_o = 1'b1;
					cmd_pending_d = 1'b0;
					mgmt_rsp_valid_d = 1'b1;
					mgmt_rsp_status_d = 4'h0;
				end
				4'h8:
					if (cmd_arg_q[7:2] == 0) begin
						pm_policy_d = cmd_arg_q[1:0];
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h0;
					end
					else begin
						cmd_pending_d = 1'b0;
						mgmt_rsp_valid_d = 1'b1;
						mgmt_rsp_status_d = 4'h2;
					end
				default: begin
					cmd_pending_d = 1'b0;
					mgmt_rsp_valid_d = 1'b1;
					mgmt_rsp_status_d = 4'h2;
				end
			endcase
		if (pm_pending_q && !pm_started_q) begin
			if (!pm_exit_q && (state_q == 6'h04))
				(* full_case, parallel_case *)
				case (pm_state_q)
					2'd0:
						if (pm_policy_q[0]) begin
							state_d = 6'h06;
							substate_d = 6'h11;
							reason_d = 8'h16;
							pm_started_d = 1'b1;
							low_power_entered_d = 1'b0;
						end
						else begin
							pm_pending_d = 1'b0;
							pm_rsp_valid_d = 1'b1;
							pm_rsp_success_d = 1'b0;
						end
					2'd1:
						if (pm_policy_q[1]) begin
							state_d = 6'h07;
							substate_d = 6'h17;
							reason_d = 8'h16;
							pm_phase_d = 2'd0;
							low_power_entered_d = 1'b0;
							pm_started_d = 1'b1;
						end
						else begin
							pm_pending_d = 1'b0;
							pm_rsp_valid_d = 1'b1;
							pm_rsp_success_d = 1'b0;
						end
					2'd2: begin
						state_d = 6'h08;
						substate_d = 6'h1a;
						reason_d = 8'h16;
						pm_phase_d = 2'd0;
						low_power_entered_d = 1'b0;
						link_context_d = 1'b0;
						pm_started_d = 1'b1;
					end
					default: begin
						pm_pending_d = 1'b0;
						pm_rsp_valid_d = 1'b1;
						pm_rsp_success_d = 1'b0;
					end
				endcase
			else if (pm_exit_q) begin
				if (((pm_state_q == 2'd0) && (state_q == 6'h06)) && (substate_q == 6'h12)) begin
					substate_d = 6'h13;
					reason_d = 8'h17;
					low_power_entered_d = 1'b0;
					pm_started_d = 1'b1;
				end
				else if (((pm_state_q == 2'd1) && (state_q == 6'h07)) && (substate_q == 6'h18)) begin
					substate_d = 6'h19;
					reason_d = 8'h17;
					pm_started_d = 1'b1;
				end
				else if ((((pm_state_q == 2'd2) && (state_q == 6'h08)) && (substate_q == 6'h1a)) && low_power_entered_q) begin
					substate_d = 6'h1b;
					reason_d = 8'h17;
					pm_started_d = 1'b1;
				end
				else begin
					pm_pending_d = 1'b0;
					pm_rsp_valid_d = 1'b1;
					pm_rsp_success_d = 1'b0;
				end
			end
			else begin
				pm_pending_d = 1'b0;
				pm_rsp_valid_d = 1'b1;
				pm_rsp_success_d = 1'b0;
			end
		end
		if (cmd_pending_q && cmd_started_q) begin
			if (fsm_timeout) begin
				cmd_pending_d = 1'b0;
				cmd_started_d = 1'b0;
				mgmt_rsp_valid_d = 1'b1;
				mgmt_rsp_status_d = 4'h3;
			end
			else if (fsm_failed || crr_fault_i) begin
				cmd_pending_d = 1'b0;
				cmd_started_d = 1'b0;
				mgmt_rsp_valid_d = 1'b1;
				mgmt_rsp_status_d = 4'h4;
			end
			else
				(* full_case, parallel_case *)
				case (cmd_opcode_q)
					4'h2:
						if ((state_d == 6'h04) && (substate_d == 6'h0c)) begin
							cmd_pending_d = 1'b0;
							cmd_started_d = 1'b0;
							mgmt_rsp_valid_d = 1'b1;
							mgmt_rsp_status_d = 4'h0;
						end
					4'h3:
						if ((state_d == 6'h04) && (substate_d == 6'h0c)) begin
							cmd_pending_d = 1'b0;
							cmd_started_d = 1'b0;
							mgmt_rsp_valid_d = 1'b1;
							mgmt_rsp_status_d = (crr_current_rate_i == cmd_arg_q[0] ? 4'h0 : 4'h4);
						end
					4'h4:
						if ((state_d == 6'h01) && (substate_d == 6'h01)) begin
							cmd_pending_d = 1'b0;
							cmd_started_d = 1'b0;
							mgmt_rsp_valid_d = 1'b1;
							mgmt_rsp_status_d = 4'h0;
						end
					4'h5:
						if ((((cmd_arg_q[2:0] != pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_DISABLE) && (state_d == 6'h0a)) && (substate_d == 6'h1e)) || ((cmd_arg_q[2:0] == pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_DISABLE) && (state_d == 6'h05))) begin
							cmd_pending_d = 1'b0;
							cmd_started_d = 1'b0;
							mgmt_rsp_valid_d = 1'b1;
							mgmt_rsp_status_d = 4'h0;
						end
					default:
						;
				endcase
		end
		if (pm_pending_q && pm_started_q) begin
			if (((fsm_timeout || fsm_failed) || crr_fault_i) || crr_power_fail_i) begin
				pm_pending_d = 1'b0;
				pm_started_d = 1'b0;
				pm_rsp_valid_d = 1'b1;
				pm_rsp_success_d = 1'b0;
			end
			else if (!pm_exit_q) begin
				if ((((((pm_state_q == 2'd0) && (state_q == 6'h06)) && (substate_q == 6'h12)) && low_power_entered_d) || (((pm_state_q == 2'd1) && (state_d == 6'h07)) && (substate_d == 6'h18))) || (((pm_state_q == 2'd2) && (state_d == 6'h08)) && low_power_entered_d)) begin
					pm_pending_d = 1'b0;
					pm_started_d = 1'b0;
					pm_rsp_valid_d = 1'b1;
					pm_rsp_success_d = 1'b1;
				end
			end
			else if ((((pm_state_q == 2'd0) && (state_d == 6'h04)) || ((pm_state_q == 2'd1) && (state_d == 6'h04))) || ((pm_state_q == 2'd2) && (state_d == 6'h01))) begin
				pm_pending_d = 1'b0;
				pm_started_d = 1'b0;
				pm_rsp_valid_d = 1'b1;
				pm_rsp_success_d = 1'b1;
			end
		end
		if (os_rx_error_i != 8'h00) begin
			fsm_error_valid = 1'b1;
			fsm_error_code = 8'h04;
			fsm_error_info = {state_q, substate_q, os_rx_error_i, peer_fields_q[9-:2], 10'd0};
			if (rx_packet_active_i)
				lt_packet_drop_o = 1'b1;
		end
		if (crr_fault_i) begin
			fsm_error_valid = 1'b1;
			fsm_error_code = (crr_fault_code_i == 8'h00 ? 8'h0c : crr_fault_code_i);
			fsm_error_fatal = pcie_gen12_phy_pkg_error_is_fatal(fsm_error_code);
			fsm_error_info = {state_q, substate_q, crr_fault_code_i, retry_count_i, 4'd0};
			lt_packet_drop_o = rx_packet_active_i;
			lt_packet_flush_o = fsm_error_fatal;
			if (fsm_error_fatal) begin
				state_d = 6'h01;
				substate_d = 6'h01;
				reason_d = 8'h13;
				link_context_d = 1'b0;
			end
		end
		transition = (state_d != state_q) || (substate_d != substate_q);
		if (state_d != 6'h09)
			disabled_hold_done_d = 1'b0;
		if (transition) begin
			local_train_done_d = 1'b0;
			remote_train_done_d = 1'b0;
			local_idle_done_d = 1'b0;
			remote_idle_done_d = 1'b0;
		end
		next_timer_id = state_timer_id(state_d, substate_d);
		timer_start_o = 1'b0;
		timer_stop_o = 1'b0;
		timer_id_o = next_timer_id;
		timer_limit_o = pcie_gen12_phy_timing_pkg_timer_default_cycles(next_timer_id, SIM_TIME_SCALE);
		if (transition) begin
			timer_stop_o = 1'b1;
			if (next_timer_id != 6'h00)
				timer_start_o = 1'b1;
		end
		else if (timer_restart) begin
			timer_start_o = 1'b1;
			timer_id_o = current_timer_id;
			timer_limit_o = pcie_gen12_phy_timing_pkg_timer_default_cycles(current_timer_id, SIM_TIME_SCALE);
		end
		lt_data_active_o = ((((((state_q == 6'h04) && (state_d == 6'h04)) && crr_ready_i) && crr_rx_aligned_i) && !crr_fault_i) && !cmd_pending_q) && !pm_pending_q;
		lt_packet_enable_o = lt_data_active_o;
	end
	localparam [1:0] pcie_gen12_phy_pkg_RATE_ID_GEN1_SUPPORTED = 2'b01;
	always @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani)
		if (!ctrl_local_reset_ani) begin
			state_q <= 6'h00;
			substate_q <= 6'h00;
			reason_q <= 8'h00;
			peer_fields_q <= 1'sb0;
			tx_fields_q <= 1'sb0;
			tx_fields_q[34] <= 1'b1;
			tx_fields_q[32] <= 1'b1;
			tx_fields_q[31] <= 1'b1;
			tx_fields_q[9-:2] <= pcie_gen12_phy_pkg_RATE_ID_GEN1_SUPPORTED | pcie_gen12_phy_pkg_RATE_ID_GEN2_SUPPORTED;
			speed_phase_q <= 2'd0;
			pm_phase_q <= 2'd0;
			enable_latched_q <= 1'b0;
			target_rate_q <= 1'b0;
			peer_gen2_capable_q <= 1'b0;
			link_context_q <= 1'b0;
			recovery_fallback_q <= 1'b0;
			pm_policy_q <= 2'b11;
			protocol_loopback_mode_q <= pcie_gen12_phy_pkg_PHY_CMD_LOOPBACK_ARG_DISABLE;
			local_train_done_q <= 1'b0;
			remote_train_done_q <= 1'b0;
			local_idle_done_q <= 1'b0;
			remote_idle_done_q <= 1'b0;
			low_power_entered_q <= 1'b0;
			disabled_hold_done_q <= 1'b0;
			cmd_pending_q <= 1'b0;
			cmd_started_q <= 1'b0;
			cmd_opcode_q <= 4'h0;
			cmd_arg_q <= 1'sb0;
			mgmt_rsp_valid_q <= 1'b0;
			mgmt_rsp_status_q <= 4'h0;
			pm_pending_q <= 1'b0;
			pm_started_q <= 1'b0;
			pm_state_q <= 2'd0;
			pm_exit_q <= 1'b0;
			pm_rsp_valid_q <= 1'b0;
			pm_rsp_success_q <= 1'b0;
			lt_status_evt_valid_o <= 1'b0;
			lt_status_evt_code_o <= 8'h00;
			lt_status_evt_info_o <= 1'sb0;
			lt_status_evt_fatal_o <= 1'b0;
		end
		else begin
			state_q <= state_d;
			substate_q <= substate_d;
			reason_q <= reason_d;
			peer_fields_q <= peer_fields_d;
			tx_fields_q <= tx_fields_d;
			speed_phase_q <= speed_phase_d;
			pm_phase_q <= pm_phase_d;
			enable_latched_q <= enable_latched_d;
			target_rate_q <= target_rate_d;
			peer_gen2_capable_q <= peer_gen2_capable_d;
			link_context_q <= link_context_d;
			recovery_fallback_q <= recovery_fallback_d;
			pm_policy_q <= pm_policy_d;
			protocol_loopback_mode_q <= protocol_loopback_mode_d;
			local_train_done_q <= local_train_done_d;
			remote_train_done_q <= remote_train_done_d;
			local_idle_done_q <= local_idle_done_d;
			remote_idle_done_q <= remote_idle_done_d;
			low_power_entered_q <= low_power_entered_d;
			disabled_hold_done_q <= disabled_hold_done_d;
			cmd_pending_q <= cmd_pending_d;
			cmd_started_q <= cmd_started_d;
			cmd_opcode_q <= cmd_opcode_d;
			cmd_arg_q <= cmd_arg_d;
			mgmt_rsp_valid_q <= mgmt_rsp_valid_d;
			mgmt_rsp_status_q <= mgmt_rsp_status_d;
			pm_pending_q <= pm_pending_d;
			pm_started_q <= pm_started_d;
			pm_state_q <= pm_state_d;
			pm_exit_q <= pm_exit_d;
			pm_rsp_valid_q <= pm_rsp_valid_d;
			pm_rsp_success_q <= pm_rsp_success_d;
			lt_status_evt_valid_o <= 1'b0;
			if (transition) begin
				lt_status_evt_valid_o <= 1'b1;
				lt_status_evt_code_o <= 8'h00;
				lt_status_evt_info_o <= {state_q, state_d, substate_q, substate_d, reason_d};
				lt_status_evt_fatal_o <= 1'b0;
			end
			if (fsm_error_valid) begin
				lt_status_evt_valid_o <= 1'b1;
				lt_status_evt_code_o <= fsm_error_code;
				lt_status_evt_info_o <= fsm_error_info;
				lt_status_evt_fatal_o <= fsm_error_fatal;
			end
		end
	initial _sv2v_0 = 0;
endmodule
