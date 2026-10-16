`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module gty_behavioral_model (
	ctrl_clk_i,
	ctrl_rst_ni,
	sym_clk_o,
	sym_rst_no,
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
	gt_fault_code_o,
	pcie_rx_p_i,
	pcie_rx_n_i,
	pcie_tx_p_o,
	pcie_tx_n_o
);
	reg _sv2v_0;
	parameter [31:0] EI_ASSERT_STABLE_CYCLES = 8;
	parameter [31:0] EI_DEASSERT_STABLE_CYCLES = 16;
	parameter [31:0] DETECT_LATENCY_CYCLES = 16;
	parameter [31:0] RATE_LATENCY_CYCLES = 64;
	parameter [31:0] POWER_LATENCY_CYCLES = 32;
	parameter [31:0] READY_LATENCY_CYCLES = 32;
	parameter [31:0] DETECT_TIMEOUT_CYCLES = 1024;
	parameter [31:0] RATE_TIMEOUT_CYCLES = 1024;
	parameter [31:0] POWER_TIMEOUT_CYCLES = 1024;
	parameter [31:0] ELASTIC_DEPTH_PAIRS = 16;
	parameter [31:0] CLOCK_COR_INTERVAL = 64;
	parameter [2:0] DETECT_STATUS = 3'b011;
	parameter [0:0] DETECT_TIMEOUT = 1'b0;
	parameter [0:0] RATE_FAIL = 1'b0;
	parameter [0:0] POWER_FAIL = 1'b0;
	parameter [0:0] LINK_POLARITY_INVERTED = 1'b0;
	parameter [0:0] INJECT_CODE_ERROR = 1'b0;
	parameter [0:0] INJECT_DISPARITY_ERROR = 1'b0;
	parameter [0:0] INJECT_RXBUF_UNDERFLOW = 1'b0;
	parameter [0:0] INJECT_RXBUF_OVERFLOW = 1'b0;
	parameter [0:0] INJECT_TXBUF_FAULT = 1'b0;
	parameter [31:0] ELASTIC_CORRECTION_MODE = 0;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	output reg sym_clk_o;
	output wire sym_rst_no;
	input wire [15:0] tx_symbol_data_i;
	input wire [1:0] tx_symbol_is_k_i;
	output reg [15:0] rx_symbol_data_o;
	output reg [1:0] rx_symbol_is_k_o;
	output reg [1:0] rx_symbol_disparity_error_o;
	output reg [1:0] rx_symbol_code_error_o;
	output reg [1:0] rx_symbol_is_comma_o;
	output reg rx_symbol_valid_o;
	output reg rx_byte_aligned_o;
	output reg rx_realign_event_o;
	output reg [1:0] gt_rx_clkcor_count_o;
	output reg [2:0] gt_rx_buffer_status_o;
	output reg gt_tx_buffer_fault_o;
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
	output reg gt_tx_electrical_idle_active_o;
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
	input wire pcie_rx_p_i;
	input wire pcie_rx_n_i;
	output reg pcie_tx_p_o;
	output reg pcie_tx_n_o;
	reg [3:0] op_state_q;
	reg [31:0] op_count_q;
	reg [31:0] ready_count_q;
	reg [31:0] rx_ei_assert_count_q;
	reg [31:0] rx_ei_deassert_count_q;
	reg [1:0] power_state_q;
	reg [1:0] saved_power_state_q;
	reg current_rate_q;
	reg rate_target_q;
	reg detect_consumed_q;
	reg rate_consumed_q;
	reg power_consumed_q;
	reg detect_fault_pending_q;
	reg internal_electrical_idle_q;
	reg txei_sync_q;
	reg tx_rd_q;
	reg rx_rd_q;
	reg [19:0] encoded_pipe_q [0:3];
	reg [3:0] encoded_valid_q;
	reg [25:0] elastic_q [0:ELASTIC_DEPTH_PAIRS - 1];
	integer elastic_wr_q;
	integer elastic_rd_q;
	integer elastic_count_q;
	reg elastic_started_q;
	reg rxbuf_fault_q;
	reg rxbuf_overflow_fault_q;
	reg [31:0] correction_count_q;
	reg [1:0] replay_count_q;
	reg [25:0] replay_q [0:2];
	reg comma_phase_q;
	reg [4:0] serial_observe_index_q;
	reg [1:0] sym_reset_sync_q;
	reg [1:0] sym_reset_ctrl_sync_q;
	reg [1:0] rx_ei_sym_q;
	reg [1:0] rx_polarity_sym_q;
	wire sym_reset_async_ni;
	reg compliance_active_q;
	reg compliance_start_pending_q;
	reg txbuf_inject_seen_q;
	reg txbuf_fault_toggle_sym_q;
	reg [1:0] txbuf_fault_toggle_ctrl_sync_q;
	reg txbuf_fault_snapshot_q;
	initial begin : validate_model_parameters
		if (ELASTIC_DEPTH_PAIRS < 4) begin
			$display("Fatal [%0t] rtl/gt/gty_behavioral_model.sv:156:7 - gty_behavioral_model.validate_model_parameters.<unnamed_block>\n msg: ", $time, "ELASTIC_DEPTH_PAIRS must hold at least one two-pair SKP OS");
			$stop(1);
		end
		if ((((((((((EI_ASSERT_STABLE_CYCLES == 0) || (EI_DEASSERT_STABLE_CYCLES == 0)) || (DETECT_LATENCY_CYCLES == 0)) || (RATE_LATENCY_CYCLES == 0)) || (POWER_LATENCY_CYCLES == 0)) || (READY_LATENCY_CYCLES == 0)) || (DETECT_TIMEOUT_CYCLES == 0)) || (RATE_TIMEOUT_CYCLES == 0)) || (POWER_TIMEOUT_CYCLES == 0)) || (CLOCK_COR_INTERVAL == 0)) begin
			$display("Fatal [%0t] rtl/gt/gty_behavioral_model.sv:164:7 - gty_behavioral_model.validate_model_parameters.<unnamed_block>\n msg: ", $time, "GT behavioral-model timing parameters must be nonzero");
			$stop(1);
		end
		if (ELASTIC_CORRECTION_MODE > 3) begin
			$display("Fatal [%0t] rtl/gt/gty_behavioral_model.sv:166:7 - gty_behavioral_model.validate_model_parameters.<unnamed_block>\n msg: ", $time, "ELASTIC_CORRECTION_MODE must be 0..3");
			$stop(1);
		end
	end
	initial begin
		sym_clk_o = 1'b0;
		forever begin
			// Nanoseconds, set by the Verilog timescale above.
			#((current_rate_q === 1'b1 ? 2 : 4))
				;
			sym_clk_o = ~sym_clk_o;
		end
	end
	assign sym_reset_async_ni = (ctrl_rst_ni && gt_ready_o) && ((((op_state_q == 4'd0) || (op_state_q == 4'd4)) || (op_state_q == 4'd6)) || (op_state_q == 4'd8));
	always @(posedge sym_clk_o or negedge sym_reset_async_ni)
		if (!sym_reset_async_ni)
			sym_reset_sync_q <= 2'b00;
		else
			sym_reset_sync_q <= {sym_reset_sync_q[0], 1'b1};
	assign sym_rst_no = sym_reset_sync_q[1];
	always @(posedge ctrl_clk_i or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni) begin
			sym_reset_ctrl_sync_q <= 2'b00;
			txbuf_fault_toggle_ctrl_sync_q <= 2'b00;
		end
		else begin
			sym_reset_ctrl_sync_q <= {sym_reset_ctrl_sync_q[0], sym_rst_no};
			txbuf_fault_toggle_ctrl_sync_q <= {txbuf_fault_toggle_ctrl_sync_q[0], txbuf_fault_toggle_sym_q};
		end
	always @(posedge sym_clk_o or negedge ctrl_rst_ni)
		if (!ctrl_rst_ni) begin
			gt_tx_buffer_fault_o <= 1'b0;
			txbuf_inject_seen_q <= 1'b0;
			txbuf_fault_toggle_sym_q <= 1'b0;
		end
		else begin
			gt_tx_buffer_fault_o <= 1'b0;
			if ((sym_rst_no && INJECT_TXBUF_FAULT) && !txbuf_inject_seen_q) begin
				gt_tx_buffer_fault_o <= 1'b1;
				txbuf_fault_toggle_sym_q <= ~txbuf_fault_toggle_sym_q;
				txbuf_inject_seen_q <= 1'b1;
			end
			else if (!INJECT_TXBUF_FAULT)
				txbuf_inject_seen_q <= 1'b0;
		end
	function automatic [7:0] table_5b6b;
		input reg [5:0] index_i;
		case (index_i)
			6'd0: table_5b6b = 8'o371;
			6'd1: table_5b6b = 8'o356;
			6'd2: table_5b6b = 8'o355;
			6'd3: table_5b6b = 8'o043;
			6'd4: table_5b6b = 8'o353;
			6'd5: table_5b6b = 8'o045;
			6'd6: table_5b6b = 8'o046;
			6'd7: table_5b6b = 8'o107;
			6'd8: table_5b6b = 8'o347;
			6'd9: table_5b6b = 8'o051;
			6'd10: table_5b6b = 8'o052;
			6'd11: table_5b6b = 8'o013;
			6'd12: table_5b6b = 8'o054;
			6'd13: table_5b6b = 8'o015;
			6'd14: table_5b6b = 8'o016;
			6'd15: table_5b6b = 8'o372;
			6'd16: table_5b6b = 8'o366;
			6'd17: table_5b6b = 8'o061;
			6'd18: table_5b6b = 8'o062;
			6'd19: table_5b6b = 8'o023;
			6'd20: table_5b6b = 8'o064;
			6'd21: table_5b6b = 8'o025;
			6'd22: table_5b6b = 8'o026;
			6'd23: table_5b6b = 8'o327;
			6'd24: table_5b6b = 8'o363;
			6'd25: table_5b6b = 8'o031;
			6'd26: table_5b6b = 8'o032;
			6'd27: table_5b6b = 8'o333;
			6'd28: table_5b6b = 8'o034;
			6'd29: table_5b6b = 8'o335;
			6'd30: table_5b6b = 8'o336;
			6'd31: table_5b6b = 8'o365;
			6'd32: table_5b6b = 8'o374;
			default: table_5b6b = 8'o000;
		endcase
	endfunction
	function automatic [7:0] table_data_3b4b;
		input reg [3:0] index_i;
		case (index_i)
			4'd0: table_data_3b4b = 8'o315;
			4'd1: table_data_3b4b = 8'o011;
			4'd2: table_data_3b4b = 8'o012;
			4'd3: table_data_3b4b = 8'o103;
			4'd4: table_data_3b4b = 8'o313;
			4'd5: table_data_3b4b = 8'o005;
			4'd6: table_data_3b4b = 8'o006;
			4'd7: table_data_3b4b = 8'o307;
			4'd8: table_data_3b4b = 8'o316;
			default: table_data_3b4b = 8'o000;
		endcase
	endfunction
	function automatic [7:0] table_ctrl_3b4b;
		input reg [2:0] index_i;
		case (index_i)
			3'd0: table_ctrl_3b4b = 8'o315;
			3'd1: table_ctrl_3b4b = 8'o106;
			3'd2: table_ctrl_3b4b = 8'o105;
			3'd3: table_ctrl_3b4b = 8'o103;
			3'd4: table_ctrl_3b4b = 8'o313;
			3'd5: table_ctrl_3b4b = 8'o112;
			3'd6: table_ctrl_3b4b = 8'o111;
			3'd7: table_ctrl_3b4b = 8'o316;
			default: table_ctrl_3b4b = 8'o000;
		endcase
	endfunction
	function automatic legal_k;
		input reg [7:0] data_i;
		reg [4:0] x;
		reg [2:0] y;
		begin
			x = data_i[4:0];
			y = data_i[7:5];
			legal_k = (x == 5'd28) || ((y == 3'd7) && ((((x == 5'd23) || (x == 5'd27)) || (x == 5'd29)) || (x == 5'd30)));
		end
	endfunction
	function automatic [11:0] encode_8b10b;
		input reg [7:0] data_i;
		input reg is_k_i;
		input reg rd_i;
		reg [11:0] result;
		reg [4:0] x;
		reg [2:0] y;
		reg [7:0] lut6;
		reg [7:0] lut4;
		reg [5:0] code6;
		reg [3:0] code4;
		reg rd_mid;
		reg use_alt7;
		begin
			x = data_i[4:0];
			y = data_i[7:5];
			result[11] = is_k_i && !legal_k(data_i);
			lut6 = (is_k_i && (x == 5'd28) ? table_5b6b(6'd32) : table_5b6b({1'b0, x}));
			code6 = (rd_i && lut6[6] ? ~lut6[5:0] : lut6[5:0]);
			rd_mid = lut6[7] ^ rd_i;
			use_alt7 = (y == 3'd7) && ((rd_mid && (((x == 5'd11) || (x == 5'd13)) || (x == 5'd14))) || (!rd_mid && (((x == 5'd17) || (x == 5'd18)) || (x == 5'd20))));
			lut4 = (is_k_i ? table_ctrl_3b4b(y) : table_data_3b4b((use_alt7 ? 4'd8 : {1'b0, y})));
			code4 = (rd_mid && lut4[6] ? ~lut4[3:0] : lut4[3:0]);
			result[10] = lut4[7] ^ rd_mid;
			result[9-:10] = {code4, code6};
			if (result[11]) begin
				result[9-:10] = 10'b0000000000;
				result[10] = rd_i;
			end
			encode_8b10b = result;
		end
	endfunction
	reg [10:0] decode_rd_minus [0:1023];
	reg [10:0] decode_rd_plus [0:1023];
	integer init_i;
	integer init_k;
	reg [11:0] init_enc;
	initial begin
		for (init_i = 0; init_i < 1024; init_i = init_i + 1)
			begin
				decode_rd_minus[init_i] = 1'sb0;
				decode_rd_plus[init_i] = 1'sb0;
			end
		for (init_i = 0; init_i < 256; init_i = init_i + 1)
			for (init_k = 0; init_k < 2; init_k = init_k + 1)
				begin
					init_enc = encode_8b10b(init_i[7:0], init_k[0], 1'b0);
					if (!init_enc[11])
						decode_rd_minus[init_enc[9-:10]] = {1'b1, init_k[0], init_enc[10], init_i[7:0]};
					init_enc = encode_8b10b(init_i[7:0], init_k[0], 1'b1);
					if (!init_enc[11])
						decode_rd_plus[init_enc[9-:10]] = {1'b1, init_k[0], init_enc[10], init_i[7:0]};
				end
	end
	function automatic [11:0] decode_8b10b;
		input reg [9:0] code_i;
		input reg rd_i;
		reg [11:0] result;
		reg [10:0] current_entry;
		reg [10:0] opposite_entry;
		begin
			current_entry = (rd_i ? decode_rd_plus[code_i] : decode_rd_minus[code_i]);
			opposite_entry = (rd_i ? decode_rd_minus[code_i] : decode_rd_plus[code_i]);
			result = 1'sb0;
			result[8] = rd_i;
			if (current_entry[10]) begin
				result[9] = current_entry[9];
				result[8] = current_entry[8];
				result[7-:8] = current_entry[7:0];
			end
			else if (opposite_entry[10]) begin
				result[10] = 1'b1;
				result[9] = opposite_entry[9];
				result[8] = opposite_entry[8];
				result[7-:8] = opposite_entry[7:0];
			end
			else
				result[11] = 1'b1;
			decode_8b10b = result;
		end
	endfunction
	assign gt_detect_busy_o = (((op_state_q == 4'd1) || (op_state_q == 4'd2)) || (op_state_q == 4'd3)) || (op_state_q == 4'd4);
	assign gt_rate_busy_o = (op_state_q == 4'd5) || (op_state_q == 4'd6);
	assign gt_power_busy_o = (op_state_q == 4'd7) || (op_state_q == 4'd8);
	always @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin : control_model
		reg txbuf_fault_changed;
		if (!ctrl_rst_ni) begin
			op_state_q <= 4'd0;
			op_count_q <= 1'sb0;
			ready_count_q <= 1'sb0;
			power_state_q <= 2'b00;
			saved_power_state_q <= 2'b00;
			current_rate_q <= 1'b0;
			rate_target_q <= 1'b0;
			detect_consumed_q <= 1'b0;
			rate_consumed_q <= 1'b0;
			power_consumed_q <= 1'b0;
			detect_fault_pending_q <= 1'b0;
			internal_electrical_idle_q <= 1'b1;
			txei_sync_q <= 1'b1;
			rx_ei_assert_count_q <= 1'sb0;
			rx_ei_deassert_count_q <= 1'sb0;
			gt_detect_done_o <= 1'b0;
			gt_receiver_present_o <= 1'b0;
			gt_rate_done_o <= 1'b0;
			gt_rate_fail_o <= 1'b0;
			gt_power_done_o <= 1'b0;
			gt_power_fail_o <= 1'b0;
			gt_tx_electrical_idle_active_o <= 1'b1;
			gt_rx_electrical_idle_o <= 1'b1;
			gt_ready_o <= 1'b0;
			gt_fault_o <= 1'b0;
			gt_fault_code_o <= 8'h00;
			txbuf_fault_snapshot_q <= 1'b0;
		end
		else begin
			txbuf_fault_changed = txbuf_fault_toggle_ctrl_sync_q[1] ^ txbuf_fault_snapshot_q;
			gt_detect_done_o <= 1'b0;
			gt_receiver_present_o <= 1'b0;
			gt_rate_done_o <= 1'b0;
			gt_rate_fail_o <= 1'b0;
			gt_power_done_o <= 1'b0;
			gt_power_fail_o <= 1'b0;
			gt_fault_o <= 1'b0;
			gt_fault_code_o <= 8'h00;
			if (txbuf_fault_changed)
				txbuf_fault_snapshot_q <= txbuf_fault_toggle_ctrl_sync_q[1];
			txei_sync_q <= gt_tx_electrical_idle_i | internal_electrical_idle_q;
			gt_tx_electrical_idle_active_o <= txei_sync_q;
			if (!gt_detect_req_i)
				detect_consumed_q <= 1'b0;
			if (!gt_rate_req_i)
				rate_consumed_q <= 1'b0;
			if (!gt_power_req_i)
				power_consumed_q <= 1'b0;
			if ((!gt_ready_o && (power_state_q == 2'b00)) && ((((op_state_q == 4'd0) || (op_state_q == 4'd4)) || (op_state_q == 4'd6)) || (op_state_q == 4'd8))) begin
				if ((ready_count_q + 1) >= READY_LATENCY_CYCLES) begin
					gt_ready_o <= 1'b1;
					internal_electrical_idle_q <= gt_tx_electrical_idle_i;
				end
				else
					ready_count_q <= ready_count_q + 1'b1;
			end
			if ((pcie_rx_p_i === pcie_rx_n_i) || (power_state_q != 2'b00)) begin
				rx_ei_deassert_count_q <= 1'sb0;
				if (rx_ei_assert_count_q < EI_ASSERT_STABLE_CYCLES)
					rx_ei_assert_count_q <= rx_ei_assert_count_q + 1'b1;
				if ((rx_ei_assert_count_q + 1) >= EI_ASSERT_STABLE_CYCLES)
					gt_rx_electrical_idle_o <= 1'b1;
			end
			else begin
				rx_ei_assert_count_q <= 1'sb0;
				if (rx_ei_deassert_count_q < EI_DEASSERT_STABLE_CYCLES)
					rx_ei_deassert_count_q <= rx_ei_deassert_count_q + 1'b1;
				if ((rx_ei_deassert_count_q + 1) >= EI_DEASSERT_STABLE_CYCLES)
					gt_rx_electrical_idle_o <= 1'b0;
			end
			if (txbuf_fault_changed) begin
				internal_electrical_idle_q <= 1'b1;
				gt_ready_o <= 1'b0;
				ready_count_q <= 1'sb0;
				gt_fault_o <= 1'b1;
				gt_fault_code_o <= 8'h0d;
				op_state_q <= 4'd9;
			end
			else
				case (op_state_q)
					4'd0: begin
						op_count_q <= 1'sb0;
						internal_electrical_idle_q <= gt_tx_electrical_idle_i;
						if (gt_rate_req_i && !rate_consumed_q) begin
							rate_consumed_q <= 1'b1;
							if (!gt_ready_o || (power_state_q != 2'b00)) begin
								gt_rate_fail_o <= 1'b1;
								gt_fault_o <= 1'b1;
								gt_fault_code_o <= 8'h13;
							end
							else begin
								rate_target_q <= gt_rate_target_gen2_i;
								internal_electrical_idle_q <= 1'b1;
								gt_ready_o <= 1'b0;
								ready_count_q <= 1'sb0;
								op_state_q <= 4'd5;
							end
						end
						else if (gt_detect_req_i && !detect_consumed_q) begin
							detect_consumed_q <= 1'b1;
							if (!gt_ready_o || (power_state_q != 2'b00)) begin
								gt_detect_done_o <= 1'b1;
								gt_receiver_present_o <= 1'b0;
								gt_fault_o <= 1'b1;
								gt_fault_code_o <= 8'h0a;
							end
							else begin
								detect_fault_pending_q <= 1'b0;
								saved_power_state_q <= power_state_q;
								internal_electrical_idle_q <= 1'b1;
								gt_ready_o <= 1'b0;
								ready_count_q <= 1'sb0;
								op_state_q <= 4'd1;
							end
						end
						else if (gt_power_req_i && !power_consumed_q) begin
							power_consumed_q <= 1'b1;
							saved_power_state_q <= gt_power_state_i;
							internal_electrical_idle_q <= 1'b1;
							gt_ready_o <= 1'b0;
							ready_count_q <= 1'sb0;
							op_state_q <= 4'd7;
						end
					end
					4'd1: begin
						op_count_q <= op_count_q + 1'b1;
						if ((op_count_q + 1) >= POWER_LATENCY_CYCLES) begin
							power_state_q <= 2'b10;
							op_count_q <= 1'sb0;
							op_state_q <= 4'd2;
						end
					end
					4'd2: begin
						op_count_q <= op_count_q + 1'b1;
						if (!DETECT_TIMEOUT && ((op_count_q + 1) >= DETECT_LATENCY_CYCLES)) begin
							op_count_q <= 1'sb0;
							if ((DETECT_STATUS != 3'b000) && (DETECT_STATUS != 3'b011))
								detect_fault_pending_q <= 1'b1;
							op_state_q <= 4'd3;
						end
						else if (DETECT_TIMEOUT && ((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES)) begin
							detect_fault_pending_q <= 1'b1;
							op_count_q <= 1'sb0;
							op_state_q <= 4'd3;
						end
					end
					4'd3: begin
						op_count_q <= op_count_q + 1'b1;
						if ((op_count_q + 1) >= POWER_LATENCY_CYCLES) begin
							power_state_q <= saved_power_state_q;
							gt_ready_o <= 1'b0;
							ready_count_q <= 1'sb0;
							op_count_q <= 1'sb0;
							op_state_q <= 4'd4;
						end
					end
					4'd4: begin
						op_count_q <= op_count_q + 1'b1;
						if (gt_ready_o && sym_reset_ctrl_sync_q[1]) begin
							gt_detect_done_o <= 1'b1;
							gt_receiver_present_o <= (DETECT_STATUS == 3'b011) && !detect_fault_pending_q;
							op_count_q <= 1'sb0;
							if (detect_fault_pending_q) begin
								internal_electrical_idle_q <= 1'b1;
								gt_ready_o <= 1'b0;
								ready_count_q <= 1'sb0;
								gt_fault_o <= 1'b1;
								gt_fault_code_o <= 8'h0a;
								op_state_q <= 4'd9;
							end
							else begin
								internal_electrical_idle_q <= gt_tx_electrical_idle_i;
								op_state_q <= 4'd0;
							end
						end
						else if ((op_count_q + 1) >= DETECT_TIMEOUT_CYCLES) begin
							gt_detect_done_o <= 1'b1;
							gt_receiver_present_o <= 1'b0;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0a;
							internal_electrical_idle_q <= 1'b1;
							op_state_q <= 4'd9;
						end
					end
					4'd5: begin
						op_count_q <= op_count_q + 1'b1;
						if ((op_count_q + 1) >= RATE_LATENCY_CYCLES) begin
							op_count_q <= 1'sb0;
							if (RATE_FAIL) begin
								gt_rate_fail_o <= 1'b1;
								gt_fault_o <= 1'b1;
								gt_fault_code_o <= 8'h0b;
								gt_ready_o <= 1'b0;
								ready_count_q <= 1'sb0;
								op_state_q <= 4'd9;
							end
							else begin
								current_rate_q <= rate_target_q;
								gt_ready_o <= 1'b0;
								ready_count_q <= 1'sb0;
								op_state_q <= 4'd6;
							end
						end
					end
					4'd6: begin
						op_count_q <= op_count_q + 1'b1;
						if (gt_ready_o && sym_reset_ctrl_sync_q[1]) begin
							internal_electrical_idle_q <= gt_tx_electrical_idle_i;
							gt_rate_done_o <= 1'b1;
							op_count_q <= 1'sb0;
							op_state_q <= 4'd0;
						end
						else if ((op_count_q + 1) >= RATE_TIMEOUT_CYCLES) begin
							gt_rate_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0b;
							internal_electrical_idle_q <= 1'b1;
							op_state_q <= 4'd9;
						end
					end
					4'd7: begin
						op_count_q <= op_count_q + 1'b1;
						if ((op_count_q + 1) >= POWER_LATENCY_CYCLES) begin
							op_count_q <= 1'sb0;
							if (POWER_FAIL) begin
								gt_power_fail_o <= 1'b1;
								gt_fault_o <= 1'b1;
								gt_fault_code_o <= 8'h0d;
								gt_ready_o <= 1'b0;
								ready_count_q <= 1'sb0;
								op_state_q <= 4'd9;
							end
							else begin
								power_state_q <= saved_power_state_q;
								if (saved_power_state_q == 2'b00) begin
									gt_ready_o <= 1'b0;
									ready_count_q <= 1'sb0;
									op_state_q <= 4'd8;
								end
								else begin
									gt_power_done_o <= 1'b1;
									op_state_q <= 4'd0;
								end
							end
						end
					end
					4'd8: begin
						op_count_q <= op_count_q + 1'b1;
						if (gt_ready_o && sym_reset_ctrl_sync_q[1]) begin
							internal_electrical_idle_q <= gt_tx_electrical_idle_i;
							gt_power_done_o <= 1'b1;
							op_count_q <= 1'sb0;
							op_state_q <= 4'd0;
						end
						else if ((op_count_q + 1) >= POWER_TIMEOUT_CYCLES) begin
							gt_power_fail_o <= 1'b1;
							gt_fault_o <= 1'b1;
							gt_fault_code_o <= 8'h0d;
							internal_electrical_idle_q <= 1'b1;
							op_state_q <= 4'd9;
						end
					end
					4'd9: begin
						internal_electrical_idle_q <= 1'b1;
						if ((!gt_detect_req_i && !gt_rate_req_i) && !gt_power_req_i) begin
							current_rate_q <= 1'b0;
							rate_target_q <= 1'b0;
							power_state_q <= 2'b00;
							saved_power_state_q <= 2'b00;
							ready_count_q <= 1'sb0;
							op_state_q <= 4'd0;
						end
					end
					default: op_state_q <= 4'd9;
				endcase
		end
	end
	localparam [7:0] pcie_gen12_phy_pkg_K_COM = 8'hbc;
	localparam [7:0] pcie_gen12_phy_pkg_K_SKP = 8'h1c;
	always @(posedge sym_clk_o or negedge sym_rst_no) begin : pcs_and_elastic_model
		integer idx;
		integer next_wr;
		integer next_rd;
		integer next_count;
		reg [11:0] enc0;
		reg [11:0] enc1;
		reg [11:0] dec0;
		reg [11:0] dec1;
		reg [19:0] received_codes;
		reg [25:0] decoded_pair;
		reg [25:0] head_pair;
		reg head_valid;
		reg head_is_skp_start;
		reg second_is_skp_tail;
		reg third_is_skp_start;
		reg fourth_is_skp_tail;
		reg overflow_event;
		reg underflow_event;
		reg fault_active;
		reg compliance_start;
		reg tx_rd_start;
		if (!sym_rst_no) begin
			tx_rd_q <= 1'b0;
			rx_rd_q <= 1'b0;
			encoded_valid_q <= 1'sb0;
			for (idx = 0; idx < 4; idx = idx + 1)
				encoded_pipe_q[idx] <= 1'sb0;
			elastic_wr_q <= 0;
			elastic_rd_q <= 0;
			elastic_count_q <= 0;
			elastic_started_q <= 1'b0;
			rxbuf_fault_q <= 1'b0;
			rxbuf_overflow_fault_q <= 1'b0;
			correction_count_q <= 1'sb0;
			replay_count_q <= 2'd0;
			for (idx = 0; idx < 3; idx = idx + 1)
				replay_q[idx] <= 1'sb0;
			rx_symbol_data_o <= 1'sb0;
			rx_symbol_is_k_o <= 1'sb0;
			rx_symbol_disparity_error_o <= 1'sb0;
			rx_symbol_code_error_o <= 1'sb0;
			rx_symbol_is_comma_o <= 1'sb0;
			rx_symbol_valid_o <= 1'b0;
			rx_byte_aligned_o <= 1'b0;
			rx_realign_event_o <= 1'b0;
			gt_rx_clkcor_count_o <= 2'b00;
			gt_rx_buffer_status_o <= 3'b000;
			comma_phase_q <= 1'b0;
			serial_observe_index_q <= 1'sb0;
			rx_ei_sym_q <= 2'b11;
			rx_polarity_sym_q <= 2'b00;
			compliance_active_q <= 1'b0;
			compliance_start_pending_q <= 1'b0;
			pcie_tx_p_o <= 1'b0;
			pcie_tx_n_o <= 1'b0;
		end
		else begin
			rx_symbol_valid_o <= 1'b0;
			rx_realign_event_o <= 1'b0;
			gt_rx_clkcor_count_o <= 2'b00;
			correction_count_q <= correction_count_q + 1'b1;
			head_pair = 1'sb0;
			head_valid = 1'b0;
			overflow_event = 1'b0;
			underflow_event = 1'b0;
			fault_active = (rxbuf_fault_q || INJECT_RXBUF_UNDERFLOW) || INJECT_RXBUF_OVERFLOW;
			rx_ei_sym_q <= {rx_ei_sym_q[0], gt_rx_electrical_idle_o};
			rx_polarity_sym_q <= {rx_polarity_sym_q[0], gt_rx_polarity_invert_i};
			if (!gt_compliance_enable_i) begin
				compliance_active_q <= 1'b0;
				compliance_start_pending_q <= 1'b0;
			end
			else if (!compliance_active_q) begin
				compliance_active_q <= 1'b1;
				compliance_start_pending_q <= 1'b1;
			end
			for (idx = 3; idx > 0; idx = idx - 1)
				begin
					encoded_pipe_q[idx] <= encoded_pipe_q[idx - 1];
					encoded_valid_q[idx] <= encoded_valid_q[idx - 1];
				end
			if ((gt_ready_o && !gt_tx_electrical_idle_active_o) && (power_state_q == 2'b00)) begin
				compliance_start = ((gt_compliance_enable_i && (!compliance_active_q || compliance_start_pending_q)) && tx_symbol_is_k_i[0]) && (tx_symbol_data_i[7:0] == pcie_gen12_phy_pkg_K_COM);
				tx_rd_start = (compliance_start ? 1'b0 : tx_rd_q);
				enc0 = encode_8b10b(tx_symbol_data_i[7:0], tx_symbol_is_k_i[0], tx_rd_start);
				enc1 = encode_8b10b(tx_symbol_data_i[15:8], tx_symbol_is_k_i[1], enc0[10]);
				encoded_pipe_q[0] <= {enc1[9-:10], enc0[9-:10]};
				encoded_valid_q[0] <= 1'b1;
				tx_rd_q <= enc1[10];
				if (compliance_start)
					compliance_start_pending_q <= 1'b0;
			end
			else begin
				encoded_pipe_q[0] <= 1'sb0;
				encoded_valid_q[0] <= 1'b0;
				tx_rd_q <= 1'b0;
			end
			next_wr = elastic_wr_q;
			next_rd = elastic_rd_q;
			next_count = elastic_count_q;
			if ((encoded_valid_q[3] && !rx_ei_sym_q[1]) && !fault_active) begin
				received_codes = (LINK_POLARITY_INVERTED ? ~encoded_pipe_q[3] : encoded_pipe_q[3]);
				if (rx_polarity_sym_q[1])
					received_codes = ~received_codes;
				dec0 = decode_8b10b(received_codes[9:0], rx_rd_q);
				dec1 = decode_8b10b(received_codes[19:10], dec0[8]);
				rx_rd_q <= dec1[8];
				decoded_pair[25-:16] = {dec1[7-:8], dec0[7-:8]};
				decoded_pair[5-:2] = {dec1[11], dec0[11]};
				decoded_pair[0] = (dec0[9] && !dec0[11]) && (dec0[7-:8] == pcie_gen12_phy_pkg_K_COM);
				decoded_pair[1] = (dec1[9] && !dec1[11]) && (dec1[7-:8] == pcie_gen12_phy_pkg_K_COM);
				if (INJECT_CODE_ERROR)
					decoded_pair[4] = 1'b1;
				decoded_pair[8] = dec0[9] && !decoded_pair[4];
				decoded_pair[9] = dec1[9] && !decoded_pair[5];
				decoded_pair[6] = (dec0[10] || INJECT_DISPARITY_ERROR) && !decoded_pair[4];
				decoded_pair[7] = (dec1[10] || INJECT_DISPARITY_ERROR) && !decoded_pair[5];
				decoded_pair[2] = decoded_pair[8] && (dec0[7-:8] == pcie_gen12_phy_pkg_K_COM);
				decoded_pair[3] = decoded_pair[9] && (dec1[7-:8] == pcie_gen12_phy_pkg_K_COM);
				if (next_count < ELASTIC_DEPTH_PAIRS) begin
					elastic_q[next_wr] = decoded_pair;
					next_wr = (next_wr + 1) % ELASTIC_DEPTH_PAIRS;
					next_count = next_count + 1;
				end
				else begin
					overflow_event = 1'b1;
					rxbuf_fault_q <= 1'b1;
					rxbuf_overflow_fault_q <= 1'b1;
					rx_byte_aligned_o <= 1'b0;
				end
			end
			else if (rx_ei_sym_q[1]) begin
				rx_rd_q <= 1'b0;
				rx_byte_aligned_o <= 1'b0;
				next_wr = 0;
				next_rd = 0;
				next_count = 0;
				elastic_started_q <= 1'b0;
				replay_count_q <= 2'd0;
			end
			if (!fault_active) begin
				if (replay_count_q != 0) begin
					head_pair = replay_q[0];
					head_valid = 1'b1;
					replay_q[0] <= replay_q[1];
					replay_q[1] <= replay_q[2];
					replay_q[2] <= 1'sb0;
					replay_count_q <= replay_count_q - 1'b1;
				end
				else if ((next_count > 0) && (elastic_started_q || (next_count >= (ELASTIC_CORRECTION_MODE == 2 ? 4 : 2)))) begin
					elastic_started_q <= 1'b1;
					head_pair = elastic_q[next_rd];
					head_is_skp_start = ((head_pair[9-:2] == 2'b11) && (head_pair[25-:16] == {pcie_gen12_phy_pkg_K_SKP, pcie_gen12_phy_pkg_K_COM})) && (head_pair[5-:2] == 2'b00);
					second_is_skp_tail = 1'b0;
					third_is_skp_start = 1'b0;
					fourth_is_skp_tail = 1'b0;
					if (next_count > 1)
						second_is_skp_tail = ((elastic_q[(next_rd + 1) % ELASTIC_DEPTH_PAIRS][9-:2] == 2'b11) && (elastic_q[(next_rd + 1) % ELASTIC_DEPTH_PAIRS][25-:16] == {pcie_gen12_phy_pkg_K_SKP, pcie_gen12_phy_pkg_K_SKP})) && (elastic_q[(next_rd + 1) % ELASTIC_DEPTH_PAIRS][5-:2] == 2'b00);
					if (next_count > 2)
						third_is_skp_start = ((elastic_q[(next_rd + 2) % ELASTIC_DEPTH_PAIRS][9-:2] == 2'b11) && (elastic_q[(next_rd + 2) % ELASTIC_DEPTH_PAIRS][25-:16] == {pcie_gen12_phy_pkg_K_SKP, pcie_gen12_phy_pkg_K_COM})) && (elastic_q[(next_rd + 2) % ELASTIC_DEPTH_PAIRS][5-:2] == 2'b00);
					if (next_count > 3)
						fourth_is_skp_tail = ((elastic_q[(next_rd + 3) % ELASTIC_DEPTH_PAIRS][9-:2] == 2'b11) && (elastic_q[(next_rd + 3) % ELASTIC_DEPTH_PAIRS][25-:16] == {pcie_gen12_phy_pkg_K_SKP, pcie_gen12_phy_pkg_K_SKP})) && (elastic_q[(next_rd + 3) % ELASTIC_DEPTH_PAIRS][5-:2] == 2'b00);
					if (((ELASTIC_CORRECTION_MODE == 2) && head_is_skp_start) && (next_count < 4))
						head_valid = 1'b0;
					else if (((head_is_skp_start && second_is_skp_tail) && (correction_count_q >= CLOCK_COR_INTERVAL)) && (ELASTIC_CORRECTION_MODE == 1)) begin
						next_rd = (next_rd + 2) % ELASTIC_DEPTH_PAIRS;
						next_count = next_count - 2;
						gt_rx_clkcor_count_o <= 2'b01;
						correction_count_q <= 1'sb0;
					end
					else if (((((head_is_skp_start && second_is_skp_tail) && third_is_skp_start) && fourth_is_skp_tail) && (correction_count_q >= CLOCK_COR_INTERVAL)) && (ELASTIC_CORRECTION_MODE == 2)) begin
						next_rd = (next_rd + 4) % ELASTIC_DEPTH_PAIRS;
						next_count = next_count - 4;
						gt_rx_clkcor_count_o <= 2'b10;
						correction_count_q <= 1'sb0;
					end
					else if (((head_is_skp_start && second_is_skp_tail) && (correction_count_q >= CLOCK_COR_INTERVAL)) && (ELASTIC_CORRECTION_MODE == 3)) begin
						head_valid = 1'b1;
						next_rd = (next_rd + 2) % ELASTIC_DEPTH_PAIRS;
						next_count = next_count - 2;
						replay_q[0] <= elastic_q[(elastic_rd_q + 1) % ELASTIC_DEPTH_PAIRS];
						replay_q[1] <= head_pair;
						replay_q[2] <= elastic_q[(elastic_rd_q + 1) % ELASTIC_DEPTH_PAIRS];
						replay_count_q <= 2'd3;
						gt_rx_clkcor_count_o <= 2'b11;
						correction_count_q <= 1'sb0;
					end
					else begin
						head_valid = 1'b1;
						next_rd = (next_rd + 1) % ELASTIC_DEPTH_PAIRS;
						next_count = next_count - 1;
					end
				end
				else if ((elastic_started_q && rx_byte_aligned_o) && !rx_ei_sym_q[1]) begin
					underflow_event = 1'b1;
					elastic_started_q <= 1'b0;
					rxbuf_fault_q <= 1'b1;
					rxbuf_overflow_fault_q <= 1'b0;
					rx_byte_aligned_o <= 1'b0;
				end
			end
			if (head_valid) begin
				rx_symbol_data_o <= head_pair[25-:16];
				rx_symbol_is_k_o <= head_pair[9-:2];
				rx_symbol_disparity_error_o <= head_pair[7-:2];
				rx_symbol_code_error_o <= head_pair[5-:2];
				rx_symbol_is_comma_o <= head_pair[3-:2];
				rx_symbol_valid_o <= ((((gt_ready_o && !rx_ei_sym_q[1]) && !INJECT_RXBUF_UNDERFLOW) && !INJECT_RXBUF_OVERFLOW) && !rxbuf_fault_q) && !overflow_event;
				if (head_pair[1-:2] != 2'b00) begin
					if (!rx_byte_aligned_o)
						rx_byte_aligned_o <= 1'b1;
					else if (comma_phase_q != head_pair[1])
						rx_realign_event_o <= 1'b1;
					comma_phase_q <= head_pair[1];
				end
			end
			elastic_wr_q <= next_wr;
			elastic_rd_q <= next_rd;
			elastic_count_q <= next_count;
			if ((INJECT_RXBUF_OVERFLOW || overflow_event) || (rxbuf_fault_q && rxbuf_overflow_fault_q))
				gt_rx_buffer_status_o <= 3'b110;
			else if ((INJECT_RXBUF_UNDERFLOW || underflow_event) || rxbuf_fault_q)
				gt_rx_buffer_status_o <= 3'b101;
			else if (next_count == 0)
				gt_rx_buffer_status_o <= 3'b001;
			else if (next_count >= (ELASTIC_DEPTH_PAIRS - 2))
				gt_rx_buffer_status_o <= 3'b010;
			else
				gt_rx_buffer_status_o <= 3'b000;
			if (gt_tx_electrical_idle_active_o || (power_state_q != 2'b00)) begin
				pcie_tx_p_o <= 1'b0;
				pcie_tx_n_o <= 1'b0;
			end
			else begin
				pcie_tx_p_o <= encoded_pipe_q[0][serial_observe_index_q];
				pcie_tx_n_o <= ~encoded_pipe_q[0][serial_observe_index_q];
				serial_observe_index_q <= (serial_observe_index_q == 5'd19 ? 5'd0 : serial_observe_index_q + 1'b1);
			end
		end
	end
	initial _sv2v_0 = 0;
endmodule
