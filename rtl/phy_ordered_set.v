`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_ordered_set (
	sym_clk_i,
	sym_rst_ni,
	os_tx_req_valid_i,
	os_tx_req_ready_o,
	os_tx_kind_i,
	os_tx_repeat_mode_i,
	os_tx_link_num_i,
	os_tx_lane_num_i,
	os_tx_n_fts_i,
	os_tx_rate_id_i,
	os_tx_training_ctrl_i,
	os_tx_link_num_is_pad_i,
	os_tx_lane_num_is_pad_i,
	skp_tx_req_i,
	os_tx_gen2_rcvrlock_i,
	os_tx_consume_i,
	os_tx_skp_start_o,
	os_tx_skp_done_o,
	os_tx_data_o,
	os_tx_is_k_o,
	os_tx_class_o,
	os_tx_valid_o,
	os_tx_done_o,
	os_rx_data_i,
	os_rx_is_k_i,
	os_rx_valid_i,
	os_rx_error_i,
	os_rx_expected_state_i,
	rx_logical_idle_valid_i,
	rx_logical_idle_char_mask_i,
	os_rx_ts1_qualified_evt_o,
	os_rx_ts2_qualified_evt_o,
	os_rx_fts_evt_o,
	os_rx_skp_evt_o,
	os_rx_eios_evt_o,
	os_rx_eieos_evt_o,
	rx_logical_idle_qualified_evt_o,
	os_rx_hot_reset_evt_o,
	os_rx_loopback_evt_o,
	os_rx_speed_change_evt_o,
	os_rx_fields_o,
	os_rx_error_o
);
	reg _sv2v_0;
	input wire sym_clk_i;
	input wire sym_rst_ni;
	input wire os_tx_req_valid_i;
	output wire os_tx_req_ready_o;
	input wire [2:0] os_tx_kind_i;
	input wire [2:0] os_tx_repeat_mode_i;
	input wire [7:0] os_tx_link_num_i;
	input wire [4:0] os_tx_lane_num_i;
	input wire [7:0] os_tx_n_fts_i;
	input wire [1:0] os_tx_rate_id_i;
	input wire [7:0] os_tx_training_ctrl_i;
	input wire os_tx_link_num_is_pad_i;
	input wire os_tx_lane_num_is_pad_i;
	input wire skp_tx_req_i;
	input wire os_tx_gen2_rcvrlock_i;
	input wire os_tx_consume_i;
	output reg os_tx_skp_start_o;
	output wire os_tx_skp_done_o;
	output reg [15:0] os_tx_data_o;
	output reg [1:0] os_tx_is_k_o;
	output reg [3:0] os_tx_class_o;
	output wire os_tx_valid_o;
	output reg os_tx_done_o;
	input wire [15:0] os_rx_data_i;
	input wire [1:0] os_rx_is_k_i;
	input wire os_rx_valid_i;
	input wire [3:0] os_rx_error_i;
	input wire [5:0] os_rx_expected_state_i;
	input wire rx_logical_idle_valid_i;
	input wire [1:0] rx_logical_idle_char_mask_i;
	output reg os_rx_ts1_qualified_evt_o;
	output reg os_rx_ts2_qualified_evt_o;
	output reg os_rx_fts_evt_o;
	output reg os_rx_skp_evt_o;
	output reg os_rx_eios_evt_o;
	output reg os_rx_eieos_evt_o;
	output reg rx_logical_idle_qualified_evt_o;
	output reg os_rx_hot_reset_evt_o;
	output reg os_rx_loopback_evt_o;
	output reg os_rx_speed_change_evt_o;
	output reg [34:0] os_rx_fields_o;
	output reg [7:0] os_rx_error_o;
	localparam [7:0] OS_RX_ERR_MALFORMED = 8'h41;
	localparam [7:0] OS_RX_ERR_TRUNCATED = 8'h42;
	localparam [7:0] OS_RX_ERR_UNEXPECTED = 8'h43;
	localparam [7:0] OS_RX_ERR_FIELD_MISMATCH = 8'h44;
	localparam [7:0] OS_RX_ERR_COUNT_BROKEN = 8'h45;
	localparam [7:0] OS_RX_ERR_CANDIDATE = 8'h46;
	reg tx_active_q;
	reg [2:0] tx_kind_q;
	reg [3:0] tx_word_index_q;
	reg [34:0] tx_fields_q;
	reg [5:0] gen2_ts_since_eieos_q;
	reg gen2_context_q;
	reg tx_requested_q;
	reg command_valid_q;
	reg command_done_reported_q;
	reg fixed_initial_active_q;
	reg [2:0] command_kind_q;
	reg [34:0] command_fields_q;
	reg [2:0] command_repeat_mode_q;
	localparam [31:0] pcie_gen12_phy_timing_pkg_POLLING_ACTIVE_MIN_TS1_TX = 1024;
	localparam [31:0] REPEAT_COUNT_W = 11;
	reg [10:0] fixed_remaining_q;
	wire cadence_due_c;
	wire cadence_boundary_due_c;
	wire desired_command_valid_c;
	wire desired_matches_command_c;
	reg current_segment_completes_c;
	reg [7:0] tx_link_symbol_c;
	reg [7:0] tx_lane_symbol_c;
	reg [7:0] tx_rate_symbol_c;
	reg [7:0] tx_training_symbol_c;
	reg [34:0] request_fields_c;
	function automatic [3:0] os_word_count;
		input reg [2:0] kind;
		(* full_case, parallel_case *)
		case (kind)
			3'h0, 3'h1, 3'h5: os_word_count = 4'd8;
			3'h2, 3'h3, 3'h4: os_word_count = 4'd2;
			default: os_word_count = 4'd0;
		endcase
	endfunction
	function automatic os_kind_is_valid;
		input reg [2:0] kind;
		os_kind_is_valid = (((((kind == 3'h0) || (kind == 3'h1)) || (kind == 3'h2)) || (kind == 3'h3)) || (kind == 3'h4)) || (kind == 3'h5);
	endfunction
	function automatic repeat_mode_is_fixed;
		input reg [2:0] mode;
		(* full_case, parallel_case *)
		case (mode)
			3'd3, 3'd4, 3'd6, 3'd5: repeat_mode_is_fixed = 1'b1;
			default: repeat_mode_is_fixed = 1'b0;
		endcase
	endfunction
	function automatic repeat_mode_continues;
		input reg [2:0] mode;
		repeat_mode_continues = mode != 3'd0;
	endfunction
	localparam [31:0] pcie_gen12_phy_timing_pkg_CFG_LINKWIDTH_TS_COUNT = 2;
	localparam [31:0] pcie_gen12_phy_timing_pkg_GEN2_EIEOS_TS1_PERIOD = 32;
	localparam [31:0] pcie_gen12_phy_timing_pkg_POLLING_CONFIG_TS2_QUAL_COUNT = 8;
	function automatic [10:0] sv2v_cast_272C8;
		input reg [10:0] inp;
		sv2v_cast_272C8 = inp;
	endfunction
	function automatic signed [10:0] sv2v_cast_272C8_signed;
		input reg signed [10:0] inp;
		sv2v_cast_272C8_signed = inp;
	endfunction
	function automatic [10:0] repeat_count;
		input reg [2:0] mode;
		(* full_case, parallel_case *)
		case (mode)
			3'd3: repeat_count = sv2v_cast_272C8(pcie_gen12_phy_timing_pkg_CFG_LINKWIDTH_TS_COUNT);
			3'd4: repeat_count = sv2v_cast_272C8(pcie_gen12_phy_timing_pkg_POLLING_CONFIG_TS2_QUAL_COUNT);
			3'd6: repeat_count = sv2v_cast_272C8(pcie_gen12_phy_timing_pkg_GEN2_EIEOS_TS1_PERIOD);
			3'd5: repeat_count = sv2v_cast_272C8(pcie_gen12_phy_timing_pkg_POLLING_ACTIVE_MIN_TS1_TX);
			default: repeat_count = sv2v_cast_272C8_signed(1);
		endcase
	endfunction
	assign cadence_due_c = os_tx_gen2_rcvrlock_i && (gen2_ts_since_eieos_q >= pcie_gen12_phy_timing_pkg_GEN2_EIEOS_TS1_PERIOD);
	assign cadence_boundary_due_c = ((tx_kind_q != 3'h5) && os_tx_gen2_rcvrlock_i) && ((gen2_ts_since_eieos_q >= pcie_gen12_phy_timing_pkg_GEN2_EIEOS_TS1_PERIOD) || (((tx_kind_q == 3'h0) && tx_requested_q) && ((gen2_ts_since_eieos_q + 1'b1) >= pcie_gen12_phy_timing_pkg_GEN2_EIEOS_TS1_PERIOD)));
	assign os_tx_req_ready_o = !tx_active_q;
	assign os_tx_valid_o = tx_active_q;
	assign os_tx_skp_done_o = ((tx_active_q && os_tx_consume_i) && (tx_kind_q == 3'h2)) && ((tx_word_index_q + 1'b1) >= os_word_count(tx_kind_q));
	always @(*) begin
		if (_sv2v_0)
			;
		request_fields_c = 1'sb0;
		request_fields_c[34] = 1'b1;
		request_fields_c[33] = os_tx_kind_i == 3'h1;
		request_fields_c[32] = os_tx_link_num_is_pad_i;
		request_fields_c[31] = os_tx_lane_num_is_pad_i;
		request_fields_c[30-:8] = os_tx_link_num_i;
		request_fields_c[22-:5] = os_tx_lane_num_i;
		request_fields_c[17-:8] = os_tx_n_fts_i;
		request_fields_c[9-:2] = os_tx_rate_id_i;
		request_fields_c[7-:8] = os_tx_training_ctrl_i;
	end
	assign desired_command_valid_c = os_tx_req_valid_i && os_kind_is_valid(os_tx_kind_i);
	assign desired_matches_command_c = (((desired_command_valid_c && command_valid_q) && (os_tx_kind_i == command_kind_q)) && (os_tx_repeat_mode_i == command_repeat_mode_q)) && (request_fields_c == command_fields_q);
	always @(*) begin : p_segment_completion
		if (_sv2v_0)
			;
		current_segment_completes_c = 1'b0;
		if (tx_requested_q && !command_done_reported_q) begin
			if (repeat_mode_is_fixed(command_repeat_mode_q))
				current_segment_completes_c = fixed_initial_active_q && (fixed_remaining_q <= sv2v_cast_272C8_signed(1));
			else
				current_segment_completes_c = 1'b1;
		end
	end
	localparam [7:0] pcie_gen12_phy_pkg_D_TS1 = 8'h4a;
	localparam [7:0] pcie_gen12_phy_pkg_D_TS2 = 8'h45;
	localparam [7:0] pcie_gen12_phy_pkg_K_COM = 8'hbc;
	localparam [7:0] pcie_gen12_phy_pkg_K_EIE = 8'hfc;
	localparam [7:0] pcie_gen12_phy_pkg_K_EIOS = 8'h7c;
	localparam [7:0] pcie_gen12_phy_pkg_K_FTS = 8'h3c;
	localparam [7:0] pcie_gen12_phy_pkg_K_PAD = 8'hf7;
	localparam [7:0] pcie_gen12_phy_pkg_K_SKP = 8'h1c;
	always @(*) begin : p_tx_template
		if (_sv2v_0)
			;
		tx_link_symbol_c = (tx_fields_q[32] ? pcie_gen12_phy_pkg_K_PAD : tx_fields_q[30-:8]);
		tx_lane_symbol_c = (tx_fields_q[31] ? pcie_gen12_phy_pkg_K_PAD : {3'b000, tx_fields_q[22-:5]});
		tx_rate_symbol_c = {tx_fields_q[5], 4'b0000, tx_fields_q[9], tx_fields_q[8], 1'b0};
		tx_training_symbol_c = {3'b000, tx_fields_q[4:0]};
		os_tx_data_o = 16'h0000;
		os_tx_is_k_o = 2'b00;
		os_tx_class_o = 4'hf;
		(* full_case, parallel_case *)
		case (tx_kind_q)
			3'h0, 3'h1: begin
				os_tx_class_o = 4'h1;
				(* full_case, parallel_case *)
				case (tx_word_index_q)
					4'd0: begin
						os_tx_data_o = {tx_link_symbol_c, pcie_gen12_phy_pkg_K_COM};
						os_tx_is_k_o = {tx_fields_q[32], 1'b1};
					end
					4'd1: begin
						os_tx_data_o = {tx_fields_q[17-:8], tx_lane_symbol_c};
						os_tx_is_k_o = {1'b0, tx_fields_q[31]};
					end
					4'd2: begin
						os_tx_data_o = {tx_training_symbol_c, tx_rate_symbol_c};
						os_tx_is_k_o = 2'b00;
					end
					default: begin
						os_tx_data_o = (tx_kind_q == 3'h1 ? {pcie_gen12_phy_pkg_D_TS2, pcie_gen12_phy_pkg_D_TS2} : {pcie_gen12_phy_pkg_D_TS1, pcie_gen12_phy_pkg_D_TS1});
						os_tx_is_k_o = 2'b00;
					end
				endcase
			end
			3'h2: begin
				os_tx_class_o = 4'h2;
				os_tx_data_o = (tx_word_index_q == 0 ? {pcie_gen12_phy_pkg_K_SKP, pcie_gen12_phy_pkg_K_COM} : {pcie_gen12_phy_pkg_K_SKP, pcie_gen12_phy_pkg_K_SKP});
				os_tx_is_k_o = 2'b11;
			end
			3'h3: begin
				os_tx_class_o = 4'h5;
				os_tx_data_o = (tx_word_index_q == 0 ? {pcie_gen12_phy_pkg_K_FTS, pcie_gen12_phy_pkg_K_COM} : {pcie_gen12_phy_pkg_K_FTS, pcie_gen12_phy_pkg_K_FTS});
				os_tx_is_k_o = 2'b11;
			end
			3'h4: begin
				os_tx_class_o = 4'h3;
				os_tx_data_o = (tx_word_index_q == 0 ? {pcie_gen12_phy_pkg_K_EIOS, pcie_gen12_phy_pkg_K_COM} : {pcie_gen12_phy_pkg_K_EIOS, pcie_gen12_phy_pkg_K_EIOS});
				os_tx_is_k_o = 2'b11;
			end
			3'h5: begin
				os_tx_class_o = 4'h4;
				if (tx_word_index_q == 0) begin
					os_tx_data_o = {pcie_gen12_phy_pkg_K_EIE, pcie_gen12_phy_pkg_K_COM};
					os_tx_is_k_o = 2'b11;
				end
				else if (tx_word_index_q == 7) begin
					os_tx_data_o = {pcie_gen12_phy_pkg_D_TS1, pcie_gen12_phy_pkg_K_EIE};
					os_tx_is_k_o = 2'b01;
				end
				else begin
					os_tx_data_o = {pcie_gen12_phy_pkg_K_EIE, pcie_gen12_phy_pkg_K_EIE};
					os_tx_is_k_o = 2'b11;
				end
			end
			default: begin
				os_tx_data_o = 16'h0000;
				os_tx_is_k_o = 2'b00;
				os_tx_class_o = 4'hf;
			end
		endcase
	end
	task automatic capture_desired_command;
		input reg [2:0] desired_kind;
		input reg [34:0] desired_fields;
		input reg [2:0] desired_repeat;
		begin
			command_valid_q <= 1'b1;
			command_kind_q <= desired_kind;
			command_fields_q <= desired_fields;
			command_repeat_mode_q <= desired_repeat;
			command_done_reported_q <= 1'b0;
			fixed_initial_active_q <= repeat_mode_is_fixed(desired_repeat);
			fixed_remaining_q <= repeat_count(desired_repeat);
		end
	endtask
	task automatic clear_desired_command;
		begin
			command_valid_q <= 1'b0;
			command_kind_q <= 3'h7;
			command_fields_q <= 1'sb0;
			command_repeat_mode_q <= 3'd0;
			command_done_reported_q <= 1'b0;
			fixed_initial_active_q <= 1'b0;
			fixed_remaining_q <= 1'sb0;
		end
	endtask
	task automatic launch_requested_os;
		input reg [2:0] launch_kind;
		input reg [34:0] launch_fields;
		begin
			tx_active_q <= 1'b1;
			tx_kind_q <= launch_kind;
			tx_fields_q <= launch_fields;
			tx_word_index_q <= 1'sb0;
			tx_requested_q <= 1'b1;
		end
	endtask
	task automatic launch_autonomous_os;
		input reg [2:0] launch_kind;
		begin
			tx_active_q <= 1'b1;
			tx_kind_q <= launch_kind;
			tx_word_index_q <= 1'sb0;
			tx_requested_q <= 1'b0;
		end
	endtask
	always @(posedge sym_clk_i or negedge sym_rst_ni) begin : p_tx_state
		if (!sym_rst_ni) begin
			tx_active_q <= 1'b0;
			tx_kind_q <= 3'h7;
			tx_word_index_q <= 1'sb0;
			tx_fields_q <= 1'sb0;
			gen2_ts_since_eieos_q <= 1'sb0;
			gen2_context_q <= 1'b0;
			tx_requested_q <= 1'b0;
			command_valid_q <= 1'b0;
			command_done_reported_q <= 1'b0;
			fixed_initial_active_q <= 1'b0;
			command_kind_q <= 3'h7;
			command_fields_q <= 1'sb0;
			command_repeat_mode_q <= 3'd0;
			fixed_remaining_q <= 1'sb0;
			os_tx_done_o <= 1'b0;
			os_tx_skp_start_o <= 1'b0;
		end
		else begin
			os_tx_done_o <= 1'b0;
			os_tx_skp_start_o <= 1'b0;
			gen2_context_q <= os_tx_gen2_rcvrlock_i;
			if (!os_tx_gen2_rcvrlock_i)
				gen2_ts_since_eieos_q <= 1'sb0;
			else if (!gen2_context_q)
				gen2_ts_since_eieos_q <= 1'sb0;
			if (tx_active_q && os_tx_consume_i) begin
				if ((tx_kind_q == 3'h2) && (tx_word_index_q == 0))
					os_tx_skp_start_o <= 1'b1;
				if ((tx_word_index_q + 1'b1) >= os_word_count(tx_kind_q)) begin
					tx_word_index_q <= 1'sb0;
					if (tx_kind_q == 3'h5)
						gen2_ts_since_eieos_q <= 1'sb0;
					else if ((tx_requested_q && (tx_kind_q == 3'h0)) && os_tx_gen2_rcvrlock_i) begin
						if (gen2_ts_since_eieos_q < pcie_gen12_phy_timing_pkg_GEN2_EIEOS_TS1_PERIOD)
							gen2_ts_since_eieos_q <= gen2_ts_since_eieos_q + 1'b1;
					end
					if (tx_requested_q) begin
						if (current_segment_completes_c)
							os_tx_done_o <= 1'b1;
						if (!desired_matches_command_c) begin
							if (desired_command_valid_c)
								capture_desired_command(os_tx_kind_i, request_fields_c, os_tx_repeat_mode_i);
							else
								clear_desired_command;
							if (cadence_boundary_due_c)
								launch_autonomous_os(3'h5);
							else if (desired_command_valid_c)
								launch_requested_os(os_tx_kind_i, request_fields_c);
							else if (skp_tx_req_i && (tx_kind_q != 3'h2))
								launch_autonomous_os(3'h2);
							else begin
								tx_active_q <= 1'b0;
								tx_kind_q <= 3'h7;
								tx_requested_q <= 1'b0;
							end
						end
						else begin
							if (!command_done_reported_q) begin
								if (repeat_mode_is_fixed(command_repeat_mode_q)) begin
									if (fixed_initial_active_q && (fixed_remaining_q > sv2v_cast_272C8_signed(1)))
										fixed_remaining_q <= fixed_remaining_q - 1'b1;
									else if (current_segment_completes_c) begin
										fixed_remaining_q <= 1'sb0;
										fixed_initial_active_q <= 1'b0;
										command_done_reported_q <= 1'b1;
									end
								end
								else if (current_segment_completes_c)
									command_done_reported_q <= 1'b1;
							end
							if (cadence_boundary_due_c)
								launch_autonomous_os(3'h5);
							else if (skp_tx_req_i && (tx_kind_q != 3'h2))
								launch_autonomous_os(3'h2);
							else if (repeat_mode_continues(command_repeat_mode_q))
								launch_requested_os(command_kind_q, command_fields_q);
							else begin
								tx_active_q <= 1'b0;
								tx_kind_q <= 3'h7;
								tx_requested_q <= 1'b0;
							end
						end
					end
					else begin
						if (!desired_matches_command_c) begin
							if (desired_command_valid_c)
								capture_desired_command(os_tx_kind_i, request_fields_c, os_tx_repeat_mode_i);
							else
								clear_desired_command;
						end
						if (cadence_boundary_due_c)
							launch_autonomous_os(3'h5);
						else if (desired_command_valid_c && !desired_matches_command_c)
							launch_requested_os(os_tx_kind_i, request_fields_c);
						else if (desired_matches_command_c) begin
							if (skp_tx_req_i && (tx_kind_q != 3'h2))
								launch_autonomous_os(3'h2);
							else if (repeat_mode_continues(command_repeat_mode_q) || !command_done_reported_q)
								launch_requested_os(command_kind_q, command_fields_q);
							else begin
								tx_active_q <= 1'b0;
								tx_kind_q <= 3'h7;
								tx_requested_q <= 1'b0;
							end
						end
						else if (skp_tx_req_i && (tx_kind_q != 3'h2))
							launch_autonomous_os(3'h2);
						else begin
							tx_active_q <= 1'b0;
							tx_kind_q <= 3'h7;
							tx_requested_q <= 1'b0;
						end
					end
				end
				else
					tx_word_index_q <= tx_word_index_q + 1'b1;
			end
			else if (!tx_active_q) begin
				if (!desired_matches_command_c) begin
					if (desired_command_valid_c)
						capture_desired_command(os_tx_kind_i, request_fields_c, os_tx_repeat_mode_i);
					else if (command_valid_q)
						clear_desired_command;
				end
				if (cadence_due_c)
					launch_autonomous_os(3'h5);
				else if (desired_command_valid_c && !desired_matches_command_c)
					launch_requested_os(os_tx_kind_i, request_fields_c);
				else if (desired_matches_command_c && (repeat_mode_continues(command_repeat_mode_q) || !command_done_reported_q)) begin
					if (skp_tx_req_i)
						launch_autonomous_os(3'h2);
					else
						launch_requested_os(command_kind_q, command_fields_q);
				end
				else if (skp_tx_req_i)
					launch_autonomous_os(3'h2);
			end
		end
	end
	reg rx_parse_active_q;
	reg rx_parse_active_d;
	reg [2:0] rx_parse_kind_q;
	reg [2:0] rx_parse_kind_d;
	reg [4:0] rx_symbol_index_q;
	reg [4:0] rx_symbol_index_d;
	reg [7:0] rx_short_symbol_q;
	reg [7:0] rx_short_symbol_d;
	reg [34:0] rx_work_fields_q;
	reg [34:0] rx_work_fields_d;
	reg rx_encoding_error_q;
	reg rx_encoding_error_d;
	reg [34:0] rx_last_ts1_q;
	reg [34:0] rx_last_ts1_d;
	reg [34:0] rx_last_ts2_q;
	reg [34:0] rx_last_ts2_d;
	reg [7:0] rx_ts1_count_q;
	reg [7:0] rx_ts1_count_d;
	reg [7:0] rx_ts2_count_q;
	reg [7:0] rx_ts2_count_d;
	reg [7:0] rx_idle_count_q;
	reg [7:0] rx_idle_count_d;
	reg [5:0] expected_state_q;
	reg [5:0] expected_state_d;
	reg [34:0] rx_fields_out_d;
	reg rx_ts1_evt_d;
	reg rx_ts2_evt_d;
	reg rx_fts_evt_d;
	reg rx_skp_evt_d;
	reg rx_eios_evt_d;
	reg rx_eieos_evt_d;
	reg rx_idle_evt_d;
	reg rx_hot_reset_evt_d;
	reg rx_loopback_evt_d;
	reg rx_speed_change_evt_d;
	reg [7:0] rx_error_d;
	localparam [31:0] pcie_gen12_phy_timing_pkg_CFG_COMPLETE_TS2_COUNT = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_CFG_LANENUM_TS_COUNT = 2;
	localparam [31:0] pcie_gen12_phy_timing_pkg_POLLING_ACTIVE_TS_QUAL_COUNT = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RECOVERY_TS_COUNT = 8;
	function automatic [31:0] ts_threshold;
		input reg [5:0] state_index;
		(* full_case, parallel_case *)
		case (state_index)
			6'h03: ts_threshold = pcie_gen12_phy_timing_pkg_POLLING_ACTIVE_TS_QUAL_COUNT;
			6'h05: ts_threshold = pcie_gen12_phy_timing_pkg_POLLING_CONFIG_TS2_QUAL_COUNT;
			6'h06, 6'h07: ts_threshold = pcie_gen12_phy_timing_pkg_CFG_LINKWIDTH_TS_COUNT;
			6'h08, 6'h09: ts_threshold = pcie_gen12_phy_timing_pkg_CFG_LANENUM_TS_COUNT;
			6'h0a: ts_threshold = pcie_gen12_phy_timing_pkg_CFG_COMPLETE_TS2_COUNT;
			6'h0d, 6'h0e: ts_threshold = pcie_gen12_phy_timing_pkg_RECOVERY_TS_COUNT;
			6'h0c, 6'h1d, 6'h1f, 6'h20, 6'h21, 6'h22: ts_threshold = pcie_gen12_phy_timing_pkg_CFG_LINKWIDTH_TS_COUNT;
			default: ts_threshold = 1;
		endcase
	endfunction
	localparam [31:0] pcie_gen12_phy_timing_pkg_CFG_IDLE_COUNT = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_LOGICAL_IDLE_QUAL_COUNT = 8;
	localparam [31:0] pcie_gen12_phy_timing_pkg_RECOVERY_IDLE_COUNT = 8;
	function automatic [31:0] idle_threshold;
		input reg [5:0] state_index;
		(* full_case, parallel_case *)
		case (state_index)
			6'h0b: idle_threshold = pcie_gen12_phy_timing_pkg_CFG_IDLE_COUNT;
			6'h10: idle_threshold = pcie_gen12_phy_timing_pkg_RECOVERY_IDLE_COUNT;
			default: idle_threshold = pcie_gen12_phy_timing_pkg_LOGICAL_IDLE_QUAL_COUNT;
		endcase
	endfunction
	function automatic idle_state_enabled;
		input reg [5:0] state_index;
		idle_state_enabled = (state_index == 6'h0b) || (state_index == 6'h10);
	endfunction
	function automatic expected_ts_kind;
		input reg [5:0] state_index;
		input reg is_ts2;
		(* full_case, parallel_case *)
		case (state_index)
			6'h03, 6'h06, 6'h07, 6'h08, 6'h0d, 6'h0c, 6'h1d, 6'h1f, 6'h20, 6'h21, 6'h22: expected_ts_kind = !is_ts2;
			6'h05, 6'h09, 6'h0a, 6'h0e: expected_ts_kind = is_ts2;
			default: expected_ts_kind = 1'b0;
		endcase
	endfunction
	function automatic ts_fields_legal;
		input reg [34:0] fields;
		input reg [5:0] state_index;
		reg exclusive_control;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			// Count only known 1 bits, matching the four-state $onehot0 rule.
			exclusive_control = !(((fields[0] === 1'b1) && (fields[1] === 1'b1)) ||
			                      ((fields[0] === 1'b1) && (fields[2] === 1'b1)) ||
			                      ((fields[1] === 1'b1) && (fields[2] === 1'b1)));
			if (((((!fields[34] || !fields[8]) || (fields[9] && !fields[8])) || !exclusive_control) || (fields[7:6] != 0)) || (!fields[31] && (fields[22-:5] != 0))) begin
				ts_fields_legal = 1'b0;
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				if (fields[5] && (state_index != 6'h0e)) begin
					ts_fields_legal = 1'b0;
					_sv2v_jump = 2'b11;
				end
				if (_sv2v_jump == 2'b00)
					(* full_case, parallel_case *)
					case (state_index)
						6'h03, 6'h05, 6'h06: begin
							ts_fields_legal = fields[32] && fields[31];
							_sv2v_jump = 2'b11;
						end
						6'h07: begin
							ts_fields_legal = !fields[32] && fields[31];
							_sv2v_jump = 2'b11;
						end
						6'h08: begin
							ts_fields_legal = !fields[32] && fields[31];
							_sv2v_jump = 2'b11;
						end
						6'h09, 6'h0a: begin
							ts_fields_legal = (!fields[32] && !fields[31]) && (fields[22-:5] == 0);
							_sv2v_jump = 2'b11;
						end
						default: begin
							ts_fields_legal = 1'b1;
							_sv2v_jump = 2'b11;
						end
					endcase
			end
		end
	endfunction
	localparam [7:0] pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET = 8'h01;
	localparam [7:0] pcie_gen12_phy_pkg_TS_CTRL_LOOPBACK = 8'h04;
	localparam [7:0] pcie_gen12_phy_pkg_TS_CTRL_SPEED_CHANGE = 8'h20;
	always @(*) begin : p_rx_parser
		reg [7:0] ch;
		reg is_k;
		reg complete_ts;
		reg complete_short;
		reg ts_is_ts2;
		reg fields_legal;
		reg kind_expected;
		reg [7:0] next_count;
		reg [34:0] completed_fields;
		if (_sv2v_0)
			;
		rx_parse_active_d = rx_parse_active_q;
		rx_parse_kind_d = rx_parse_kind_q;
		rx_symbol_index_d = rx_symbol_index_q;
		rx_short_symbol_d = rx_short_symbol_q;
		rx_work_fields_d = rx_work_fields_q;
		rx_encoding_error_d = rx_encoding_error_q;
		rx_last_ts1_d = rx_last_ts1_q;
		rx_last_ts2_d = rx_last_ts2_q;
		rx_ts1_count_d = rx_ts1_count_q;
		rx_ts2_count_d = rx_ts2_count_q;
		rx_idle_count_d = rx_idle_count_q;
		expected_state_d = os_rx_expected_state_i;
		rx_fields_out_d = os_rx_fields_o;
		rx_ts1_evt_d = 1'b0;
		rx_ts2_evt_d = 1'b0;
		rx_fts_evt_d = 1'b0;
		rx_skp_evt_d = 1'b0;
		rx_eios_evt_d = 1'b0;
		rx_eieos_evt_d = 1'b0;
		rx_idle_evt_d = 1'b0;
		rx_hot_reset_evt_d = 1'b0;
		rx_loopback_evt_d = 1'b0;
		rx_speed_change_evt_d = 1'b0;
		rx_error_d = 8'h00;
		if (os_rx_expected_state_i != expected_state_q) begin
			rx_parse_active_d = 1'b0;
			rx_parse_kind_d = 3'h7;
			rx_symbol_index_d = 1'sb0;
			rx_encoding_error_d = 1'b0;
			rx_ts1_count_d = 1'sb0;
			rx_ts2_count_d = 1'sb0;
			rx_idle_count_d = 1'sb0;
			rx_last_ts1_d = 1'sb0;
			rx_last_ts2_d = 1'sb0;
		end
		else begin
			if (rx_logical_idle_valid_i && idle_state_enabled(os_rx_expected_state_i)) begin : sv2v_autoblock_1
				reg [31:0] idle_lane;
				for (idle_lane = 0; idle_lane < 2; idle_lane = idle_lane + 1)
					if (rx_logical_idle_char_mask_i[idle_lane]) begin
						if (rx_idle_count_d != 8'hff) begin
							next_count = rx_idle_count_d + 1'b1;
							rx_idle_count_d = next_count;
						end
						else
							next_count = rx_idle_count_d;
						if (next_count == idle_threshold(os_rx_expected_state_i))
							rx_idle_evt_d = 1'b1;
					end
					else
						rx_idle_count_d = 1'sb0;
			end
			else if (!idle_state_enabled(os_rx_expected_state_i))
				rx_idle_count_d = 1'sb0;
			if (os_rx_valid_i) begin
				if (os_rx_error_i != 0) begin
					if ((rx_parse_active_q || (rx_ts1_count_q != 0)) || (rx_ts2_count_q != 0))
						rx_error_d = OS_RX_ERR_CANDIDATE;
					rx_parse_active_d = 1'b0;
					rx_parse_kind_d = 3'h7;
					rx_symbol_index_d = 1'sb0;
					rx_encoding_error_d = 1'b0;
					rx_ts1_count_d = 1'sb0;
					rx_ts2_count_d = 1'sb0;
				end
				else begin : sv2v_autoblock_2
					reg [31:0] lane;
					for (lane = 0; lane < 2; lane = lane + 1)
						begin
							ch = os_rx_data_i[lane * 8+:8];
							is_k = os_rx_is_k_i[lane];
							complete_ts = 1'b0;
							complete_short = 1'b0;
							if (is_k && (ch == pcie_gen12_phy_pkg_K_COM)) begin
								if (rx_parse_active_d && (rx_error_d == 0)) begin
									rx_error_d = OS_RX_ERR_TRUNCATED;
									rx_ts1_count_d = 1'sb0;
									rx_ts2_count_d = 1'sb0;
								end
								rx_parse_active_d = 1'b1;
								rx_parse_kind_d = 3'h7;
								rx_symbol_index_d = 5'd1;
								rx_encoding_error_d = 1'b0;
								rx_work_fields_d = 1'sb0;
								rx_idle_count_d = 1'sb0;
							end
							else if (rx_parse_active_d) begin
								(* full_case, parallel_case *)
								case (rx_symbol_index_d)
									5'd1:
										if (is_k && (ch == pcie_gen12_phy_pkg_K_SKP)) begin
											rx_parse_kind_d = 3'h2;
											rx_short_symbol_d = pcie_gen12_phy_pkg_K_SKP;
											rx_symbol_index_d = 5'd2;
										end
										else if (is_k && (ch == pcie_gen12_phy_pkg_K_FTS)) begin
											rx_parse_kind_d = 3'h3;
											rx_short_symbol_d = pcie_gen12_phy_pkg_K_FTS;
											rx_symbol_index_d = 5'd2;
										end
										else if (is_k && (ch == pcie_gen12_phy_pkg_K_EIOS)) begin
											rx_parse_kind_d = 3'h4;
											rx_short_symbol_d = pcie_gen12_phy_pkg_K_EIOS;
											rx_symbol_index_d = 5'd2;
										end
										else if (is_k && (ch == pcie_gen12_phy_pkg_K_EIE)) begin
											rx_parse_kind_d = 3'h5;
											rx_symbol_index_d = 5'd2;
										end
										else if (!is_k || (ch == pcie_gen12_phy_pkg_K_PAD)) begin
											rx_parse_kind_d = 3'h7;
											rx_work_fields_d[32] = is_k;
											rx_work_fields_d[30-:8] = (is_k ? 8'h00 : ch);
											rx_symbol_index_d = 5'd2;
										end
										else begin
											rx_error_d = OS_RX_ERR_MALFORMED;
											rx_parse_active_d = 1'b0;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
									5'd2:
										if (((rx_parse_kind_d == 3'h2) || (rx_parse_kind_d == 3'h3)) || (rx_parse_kind_d == 3'h4)) begin
											if (is_k && (ch == rx_short_symbol_d))
												rx_symbol_index_d = 5'd3;
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_parse_active_d = 1'b0;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
										end
										else if (rx_parse_kind_d == 3'h5) begin
											if (is_k && (ch == pcie_gen12_phy_pkg_K_EIE))
												rx_symbol_index_d = 5'd3;
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_parse_active_d = 1'b0;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
										end
										else if (!is_k || (ch == pcie_gen12_phy_pkg_K_PAD)) begin
											rx_work_fields_d[31] = is_k;
											rx_work_fields_d[22-:5] = (is_k ? 5'd0 : ch[4:0]);
											if (!is_k && (ch[7:5] != 0))
												rx_encoding_error_d = 1'b1;
											rx_symbol_index_d = 5'd3;
										end
										else begin
											rx_error_d = OS_RX_ERR_MALFORMED;
											rx_parse_active_d = 1'b0;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
									5'd3:
										if (((rx_parse_kind_d == 3'h2) || (rx_parse_kind_d == 3'h3)) || (rx_parse_kind_d == 3'h4)) begin
											if (is_k && (ch == rx_short_symbol_d))
												complete_short = 1'b1;
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
											rx_parse_active_d = 1'b0;
											rx_symbol_index_d = 1'sb0;
										end
										else if (rx_parse_kind_d == 3'h5) begin
											if (is_k && (ch == pcie_gen12_phy_pkg_K_EIE))
												rx_symbol_index_d = 5'd4;
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_parse_active_d = 1'b0;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
										end
										else if (!is_k) begin
											rx_work_fields_d[17-:8] = ch;
											rx_symbol_index_d = 5'd4;
										end
										else begin
											rx_error_d = OS_RX_ERR_MALFORMED;
											rx_parse_active_d = 1'b0;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
									5'd4:
										if (rx_parse_kind_d == 3'h5) begin
											if (is_k && (ch == pcie_gen12_phy_pkg_K_EIE))
												rx_symbol_index_d = 5'd5;
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_parse_active_d = 1'b0;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
										end
										else if (!is_k) begin
											rx_work_fields_d[9-:2] = {ch[2], ch[1]};
											rx_work_fields_d[5] = ch[7];
											if (ch[0] || (ch[6:3] != 0))
												rx_encoding_error_d = 1'b1;
											rx_symbol_index_d = 5'd5;
										end
										else begin
											rx_error_d = OS_RX_ERR_MALFORMED;
											rx_parse_active_d = 1'b0;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
									5'd5:
										if (rx_parse_kind_d == 3'h5) begin
											if (is_k && (ch == pcie_gen12_phy_pkg_K_EIE))
												rx_symbol_index_d = 5'd6;
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_parse_active_d = 1'b0;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
										end
										else if (!is_k) begin
											rx_work_fields_d[4:0] = ch[4:0];
											if (ch[7:5] != 0)
												rx_encoding_error_d = 1'b1;
											rx_symbol_index_d = 5'd6;
										end
										else begin
											rx_error_d = OS_RX_ERR_MALFORMED;
											rx_parse_active_d = 1'b0;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
									5'd6:
										if (rx_parse_kind_d == 3'h5) begin
											if (is_k && (ch == pcie_gen12_phy_pkg_K_EIE))
												rx_symbol_index_d = 5'd7;
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_parse_active_d = 1'b0;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
										end
										else if (!is_k && ((ch == pcie_gen12_phy_pkg_D_TS1) || (ch == pcie_gen12_phy_pkg_D_TS2))) begin
											rx_parse_kind_d = (ch == pcie_gen12_phy_pkg_D_TS2 ? 3'h1 : 3'h0);
											rx_work_fields_d[33] = ch == pcie_gen12_phy_pkg_D_TS2;
											rx_symbol_index_d = 5'd7;
										end
										else begin
											rx_error_d = OS_RX_ERR_MALFORMED;
											rx_parse_active_d = 1'b0;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
									default:
										if (rx_parse_kind_d == 3'h5) begin
											if (((rx_symbol_index_d <= 5'd14) && is_k) && (ch == pcie_gen12_phy_pkg_K_EIE))
												rx_symbol_index_d = rx_symbol_index_d + 1'b1;
											else if (((rx_symbol_index_d == 5'd15) && !is_k) && (ch == pcie_gen12_phy_pkg_D_TS1)) begin
												rx_eieos_evt_d = 1'b1;
												rx_parse_active_d = 1'b0;
												rx_symbol_index_d = 1'sb0;
											end
											else begin
												rx_error_d = OS_RX_ERR_MALFORMED;
												rx_parse_active_d = 1'b0;
												rx_ts1_count_d = 1'sb0;
												rx_ts2_count_d = 1'sb0;
											end
										end
										else if (!is_k && (((rx_parse_kind_d == 3'h0) && (ch == pcie_gen12_phy_pkg_D_TS1)) || ((rx_parse_kind_d == 3'h1) && (ch == pcie_gen12_phy_pkg_D_TS2)))) begin
											if (rx_symbol_index_d == 5'd15) begin
												complete_ts = 1'b1;
												rx_parse_active_d = 1'b0;
												rx_symbol_index_d = 1'sb0;
											end
											else
												rx_symbol_index_d = rx_symbol_index_d + 1'b1;
										end
										else begin
											rx_error_d = OS_RX_ERR_MALFORMED;
											rx_parse_active_d = 1'b0;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
								endcase
								if (complete_short)
									(* full_case, parallel_case *)
									case (rx_parse_kind_d)
										3'h2: rx_skp_evt_d = 1'b1;
										3'h3: begin
											rx_fts_evt_d = 1'b1;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
										3'h4: begin
											rx_eios_evt_d = 1'b1;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
										default:
											;
									endcase
								if (complete_ts) begin
									completed_fields = rx_work_fields_d;
									completed_fields[34] = 1'b1;
									ts_is_ts2 = rx_parse_kind_d == 3'h1;
									completed_fields[33] = ts_is_ts2;
									fields_legal = !rx_encoding_error_d && ts_fields_legal(completed_fields, os_rx_expected_state_i);
									kind_expected = expected_ts_kind(os_rx_expected_state_i, ts_is_ts2);
									if (!fields_legal) begin
										rx_error_d = OS_RX_ERR_FIELD_MISMATCH;
										rx_ts1_count_d = 1'sb0;
										rx_ts2_count_d = 1'sb0;
									end
									else begin
										rx_fields_out_d = completed_fields;
										if (!kind_expected) begin
											rx_error_d = OS_RX_ERR_UNEXPECTED;
											rx_ts1_count_d = 1'sb0;
											rx_ts2_count_d = 1'sb0;
										end
										else if (!ts_is_ts2) begin
											rx_ts2_count_d = 1'sb0;
											if (rx_last_ts1_q[34] && (completed_fields == rx_last_ts1_q))
												next_count = (rx_ts1_count_q == 8'hff ? 8'hff : rx_ts1_count_q + 1'b1);
											else begin
												next_count = 8'd1;
												if (rx_ts1_count_q != 0)
													rx_error_d = OS_RX_ERR_COUNT_BROKEN;
											end
											rx_last_ts1_d = completed_fields;
											rx_ts1_count_d = next_count;
											if (next_count == ts_threshold(os_rx_expected_state_i)) begin
												rx_ts1_evt_d = 1'b1;
												rx_hot_reset_evt_d = |(completed_fields[7-:8] & pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET);
												rx_loopback_evt_d = |(completed_fields[7-:8] & pcie_gen12_phy_pkg_TS_CTRL_LOOPBACK);
												rx_speed_change_evt_d = |(completed_fields[7-:8] & pcie_gen12_phy_pkg_TS_CTRL_SPEED_CHANGE);
											end
										end
										else begin
											rx_ts1_count_d = 1'sb0;
											if (rx_last_ts2_q[34] && (completed_fields == rx_last_ts2_q))
												next_count = (rx_ts2_count_q == 8'hff ? 8'hff : rx_ts2_count_q + 1'b1);
											else begin
												next_count = 8'd1;
												if (rx_ts2_count_q != 0)
													rx_error_d = OS_RX_ERR_COUNT_BROKEN;
											end
											rx_last_ts2_d = completed_fields;
											rx_ts2_count_d = next_count;
											if (next_count == ts_threshold(os_rx_expected_state_i)) begin
												rx_ts2_evt_d = 1'b1;
												rx_hot_reset_evt_d = |(completed_fields[7-:8] & pcie_gen12_phy_pkg_TS_CTRL_HOT_RESET);
												rx_loopback_evt_d = |(completed_fields[7-:8] & pcie_gen12_phy_pkg_TS_CTRL_LOOPBACK);
												rx_speed_change_evt_d = |(completed_fields[7-:8] & pcie_gen12_phy_pkg_TS_CTRL_SPEED_CHANGE);
											end
										end
									end
									rx_encoding_error_d = 1'b0;
								end
							end
							else if ((rx_ts1_count_d != 0) || (rx_ts2_count_d != 0)) begin
								rx_error_d = OS_RX_ERR_COUNT_BROKEN;
								rx_ts1_count_d = 1'sb0;
								rx_ts2_count_d = 1'sb0;
							end
						end
				end
			end
			else begin
				if (rx_parse_active_q)
					rx_error_d = OS_RX_ERR_TRUNCATED;
				else if ((rx_ts1_count_q != 0) || (rx_ts2_count_q != 0))
					rx_error_d = OS_RX_ERR_COUNT_BROKEN;
				rx_parse_active_d = 1'b0;
				rx_parse_kind_d = 3'h7;
				rx_symbol_index_d = 1'sb0;
				rx_encoding_error_d = 1'b0;
				rx_ts1_count_d = 1'sb0;
				rx_ts2_count_d = 1'sb0;
				if (!rx_logical_idle_valid_i)
					rx_idle_count_d = 1'sb0;
			end
		end
	end
	always @(posedge sym_clk_i or negedge sym_rst_ni) begin : p_rx_state
		if (!sym_rst_ni) begin
			rx_parse_active_q <= 1'b0;
			rx_parse_kind_q <= 3'h7;
			rx_symbol_index_q <= 1'sb0;
			rx_short_symbol_q <= 1'sb0;
			rx_work_fields_q <= 1'sb0;
			rx_encoding_error_q <= 1'b0;
			rx_last_ts1_q <= 1'sb0;
			rx_last_ts2_q <= 1'sb0;
			rx_ts1_count_q <= 1'sb0;
			rx_ts2_count_q <= 1'sb0;
			rx_idle_count_q <= 1'sb0;
			expected_state_q <= 1'sb0;
			os_rx_fields_o <= 1'sb0;
			os_rx_ts1_qualified_evt_o <= 1'b0;
			os_rx_ts2_qualified_evt_o <= 1'b0;
			os_rx_fts_evt_o <= 1'b0;
			os_rx_skp_evt_o <= 1'b0;
			os_rx_eios_evt_o <= 1'b0;
			os_rx_eieos_evt_o <= 1'b0;
			rx_logical_idle_qualified_evt_o <= 1'b0;
			os_rx_hot_reset_evt_o <= 1'b0;
			os_rx_loopback_evt_o <= 1'b0;
			os_rx_speed_change_evt_o <= 1'b0;
			os_rx_error_o <= 8'h00;
		end
		else begin
			rx_parse_active_q <= rx_parse_active_d;
			rx_parse_kind_q <= rx_parse_kind_d;
			rx_symbol_index_q <= rx_symbol_index_d;
			rx_short_symbol_q <= rx_short_symbol_d;
			rx_work_fields_q <= rx_work_fields_d;
			rx_encoding_error_q <= rx_encoding_error_d;
			rx_last_ts1_q <= rx_last_ts1_d;
			rx_last_ts2_q <= rx_last_ts2_d;
			rx_ts1_count_q <= rx_ts1_count_d;
			rx_ts2_count_q <= rx_ts2_count_d;
			rx_idle_count_q <= rx_idle_count_d;
			expected_state_q <= expected_state_d;
			os_rx_fields_o <= rx_fields_out_d;
			os_rx_ts1_qualified_evt_o <= rx_ts1_evt_d;
			os_rx_ts2_qualified_evt_o <= rx_ts2_evt_d;
			os_rx_fts_evt_o <= rx_fts_evt_d;
			os_rx_skp_evt_o <= rx_skp_evt_d;
			os_rx_eios_evt_o <= rx_eios_evt_d;
			os_rx_eieos_evt_o <= rx_eieos_evt_d;
			rx_logical_idle_qualified_evt_o <= rx_idle_evt_d;
			os_rx_hot_reset_evt_o <= rx_hot_reset_evt_d;
			os_rx_loopback_evt_o <= rx_loopback_evt_d;
			os_rx_speed_change_evt_o <= rx_speed_change_evt_d;
			os_rx_error_o <= rx_error_d;
		end
	end
	initial _sv2v_0 = 0;
endmodule
