`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_scrambler_descrambler (
	sym_clk_i,
	sym_rst_ni,
	tx_scr_data_i,
	tx_scr_is_k_i,
	tx_scr_class_i,
	tx_scr_lfsr_action_i,
	tx_scr_data_o,
	tx_scr_is_k_o,
	rx_descr_data_i,
	rx_descr_is_k_i,
	rx_descr_valid_i,
	rx_descr_class_i,
	rx_descr_lfsr_action_i,
	rx_descr_data_o,
	rx_descr_valid_o,
	tx_scrambler_state_o,
	rx_descrambler_state_o,
	scrambler_sync_error_o
);
	reg _sv2v_0;
	input wire sym_clk_i;
	input wire sym_rst_ni;
	input wire [15:0] tx_scr_data_i;
	input wire [1:0] tx_scr_is_k_i;
	input wire [3:0] tx_scr_class_i;
	input wire [1:0] tx_scr_lfsr_action_i;
	output reg [15:0] tx_scr_data_o;
	output reg [1:0] tx_scr_is_k_o;
	input wire [15:0] rx_descr_data_i;
	input wire [1:0] rx_descr_is_k_i;
	input wire rx_descr_valid_i;
	input wire [3:0] rx_descr_class_i;
	input wire [3:0] rx_descr_lfsr_action_i;
	output reg [15:0] rx_descr_data_o;
	output reg rx_descr_valid_o;
	output wire [15:0] tx_scrambler_state_o;
	output wire [15:0] rx_descrambler_state_o;
	output reg scrambler_sync_error_o;
	reg [15:0] tx_lfsr_q;
	reg [15:0] rx_lfsr_q;
	reg [15:0] tx_lfsr_next;
	reg [15:0] rx_lfsr_next;
	reg tx_rule_error;
	reg rx_rule_error;
	reg [23:0] tx_char0_result;
	reg [23:0] tx_char1_result;
	reg [23:0] rx_char0_result;
	reg [23:0] rx_char1_result;
	reg [1:0] tx_pair_action;
	reg [1:0] tx_char0_action;
	reg [1:0] tx_char1_action;
	reg [1:0] rx_char0_action;
	reg [1:0] rx_char1_action;
	localparam [31:0] pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_16 = 15;
	localparam [31:0] pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_3 = 2;
	localparam [31:0] pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_4 = 3;
	localparam [31:0] pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_5 = 4;
	function automatic [15:0] lfsr_step;
		input reg [15:0] state;
		reg feedback;
		begin
			feedback = ((state[pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_16] ^ state[pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_5]) ^ state[pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_4]) ^ state[pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_3];
			lfsr_step = {state[14:0], feedback};
		end
	endfunction
	localparam [15:0] pcie_gen12_phy_pkg_PCIE_SCRAMBLER_SEED = 16'hffff;
	function automatic [23:0] process_character;
		input reg [7:0] data;
		input reg is_k;
		input reg [1:0] action;
		input reg [15:0] state;
		reg [23:0] result;
		reg [15:0] working_state;
		reg [31:0] bit_index;
		begin
			result[23-:8] = data;
			result[15-:16] = state;
			working_state = state;
			(* full_case, parallel_case *)
			case (action)
				2'b11: result[15-:16] = pcie_gen12_phy_pkg_PCIE_SCRAMBLER_SEED;
				2'b10: result[15-:16] = state;
				2'b01: begin
					for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
						working_state = lfsr_step(working_state);
					result[15-:16] = working_state;
				end
				default: begin
					for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
						begin
							if (!is_k)
								result[16 + bit_index] = data[bit_index] ^ working_state[pcie_gen12_phy_pkg_PCIE_SCRAMBLER_TAP_16];
							working_state = lfsr_step(working_state);
						end
					result[15-:16] = working_state;
				end
			endcase
			process_character = result;
		end
	endfunction
	function automatic [1:0] expected_pair_action;
		input reg [3:0] character_class;
		(* full_case, parallel_case *)
		case (character_class)
			4'h0, 4'h8, 4'h7: expected_pair_action = 2'b00;
			4'h2: expected_pair_action = 2'b10;
			default: expected_pair_action = 2'b01;
		endcase
	endfunction
	localparam [7:0] pcie_gen12_phy_pkg_K_COM = 8'hbc;
	function automatic [1:0] resolve_tx_character_action;
		input reg [7:0] data;
		input reg is_k;
		input reg [3:0] character_class;
		input reg [1:0] pair_action;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if (is_k && (data == pcie_gen12_phy_pkg_K_COM)) begin
				resolve_tx_character_action = 2'b11;
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				if (character_class == 4'h2) begin
					resolve_tx_character_action = 2'b10;
					_sv2v_jump = 2'b11;
				end
				if (_sv2v_jump == 2'b00) begin
					resolve_tx_character_action = pair_action;
					_sv2v_jump = 2'b11;
				end
			end
		end
	endfunction
	localparam [7:0] pcie_gen12_phy_pkg_K_SKP = 8'h1c;
	function automatic rx_action_is_legal;
		input reg [7:0] data;
		input reg is_k;
		input reg [3:0] character_class;
		input reg [1:0] action;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if (is_k && (data == pcie_gen12_phy_pkg_K_COM)) begin
				rx_action_is_legal = action == 2'b11;
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				if (is_k && (data == pcie_gen12_phy_pkg_K_SKP)) begin
					rx_action_is_legal = action == 2'b10;
					_sv2v_jump = 2'b11;
				end
				if (_sv2v_jump == 2'b00) begin
					if (character_class == 4'h2) begin
						rx_action_is_legal = 1'b0;
						_sv2v_jump = 2'b11;
					end
					if (_sv2v_jump == 2'b00) begin
						rx_action_is_legal = (action != 2'b11) && (action != 2'b10);
						_sv2v_jump = 2'b11;
					end
				end
			end
		end
	endfunction
	localparam [7:0] pcie_gen12_phy_pkg_D_LOGICAL_IDLE = 8'h00;
	always @(*) begin
		if (_sv2v_0)
			;
		tx_pair_action = tx_scr_lfsr_action_i;
		tx_char0_action = resolve_tx_character_action(tx_scr_data_i[7:0], tx_scr_is_k_i[0], tx_scr_class_i, tx_pair_action);
		tx_char1_action = resolve_tx_character_action(tx_scr_data_i[15:8], tx_scr_is_k_i[1], tx_scr_class_i, tx_pair_action);
		rx_char0_action = rx_descr_lfsr_action_i[1:0];
		rx_char1_action = rx_descr_lfsr_action_i[3:2];
		tx_char0_result = process_character(tx_scr_data_i[7:0], tx_scr_is_k_i[0], tx_char0_action, tx_lfsr_q);
		tx_char1_result = process_character(tx_scr_data_i[15:8], tx_scr_is_k_i[1], tx_char1_action, tx_char0_result[15-:16]);
		rx_char0_result = process_character(rx_descr_data_i[7:0], rx_descr_is_k_i[0], rx_char0_action, rx_lfsr_q);
		rx_char1_result = process_character(rx_descr_data_i[15:8], rx_descr_is_k_i[1], rx_char1_action, rx_char0_result[15-:16]);
		tx_lfsr_next = tx_char1_result[15-:16];
		rx_lfsr_next = rx_char1_result[15-:16];
		tx_rule_error = ((tx_pair_action != expected_pair_action(tx_scr_class_i)) || ((tx_scr_class_i == 4'h2) && ((!tx_scr_is_k_i[0] || ((tx_scr_data_i[7:0] != pcie_gen12_phy_pkg_K_COM) && (tx_scr_data_i[7:0] != pcie_gen12_phy_pkg_K_SKP))) || (!tx_scr_is_k_i[1] || ((tx_scr_data_i[15:8] != pcie_gen12_phy_pkg_K_COM) && (tx_scr_data_i[15:8] != pcie_gen12_phy_pkg_K_SKP)))))) || (tx_scr_class_i == 4'hf);
		rx_rule_error = (!rx_action_is_legal(rx_descr_data_i[7:0], rx_descr_is_k_i[0], rx_descr_class_i, rx_char0_action) || !rx_action_is_legal(rx_descr_data_i[15:8], rx_descr_is_k_i[1], rx_descr_class_i, rx_char1_action)) || ((rx_descr_class_i == 4'hf) && ((rx_char0_action != 2'b10) || (rx_char1_action != 2'b10)));
		if (!sym_rst_ni) begin
			tx_scr_data_o = {pcie_gen12_phy_pkg_D_LOGICAL_IDLE, pcie_gen12_phy_pkg_D_LOGICAL_IDLE};
			tx_scr_is_k_o = 2'b00;
			rx_descr_data_o = 1'sb0;
			rx_descr_valid_o = 1'b0;
		end
		else begin
			tx_scr_data_o = {tx_char1_result[23-:8], tx_char0_result[23-:8]};
			tx_scr_is_k_o = tx_scr_is_k_i;
			rx_descr_data_o = {rx_char1_result[23-:8], rx_char0_result[23-:8]};
			rx_descr_valid_o = rx_descr_valid_i;
		end
	end
	always @(posedge sym_clk_i or negedge sym_rst_ni)
		if (!sym_rst_ni) begin
			tx_lfsr_q <= pcie_gen12_phy_pkg_PCIE_SCRAMBLER_SEED;
			rx_lfsr_q <= pcie_gen12_phy_pkg_PCIE_SCRAMBLER_SEED;
			scrambler_sync_error_o <= 1'b0;
		end
		else begin
			tx_lfsr_q <= tx_lfsr_next;
			if (rx_descr_valid_i)
				rx_lfsr_q <= rx_lfsr_next;
			scrambler_sync_error_o <= tx_rule_error || (rx_descr_valid_i && rx_rule_error);
		end
	assign tx_scrambler_state_o = tx_lfsr_q;
	assign rx_descrambler_state_o = rx_lfsr_q;
	initial _sv2v_0 = 0;
endmodule
