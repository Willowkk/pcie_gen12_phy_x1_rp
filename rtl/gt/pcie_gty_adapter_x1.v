`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

`ifdef GT_BEHAV_MODEL
module pcie_gty_adapter_x1 (
	ctrl_clk_i,
	ctrl_rst_ni,
	pcie_refclk_p_i,
	pcie_refclk_n_i,
	pcie_rx_p_i,
	pcie_rx_n_i,
	pcie_tx_p_o,
	pcie_tx_n_o,
	gt_sym_clk_o,
	gt_sym_rst_no,
	gt_sym_clk_stable_o,
	gt_buffer_reinit_done_o,
	tx_symbol_data_i,
	tx_symbol_is_k_i,
	rx_symbol_data_o,
	rx_symbol_is_k_o,
	rx_symbol_disparity_error_o,
	rx_symbol_code_error_o,
	rx_symbol_is_comma_o,
	rx_symbol_valid_o,
	rx_byte_aligned_o,
	rx_realign_event_o,
	gt_rx_clkcor_count_o,
	gt_rx_buffer_status_o,
	gt_tx_buffer_fault_o,
	gt_detect_req_i,
	gt_detect_busy_o,
	gt_detect_done_o,
	gt_receiver_present_o,
	gt_rate_req_i,
	gt_rate_target_gen2_i,
	gt_rate_busy_o,
	gt_rate_done_o,
	gt_rate_fail_o,
	gt_tx_electrical_idle_i,
	gt_tx_electrical_idle_active_o,
	gt_rx_electrical_idle_o,
	gt_power_req_i,
	gt_power_state_i,
	gt_power_busy_o,
	gt_power_done_o,
	gt_power_fail_o,
	gt_rx_polarity_invert_i,
	gt_tx_deemphasis_i,
	gt_tx_swing_i,
	gt_tx_margin_i,
	gt_compliance_enable_i,
	gt_loopback_mode_i,
	gt_ready_o,
	gt_fault_o,
	gt_fault_code_o
);
	parameter [31:0] SIM_TIME_SCALE = 1;
	parameter [2:0] BEHAV_DETECT_STATUS = 3'b011;
	parameter [0:0] BEHAV_DETECT_TIMEOUT = 1'b0;
	parameter [0:0] BEHAV_RATE_FAIL = 1'b0;
	parameter [0:0] BEHAV_POWER_FAIL = 1'b0;
	parameter [0:0] BEHAV_LINK_POLARITY_INVERTED = 1'b0;
	parameter [31:0] BEHAV_ELASTIC_DEPTH_PAIRS = 16;
	parameter [31:0] BEHAV_ELASTIC_CORRECTION_MODE = 0;
	parameter [0:0] BEHAV_INJECT_CODE_ERROR = 1'b0;
	parameter [0:0] BEHAV_INJECT_DISPARITY_ERROR = 1'b0;
	parameter [0:0] BEHAV_INJECT_RXBUF_UNDERFLOW = 1'b0;
	parameter [0:0] BEHAV_INJECT_RXBUF_OVERFLOW = 1'b0;
	parameter [0:0] BEHAV_INJECT_TXBUF_FAULT = 1'b0;
	// TODO(Wizard): Replace these placeholder native TXRATE/RXRATE encodings
	// with the values from the final GT Wizard wrapper.
	parameter [2:0] WIZARD_RATE_CODE_GEN1 = 3'b000;
	parameter [2:0] WIZARD_RATE_CODE_GEN2 = 3'b000;
	// TODO(Wizard): Replace these placeholder rate-mode values with the values
	// from the final GT Wizard wrapper.
	parameter [0:0] WIZARD_TX_RATE_MODE = 1'b0;
	parameter [0:0] WIZARD_RX_RATE_MODE = 1'b0;
	// TODO(Wizard): Replace this placeholder RXELECIDLEMODE value with the value
	// from the final GT Wizard wrapper.
	parameter [1:0] WIZARD_RX_EI_MODE = 2'b00;
	// TODO(Wizard): Freeze RX LPM-versus-DFE selection and any static board-only
	// TX polarity setting from the final Wizard/electrical configuration.
	parameter [0:0] WIZARD_RX_LPM_ENABLE = 1'b0;
	parameter [0:0] WIZARD_TX_POLARITY = 1'b0;
	// TODO(Wizard): Freeze the TXCTRL0/TXCTRL1 low-bit values which make the
	// first Compliance K28.5 use negative-current-disparity semantics.
	parameter [1:0] WIZARD_COMPLIANCE_TXCTRL0_LOW = 2'b00;
	parameter [1:0] WIZARD_COMPLIANCE_TXCTRL1_LOW = 2'b00;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	input wire pcie_refclk_p_i;
	input wire pcie_refclk_n_i;
	input wire pcie_rx_p_i;
	input wire pcie_rx_n_i;
	output wire pcie_tx_p_o;
	output wire pcie_tx_n_o;
	output wire gt_sym_clk_o;
	output wire gt_sym_rst_no;
	output wire gt_sym_clk_stable_o;
	output wire gt_buffer_reinit_done_o;
	input wire [15:0] tx_symbol_data_i;
	input wire [1:0] tx_symbol_is_k_i;
	output wire [15:0] rx_symbol_data_o;
	output wire [1:0] rx_symbol_is_k_o;
	output wire [1:0] rx_symbol_disparity_error_o;
	output wire [1:0] rx_symbol_code_error_o;
	output wire [1:0] rx_symbol_is_comma_o;
	output wire rx_symbol_valid_o;
	output wire rx_byte_aligned_o;
	output wire rx_realign_event_o;
	output wire [1:0] gt_rx_clkcor_count_o;
	output wire [2:0] gt_rx_buffer_status_o;
	output wire gt_tx_buffer_fault_o;
	input wire gt_detect_req_i;
	output wire gt_detect_busy_o;
	output wire gt_detect_done_o;
	output wire gt_receiver_present_o;
	input wire gt_rate_req_i;
	input wire gt_rate_target_gen2_i;
	output wire gt_rate_busy_o;
	output wire gt_rate_done_o;
	output wire gt_rate_fail_o;
	input wire gt_tx_electrical_idle_i;
	output wire gt_tx_electrical_idle_active_o;
	output wire gt_rx_electrical_idle_o;
	input wire gt_power_req_i;
	input wire [1:0] gt_power_state_i;
	output wire gt_power_busy_o;
	output wire gt_power_done_o;
	output wire gt_power_fail_o;
	input wire gt_rx_polarity_invert_i;
	input wire gt_tx_deemphasis_i;
	input wire gt_tx_swing_i;
	input wire [2:0] gt_tx_margin_i;
	input wire gt_compliance_enable_i;
	input wire [2:0] gt_loopback_mode_i;
	output wire gt_ready_o;
	output wire gt_fault_o;
	output wire [7:0] gt_fault_code_o;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES = 16;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES = 32;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_EI_ASSERT_STABLE_CYCLES = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_EI_DEASSERT_STABLE_CYCLES = 16;
	localparam [31:0] pcie_gen12_phy_timing_pkg_SKP_SCHEDULE_INTERVAL_SYMBOLS = 1180;
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
	gty_behavioral_model #(
		.EI_ASSERT_STABLE_CYCLES(pcie_gen12_phy_timing_pkg_RX_EI_ASSERT_STABLE_CYCLES),
		.EI_DEASSERT_STABLE_CYCLES(pcie_gen12_phy_timing_pkg_RX_EI_DEASSERT_STABLE_CYCLES),
		.DETECT_LATENCY_CYCLES(pcie_gen12_phy_timing_pkg_sim_scaled_cycles(pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES, SIM_TIME_SCALE)),
		.RATE_LATENCY_CYCLES(pcie_gen12_phy_timing_pkg_sim_scaled_cycles(pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES, SIM_TIME_SCALE)),
		.POWER_LATENCY_CYCLES(pcie_gen12_phy_timing_pkg_sim_scaled_cycles(pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES, SIM_TIME_SCALE)),
		.READY_LATENCY_CYCLES(pcie_gen12_phy_timing_pkg_sim_scaled_cycles(pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES, SIM_TIME_SCALE)),
		.DETECT_TIMEOUT_CYCLES(pcie_gen12_phy_timing_pkg_timer_default_cycles(6'h13, SIM_TIME_SCALE)),
		.RATE_TIMEOUT_CYCLES(pcie_gen12_phy_timing_pkg_timer_default_cycles(6'h14, SIM_TIME_SCALE)),
		.POWER_TIMEOUT_CYCLES(pcie_gen12_phy_timing_pkg_timer_default_cycles(6'h15, SIM_TIME_SCALE)),
		.ELASTIC_DEPTH_PAIRS(BEHAV_ELASTIC_DEPTH_PAIRS),
		.CLOCK_COR_INTERVAL(590),
		.DETECT_STATUS(BEHAV_DETECT_STATUS),
		.DETECT_TIMEOUT(BEHAV_DETECT_TIMEOUT),
		.RATE_FAIL(BEHAV_RATE_FAIL),
		.POWER_FAIL(BEHAV_POWER_FAIL),
		.LINK_POLARITY_INVERTED(BEHAV_LINK_POLARITY_INVERTED),
		.INJECT_CODE_ERROR(BEHAV_INJECT_CODE_ERROR),
		.INJECT_DISPARITY_ERROR(BEHAV_INJECT_DISPARITY_ERROR),
		.INJECT_RXBUF_UNDERFLOW(BEHAV_INJECT_RXBUF_UNDERFLOW),
		.INJECT_RXBUF_OVERFLOW(BEHAV_INJECT_RXBUF_OVERFLOW),
		.INJECT_TXBUF_FAULT(BEHAV_INJECT_TXBUF_FAULT),
		.ELASTIC_CORRECTION_MODE(BEHAV_ELASTIC_CORRECTION_MODE)
	) u_gty_behavioral_model(
		.ctrl_clk_i(ctrl_clk_i),
		.ctrl_rst_ni(ctrl_rst_ni),
		.sym_clk_o(gt_sym_clk_o),
		.sym_rst_no(gt_sym_rst_no),
		.tx_symbol_data_i(tx_symbol_data_i),
		.tx_symbol_is_k_i(tx_symbol_is_k_i),
		.rx_symbol_data_o(rx_symbol_data_o),
		.rx_symbol_is_k_o(rx_symbol_is_k_o),
		.rx_symbol_disparity_error_o(rx_symbol_disparity_error_o),
		.rx_symbol_code_error_o(rx_symbol_code_error_o),
		.rx_symbol_is_comma_o(rx_symbol_is_comma_o),
		.rx_symbol_valid_o(rx_symbol_valid_o),
		.rx_byte_aligned_o(rx_byte_aligned_o),
		.rx_realign_event_o(rx_realign_event_o),
		.gt_rx_clkcor_count_o(gt_rx_clkcor_count_o),
		.gt_rx_buffer_status_o(gt_rx_buffer_status_o),
		.gt_tx_buffer_fault_o(gt_tx_buffer_fault_o),
		.gt_detect_req_i(gt_detect_req_i),
		.gt_detect_busy_o(gt_detect_busy_o),
		.gt_detect_done_o(gt_detect_done_o),
		.gt_receiver_present_o(gt_receiver_present_o),
		.gt_rate_req_i(gt_rate_req_i),
		.gt_rate_target_gen2_i(gt_rate_target_gen2_i),
		.gt_rate_busy_o(gt_rate_busy_o),
		.gt_rate_done_o(gt_rate_done_o),
		.gt_rate_fail_o(gt_rate_fail_o),
		.gt_tx_electrical_idle_i(gt_tx_electrical_idle_i),
		.gt_tx_electrical_idle_active_o(gt_tx_electrical_idle_active_o),
		.gt_rx_electrical_idle_o(gt_rx_electrical_idle_o),
		.gt_power_req_i(gt_power_req_i),
		.gt_power_state_i(gt_power_state_i),
		.gt_power_busy_o(gt_power_busy_o),
		.gt_power_done_o(gt_power_done_o),
		.gt_power_fail_o(gt_power_fail_o),
		.gt_rx_polarity_invert_i(gt_rx_polarity_invert_i),
		.gt_tx_deemphasis_i(gt_tx_deemphasis_i),
		.gt_tx_swing_i(gt_tx_swing_i),
		.gt_tx_margin_i(gt_tx_margin_i),
		.gt_compliance_enable_i(gt_compliance_enable_i),
		.gt_loopback_mode_i(gt_loopback_mode_i),
		.gt_ready_o(gt_ready_o),
		.gt_fault_o(gt_fault_o),
		.gt_fault_code_o(gt_fault_code_o),
		.pcie_rx_p_i(pcie_rx_p_i),
		.pcie_rx_n_i(pcie_rx_n_i),
		.pcie_tx_p_o(pcie_tx_p_o),
		.pcie_tx_n_o(pcie_tx_n_o)
	);
	(* ASYNC_REG = "TRUE" *) reg [1:0] behav_sym_rst_ctrl_sync_q;
	always @(posedge ctrl_clk_i or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni)
			behav_sym_rst_ctrl_sync_q <= 2'b00;
		else
			behav_sym_rst_ctrl_sync_q <= {behav_sym_rst_ctrl_sync_q[0], gt_sym_rst_no};
	assign gt_sym_clk_stable_o = gt_ready_o && behav_sym_rst_ctrl_sync_q[1];
	assign gt_buffer_reinit_done_o = gt_ready_o && behav_sym_rst_ctrl_sync_q[1];
endmodule
`else
module pcie_gty_adapter_x1 (
	ctrl_clk_i,
	ctrl_rst_ni,
	pcie_refclk_p_i,
	pcie_refclk_n_i,
	pcie_rx_p_i,
	pcie_rx_n_i,
	pcie_tx_p_o,
	pcie_tx_n_o,
	gt_sym_clk_o,
	gt_sym_rst_no,
	gt_sym_clk_stable_o,
	gt_buffer_reinit_done_o,
	tx_symbol_data_i,
	tx_symbol_is_k_i,
	rx_symbol_data_o,
	rx_symbol_is_k_o,
	rx_symbol_disparity_error_o,
	rx_symbol_code_error_o,
	rx_symbol_is_comma_o,
	rx_symbol_valid_o,
	rx_byte_aligned_o,
	rx_realign_event_o,
	gt_rx_clkcor_count_o,
	gt_rx_buffer_status_o,
	gt_tx_buffer_fault_o,
	gt_detect_req_i,
	gt_detect_busy_o,
	gt_detect_done_o,
	gt_receiver_present_o,
	gt_rate_req_i,
	gt_rate_target_gen2_i,
	gt_rate_busy_o,
	gt_rate_done_o,
	gt_rate_fail_o,
	gt_tx_electrical_idle_i,
	gt_tx_electrical_idle_active_o,
	gt_rx_electrical_idle_o,
	gt_power_req_i,
	gt_power_state_i,
	gt_power_busy_o,
	gt_power_done_o,
	gt_power_fail_o,
	gt_rx_polarity_invert_i,
	gt_tx_deemphasis_i,
	gt_tx_swing_i,
	gt_tx_margin_i,
	gt_compliance_enable_i,
	gt_loopback_mode_i,
	gt_ready_o,
	gt_fault_o,
	gt_fault_code_o
);
	reg _sv2v_0;
	parameter [31:0] SIM_TIME_SCALE = 1;
	parameter [2:0] BEHAV_DETECT_STATUS = 3'b011;
	parameter [0:0] BEHAV_DETECT_TIMEOUT = 1'b0;
	parameter [0:0] BEHAV_RATE_FAIL = 1'b0;
	parameter [0:0] BEHAV_POWER_FAIL = 1'b0;
	parameter [0:0] BEHAV_LINK_POLARITY_INVERTED = 1'b0;
	parameter [31:0] BEHAV_ELASTIC_DEPTH_PAIRS = 16;
	parameter [31:0] BEHAV_ELASTIC_CORRECTION_MODE = 0;
	parameter [0:0] BEHAV_INJECT_CODE_ERROR = 1'b0;
	parameter [0:0] BEHAV_INJECT_DISPARITY_ERROR = 1'b0;
	parameter [0:0] BEHAV_INJECT_RXBUF_UNDERFLOW = 1'b0;
	parameter [0:0] BEHAV_INJECT_RXBUF_OVERFLOW = 1'b0;
	parameter [0:0] BEHAV_INJECT_TXBUF_FAULT = 1'b0;
	// TODO(Wizard): Replace these placeholder native TXRATE/RXRATE encodings
	// with the values from the final GT Wizard wrapper.
	parameter [2:0] WIZARD_RATE_CODE_GEN1 = 3'b000;
	parameter [2:0] WIZARD_RATE_CODE_GEN2 = 3'b000;
	// TODO(Wizard): Replace these placeholder rate-mode values with the values
	// from the final GT Wizard wrapper.
	parameter [0:0] WIZARD_TX_RATE_MODE = 1'b0;
	parameter [0:0] WIZARD_RX_RATE_MODE = 1'b0;
	// TODO(Wizard): Replace this placeholder RXELECIDLEMODE value with the value
	// from the final GT Wizard wrapper.
	parameter [1:0] WIZARD_RX_EI_MODE = 2'b00;
	// TODO(Wizard): Freeze RX LPM-versus-DFE selection and any static board-only
	// TX polarity setting from the final Wizard/electrical configuration.
	parameter [0:0] WIZARD_RX_LPM_ENABLE = 1'b0;
	parameter [0:0] WIZARD_TX_POLARITY = 1'b0;
	// TODO(Wizard): Freeze the TXCTRL0/TXCTRL1 low-bit values which make the
	// first Compliance K28.5 use negative-current-disparity semantics.
	parameter [1:0] WIZARD_COMPLIANCE_TXCTRL0_LOW = 2'b00;
	parameter [1:0] WIZARD_COMPLIANCE_TXCTRL1_LOW = 2'b00;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	input wire pcie_refclk_p_i;
	input wire pcie_refclk_n_i;
	input wire pcie_rx_p_i;
	input wire pcie_rx_n_i;
	output wire pcie_tx_p_o;
	output wire pcie_tx_n_o;
	output wire gt_sym_clk_o;
	output wire gt_sym_rst_no;
	output wire gt_sym_clk_stable_o;
	output wire gt_buffer_reinit_done_o;
	input wire [15:0] tx_symbol_data_i;
	input wire [1:0] tx_symbol_is_k_i;
	output wire [15:0] rx_symbol_data_o;
	output wire [1:0] rx_symbol_is_k_o;
	output wire [1:0] rx_symbol_disparity_error_o;
	output wire [1:0] rx_symbol_code_error_o;
	output wire [1:0] rx_symbol_is_comma_o;
	output wire rx_symbol_valid_o;
	output wire rx_byte_aligned_o;
	output wire rx_realign_event_o;
	output wire [1:0] gt_rx_clkcor_count_o;
	output reg [2:0] gt_rx_buffer_status_o;
	output wire gt_tx_buffer_fault_o;
	input wire gt_detect_req_i;
	output wire gt_detect_busy_o;
	output reg gt_detect_done_o;
	output reg gt_receiver_present_o;
	input wire gt_rate_req_i;
	input wire gt_rate_target_gen2_i;
	output wire gt_rate_busy_o;
	output reg gt_rate_done_o;
	output reg gt_rate_fail_o;
	input wire gt_tx_electrical_idle_i;
	output wire gt_tx_electrical_idle_active_o;
	output reg gt_rx_electrical_idle_o;
	input wire gt_power_req_i;
	input wire [1:0] gt_power_state_i;
	output wire gt_power_busy_o;
	output reg gt_power_done_o;
	output reg gt_power_fail_o;
	input wire gt_rx_polarity_invert_i;
	input wire gt_tx_deemphasis_i;
	input wire gt_tx_swing_i;
	input wire [2:0] gt_tx_margin_i;
	input wire gt_compliance_enable_i;
	input wire [2:0] gt_loopback_mode_i;
	output reg gt_ready_o;
	output reg gt_fault_o;
	output reg [7:0] gt_fault_code_o;
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
	reg [4:0] ctrl_state_q;
	reg [31:0] op_count_q;
	reg [31:0] stable_count_q;
	reg detect_consumed_q;
	reg rate_consumed_q;
	reg power_consumed_q;
	reg detect_fault_pending_q;
	reg detect_result_q;
	reg rate_target_q;
	reg current_rate_q;
	reg [1:0] power_target_q;
	reg [1:0] current_power_q;
	reg [1:0] detect_saved_power_q;
	// TODO(Wizard): Recheck the primitive DATA/CTRL port widths and unused high
	// bit tie-offs against the exact Vivado-version-generated GTYE4 instance.
	wire gt_refclk;
	wire gt_refclk_div2;
	wire native_txoutclk;
	wire native_rxoutclk;
	wire [127:0] native_txdata;
	wire [127:0] native_rxdata;
	wire [15:0] native_txctrl0;
	wire [15:0] native_txctrl1;
	wire [7:0] native_txctrl2;
	wire [15:0] native_rxctrl0;
	wire [15:0] native_rxctrl1;
	wire [7:0] native_rxctrl2;
	wire [7:0] native_rxctrl3;
	wire [1:0] native_rxdatavalid;
	wire native_rxbyteisaligned;
	wire native_rxbyterealign;
	wire native_rxcommadet;
	wire [1:0] native_rxclkcorcnt;
	wire [2:0] native_rxbufstatus;
	wire [1:0] native_txbufstatus;
	wire native_rxelecidle;
	wire native_phystatus;
	wire native_rxcdrlock;
	reg native_txbuf_fault_prev_q;
	reg native_txbuf_fault_event_q;
	reg native_txbuf_fault_toggle_sym_q;
	wire [2:0] native_rxstatus;
	wire native_txratedone;
	wire native_rxratedone;
	wire native_txresetdone;
	wire native_rxresetdone;
	wire native_cplllock;
	wire native_gtpowergood;
	reg [1:0] native_txpd_q;
	reg [1:0] native_rxpd_q;
	reg [2:0] native_rate_q;
	wire [1:0] native_txdeemph;
	reg native_txdetectrx_q;
	reg native_txelecidle_q;
	reg native_gttxreset_q;
	reg native_gtrxreset_q;
	reg native_rxbufreset_q;
	reg native_txuserrdy_q;
	reg native_rxuserrdy_q;
	reg sym_release_ctrl_q;
	reg data_enable_ctrl_q;
	reg [14:0] native_ctrl_desired;
	reg [14:0] native_ctrl_source_q;
	reg [14:0] native_ctrl_applied_q;
	reg native_ctrl_req_toggle_q;
	reg native_ctrl_ack_toggle_sym_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] native_ctrl_req_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] native_ctrl_ack_sync_q;
	reg compliance_pending_sym_q;
	wire compliance_force_now;
	reg phystatus_toggle_sym_q;
	reg txratedone_toggle_sym_q;
	reg rxratedone_toggle_sym_q;
	reg [2:0] phystatus_value_sym_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] phystatus_toggle_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] txratedone_toggle_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] rxratedone_toggle_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] txbuf_fault_toggle_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [2:0] phystatus_value_meta_q;
	(* ASYNC_REG = "TRUE" *) reg [2:0] phystatus_value_sync_q;
	reg phystatus_snapshot_q;
	reg txratedone_snapshot_q;
	reg rxratedone_snapshot_q;
	reg txbuf_fault_snapshot_q;
	reg txrate_seen_q;
	reg rxrate_seen_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] txresetdone_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] rxresetdone_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] cplllock_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] gtpowergood_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] txei_feedback_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] rxelecidle_sync_q;
	reg [31:0] rx_ei_assert_count_q;
	reg [31:0] rx_ei_deassert_count_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] sym_reset_release_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] data_enable_sym_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] txei_feedback_sym_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] rxei_gate_sym_q;
	(* ASYNC_REG = "TRUE" *) reg gt_sym_rst_ctrl_meta_q;
	(* ASYNC_REG = "TRUE" *) reg gt_sym_rst_ctrl_q;
	wire sym_async_reset_ni;
	// TODO(Wizard): Replace the unused DATA/CTRL high-bit zero placeholders with
	// the static tie-offs emitted by the final Wizard wrapper.
	assign native_txdata = {112'h0000000000000000000000000000, tx_symbol_data_i};
	localparam [7:0] pcie_gen12_phy_pkg_K_COM = 8'hbc;
	assign compliance_force_now = ((compliance_pending_sym_q && native_ctrl_applied_q[0]) && tx_symbol_is_k_i[0]) && (tx_symbol_data_i[7:0] == pcie_gen12_phy_pkg_K_COM);
	assign native_txctrl0 = {14'h0000, (compliance_force_now ? WIZARD_COMPLIANCE_TXCTRL0_LOW : 2'b00)};
	assign native_txctrl1 = {14'h0000, (compliance_force_now ? WIZARD_COMPLIANCE_TXCTRL1_LOW : 2'b00)};
	assign native_txctrl2 = {6'h00, tx_symbol_is_k_i};
	// TODO(Wizard): Freeze the normalized one-bit deemphasis to GTYE4's
	// two-bit TXDEEMPH mapping from the final Wizard electrical configuration.
	assign native_txdeemph = {1'b0, native_ctrl_applied_q[8]};
	always @(*) begin
		if (_sv2v_0)
			;
		native_ctrl_desired[14-:3] = native_rate_q;
		native_ctrl_desired[11] = native_txdetectrx_q;
		native_ctrl_desired[10] = native_txelecidle_q;
		native_ctrl_desired[9] = gt_rx_polarity_invert_i;
		native_ctrl_desired[8] = gt_tx_deemphasis_i;
		native_ctrl_desired[7] = gt_tx_swing_i;
		native_ctrl_desired[6-:3] = gt_tx_margin_i;
		native_ctrl_desired[3-:3] = gt_loopback_mode_i;
		native_ctrl_desired[0] = gt_compliance_enable_i;
	end
	assign rx_symbol_data_o = native_rxdata[15:0];
	assign rx_symbol_code_error_o = native_rxctrl3[1:0];
	assign rx_symbol_is_k_o = native_rxctrl0[1:0] & ~native_rxctrl3[1:0];
	assign rx_symbol_disparity_error_o = native_rxctrl1[1:0] & ~native_rxctrl3[1:0];
	assign rx_symbol_is_comma_o = native_rxctrl2[1:0] & ~native_rxctrl3[1:0];
	assign rx_byte_aligned_o = native_rxbyteisaligned;
	assign rx_realign_event_o = native_rxbyterealign;
	assign gt_rx_clkcor_count_o = native_rxclkcorcnt;
	assign gt_tx_buffer_fault_o = native_txbuf_fault_event_q;
	assign rx_symbol_valid_o = ((((&native_rxdatavalid && data_enable_sym_q[1]) && gt_sym_rst_no) && native_rxcdrlock) && !rxei_gate_sym_q[1]) && (((native_rxbufstatus == 3'b000) || (native_rxbufstatus == 3'b001)) || (native_rxbufstatus == 3'b010));
	assign gt_tx_electrical_idle_active_o = txei_feedback_sync_q[1];
	assign gt_sym_clk_stable_o = gt_ready_o && gt_sym_rst_ctrl_q;
	assign gt_buffer_reinit_done_o = gt_ready_o && gt_sym_rst_ctrl_q;
	always @(*) begin
		if (_sv2v_0)
			;
		case (native_rxbufstatus)
			3'b000: gt_rx_buffer_status_o = 3'b000;
			3'b001: gt_rx_buffer_status_o = 3'b001;
			3'b010: gt_rx_buffer_status_o = 3'b010;
			3'b101: gt_rx_buffer_status_o = 3'b101;
			3'b110: gt_rx_buffer_status_o = 3'b110;
			default: gt_rx_buffer_status_o = native_rxbufstatus;
		endcase
	end
	assign gt_detect_busy_o = (((((ctrl_state_q == 5'd3) || (ctrl_state_q == 5'd4)) || (ctrl_state_q == 5'd5)) || (ctrl_state_q == 5'd6)) || (ctrl_state_q == 5'd7)) || (ctrl_state_q == 5'd8);
	assign gt_rate_busy_o = (((ctrl_state_q == 5'd9) || (ctrl_state_q == 5'd10)) || (ctrl_state_q == 5'd11)) || (ctrl_state_q == 5'd12);
	assign gt_power_busy_o = ((ctrl_state_q == 5'd13) || (ctrl_state_q == 5'd14)) || (ctrl_state_q == 5'd15);
	always @(posedge gt_sym_clk_o or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni) begin
			native_txbuf_fault_prev_q <= 1'b0;
			native_txbuf_fault_event_q <= 1'b0;
			native_txbuf_fault_toggle_sym_q <= 1'b0;
		end
		else begin
			native_txbuf_fault_event_q <= (native_txbufstatus != 2'b00) && !native_txbuf_fault_prev_q;
			if ((native_txbufstatus != 2'b00) && !native_txbuf_fault_prev_q)
				native_txbuf_fault_toggle_sym_q <= ~native_txbuf_fault_toggle_sym_q;
			native_txbuf_fault_prev_q <= native_txbufstatus != 2'b00;
		end
	always @(posedge ctrl_clk_i or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni) begin
			native_ctrl_source_q[14-:3] <= WIZARD_RATE_CODE_GEN1;
			native_ctrl_source_q[11] <= 1'b0;
			native_ctrl_source_q[10] <= 1'b1;
			native_ctrl_source_q[9] <= 1'b0;
			native_ctrl_source_q[8] <= 1'b0;
			native_ctrl_source_q[7] <= 1'b0;
			native_ctrl_source_q[6-:3] <= 3'b000;
			native_ctrl_source_q[3-:3] <= 3'b000;
			native_ctrl_source_q[0] <= 1'b0;
			native_ctrl_req_toggle_q <= 1'b0;
			native_ctrl_ack_sync_q <= 2'b00;
		end
		else begin
			native_ctrl_ack_sync_q <= {native_ctrl_ack_sync_q[0], native_ctrl_ack_toggle_sym_q};
			if ((native_ctrl_ack_sync_q[1] == native_ctrl_req_toggle_q) && (native_ctrl_source_q != native_ctrl_desired)) begin
				native_ctrl_source_q <= native_ctrl_desired;
				native_ctrl_req_toggle_q <= ~native_ctrl_req_toggle_q;
			end
		end
	always @(posedge gt_sym_clk_o or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni) begin
			native_ctrl_req_sync_q <= 2'b00;
			native_ctrl_ack_toggle_sym_q <= 1'b0;
			native_ctrl_applied_q[14-:3] <= WIZARD_RATE_CODE_GEN1;
			native_ctrl_applied_q[11] <= 1'b0;
			native_ctrl_applied_q[10] <= 1'b1;
			native_ctrl_applied_q[9] <= 1'b0;
			native_ctrl_applied_q[8] <= 1'b0;
			native_ctrl_applied_q[7] <= 1'b0;
			native_ctrl_applied_q[6-:3] <= 3'b000;
			native_ctrl_applied_q[3-:3] <= 3'b000;
			native_ctrl_applied_q[0] <= 1'b0;
			compliance_pending_sym_q <= 1'b0;
		end
		else begin
			if (compliance_force_now)
				compliance_pending_sym_q <= 1'b0;
			native_ctrl_req_sync_q <= {native_ctrl_req_sync_q[0], native_ctrl_req_toggle_q};
			if (native_ctrl_req_sync_q[1] != native_ctrl_ack_toggle_sym_q) begin
				if (native_ctrl_source_q[0] && !native_ctrl_applied_q[0])
					compliance_pending_sym_q <= 1'b1;
				else if (!native_ctrl_source_q[0])
					compliance_pending_sym_q <= 1'b0;
				native_ctrl_applied_q <= native_ctrl_source_q;
				native_ctrl_ack_toggle_sym_q <= native_ctrl_req_sync_q[1];
			end
		end
	assign sym_async_reset_ni = ctrl_rst_ni && sym_release_ctrl_q;
	always @(posedge gt_sym_clk_o or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni) begin
			phystatus_toggle_sym_q <= 1'b0;
			txratedone_toggle_sym_q <= 1'b0;
			rxratedone_toggle_sym_q <= 1'b0;
			phystatus_value_sym_q <= 3'b000;
		end
		else begin
			if (native_phystatus) begin
				phystatus_value_sym_q <= native_rxstatus;
				phystatus_toggle_sym_q <= ~phystatus_toggle_sym_q;
			end
			if (native_txratedone)
				txratedone_toggle_sym_q <= ~txratedone_toggle_sym_q;
			if (native_rxratedone)
				rxratedone_toggle_sym_q <= ~rxratedone_toggle_sym_q;
		end
	always @(posedge gt_sym_clk_o or negedge sym_async_reset_ni)
		if (!sym_async_reset_ni) begin
			sym_reset_release_q <= 2'b00;
			data_enable_sym_q <= 2'b00;
			txei_feedback_sym_q <= 2'b11;
			rxei_gate_sym_q <= 2'b11;
		end
		else begin
			if (!sym_release_ctrl_q)
				sym_reset_release_q <= 2'b00;
			else
				sym_reset_release_q <= {sym_reset_release_q[0], 1'b1};
			data_enable_sym_q <= {data_enable_sym_q[0], data_enable_ctrl_q};
			txei_feedback_sym_q <= {txei_feedback_sym_q[0], native_ctrl_applied_q[10]};
			rxei_gate_sym_q <= {rxei_gate_sym_q[0], gt_rx_electrical_idle_o};
		end
	assign gt_sym_rst_no = sym_reset_release_q[1];
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_EI_ASSERT_STABLE_CYCLES = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RX_EI_DEASSERT_STABLE_CYCLES = 16;
	always @(posedge ctrl_clk_i or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni) begin
			phystatus_toggle_sync_q <= 2'b00;
			txratedone_toggle_sync_q <= 2'b00;
			rxratedone_toggle_sync_q <= 2'b00;
			txbuf_fault_toggle_sync_q <= 2'b00;
			phystatus_value_meta_q <= 3'b000;
			phystatus_value_sync_q <= 3'b000;
			txresetdone_sync_q <= 2'b00;
			rxresetdone_sync_q <= 2'b00;
			cplllock_sync_q <= 2'b00;
			gtpowergood_sync_q <= 2'b00;
			txei_feedback_sync_q <= 2'b11;
			rxelecidle_sync_q <= 2'b11;
			gt_sym_rst_ctrl_meta_q <= 1'b0;
			gt_sym_rst_ctrl_q <= 1'b0;
			rx_ei_assert_count_q <= 1'sb0;
			rx_ei_deassert_count_q <= 1'sb0;
			gt_rx_electrical_idle_o <= 1'b1;
		end
		else begin
			phystatus_toggle_sync_q <= {phystatus_toggle_sync_q[0], phystatus_toggle_sym_q};
			txratedone_toggle_sync_q <= {txratedone_toggle_sync_q[0], txratedone_toggle_sym_q};
			rxratedone_toggle_sync_q <= {rxratedone_toggle_sync_q[0], rxratedone_toggle_sym_q};
			txbuf_fault_toggle_sync_q <= {txbuf_fault_toggle_sync_q[0], native_txbuf_fault_toggle_sym_q};
			phystatus_value_meta_q <= phystatus_value_sym_q;
			phystatus_value_sync_q <= phystatus_value_meta_q;
			txresetdone_sync_q <= {txresetdone_sync_q[0], native_txresetdone};
			rxresetdone_sync_q <= {rxresetdone_sync_q[0], native_rxresetdone};
			cplllock_sync_q <= {cplllock_sync_q[0], native_cplllock};
			gtpowergood_sync_q <= {gtpowergood_sync_q[0], native_gtpowergood};
			txei_feedback_sync_q <= {txei_feedback_sync_q[0], txei_feedback_sym_q[1]};
			rxelecidle_sync_q <= {rxelecidle_sync_q[0], native_rxelecidle};
			gt_sym_rst_ctrl_meta_q <= gt_sym_rst_no;
			gt_sym_rst_ctrl_q <= gt_sym_rst_ctrl_meta_q;
			if (rxelecidle_sync_q[1]) begin
				rx_ei_deassert_count_q <= 1'sb0;
				if (rx_ei_assert_count_q < pcie_gen12_phy_timing_pkg_RX_EI_ASSERT_STABLE_CYCLES)
					rx_ei_assert_count_q <= rx_ei_assert_count_q + 1'b1;
				if ((rx_ei_assert_count_q + 1) >= pcie_gen12_phy_timing_pkg_RX_EI_ASSERT_STABLE_CYCLES)
					gt_rx_electrical_idle_o <= 1'b1;
			end
			else begin
				rx_ei_assert_count_q <= 1'sb0;
				if (rx_ei_deassert_count_q < pcie_gen12_phy_timing_pkg_RX_EI_DEASSERT_STABLE_CYCLES)
					rx_ei_deassert_count_q <= rx_ei_deassert_count_q + 1'b1;
				if ((rx_ei_deassert_count_q + 1) >= pcie_gen12_phy_timing_pkg_RX_EI_DEASSERT_STABLE_CYCLES)
					gt_rx_electrical_idle_o <= 1'b0;
			end
		end
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES = 16;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES = 32;
	always @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin : native_control
		reg phystatus_changed;
		reg txrate_changed;
		reg rxrate_changed;
		reg txbuf_fault_changed;
		if (!ctrl_rst_ni) begin
			ctrl_state_q <= 5'd0;
			op_count_q <= 1'sb0;
			stable_count_q <= 1'sb0;
			detect_consumed_q <= 1'b0;
			rate_consumed_q <= 1'b0;
			power_consumed_q <= 1'b0;
			detect_fault_pending_q <= 1'b0;
			detect_result_q <= 1'b0;
			rate_target_q <= 1'b0;
			current_rate_q <= 1'b0;
			power_target_q <= 2'b00;
			current_power_q <= 2'b00;
			detect_saved_power_q <= 2'b00;
			phystatus_snapshot_q <= 1'b0;
			txratedone_snapshot_q <= 1'b0;
			rxratedone_snapshot_q <= 1'b0;
			txbuf_fault_snapshot_q <= 1'b0;
			txrate_seen_q <= 1'b0;
			rxrate_seen_q <= 1'b0;
			native_txpd_q <= 2'b00;
			native_rxpd_q <= 2'b00;
			native_rate_q <= WIZARD_RATE_CODE_GEN1;
			native_txdetectrx_q <= 1'b0;
			native_txelecidle_q <= 1'b1;
			native_gttxreset_q <= 1'b1;
			native_gtrxreset_q <= 1'b1;
			native_rxbufreset_q <= 1'b1;
			native_txuserrdy_q <= 1'b0;
			native_rxuserrdy_q <= 1'b0;
			sym_release_ctrl_q <= 1'b0;
			data_enable_ctrl_q <= 1'b0;
			gt_detect_done_o <= 1'b0;
			gt_receiver_present_o <= 1'b0;
			gt_rate_done_o <= 1'b0;
			gt_rate_fail_o <= 1'b0;
			gt_power_done_o <= 1'b0;
			gt_power_fail_o <= 1'b0;
			gt_ready_o <= 1'b0;
			gt_fault_o <= 1'b0;
			gt_fault_code_o <= 8'h00;
		end
		else begin
			phystatus_changed = phystatus_toggle_sync_q[1] ^ phystatus_snapshot_q;
			txrate_changed = txratedone_toggle_sync_q[1] ^ txratedone_snapshot_q;
			rxrate_changed = rxratedone_toggle_sync_q[1] ^ rxratedone_snapshot_q;
			txbuf_fault_changed = txbuf_fault_toggle_sync_q[1] ^ txbuf_fault_snapshot_q;
			gt_detect_done_o <= 1'b0;
			gt_receiver_present_o <= 1'b0;
			gt_rate_done_o <= 1'b0;
			gt_rate_fail_o <= 1'b0;
			gt_power_done_o <= 1'b0;
			gt_power_fail_o <= 1'b0;
			gt_fault_o <= 1'b0;
			gt_fault_code_o <= 8'h00;
			if (txbuf_fault_changed)
				txbuf_fault_snapshot_q <= txbuf_fault_toggle_sync_q[1];
			if (!gt_detect_req_i)
				detect_consumed_q <= 1'b0;
			if (!gt_rate_req_i)
				rate_consumed_q <= 1'b0;
			if (!gt_power_req_i)
				power_consumed_q <= 1'b0;
			if ((((ctrl_state_q == 5'd2) && gt_ready_o) && (current_power_q == 2'b00)) && (!cplllock_sync_q[1] || !gtpowergood_sync_q[1])) begin
				gt_ready_o <= 1'b0;
				data_enable_ctrl_q <= 1'b0;
				native_txelecidle_q <= 1'b1;
				gt_fault_o <= 1'b1;
				gt_fault_code_o <= (!cplllock_sync_q[1] ? 8'h0c : 8'h0d);
				ctrl_state_q <= 5'd16;
			end
			else if (txbuf_fault_changed) begin
				gt_ready_o <= 1'b0;
				data_enable_ctrl_q <= 1'b0;
				native_txelecidle_q <= 1'b1;
				gt_fault_o <= 1'b1;
				gt_fault_code_o <= 8'h0d;
				ctrl_state_q <= 5'd16;
			end
			else
				case (ctrl_state_q)
					5'd0: begin
						gt_ready_o <= 1'b0;
						data_enable_ctrl_q <= 1'b0;
						native_txelecidle_q <= 1'b1;
						native_gttxreset_q <= 1'b1;
						native_gtrxreset_q <= 1'b1;
						native_rxbufreset_q <= 1'b1;
						native_txuserrdy_q <= 1'b0;
						native_rxuserrdy_q <= 1'b0;
						sym_release_ctrl_q <= 1'b0;
						if ((op_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES) begin
							op_count_q <= 1'sb0;
							stable_count_q <= 1'sb0;
							native_gttxreset_q <= 1'b0;
							native_gtrxreset_q <= 1'b0;
							native_rxbufreset_q <= 1'b0;
							native_txuserrdy_q <= 1'b1;
							native_rxuserrdy_q <= 1'b1;
							ctrl_state_q <= 5'd1;
						end
						else if ((op_count_q + 1) >= RESET_TIMEOUT_CYCLES) begin
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0d;
							ctrl_state_q <= 5'd16;
						end
						else
							op_count_q <= op_count_q + 1'b1;
					end
					5'd1: begin
						op_count_q <= op_count_q + 1'b1;
						if ((((!native_gttxreset_q && !native_gtrxreset_q) && !native_rxbufreset_q) && native_txuserrdy_q) && native_rxuserrdy_q)
							sym_release_ctrl_q <= 1'b1;
						if ((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) begin
							if ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES) begin
								gt_ready_o <= 1'b1;
								native_txelecidle_q <= gt_tx_electrical_idle_i;
								data_enable_ctrl_q <= current_power_q == 2'b00;
								ctrl_state_q <= 5'd2;
								op_count_q <= 1'sb0;
							end
							else
								stable_count_q <= stable_count_q + 1'b1;
						end
						else
							stable_count_q <= 1'sb0;
						if (((op_count_q + 1) >= RESET_TIMEOUT_CYCLES) && !(((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) && ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES))) begin
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0d;
							ctrl_state_q <= 5'd16;
						end
					end
					5'd2: begin
						op_count_q <= 1'sb0;
						stable_count_q <= 1'sb0;
						native_txdetectrx_q <= 1'b0;
						data_enable_ctrl_q <= current_power_q == 2'b00;
						native_txelecidle_q <= (current_power_q == 2'b00 ? gt_tx_electrical_idle_i : 1'b1);
						if (gt_rate_req_i && !rate_consumed_q) begin
							rate_consumed_q <= 1'b1;
							if (!gt_ready_o || (current_power_q != 2'b00)) begin
								gt_rate_fail_o <= 1'b1;
								gt_fault_o <= 1'b1;
								gt_fault_code_o <= 8'h13;
							end
							else begin
								rate_target_q <= gt_rate_target_gen2_i;
								txrate_seen_q <= 1'b0;
								rxrate_seen_q <= 1'b0;
								data_enable_ctrl_q <= 1'b0;
								native_txelecidle_q <= 1'b1;
								ctrl_state_q <= 5'd9;
							end
						end
						else if (gt_detect_req_i && !detect_consumed_q) begin
							detect_consumed_q <= 1'b1;
							if (!gt_ready_o || (current_power_q != 2'b00)) begin
								gt_detect_done_o <= 1'b1;
								gt_receiver_present_o <= 1'b0;
								gt_fault_o <= 1'b1;
								gt_fault_code_o <= 8'h0a;
							end
							else begin
								detect_saved_power_q <= current_power_q;
								detect_fault_pending_q <= 1'b0;
								detect_result_q <= 1'b0;
								phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
								native_txpd_q <= 2'b10;
								native_rxpd_q <= 2'b10;
								data_enable_ctrl_q <= 1'b0;
								native_txelecidle_q <= 1'b1;
								gt_ready_o <= 1'b0;
								sym_release_ctrl_q <= 1'b0;
								ctrl_state_q <= 5'd3;
							end
						end
						else if (gt_power_req_i && !power_consumed_q) begin
							power_consumed_q <= 1'b1;
							power_target_q <= gt_power_state_i;
							native_txpd_q <= gt_power_state_i;
							native_rxpd_q <= gt_power_state_i;
							phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
							data_enable_ctrl_q <= 1'b0;
							native_txelecidle_q <= 1'b1;
							gt_ready_o <= 1'b0;
							sym_release_ctrl_q <= 1'b0;
							ctrl_state_q <= 5'd13;
						end
					end
					5'd3: begin
						data_enable_ctrl_q <= 1'b0;
						native_txelecidle_q <= 1'b1;
						op_count_q <= op_count_q + 1'b1;
						if (phystatus_changed || ((detect_saved_power_q == 2'b10) && ((op_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES))) begin
							op_count_q <= 1'sb0;
							phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
							native_txdetectrx_q <= 1'b1;
							ctrl_state_q <= 5'd4;
						end
						else if ((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES) begin
							native_txpd_q <= detect_saved_power_q;
							native_rxpd_q <= detect_saved_power_q;
							detect_fault_pending_q <= 1'b1;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd6;
						end
					end
					5'd4: begin
						op_count_q <= op_count_q + 1'b1;
						if (phystatus_changed) begin
							phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
							native_txdetectrx_q <= 1'b0;
							detect_result_q <= phystatus_value_sync_q == 3'b011;
							detect_fault_pending_q <= (phystatus_value_sync_q != 3'b000) && (phystatus_value_sync_q != 3'b011);
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd5;
						end
						else if ((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES) begin
							native_txdetectrx_q <= 1'b0;
							detect_result_q <= 1'b0;
							detect_fault_pending_q <= 1'b1;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd5;
						end
					end
					5'd5: begin
						op_count_q <= op_count_q + 1'b1;
						native_txelecidle_q <= 1'b1;
						data_enable_ctrl_q <= 1'b0;
						if (!native_ctrl_applied_q[11]) begin
							native_txpd_q <= detect_saved_power_q;
							native_rxpd_q <= detect_saved_power_q;
							phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd6;
						end
						else if ((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES) begin
							native_txpd_q <= detect_saved_power_q;
							native_rxpd_q <= detect_saved_power_q;
							detect_fault_pending_q <= 1'b1;
							phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd6;
						end
					end
					5'd6: begin
						op_count_q <= op_count_q + 1'b1;
						if (phystatus_changed || ((detect_saved_power_q == 2'b10) && ((op_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES))) begin
							phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
							current_power_q <= detect_saved_power_q;
							native_gttxreset_q <= 1'b1;
							native_gtrxreset_q <= 1'b1;
							native_rxbufreset_q <= 1'b1;
							native_txuserrdy_q <= 1'b0;
							native_rxuserrdy_q <= 1'b0;
							gt_ready_o <= 1'b0;
							data_enable_ctrl_q <= 1'b0;
							native_txelecidle_q <= 1'b1;
							sym_release_ctrl_q <= 1'b0;
							stable_count_q <= 1'sb0;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd7;
						end
						else if ((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES) begin
							current_power_q <= detect_saved_power_q;
							data_enable_ctrl_q <= 1'b0;
							native_txelecidle_q <= 1'b1;
							gt_detect_done_o <= 1'b1;
							gt_receiver_present_o <= 1'b0;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0a;
							gt_ready_o <= 1'b0;
							ctrl_state_q <= 5'd16;
							op_count_q <= 1'sb0;
						end
					end
					5'd7:
						if ((op_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES) begin
							native_gttxreset_q <= 1'b0;
							native_gtrxreset_q <= 1'b0;
							native_rxbufreset_q <= 1'b0;
							native_txuserrdy_q <= 1'b1;
							native_rxuserrdy_q <= 1'b1;
							stable_count_q <= 1'sb0;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd8;
						end
						else if ((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES) begin
							gt_detect_done_o <= 1'b1;
							gt_receiver_present_o <= 1'b0;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0a;
							ctrl_state_q <= 5'd16;
						end
						else
							op_count_q <= op_count_q + 1'b1;
					5'd8: begin
						op_count_q <= op_count_q + 1'b1;
						if ((((!native_gttxreset_q && !native_gtrxreset_q) && !native_rxbufreset_q) && native_txuserrdy_q) && native_rxuserrdy_q)
							sym_release_ctrl_q <= 1'b1;
						if ((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) begin
							if ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES) begin
								gt_detect_done_o <= 1'b1;
								gt_receiver_present_o <= detect_result_q && !detect_fault_pending_q;
								if (detect_fault_pending_q) begin
									gt_ready_o <= 1'b0;
									data_enable_ctrl_q <= 1'b0;
									native_txelecidle_q <= 1'b1;
									gt_fault_o <= 1'b1;
									gt_fault_code_o <= 8'h0a;
									ctrl_state_q <= 5'd16;
								end
								else begin
									gt_ready_o <= 1'b1;
									data_enable_ctrl_q <= 1'b1;
									native_txelecidle_q <= gt_tx_electrical_idle_i;
									ctrl_state_q <= 5'd2;
								end
							end
							else
								stable_count_q <= stable_count_q + 1'b1;
						end
						else
							stable_count_q <= 1'sb0;
						if (((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES) && !(((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) && ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES))) begin
							gt_detect_done_o <= 1'b1;
							gt_receiver_present_o <= 1'b0;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0a;
							ctrl_state_q <= 5'd16;
						end
					end
					5'd9: begin
						op_count_q <= op_count_q + 1'b1;
						data_enable_ctrl_q <= 1'b0;
						native_txelecidle_q <= 1'b1;
						if (txei_feedback_sync_q[1]) begin
							gt_ready_o <= 1'b0;
							sym_release_ctrl_q <= 1'b0;
							native_rate_q <= (rate_target_q ? WIZARD_RATE_CODE_GEN2 : WIZARD_RATE_CODE_GEN1);
							txratedone_snapshot_q <= txratedone_toggle_sync_q[1];
							rxratedone_snapshot_q <= rxratedone_toggle_sync_q[1];
							txrate_seen_q <= 1'b0;
							rxrate_seen_q <= 1'b0;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd10;
						end
						else if ((op_count_q + 1) >= RATE_TIMEOUT_CYCLES) begin
							native_rate_q <= (current_rate_q ? WIZARD_RATE_CODE_GEN2 : WIZARD_RATE_CODE_GEN1);
							gt_rate_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h13;
							gt_ready_o <= 1'b0;
							ctrl_state_q <= 5'd16;
						end
					end
					5'd10: begin
						op_count_q <= op_count_q + 1'b1;
						if (txrate_changed)
							txrate_seen_q <= 1'b1;
						if (rxrate_changed)
							rxrate_seen_q <= 1'b1;
						if ((txrate_seen_q || txrate_changed) && (rxrate_seen_q || rxrate_changed)) begin
							native_gttxreset_q <= 1'b1;
							native_gtrxreset_q <= 1'b1;
							native_rxbufreset_q <= 1'b1;
							native_txuserrdy_q <= 1'b0;
							native_rxuserrdy_q <= 1'b0;
							sym_release_ctrl_q <= 1'b0;
							gt_ready_o <= 1'b0;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd11;
						end
						else if ((op_count_q + 1) >= RATE_TIMEOUT_CYCLES) begin
							native_rate_q <= (current_rate_q ? WIZARD_RATE_CODE_GEN2 : WIZARD_RATE_CODE_GEN1);
							gt_rate_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0b;
							gt_ready_o <= 1'b0;
							ctrl_state_q <= 5'd16;
						end
					end
					5'd11:
						if ((op_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES) begin
							native_gttxreset_q <= 1'b0;
							native_gtrxreset_q <= 1'b0;
							native_rxbufreset_q <= 1'b0;
							native_txuserrdy_q <= 1'b1;
							native_rxuserrdy_q <= 1'b1;
							stable_count_q <= 1'sb0;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd12;
						end
						else if ((op_count_q + 1) >= RATE_TIMEOUT_CYCLES) begin
							native_rate_q <= (current_rate_q ? WIZARD_RATE_CODE_GEN2 : WIZARD_RATE_CODE_GEN1);
							gt_rate_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0b;
							ctrl_state_q <= 5'd16;
						end
						else
							op_count_q <= op_count_q + 1'b1;
					5'd12: begin
						op_count_q <= op_count_q + 1'b1;
						if ((((!native_gttxreset_q && !native_gtrxreset_q) && !native_rxbufreset_q) && native_txuserrdy_q) && native_rxuserrdy_q)
							sym_release_ctrl_q <= 1'b1;
						if ((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) begin
							if ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES) begin
								current_rate_q <= rate_target_q;
								gt_ready_o <= 1'b1;
								data_enable_ctrl_q <= current_power_q == 2'b00;
								native_txelecidle_q <= gt_tx_electrical_idle_i;
								gt_rate_done_o <= 1'b1;
								ctrl_state_q <= 5'd2;
							end
							else
								stable_count_q <= stable_count_q + 1'b1;
						end
						else
							stable_count_q <= 1'sb0;
						if (((op_count_q + 1) >= RATE_TIMEOUT_CYCLES) && !(((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) && ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES))) begin
							native_rate_q <= (current_rate_q ? WIZARD_RATE_CODE_GEN2 : WIZARD_RATE_CODE_GEN1);
							gt_rate_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0b;
							ctrl_state_q <= 5'd16;
						end
					end
					5'd13: begin
						op_count_q <= op_count_q + 1'b1;
						if (phystatus_changed) begin
							phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
							current_power_q <= power_target_q;
							op_count_q <= 1'sb0;
							if (power_target_q == 2'b00) begin
								native_gttxreset_q <= 1'b1;
								native_gtrxreset_q <= 1'b1;
								native_rxbufreset_q <= 1'b1;
								native_txuserrdy_q <= 1'b0;
								native_rxuserrdy_q <= 1'b0;
								sym_release_ctrl_q <= 1'b0;
								gt_ready_o <= 1'b0;
								ctrl_state_q <= 5'd14;
							end
							else begin
								gt_power_done_o <= 1'b1;
								ctrl_state_q <= 5'd2;
							end
						end
						else if ((op_count_q + 1) >= POWER_TIMEOUT_CYCLES) begin
							native_txpd_q <= current_power_q;
							native_rxpd_q <= current_power_q;
							gt_power_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0d;
							gt_ready_o <= 1'b0;
							ctrl_state_q <= 5'd16;
						end
					end
					5'd14:
						if ((op_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_BUFFER_REINIT_CYCLES) begin
							native_gttxreset_q <= 1'b0;
							native_gtrxreset_q <= 1'b0;
							native_rxbufreset_q <= 1'b0;
							native_txuserrdy_q <= 1'b1;
							native_rxuserrdy_q <= 1'b1;
							stable_count_q <= 1'sb0;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd15;
						end
						else if ((op_count_q + 1) >= POWER_TIMEOUT_CYCLES) begin
							native_txpd_q <= current_power_q;
							native_rxpd_q <= current_power_q;
							gt_power_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0d;
							ctrl_state_q <= 5'd16;
						end
						else
							op_count_q <= op_count_q + 1'b1;
					5'd15: begin
						op_count_q <= op_count_q + 1'b1;
						if ((((!native_gttxreset_q && !native_gtrxreset_q) && !native_rxbufreset_q) && native_txuserrdy_q) && native_rxuserrdy_q)
							sym_release_ctrl_q <= 1'b1;
						if ((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) begin
							if ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES) begin
								gt_ready_o <= 1'b1;
								data_enable_ctrl_q <= 1'b1;
								native_txelecidle_q <= gt_tx_electrical_idle_i;
								gt_power_done_o <= 1'b1;
								ctrl_state_q <= 5'd2;
							end
							else
								stable_count_q <= stable_count_q + 1'b1;
						end
						else
							stable_count_q <= 1'sb0;
						if (((op_count_q + 1) >= POWER_TIMEOUT_CYCLES) && !(((((txresetdone_sync_q[1] && rxresetdone_sync_q[1]) && cplllock_sync_q[1]) && gtpowergood_sync_q[1]) && gt_sym_rst_ctrl_q) && ((stable_count_q + 1) >= pcie_gen12_phy_timing_pkg_GT_CLOCK_STABLE_CYCLES))) begin
							native_txpd_q <= current_power_q;
							native_rxpd_q <= current_power_q;
							gt_power_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0d;
							ctrl_state_q <= 5'd16;
						end
					end
					5'd16: begin
						gt_ready_o <= 1'b0;
						data_enable_ctrl_q <= 1'b0;
						native_txelecidle_q <= 1'b1;
						native_txdetectrx_q <= 1'b0;
						native_gttxreset_q <= 1'b1;
						native_gtrxreset_q <= 1'b1;
						native_rxbufreset_q <= 1'b1;
						native_txuserrdy_q <= 1'b0;
						native_rxuserrdy_q <= 1'b0;
						sym_release_ctrl_q <= 1'b0;
						if ((!gt_detect_req_i && !gt_rate_req_i) && !gt_power_req_i) begin
							native_rate_q <= WIZARD_RATE_CODE_GEN1;
							current_rate_q <= 1'b0;
							rate_target_q <= 1'b0;
							native_txpd_q <= 2'b00;
							native_rxpd_q <= 2'b00;
							current_power_q <= 2'b00;
							op_count_q <= 1'sb0;
							ctrl_state_q <= 5'd0;
						end
					end
					default: ctrl_state_q <= 5'd16;
				endcase
		end
	end
	// TODO(Wizard): Copy IBUFDS_GTE4 attributes and reference-clock selection
	// from the final GT Wizard generated wrapper.
	IBUFDS_GTE4 u_pcie_refclk_ibuf(
		.I(pcie_refclk_p_i),
		.IB(pcie_refclk_n_i),
		.CEB(1'b0),
		.O(gt_refclk),
		.ODIV2(gt_refclk_div2)
	);
	// TODO(Wizard): Replace this provisional BUFG_GT topology, including its
	// DIV/CE/CLR values, with the final Wizard user-clock helper.
	BUFG_GT u_gt_sym_clk_buf(
		.I(native_txoutclk),
		.CE(1'b1),
		.CEMASK(1'b0),
		.CLR(1'b0),
		.CLRMASK(1'b0),
		.DIV(3'b000),
		.O(gt_sym_clk_o)
	);
	// TODO(Wizard): Copy the complete GTYE4_CHANNEL attribute set verbatim from
	// the final PCIe Gen1/Gen2, 20-bit internal, hard-8b10b Wizard generation.
	// TODO(Wizard): Freeze CPLL/QPLL selection, refclk/system-clock selectors,
	// OUTCLK selectors, PROGDIV/reset helpers, and unused-port tie-offs from the
	// same generation; no values are inferred here.
	// TODO(Wizard): Freeze CLK_COR_SEQ, comma/alignment, and RX elastic-buffer
	// attributes from the final Wizard generation.
	GTYE4_CHANNEL u_gtye4_channel(
		.GTREFCLK0(gt_refclk),
		.GTYRXP(pcie_rx_p_i),
		.GTYRXN(pcie_rx_n_i),
		.GTYTXP(pcie_tx_p_o),
		.GTYTXN(pcie_tx_n_o),
		.TXDATA(native_txdata),
		.TXCTRL0(native_txctrl0),
		.TXCTRL1(native_txctrl1),
		.TXCTRL2(native_txctrl2),
		.RXDATA(native_rxdata),
		.RXCTRL0(native_rxctrl0),
		.RXCTRL1(native_rxctrl1),
		.RXCTRL2(native_rxctrl2),
		.RXCTRL3(native_rxctrl3),
		.RXDATAVALID(native_rxdatavalid),
		.TX8B10BEN(1'b1),
		.RX8B10BEN(1'b1),
		// TODO(Wizard): Preserve low bits [1:0]=0 and replace unused high bits with
		// the final Wizard-generated TX8B10BBYPASS tie-off.
		.TX8B10BBYPASS(8'h00),
		.RXCOMMADETEN(1'b1),
		.RXPCOMMAALIGNEN(1'b1),
		.RXMCOMMAALIGNEN(1'b1),
		.RXBYTEISALIGNED(native_rxbyteisaligned),
		.RXBYTEREALIGN(native_rxbyterealign),
		.RXCOMMADET(native_rxcommadet),
		.RXCLKCORCNT(native_rxclkcorcnt),
		.RXBUFSTATUS(native_rxbufstatus),
		.TXBUFSTATUS(native_txbufstatus),
		.RXBUFRESET(native_rxbufreset_q),
		.TXELECIDLE(native_ctrl_applied_q[10]),
		.RXELECIDLE(native_rxelecidle),
		.RXCDRLOCK(native_rxcdrlock),
		.RXELECIDLEMODE(WIZARD_RX_EI_MODE),
		.RXLPMEN(WIZARD_RX_LPM_ENABLE),
		.TXDETECTRX(native_ctrl_applied_q[11]),
		.PHYSTATUS(native_phystatus),
		.RXSTATUS(native_rxstatus),
		.TXPD(native_txpd_q),
		.RXPD(native_rxpd_q),
		.TXRATE(native_ctrl_applied_q[14-:3]),
		.RXRATE(native_ctrl_applied_q[14-:3]),
		.TXRATEMODE(WIZARD_TX_RATE_MODE),
		.RXRATEMODE(WIZARD_RX_RATE_MODE),
		.TXRATEDONE(native_txratedone),
		.RXRATEDONE(native_rxratedone),
		.RXPOLARITY(native_ctrl_applied_q[9]),
		.TXPOLARITY(WIZARD_TX_POLARITY),
		.TXDEEMPH(native_txdeemph),
		.TXSWING(native_ctrl_applied_q[7]),
		.TXMARGIN(native_ctrl_applied_q[6-:3]),
		.LOOPBACK(native_ctrl_applied_q[3-:3]),
		.GTTXRESET(native_gttxreset_q),
		.GTRXRESET(native_gtrxreset_q),
		.TXUSERRDY(native_txuserrdy_q),
		.RXUSERRDY(native_rxuserrdy_q),
		.TXRESETDONE(native_txresetdone),
		.RXRESETDONE(native_rxresetdone),
		.GTPOWERGOOD(native_gtpowergood),
		.CPLLLOCK(native_cplllock),
		.TXOUTCLK(native_txoutclk),
		.RXOUTCLK(native_rxoutclk),
		.TXUSRCLK(gt_sym_clk_o),
		.TXUSRCLK2(gt_sym_clk_o),
		.RXUSRCLK(gt_sym_clk_o),
		.RXUSRCLK2(gt_sym_clk_o)
	);
	initial _sv2v_0 = 0;
endmodule
`endif
