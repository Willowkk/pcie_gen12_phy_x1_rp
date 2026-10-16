`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_timer_bank (
	ctrl_clk_i,
	ctrl_rst_ni,
	port_reset_ni,
	timer_start_i,
	timer_stop_i,
	timer_id_i,
	timer_limit_i,
	retry_update_i,
	retry_clear_i,
	timer_expired_o,
	timer_id_o,
	retry_count_o,
	timer_active_o,
	timer_count_o
);
	reg _sv2v_0;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	input wire port_reset_ni;
	input wire timer_start_i;
	input wire timer_stop_i;
	input wire [5:0] timer_id_i;
	input wire [31:0] timer_limit_i;
	input wire retry_update_i;
	input wire retry_clear_i;
	output reg timer_expired_o;
	output reg [5:0] timer_id_o;
	output reg [7:0] retry_count_o;
	output reg timer_active_o;
	output reg [31:0] timer_count_o;
	wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;
	reg [31:0] selected_limit;
	reg [1:0] retry_action;
	localparam [31:0] pcie_gen12_phy_timing_pkg_SIM_TIME_SCALE = 1;
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
		if (timer_limit_i != 0)
			selected_limit = timer_limit_i;
		else
			selected_limit = pcie_gen12_phy_timing_pkg_timer_default_cycles(timer_id_i, pcie_gen12_phy_timing_pkg_SIM_TIME_SCALE);
		if (selected_limit == 0)
			selected_limit = 1;
		retry_action = 2'b00;
		if (retry_clear_i)
			retry_action = 2'b10;
		else if (retry_update_i)
			retry_action = 2'b01;
	end
	always @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani)
		if (!ctrl_local_reset_ani) begin
			timer_active_o <= 1'b0;
			timer_count_o <= 1'sb0;
			timer_expired_o <= 1'b0;
			timer_id_o <= 6'h00;
			retry_count_o <= 1'sb0;
		end
		else begin
			timer_expired_o <= 1'b0;
			if (timer_start_i) begin
				timer_active_o <= 1'b1;
				timer_count_o <= selected_limit;
				timer_id_o <= timer_id_i;
			end
			else if (timer_stop_i) begin
				timer_active_o <= 1'b0;
				timer_count_o <= 1'sb0;
				timer_id_o <= 6'h00;
			end
			else if (timer_active_o) begin
				if (timer_count_o <= 1) begin
					timer_active_o <= 1'b0;
					timer_count_o <= 1'sb0;
					timer_expired_o <= 1'b1;
				end
				else
					timer_count_o <= timer_count_o - 1'b1;
			end
			(* full_case, parallel_case *)
			case (retry_action)
				2'b10: retry_count_o <= 1'sb0;
				2'b01:
					if (retry_count_o != 8'hff)
						retry_count_o <= retry_count_o + 1'b1;
				default:
					;
			endcase
		end
	initial _sv2v_0 = 0;
endmodule
