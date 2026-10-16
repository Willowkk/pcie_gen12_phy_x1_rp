`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_tx_framer_scheduler (
	sym_clk_i,
	sym_rst_ni,
	txbuf_pkt_valid_i,
	txbuf_pkt_ready_o,
	txbuf_pkt_data_i,
	txbuf_pkt_keep_i,
	txbuf_pkt_sop_i,
	txbuf_pkt_eop_i,
	txbuf_pkt_kind_i,
	txbuf_pkt_abort_i,
	txbuf_pending_i,
	lt_tx_mode_i,
	lt_tx_quiesce_i,
	lt_packet_enable_i,
	lt_state_i,
	lt_substate_i,
	os_tx_data_i,
	os_tx_is_k_i,
	os_tx_class_i,
	os_tx_valid_i,
	os_tx_done_i,
	os_tx_consume_o,
	skp_due_i,
	skp_deadline_i,
	tx_sel_data_o,
	tx_sel_is_k_o,
	tx_symbol_class_o,
	tx_lfsr_action_o,
	tx_packet_active_o,
	tx_quiesced_o,
	tx_logical_idle_qualified_evt_o,
	tx_scheduler_error_evt_o,
	tx_scheduler_error_code_o
);
	reg _sv2v_0;
	input wire sym_clk_i;
	input wire sym_rst_ni;
	input wire txbuf_pkt_valid_i;
	output reg txbuf_pkt_ready_o;
	input wire [15:0] txbuf_pkt_data_i;
	input wire [1:0] txbuf_pkt_keep_i;
	input wire txbuf_pkt_sop_i;
	input wire txbuf_pkt_eop_i;
	input wire txbuf_pkt_kind_i;
	input wire txbuf_pkt_abort_i;
	input wire txbuf_pending_i;
	input wire [3:0] lt_tx_mode_i;
	input wire lt_tx_quiesce_i;
	input wire lt_packet_enable_i;
	input wire [5:0] lt_state_i;
	input wire [5:0] lt_substate_i;
	input wire [15:0] os_tx_data_i;
	input wire [1:0] os_tx_is_k_i;
	input wire [3:0] os_tx_class_i;
	input wire os_tx_valid_i;
	input wire os_tx_done_i;
	output reg os_tx_consume_o;
	input wire skp_due_i;
	input wire [15:0] skp_deadline_i;
	output reg [15:0] tx_sel_data_o;
	output reg [1:0] tx_sel_is_k_o;
	output reg [3:0] tx_symbol_class_o;
	output reg [1:0] tx_lfsr_action_o;
	output reg tx_packet_active_o;
	output reg tx_quiesced_o;
	output reg tx_logical_idle_qualified_evt_o;
	output reg tx_scheduler_error_evt_o;
	output reg [7:0] tx_scheduler_error_code_o;
	localparam [31:0] TX_CHARACTERS_PER_CYCLE = 2;
	localparam [31:0] pcie_gen12_phy_timing_pkg_CFG_IDLE_COUNT = 8;
	localparam [31:0] IDLE_COUNT_WIDTH = 4;
	reg [1:0] state_q;
	reg [1:0] state_d;
	reg [7:0] carry_byte_q;
	reg [7:0] carry_byte_d;
	reg carry_ends_packet_q;
	reg carry_ends_packet_d;
	reg packet_abort_q;
	reg packet_abort_d;
	reg packet_kind_q;
	reg packet_kind_d;
	reg os_active_q;
	reg os_active_d;
	reg os_gap_reported_q;
	reg os_gap_reported_d;
	reg mode_conflict_reported_q;
	reg mode_conflict_reported_d;
	reg compliance_phase_q;
	reg selected_compliance_pair;
	reg [3:0] logical_idle_count_q;
	reg [IDLE_COUNT_WIDTH:0] logical_idle_count_plus_pair;
	reg selected_logical_idle_pair;
	reg mode_requires_sequence;
	reg start_beat_legal;
	reg continuation_beat_legal;
	reg packet_source_allowed;
	reg request_sequence_now;
	reg character_stream_enabled;
	function automatic keep_is_legal;
		input reg [1:0] keep;
		input reg eop;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if (eop) begin
				keep_is_legal = (keep == 2'b01) || (keep == 2'b11);
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				keep_is_legal = keep == 2'b11;
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic mode_owns_character_stream;
		input reg [3:0] mode;
		(* full_case, parallel_case *)
		case (mode)
			4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'ha: mode_owns_character_stream = 1'b1;
			default: mode_owns_character_stream = 1'b0;
		endcase
	endfunction
	function automatic [1:0] class_lfsr_action;
		input reg [3:0] character_class;
		(* full_case, parallel_case *)
		case (character_class)
			4'h0, 4'h8, 4'h7: class_lfsr_action = 2'b00;
			4'h2: class_lfsr_action = 2'b10;
			default: class_lfsr_action = 2'b01;
		endcase
	endfunction
	localparam [7:0] pcie_gen12_phy_pkg_D_COMPLIANCE_D10_2 = 8'h4a;
	localparam [7:0] pcie_gen12_phy_pkg_D_COMPLIANCE_D21_5 = 8'hb5;
	localparam [7:0] pcie_gen12_phy_pkg_D_LOGICAL_IDLE = 8'h00;
	localparam [7:0] pcie_gen12_phy_pkg_K_COM = 8'hbc;
	localparam [7:0] pcie_gen12_phy_pkg_K_EDB = 8'hfe;
	localparam [7:0] pcie_gen12_phy_pkg_K_END = 8'hfd;
	localparam [7:0] pcie_gen12_phy_pkg_K_SDP = 8'h5c;
	localparam [7:0] pcie_gen12_phy_pkg_K_STP = 8'hfb;
	always @(*) begin
		if (_sv2v_0)
			;
		mode_requires_sequence = mode_owns_character_stream(lt_tx_mode_i);
		packet_source_allowed = (lt_tx_mode_i == 4'h9) && lt_packet_enable_i;
		character_stream_enabled = lt_tx_mode_i != 4'h0;
		request_sequence_now = (os_active_q || (mode_requires_sequence && (lt_tx_mode_i != 4'h8))) || (skp_due_i && character_stream_enabled);
		start_beat_legal = (txbuf_pkt_sop_i && keep_is_legal(txbuf_pkt_keep_i, txbuf_pkt_eop_i)) && (!txbuf_pkt_abort_i || (txbuf_pkt_eop_i && (txbuf_pkt_kind_i == 1'b0)));
		continuation_beat_legal = ((!txbuf_pkt_sop_i && (txbuf_pkt_kind_i == packet_kind_q)) && keep_is_legal(txbuf_pkt_keep_i, txbuf_pkt_eop_i)) && (!txbuf_pkt_abort_i || (txbuf_pkt_eop_i && (packet_kind_q == 1'b0)));
		state_d = state_q;
		carry_byte_d = carry_byte_q;
		carry_ends_packet_d = carry_ends_packet_q;
		packet_abort_d = packet_abort_q;
		packet_kind_d = packet_kind_q;
		os_active_d = os_active_q;
		os_gap_reported_d = os_gap_reported_q;
		mode_conflict_reported_d = mode_conflict_reported_q;
		txbuf_pkt_ready_o = 1'b0;
		os_tx_consume_o = 1'b0;
		tx_sel_data_o = {pcie_gen12_phy_pkg_D_LOGICAL_IDLE, pcie_gen12_phy_pkg_D_LOGICAL_IDLE};
		tx_sel_is_k_o = 2'b00;
		tx_symbol_class_o = 4'h7;
		tx_lfsr_action_o = 2'b00;
		tx_packet_active_o = 1'b0;
		tx_quiesced_o = 1'b0;
		tx_scheduler_error_evt_o = 1'b0;
		tx_scheduler_error_code_o = 8'h00;
		selected_compliance_pair = 1'b0;
		(* full_case, parallel_case *)
		case (state_q)
			2'd0: begin
				mode_conflict_reported_d = 1'b0;
				if ((lt_tx_mode_i == 4'h8) && !os_active_q) begin
					tx_sel_data_o = (compliance_phase_q ? {pcie_gen12_phy_pkg_D_COMPLIANCE_D10_2, pcie_gen12_phy_pkg_K_COM} : {pcie_gen12_phy_pkg_D_COMPLIANCE_D21_5, pcie_gen12_phy_pkg_K_COM});
					tx_sel_is_k_o = 2'b01;
					tx_symbol_class_o = 4'h6;
					tx_lfsr_action_o = 2'b01;
					selected_compliance_pair = 1'b1;
				end
				else if (request_sequence_now) begin
					if (os_tx_valid_i) begin
						tx_sel_data_o = os_tx_data_i;
						tx_sel_is_k_o = os_tx_is_k_i;
						tx_symbol_class_o = os_tx_class_i;
						tx_lfsr_action_o = class_lfsr_action(os_tx_class_i);
						os_tx_consume_o = 1'b1;
						os_active_d = !os_tx_done_i;
						os_gap_reported_d = 1'b0;
					end
					else if (os_active_q && os_tx_done_i) begin
						os_active_d = 1'b0;
						os_gap_reported_d = 1'b0;
					end
					else begin
						os_active_d = 1'b1;
						if (os_active_q && !os_gap_reported_q) begin
							tx_scheduler_error_evt_o = 1'b1;
							tx_scheduler_error_code_o = 8'h0e;
							os_gap_reported_d = 1'b1;
						end
					end
				end
				else if (packet_source_allowed) begin
					txbuf_pkt_ready_o = 1'b1;
					if (txbuf_pkt_valid_i) begin
						tx_packet_active_o = 1'b1;
						if (start_beat_legal) begin
							tx_sel_data_o = {txbuf_pkt_data_i[7:0], (txbuf_pkt_kind_i == 1'b1 ? pcie_gen12_phy_pkg_K_SDP : pcie_gen12_phy_pkg_K_STP)};
							tx_sel_is_k_o = 2'b01;
							tx_symbol_class_o = 4'h8;
							tx_lfsr_action_o = 2'b00;
							packet_kind_d = txbuf_pkt_kind_i;
							packet_abort_d = txbuf_pkt_abort_i;
							if (txbuf_pkt_eop_i) begin
								if (txbuf_pkt_keep_i == 2'b01)
									state_d = 2'd2;
								else begin
									carry_byte_d = txbuf_pkt_data_i[15:8];
									carry_ends_packet_d = 1'b1;
									state_d = 2'd1;
								end
							end
							else begin
								carry_byte_d = txbuf_pkt_data_i[15:8];
								carry_ends_packet_d = 1'b0;
								state_d = 2'd1;
							end
						end
						else begin
							tx_sel_data_o = {pcie_gen12_phy_pkg_D_LOGICAL_IDLE, pcie_gen12_phy_pkg_K_EDB};
							tx_sel_is_k_o = 2'b01;
							tx_symbol_class_o = 4'h8;
							tx_lfsr_action_o = 2'b00;
							tx_scheduler_error_evt_o = 1'b1;
							tx_scheduler_error_code_o = 8'h0e;
							state_d = (txbuf_pkt_eop_i ? 2'd0 : 2'd3);
						end
					end
				end
				tx_quiesced_o = ((((!request_sequence_now && !os_tx_valid_i) && !tx_packet_active_o) && !(txbuf_pkt_valid_i && packet_source_allowed)) && (tx_symbol_class_o == 4'h7)) && !tx_sel_is_k_o;
			end
			2'd1: begin
				tx_packet_active_o = 1'b1;
				tx_symbol_class_o = 4'h8;
				tx_lfsr_action_o = 2'b00;
				if (mode_requires_sequence && !mode_conflict_reported_q) begin
					tx_scheduler_error_evt_o = 1'b1;
					tx_scheduler_error_code_o = 8'h13;
					mode_conflict_reported_d = 1'b1;
				end
				if (carry_ends_packet_q) begin
					tx_sel_data_o = {(packet_abort_q ? pcie_gen12_phy_pkg_K_EDB : pcie_gen12_phy_pkg_K_END), carry_byte_q};
					tx_sel_is_k_o = 2'b10;
					state_d = 2'd0;
					carry_ends_packet_d = 1'b0;
				end
				else begin
					txbuf_pkt_ready_o = 1'b1;
					if (txbuf_pkt_valid_i && continuation_beat_legal) begin
						tx_sel_data_o = {txbuf_pkt_data_i[7:0], carry_byte_q};
						tx_sel_is_k_o = 2'b00;
						if (txbuf_pkt_eop_i) begin
							packet_abort_d = txbuf_pkt_abort_i;
							if (txbuf_pkt_keep_i == 2'b01)
								state_d = 2'd2;
							else begin
								carry_byte_d = txbuf_pkt_data_i[15:8];
								carry_ends_packet_d = 1'b1;
							end
						end
						else begin
							carry_byte_d = txbuf_pkt_data_i[15:8];
							carry_ends_packet_d = 1'b0;
						end
					end
					else begin
						tx_sel_data_o = {pcie_gen12_phy_pkg_K_EDB, carry_byte_q};
						tx_sel_is_k_o = 2'b10;
						tx_scheduler_error_evt_o = 1'b1;
						tx_scheduler_error_code_o = 8'h0e;
						state_d = (txbuf_pkt_valid_i && txbuf_pkt_eop_i ? 2'd0 : 2'd3);
					end
				end
			end
			2'd2: begin
				tx_sel_data_o = {pcie_gen12_phy_pkg_D_LOGICAL_IDLE, (packet_abort_q ? pcie_gen12_phy_pkg_K_EDB : pcie_gen12_phy_pkg_K_END)};
				tx_sel_is_k_o = 2'b01;
				tx_symbol_class_o = 4'h8;
				tx_lfsr_action_o = 2'b00;
				tx_packet_active_o = 1'b1;
				state_d = 2'd0;
			end
			default: begin
				txbuf_pkt_ready_o = 1'b1;
				tx_packet_active_o = 1'b1;
				if (txbuf_pkt_valid_i && txbuf_pkt_eop_i)
					state_d = 2'd0;
			end
		endcase
		if (!sym_rst_ni) begin
			txbuf_pkt_ready_o = 1'b0;
			os_tx_consume_o = 1'b0;
			tx_sel_data_o = {pcie_gen12_phy_pkg_D_LOGICAL_IDLE, pcie_gen12_phy_pkg_D_LOGICAL_IDLE};
			tx_sel_is_k_o = 2'b00;
			tx_symbol_class_o = 4'h7;
			tx_lfsr_action_o = 2'b00;
			tx_packet_active_o = 1'b0;
			tx_quiesced_o = 1'b1;
			tx_scheduler_error_evt_o = 1'b0;
			tx_scheduler_error_code_o = 8'h00;
			selected_compliance_pair = 1'b0;
		end
		selected_logical_idle_pair = ((((state_q == 2'd0) && (lt_tx_mode_i == 4'h1)) && (tx_symbol_class_o == 4'h7)) && (tx_sel_is_k_o == 2'b00)) && (tx_sel_data_o == {pcie_gen12_phy_pkg_D_LOGICAL_IDLE, pcie_gen12_phy_pkg_D_LOGICAL_IDLE});
		logical_idle_count_plus_pair = logical_idle_count_q + TX_CHARACTERS_PER_CYCLE;
	end
	always @(posedge sym_clk_i or negedge sym_rst_ni)
		if (!sym_rst_ni) begin
			state_q <= 2'd0;
			carry_byte_q <= pcie_gen12_phy_pkg_D_LOGICAL_IDLE;
			carry_ends_packet_q <= 1'b0;
			packet_abort_q <= 1'b0;
			packet_kind_q <= 1'b0;
			os_active_q <= 1'b0;
			os_gap_reported_q <= 1'b0;
			mode_conflict_reported_q <= 1'b0;
			compliance_phase_q <= 1'b0;
			logical_idle_count_q <= 1'sb0;
			tx_logical_idle_qualified_evt_o <= 1'b0;
		end
		else begin
			state_q <= state_d;
			carry_byte_q <= carry_byte_d;
			carry_ends_packet_q <= carry_ends_packet_d;
			packet_abort_q <= packet_abort_d;
			packet_kind_q <= packet_kind_d;
			os_active_q <= os_active_d;
			os_gap_reported_q <= os_gap_reported_d;
			mode_conflict_reported_q <= mode_conflict_reported_d;
			if (selected_compliance_pair)
				compliance_phase_q <= ~compliance_phase_q;
			else if (lt_tx_mode_i != 4'h8)
				compliance_phase_q <= 1'b0;
			tx_logical_idle_qualified_evt_o <= 1'b0;
			if (selected_logical_idle_pair) begin
				if (logical_idle_count_q < pcie_gen12_phy_timing_pkg_CFG_IDLE_COUNT) begin
					if (logical_idle_count_plus_pair >= pcie_gen12_phy_timing_pkg_CFG_IDLE_COUNT) begin
						logical_idle_count_q <= pcie_gen12_phy_timing_pkg_CFG_IDLE_COUNT[3:0];
						tx_logical_idle_qualified_evt_o <= 1'b1;
					end
					else
						logical_idle_count_q <= logical_idle_count_plus_pair[3:0];
				end
			end
			else
				logical_idle_count_q <= 1'sb0;
		end
	initial _sv2v_0 = 0;
endmodule
