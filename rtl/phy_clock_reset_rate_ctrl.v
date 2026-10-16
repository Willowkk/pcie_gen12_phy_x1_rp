`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_clock_reset_rate_ctrl (
	ctrl_clk_i,
	ctrl_rst_ni,
	port_reset_ni,
	pcie_refclk_p_i,
	pcie_refclk_n_i,
	gt_sym_clk_i,
	gt_sym_rst_ni,
	gt_sym_clk_stable_i,
	gt_buffer_reinit_done_i,
	phy_sym_clk_o,
	phy_sym_rst_no,
	crr_ready_o,
	crr_current_rate_o,
	lt_gt_detect_req_i,
	lt_gt_rate_req_i,
	lt_gt_rate_target_gen2_i,
	lt_gt_power_req_i,
	lt_gt_power_state_i,
	lt_gt_tx_electrical_idle_i,
	lt_gt_rx_polarity_invert_i,
	lt_gt_tx_deemphasis_i,
	lt_gt_tx_swing_i,
	lt_gt_tx_margin_i,
	lt_gt_compliance_enable_i,
	lt_gt_loopback_mode_i,
	crr_detect_done_o,
	crr_receiver_present_o,
	crr_rate_done_o,
	crr_rate_fail_o,
	crr_power_done_o,
	crr_power_fail_o,
	crr_tx_electrical_idle_active_o,
	crr_rx_electrical_idle_o,
	crr_rx_aligned_o,
	crr_fault_o,
	crr_fault_code_o,
	gt_detect_busy_i,
	gt_detect_done_i,
	gt_receiver_present_i,
	gt_rate_busy_i,
	gt_rate_done_i,
	gt_rate_fail_i,
	gt_tx_electrical_idle_active_i,
	gt_rx_electrical_idle_i,
	gt_power_busy_i,
	gt_power_done_i,
	gt_power_fail_i,
	gt_ready_i,
	gt_fault_i,
	gt_fault_code_i,
	rx_byte_aligned_i,
	tx_quiesced_i,
	rx_packet_active_i,
	gt_detect_req_o,
	gt_rate_req_o,
	gt_rate_target_gen2_o,
	gt_tx_electrical_idle_o,
	gt_power_req_o,
	gt_power_state_o,
	gt_rx_polarity_invert_o,
	gt_tx_deemphasis_o,
	gt_tx_swing_o,
	gt_tx_margin_o,
	gt_compliance_enable_o,
	gt_loopback_mode_o,
	sym_path_reset_o,
	packet_admission_enable_o,
	packet_buffer_flush_o
);
	reg _sv2v_0;
	localparam [31:0] pcie_gen12_phy_timing_pkg_SIM_TIME_SCALE = 1;
	parameter [31:0] SIM_TIME_SCALE = pcie_gen12_phy_timing_pkg_SIM_TIME_SCALE;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	input wire port_reset_ni;
	input wire pcie_refclk_p_i;
	input wire pcie_refclk_n_i;
	input wire gt_sym_clk_i;
	input wire gt_sym_rst_ni;
	input wire gt_sym_clk_stable_i;
	input wire gt_buffer_reinit_done_i;
	output wire phy_sym_clk_o;
	output reg phy_sym_rst_no;
	output reg crr_ready_o;
	output reg crr_current_rate_o;
	input wire lt_gt_detect_req_i;
	input wire lt_gt_rate_req_i;
	input wire lt_gt_rate_target_gen2_i;
	input wire lt_gt_power_req_i;
	input wire [1:0] lt_gt_power_state_i;
	input wire lt_gt_tx_electrical_idle_i;
	input wire lt_gt_rx_polarity_invert_i;
	input wire lt_gt_tx_deemphasis_i;
	input wire lt_gt_tx_swing_i;
	input wire [2:0] lt_gt_tx_margin_i;
	input wire lt_gt_compliance_enable_i;
	input wire [2:0] lt_gt_loopback_mode_i;
	output reg crr_detect_done_o;
	output reg crr_receiver_present_o;
	output reg crr_rate_done_o;
	output reg crr_rate_fail_o;
	output reg crr_power_done_o;
	output reg crr_power_fail_o;
	output reg crr_tx_electrical_idle_active_o;
	output reg crr_rx_electrical_idle_o;
	output reg crr_rx_aligned_o;
	output reg crr_fault_o;
	output reg [7:0] crr_fault_code_o;
	input wire gt_detect_busy_i;
	input wire gt_detect_done_i;
	input wire gt_receiver_present_i;
	input wire gt_rate_busy_i;
	input wire gt_rate_done_i;
	input wire gt_rate_fail_i;
	input wire gt_tx_electrical_idle_active_i;
	input wire gt_rx_electrical_idle_i;
	input wire gt_power_busy_i;
	input wire gt_power_done_i;
	input wire gt_power_fail_i;
	input wire gt_ready_i;
	input wire gt_fault_i;
	input wire [7:0] gt_fault_code_i;
	input wire rx_byte_aligned_i;
	input wire tx_quiesced_i;
	input wire rx_packet_active_i;
	output wire gt_detect_req_o;
	output wire gt_rate_req_o;
	output wire gt_rate_target_gen2_o;
	output reg gt_tx_electrical_idle_o;
	output wire gt_power_req_o;
	output wire [1:0] gt_power_state_o;
	output wire gt_rx_polarity_invert_o;
	output wire gt_tx_deemphasis_o;
	output wire gt_tx_swing_o;
	output wire [2:0] gt_tx_margin_o;
	output wire gt_compliance_enable_o;
	output wire [2:0] gt_loopback_mode_o;
	output reg sym_path_reset_o;
	output reg packet_admission_enable_o;
	output reg packet_buffer_flush_o;
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
	localparam [31:0] RESET_TIMEOUT_CYCLES = pcie_gen12_phy_timing_pkg_timer_default_cycles(6'h12, SIM_TIME_SCALE);
	localparam [31:0] DETECT_TIMEOUT_CYCLES = pcie_gen12_phy_timing_pkg_timer_default_cycles(6'h13, SIM_TIME_SCALE);
	localparam [31:0] RATE_TIMEOUT_CYCLES = pcie_gen12_phy_timing_pkg_timer_default_cycles(6'h14, SIM_TIME_SCALE);
	localparam [31:0] POWER_TIMEOUT_CYCLES = pcie_gen12_phy_timing_pkg_timer_default_cycles(6'h15, SIM_TIME_SCALE);
	wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;
	wire sym_release_ani = ((ctrl_rst_ni & port_reset_ni) & gt_sym_rst_ni) & ~sym_path_reset_o;
	reg [4:0] crr_state_q;
	reg [31:0] operation_timer_q;
	reg [31:0] clock_stable_count_q;
	reg [31:0] rx_ei_filter_count_q;
	reg [31:0] rx_align_filter_count_q;
	reg [2:0] sym_reset_release_q;
	reg [1:0] phy_sym_rst_ctrl_sync_q;
	reg reset_timeout_reported_q;
	reg gt_fault_reported_q;
	reg detect_armed_q;
	reg rate_armed_q;
	reg power_armed_q;
	reg rate_target_q;
	reg [1:0] power_target_q;
	reg [1:0] current_power_q;
	reg mode_tx_electrical_idle_q;
	reg mode_rx_polarity_q;
	reg mode_tx_deemphasis_q;
	reg mode_tx_swing_q;
	reg [2:0] mode_tx_margin_q;
	reg mode_compliance_q;
	reg [2:0] mode_loopback_q;
	reg refclk_observation_q;
	assign phy_sym_clk_o = gt_sym_clk_i;
	assign gt_detect_req_o = crr_state_q == 5'd3;
	assign gt_rate_req_o = crr_state_q == 5'd7;
	assign gt_power_req_o = crr_state_q == 5'd13;
	assign gt_rate_target_gen2_o = rate_target_q;
	assign gt_power_state_o = power_target_q;
	assign gt_rx_polarity_invert_o = mode_rx_polarity_q;
	assign gt_tx_deemphasis_o = mode_tx_deemphasis_q;
	assign gt_tx_swing_o = mode_tx_swing_q;
	assign gt_tx_margin_o = mode_tx_margin_q;
	assign gt_compliance_enable_o = mode_compliance_q;
	assign gt_loopback_mode_o = mode_loopback_q;
	always @(*) begin
		if (_sv2v_0)
			;
		gt_tx_electrical_idle_o = mode_tx_electrical_idle_q;
		(* full_case, parallel_case *)
		case (crr_state_q)
			5'd0, 5'd1, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8, 5'd9, 5'd10, 5'd12, 5'd13, 5'd14, 5'd15, 5'd16: gt_tx_electrical_idle_o = 1'b1;
			default:
				;
		endcase
	end
	always @(posedge gt_sym_clk_i or negedge sym_release_ani)
		if (!sym_release_ani) begin
			sym_reset_release_q <= 1'sb0;
			phy_sym_rst_no <= 1'b0;
		end
		else begin
			sym_reset_release_q <= {sym_reset_release_q[1:0], 1'b1};
			phy_sym_rst_no <= &sym_reset_release_q;
		end
	always @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani)
		if (!ctrl_local_reset_ani)
			phy_sym_rst_ctrl_sync_q <= 1'sb0;
		else
			phy_sym_rst_ctrl_sync_q <= {phy_sym_rst_ctrl_sync_q[0], phy_sym_rst_no};
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES = 32;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_ALIGNMENT_STABLE_CYCLES = 16;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_EI_ASSERT_STABLE_CYCLES = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_EI_DEASSERT_STABLE_CYCLES = 16;
	always @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani)
		if (!ctrl_local_reset_ani) begin
			crr_state_q <= 5'd0;
			operation_timer_q <= RESET_TIMEOUT_CYCLES;
			clock_stable_count_q <= 1'sb0;
			rx_ei_filter_count_q <= 1'sb0;
			rx_align_filter_count_q <= 1'sb0;
			reset_timeout_reported_q <= 1'b0;
			gt_fault_reported_q <= 1'b0;
			detect_armed_q <= 1'b1;
			rate_armed_q <= 1'b1;
			power_armed_q <= 1'b1;
			rate_target_q <= 1'b0;
			power_target_q <= 2'b00;
			current_power_q <= 2'b00;
			crr_current_rate_o <= 1'b0;
			mode_tx_electrical_idle_q <= 1'b1;
			mode_rx_polarity_q <= 1'b0;
			mode_tx_deemphasis_q <= 1'b0;
			mode_tx_swing_q <= 1'b0;
			mode_tx_margin_q <= 1'sb0;
			mode_compliance_q <= 1'b0;
			mode_loopback_q <= 1'sb0;
			refclk_observation_q <= 1'b0;
			sym_path_reset_o <= 1'b1;
			packet_buffer_flush_o <= 1'b1;
			packet_admission_enable_o <= 1'b0;
			crr_ready_o <= 1'b0;
			crr_detect_done_o <= 1'b0;
			crr_receiver_present_o <= 1'b0;
			crr_rate_done_o <= 1'b0;
			crr_rate_fail_o <= 1'b0;
			crr_power_done_o <= 1'b0;
			crr_power_fail_o <= 1'b0;
			crr_tx_electrical_idle_active_o <= 1'b1;
			crr_rx_electrical_idle_o <= 1'b1;
			crr_rx_aligned_o <= 1'b0;
			crr_fault_o <= 1'b0;
			crr_fault_code_o <= 8'h00;
		end
		else begin
			crr_detect_done_o <= 1'b0;
			crr_rate_done_o <= 1'b0;
			crr_rate_fail_o <= 1'b0;
			crr_power_done_o <= 1'b0;
			crr_power_fail_o <= 1'b0;
			crr_fault_o <= 1'b0;
			packet_buffer_flush_o <= 1'b0;
			refclk_observation_q <= pcie_refclk_p_i ^ pcie_refclk_n_i;
			crr_tx_electrical_idle_active_o <= gt_tx_electrical_idle_active_i;
			if (!lt_gt_detect_req_i)
				detect_armed_q <= 1'b1;
			if (!lt_gt_rate_req_i)
				rate_armed_q <= 1'b1;
			if (!lt_gt_power_req_i)
				power_armed_q <= 1'b1;
			if (operation_timer_q != 0)
				operation_timer_q <= operation_timer_q - 1'b1;
			if (gt_rx_electrical_idle_i == crr_rx_electrical_idle_o)
				rx_ei_filter_count_q <= 1'sb0;
			else if (rx_ei_filter_count_q != 32'hffffffff) begin
				rx_ei_filter_count_q <= rx_ei_filter_count_q + 1'b1;
				if (gt_rx_electrical_idle_i && ((rx_ei_filter_count_q + 1'b1) >= pcie_gen12_phy_timing_pkg_RX_EI_ASSERT_STABLE_CYCLES)) begin
					crr_rx_electrical_idle_o <= 1'b1;
					crr_rx_aligned_o <= 1'b0;
					rx_ei_filter_count_q <= 1'sb0;
				end
				else if (!gt_rx_electrical_idle_i && ((rx_ei_filter_count_q + 1'b1) >= pcie_gen12_phy_timing_pkg_RX_EI_DEASSERT_STABLE_CYCLES)) begin
					crr_rx_electrical_idle_o <= 1'b0;
					rx_ei_filter_count_q <= 1'sb0;
				end
			end
			if ((crr_rx_electrical_idle_o || !rx_byte_aligned_i) || sym_path_reset_o) begin
				rx_align_filter_count_q <= 1'sb0;
				crr_rx_aligned_o <= 1'b0;
			end
			else if (!crr_rx_aligned_o) begin
				if (rx_align_filter_count_q != 32'hffffffff)
					rx_align_filter_count_q <= rx_align_filter_count_q + 1'b1;
				if ((rx_align_filter_count_q + 1'b1) >= pcie_gen12_phy_timing_pkg_RX_ALIGNMENT_STABLE_CYCLES) begin
					crr_rx_aligned_o <= 1'b1;
					rx_align_filter_count_q <= 1'sb0;
				end
			end
			if (gt_fault_i) begin
				if (!gt_fault_reported_q) begin
					crr_fault_o <= 1'b1;
					crr_fault_code_o <= (gt_fault_code_i == 8'h00 ? 8'h0c : gt_fault_code_i);
					gt_fault_reported_q <= 1'b1;
				end
				if (|{crr_state_q == 5'd5, crr_state_q == 5'd6, crr_state_q == 5'd7, crr_state_q == 5'd8, crr_state_q == 5'd9, crr_state_q == 5'd10})
					crr_rate_fail_o <= 1'b1;
				if (|{crr_state_q == 5'd11, crr_state_q == 5'd12, crr_state_q == 5'd13, crr_state_q == 5'd14, crr_state_q == 5'd15, crr_state_q == 5'd16})
					crr_power_fail_o <= 1'b1;
				if (|{crr_state_q == 5'd3, crr_state_q == 5'd4}) begin
					crr_detect_done_o <= 1'b1;
					crr_receiver_present_o <= 1'b0;
				end
				crr_state_q <= 5'd0;
				operation_timer_q <= RESET_TIMEOUT_CYCLES;
				clock_stable_count_q <= 1'sb0;
				reset_timeout_reported_q <= 1'b0;
				crr_ready_o <= 1'b0;
				sym_path_reset_o <= 1'b1;
				packet_admission_enable_o <= 1'b0;
				packet_buffer_flush_o <= 1'b1;
			end
			else begin
				gt_fault_reported_q <= 1'b0;
				(* full_case, parallel_case *)
				case (crr_state_q)
					5'd0: begin
						crr_ready_o <= 1'b0;
						sym_path_reset_o <= 1'b1;
						packet_admission_enable_o <= 1'b0;
						mode_tx_electrical_idle_q <= 1'b1;
						current_power_q <= 2'b00;
						crr_current_rate_o <= 1'b0;
						if (((gt_ready_i && gt_sym_clk_stable_i) && gt_sym_rst_ni) && gt_buffer_reinit_done_i) begin
							if ((clock_stable_count_q + 1'b1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES) begin
								clock_stable_count_q <= 1'sb0;
								sym_path_reset_o <= 1'b0;
								crr_state_q <= 5'd1;
							end
							else
								clock_stable_count_q <= clock_stable_count_q + 1'b1;
						end
						else
							clock_stable_count_q <= 1'sb0;
						if ((operation_timer_q == 0) && !reset_timeout_reported_q) begin
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0d;
							reset_timeout_reported_q <= 1'b1;
						end
					end
					5'd1: begin
						crr_ready_o <= 1'b0;
						packet_admission_enable_o <= 1'b0;
						if ((!gt_ready_i || !gt_sym_clk_stable_i) || !gt_sym_rst_ni) begin
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
							sym_path_reset_o <= 1'b1;
							clock_stable_count_q <= 1'sb0;
						end
						else if (phy_sym_rst_ctrl_sync_q[1]) begin
							crr_ready_o <= 1'b1;
							packet_admission_enable_o <= 1'b1;
							reset_timeout_reported_q <= 1'b0;
							crr_state_q <= 5'd2;
						end
					end
					5'd2: begin
						crr_ready_o <= (((gt_ready_i && gt_sym_clk_stable_i) && gt_sym_rst_ni) && phy_sym_rst_ctrl_sync_q[1]) && !sym_path_reset_o;
						packet_admission_enable_o <= crr_ready_o && (current_power_q == 2'b00);
						mode_tx_electrical_idle_q <= lt_gt_tx_electrical_idle_i;
						mode_rx_polarity_q <= lt_gt_rx_polarity_invert_i;
						mode_tx_deemphasis_q <= lt_gt_tx_deemphasis_i;
						mode_tx_swing_q <= lt_gt_tx_swing_i;
						mode_tx_margin_q <= lt_gt_tx_margin_i;
						mode_compliance_q <= lt_gt_compliance_enable_i;
						mode_loopback_q <= lt_gt_loopback_mode_i;
						if ((lt_gt_rate_req_i && rate_armed_q) && (current_power_q == 2'b00)) begin
							rate_armed_q <= 1'b0;
							rate_target_q <= lt_gt_rate_target_gen2_i;
							packet_admission_enable_o <= 1'b0;
							operation_timer_q <= RATE_TIMEOUT_CYCLES;
							crr_state_q <= 5'd5;
						end
						else if (((lt_gt_detect_req_i && detect_armed_q) && crr_ready_o) && (current_power_q == 2'b00)) begin
							detect_armed_q <= 1'b0;
							packet_admission_enable_o <= 1'b0;
							mode_tx_electrical_idle_q <= 1'b1;
							operation_timer_q <= DETECT_TIMEOUT_CYCLES;
							crr_state_q <= 5'd3;
						end
						else if (lt_gt_power_req_i && power_armed_q) begin
							power_armed_q <= 1'b0;
							power_target_q <= lt_gt_power_state_i;
							operation_timer_q <= POWER_TIMEOUT_CYCLES;
							packet_admission_enable_o <= 1'b0;
							if (lt_gt_power_state_i == 2'b00) begin
								sym_path_reset_o <= 1'b1;
								crr_ready_o <= 1'b0;
								crr_state_q <= 5'd13;
							end
							else
								crr_state_q <= 5'd11;
						end
						else if ((current_power_q == 2'b00) && ((!gt_ready_i || !gt_sym_clk_stable_i) || !gt_sym_rst_ni)) begin
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0c;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
							reset_timeout_reported_q <= 1'b0;
							sym_path_reset_o <= 1'b1;
							packet_buffer_flush_o <= 1'b1;
							packet_admission_enable_o <= 1'b0;
							crr_ready_o <= 1'b0;
						end
					end
					5'd3: begin
						crr_ready_o <= 1'b0;
						packet_admission_enable_o <= 1'b0;
						if (gt_detect_done_i) begin
							crr_detect_done_o <= 1'b1;
							crr_receiver_present_o <= gt_receiver_present_i;
							crr_state_q <= 5'd2;
						end
						else if (gt_detect_busy_i)
							crr_state_q <= 5'd4;
						else if (operation_timer_q == 0) begin
							crr_detect_done_o <= 1'b1;
							crr_receiver_present_o <= 1'b0;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0a;
							crr_state_q <= 5'd2;
						end
					end
					5'd4: begin
						crr_ready_o <= 1'b0;
						packet_admission_enable_o <= 1'b0;
						if (gt_detect_done_i) begin
							crr_detect_done_o <= 1'b1;
							crr_receiver_present_o <= gt_receiver_present_i;
							crr_state_q <= 5'd2;
						end
						else if (operation_timer_q == 0) begin
							crr_detect_done_o <= 1'b1;
							crr_receiver_present_o <= 1'b0;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0a;
							crr_state_q <= 5'd2;
						end
					end
					5'd5: begin
						crr_ready_o <= 1'b0;
						packet_admission_enable_o <= 1'b0;
						if (tx_quiesced_i && !rx_packet_active_i) begin
							packet_buffer_flush_o <= 1'b1;
							mode_tx_electrical_idle_q <= 1'b1;
							crr_state_q <= 5'd6;
						end
						else if (operation_timer_q == 0) begin
							crr_rate_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h13;
							crr_state_q <= 5'd2;
						end
					end
					5'd6: begin
						crr_ready_o <= 1'b0;
						packet_admission_enable_o <= 1'b0;
						if (gt_tx_electrical_idle_active_i) begin
							sym_path_reset_o <= 1'b1;
							crr_state_q <= 5'd7;
						end
						else if (operation_timer_q == 0) begin
							crr_rate_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0b;
							crr_state_q <= 5'd2;
						end
					end
					5'd7:
						if (gt_rate_done_i) begin
							clock_stable_count_q <= 1'sb0;
							crr_state_q <= 5'd9;
						end
						else if (gt_rate_fail_i || (operation_timer_q == 0)) begin
							crr_rate_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0b;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
						else if (gt_rate_busy_i)
							crr_state_q <= 5'd8;
					5'd8:
						if (gt_rate_done_i) begin
							clock_stable_count_q <= 1'sb0;
							crr_state_q <= 5'd9;
						end
						else if (gt_rate_fail_i || (operation_timer_q == 0)) begin
							crr_rate_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0b;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
					5'd9: begin
						if (((gt_ready_i && gt_sym_clk_stable_i) && gt_sym_rst_ni) && gt_buffer_reinit_done_i) begin
							if ((clock_stable_count_q + 1'b1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES) begin
								clock_stable_count_q <= 1'sb0;
								sym_path_reset_o <= 1'b0;
								crr_state_q <= 5'd10;
							end
							else
								clock_stable_count_q <= clock_stable_count_q + 1'b1;
						end
						else
							clock_stable_count_q <= 1'sb0;
						if (operation_timer_q == 0) begin
							crr_rate_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0b;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
					end
					5'd10:
						if ((phy_sym_rst_ctrl_sync_q[1] && gt_ready_i) && gt_buffer_reinit_done_i) begin
							crr_current_rate_o <= rate_target_q;
							crr_rate_done_o <= 1'b1;
							crr_ready_o <= 1'b1;
							packet_admission_enable_o <= 1'b1;
							crr_state_q <= 5'd2;
						end
						else if (operation_timer_q == 0) begin
							crr_rate_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0b;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
					5'd11: begin
						crr_ready_o <= 1'b0;
						packet_admission_enable_o <= 1'b0;
						if (tx_quiesced_i && !rx_packet_active_i) begin
							packet_buffer_flush_o <= 1'b1;
							mode_tx_electrical_idle_q <= 1'b1;
							crr_state_q <= (power_target_q == 2'b01 ? 5'd13 : 5'd12);
						end
						else if (operation_timer_q == 0) begin
							crr_power_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h09;
							crr_state_q <= 5'd2;
						end
					end
					5'd12:
						if (gt_tx_electrical_idle_active_i) begin
							sym_path_reset_o <= 1'b1;
							crr_state_q <= 5'd13;
						end
						else if (operation_timer_q == 0) begin
							crr_power_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h09;
							crr_state_q <= 5'd2;
						end
					5'd13:
						if (gt_power_done_i) begin
							current_power_q <= power_target_q;
							if (power_target_q == 2'b00) begin
								clock_stable_count_q <= 1'sb0;
								crr_state_q <= 5'd15;
							end
							else begin
								crr_power_done_o <= 1'b1;
								crr_state_q <= 5'd2;
							end
						end
						else if (gt_power_fail_i || (operation_timer_q == 0)) begin
							crr_power_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0d;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
						else if (gt_power_busy_i)
							crr_state_q <= 5'd14;
					5'd14:
						if (gt_power_done_i) begin
							current_power_q <= power_target_q;
							if (power_target_q == 2'b00) begin
								clock_stable_count_q <= 1'sb0;
								crr_state_q <= 5'd15;
							end
							else begin
								crr_power_done_o <= 1'b1;
								crr_state_q <= 5'd2;
							end
						end
						else if (gt_power_fail_i || (operation_timer_q == 0)) begin
							crr_power_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0d;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
					5'd15: begin
						if (((gt_ready_i && gt_sym_clk_stable_i) && gt_sym_rst_ni) && gt_buffer_reinit_done_i) begin
							if ((clock_stable_count_q + 1'b1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES) begin
								clock_stable_count_q <= 1'sb0;
								sym_path_reset_o <= 1'b0;
								crr_state_q <= 5'd16;
							end
							else
								clock_stable_count_q <= clock_stable_count_q + 1'b1;
						end
						else
							clock_stable_count_q <= 1'sb0;
						if (operation_timer_q == 0) begin
							crr_power_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0d;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
					end
					5'd16:
						if ((phy_sym_rst_ctrl_sync_q[1] && gt_ready_i) && gt_buffer_reinit_done_i) begin
							crr_power_done_o <= 1'b1;
							crr_ready_o <= 1'b1;
							packet_admission_enable_o <= 1'b1;
							crr_state_q <= 5'd2;
						end
						else if (operation_timer_q == 0) begin
							crr_power_fail_o <= 1'b1;
							crr_fault_o <= 1'b1;
							crr_fault_code_o <= 8'h0d;
							crr_state_q <= 5'd0;
							operation_timer_q <= RESET_TIMEOUT_CYCLES;
						end
					default: begin
						crr_state_q <= 5'd0;
						operation_timer_q <= RESET_TIMEOUT_CYCLES;
						sym_path_reset_o <= 1'b1;
						packet_admission_enable_o <= 1'b0;
						packet_buffer_flush_o <= 1'b1;
						crr_ready_o <= 1'b0;
					end
				endcase
			end
		end
	initial _sv2v_0 = 0;
endmodule
