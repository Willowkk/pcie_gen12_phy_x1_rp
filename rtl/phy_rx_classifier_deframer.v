`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_rx_classifier_deframer (
	sym_clk_i,
	sym_rst_ni,
	rx_symbol_data_i,
	rx_symbol_is_k_i,
	rx_symbol_valid_i,
	rx_symbol_is_comma_i,
	rx_symbol_code_error_i,
	rx_symbol_disparity_error_i,
	rx_byte_aligned_i,
	os_rx_candidate_data_o,
	os_rx_candidate_is_k_o,
	os_rx_candidate_valid_o,
	os_rx_candidate_error_o,
	rx_descr_data_o,
	rx_descr_is_k_o,
	rx_descr_valid_o,
	rx_descr_class_o,
	rx_descr_lfsr_action_o,
	rx_descrambled_data_i,
	rx_descrambled_valid_i,
	rxbuf_pkt_valid_o,
	rxbuf_pkt_ready_i,
	rxbuf_pkt_data_o,
	rxbuf_pkt_keep_o,
	rxbuf_pkt_sop_o,
	rxbuf_pkt_eop_o,
	rxbuf_pkt_kind_o,
	rxbuf_pkt_abort_o,
	rxbuf_pkt_drop_o,
	rx_logical_idle_valid_o,
	rx_logical_idle_char_mask_o,
	rx_align_loss_evt_o,
	rx_invalid_k_evt_o,
	rx_code_error_evt_o,
	rx_disparity_error_evt_o,
	rx_frame_error_evt_o,
	rx_packet_buffer_error_evt_o,
	rx_packet_drop_evt_o,
	rx_packet_active_o
);
	reg _sv2v_0;
	localparam [31:0] pcie_gen12_phy_timing_pkg_PHY_MAX_PACKET_BYTES = 4128;
	parameter [31:0] PHY_MAX_PACKET_BYTES = pcie_gen12_phy_timing_pkg_PHY_MAX_PACKET_BYTES;
	input wire sym_clk_i;
	input wire sym_rst_ni;
	input wire [15:0] rx_symbol_data_i;
	input wire [1:0] rx_symbol_is_k_i;
	input wire rx_symbol_valid_i;
	input wire [1:0] rx_symbol_is_comma_i;
	input wire [1:0] rx_symbol_code_error_i;
	input wire [1:0] rx_symbol_disparity_error_i;
	input wire rx_byte_aligned_i;
	output reg [15:0] os_rx_candidate_data_o;
	output reg [1:0] os_rx_candidate_is_k_o;
	output reg os_rx_candidate_valid_o;
	output reg [3:0] os_rx_candidate_error_o;
	output reg [15:0] rx_descr_data_o;
	output reg [1:0] rx_descr_is_k_o;
	output reg rx_descr_valid_o;
	output reg [3:0] rx_descr_class_o;
	output reg [3:0] rx_descr_lfsr_action_o;
	input wire [15:0] rx_descrambled_data_i;
	input wire rx_descrambled_valid_i;
	output reg rxbuf_pkt_valid_o;
	input wire rxbuf_pkt_ready_i;
	output reg [15:0] rxbuf_pkt_data_o;
	output reg [1:0] rxbuf_pkt_keep_o;
	output reg rxbuf_pkt_sop_o;
	output reg rxbuf_pkt_eop_o;
	output reg rxbuf_pkt_kind_o;
	output reg rxbuf_pkt_abort_o;
	output reg rxbuf_pkt_drop_o;
	output reg rx_logical_idle_valid_o;
	output reg [1:0] rx_logical_idle_char_mask_o;
	output reg rx_align_loss_evt_o;
	output reg rx_invalid_k_evt_o;
	output reg rx_code_error_evt_o;
	output reg rx_disparity_error_evt_o;
	output reg rx_frame_error_evt_o;
	output reg rx_packet_buffer_error_evt_o;
	output reg rx_packet_drop_evt_o;
	output reg rx_packet_active_o;
	localparam [31:0] BYTE_COUNT_W = (PHY_MAX_PACKET_BYTES < 2 ? 1 : $clog2(PHY_MAX_PACKET_BYTES + 1));
	reg pre_active_q;
	reg pre_active_d;
	reg [1:0] pre_kind_q;
	reg [1:0] pre_kind_d;
	reg [4:0] pre_pos_q;
	reg [4:0] pre_pos_d;
	reg [7:0] pre_short_symbol_q;
	reg [7:0] pre_short_symbol_d;
	reg [3:0] pre_short_class_q;
	reg [3:0] pre_short_class_d;
	reg [3:0] lane0_class_c;
	reg [3:0] lane1_class_c;
	reg [1:0] lane0_action_c;
	reg [1:0] lane1_action_c;
	wire [1:0] effective_disparity_c;
	wire [1:0] comma_mismatch_c;
	localparam [7:0] pcie_gen12_phy_pkg_K_EDB = 8'hfe;
	localparam [7:0] pcie_gen12_phy_pkg_K_END = 8'hfd;
	localparam [7:0] pcie_gen12_phy_pkg_K_SDP = 8'h5c;
	localparam [7:0] pcie_gen12_phy_pkg_K_STP = 8'hfb;
	function automatic is_frame_delimiter;
		input reg [7:0] ch;
		is_frame_delimiter = (((ch == pcie_gen12_phy_pkg_K_STP) || (ch == pcie_gen12_phy_pkg_K_SDP)) || (ch == pcie_gen12_phy_pkg_K_END)) || (ch == pcie_gen12_phy_pkg_K_EDB);
	endfunction
	localparam [7:0] pcie_gen12_phy_pkg_D_TS1 = 8'h4a;
	localparam [7:0] pcie_gen12_phy_pkg_K_COM = 8'hbc;
	localparam [7:0] pcie_gen12_phy_pkg_K_EIE = 8'hfc;
	localparam [7:0] pcie_gen12_phy_pkg_K_EIOS = 8'h7c;
	localparam [7:0] pcie_gen12_phy_pkg_K_FTS = 8'h3c;
	localparam [7:0] pcie_gen12_phy_pkg_K_PAD = 8'hf7;
	localparam [7:0] pcie_gen12_phy_pkg_K_SKP = 8'h1c;
	always @(*) begin : p_preclass
		reg active_w;
		reg [1:0] kind_w;
		reg [4:0] pos_w;
		reg [7:0] short_symbol_w;
		reg [3:0] short_class_w;
		reg [7:0] ch;
		reg is_k;
		reg code_bad;
		reg [3:0] class_w;
		reg [1:0] action_w;
		if (_sv2v_0)
			;
		active_w = pre_active_q;
		kind_w = pre_kind_q;
		pos_w = pre_pos_q;
		short_symbol_w = pre_short_symbol_q;
		short_class_w = pre_short_class_q;
		lane0_class_c = 4'hf;
		lane1_class_c = 4'hf;
		lane0_action_c = 2'b10;
		lane1_action_c = 2'b10;
		begin : sv2v_autoblock_1
			reg [31:0] lane;
			for (lane = 0; lane < 2; lane = lane + 1)
				begin
					ch = rx_symbol_data_i[lane * 8+:8];
					is_k = rx_symbol_is_k_i[lane];
					code_bad = rx_symbol_code_error_i[lane];
					class_w = 4'hf;
					action_w = 2'b10;
					if (!rx_byte_aligned_i || code_bad) begin
						active_w = 1'b0;
						kind_w = 2'd0;
						pos_w = 1'sb0;
					end
					else if (is_k && (ch == pcie_gen12_phy_pkg_K_COM)) begin
						class_w = 4'h9;
						action_w = 2'b11;
						active_w = 1'b1;
						kind_w = 2'd0;
						pos_w = 5'd1;
					end
					else if (active_w) begin
						if (pos_w == 5'd1) begin
							if (!is_k || (ch == pcie_gen12_phy_pkg_K_PAD)) begin
								kind_w = 2'd1;
								class_w = (is_k ? 4'ha : 4'h1);
								action_w = 2'b01;
								pos_w = 5'd2;
							end
							else
								(* full_case, parallel_case *)
								case (ch)
									pcie_gen12_phy_pkg_K_SKP: begin
										kind_w = 2'd2;
										short_symbol_w = pcie_gen12_phy_pkg_K_SKP;
										short_class_w = 4'h2;
										class_w = 4'h2;
										action_w = 2'b10;
										pos_w = 5'd2;
									end
									pcie_gen12_phy_pkg_K_FTS: begin
										kind_w = 2'd2;
										short_symbol_w = pcie_gen12_phy_pkg_K_FTS;
										short_class_w = 4'h5;
										class_w = 4'h5;
										action_w = 2'b01;
										pos_w = 5'd2;
									end
									pcie_gen12_phy_pkg_K_EIOS: begin
										kind_w = 2'd2;
										short_symbol_w = pcie_gen12_phy_pkg_K_EIOS;
										short_class_w = 4'h3;
										class_w = 4'h3;
										action_w = 2'b01;
										pos_w = 5'd2;
									end
									pcie_gen12_phy_pkg_K_EIE: begin
										kind_w = 2'd3;
										class_w = 4'h4;
										action_w = 2'b01;
										pos_w = 5'd2;
									end
									default: begin
										active_w = 1'b0;
										kind_w = 2'd0;
										pos_w = 1'sb0;
										class_w = 4'hf;
										action_w = 2'b01;
									end
								endcase
						end
						else
							(* full_case, parallel_case *)
							case (kind_w)
								2'd2:
									if (is_k && (ch == short_symbol_w)) begin
										class_w = short_class_w;
										action_w = (short_symbol_w == pcie_gen12_phy_pkg_K_SKP ? 2'b10 : 2'b01);
										if (pos_w == 5'd3) begin
											active_w = 1'b0;
											kind_w = 2'd0;
											pos_w = 1'sb0;
										end
										else
											pos_w = pos_w + 1'b1;
									end
									else begin
										active_w = 1'b0;
										kind_w = 2'd0;
										pos_w = 1'sb0;
										class_w = 4'hf;
										action_w = (is_k ? 2'b01 : 2'b00);
									end
								2'd3:
									if (((pos_w <= 5'd14) && is_k) && (ch == pcie_gen12_phy_pkg_K_EIE)) begin
										class_w = 4'h4;
										action_w = 2'b01;
										pos_w = pos_w + 1'b1;
									end
									else if (((pos_w == 5'd15) && !is_k) && (ch == pcie_gen12_phy_pkg_D_TS1)) begin
										class_w = 4'h4;
										action_w = 2'b01;
										active_w = 1'b0;
										kind_w = 2'd0;
										pos_w = 1'sb0;
									end
									else begin
										active_w = 1'b0;
										kind_w = 2'd0;
										pos_w = 1'sb0;
										class_w = 4'hf;
										action_w = (is_k ? 2'b01 : 2'b00);
									end
								2'd1:
									if (((pos_w <= 5'd2) && (!is_k || (ch == pcie_gen12_phy_pkg_K_PAD))) || ((pos_w >= 5'd3) && !is_k)) begin
										class_w = (is_k ? 4'ha : 4'h1);
										action_w = 2'b01;
										if (pos_w == 5'd15) begin
											active_w = 1'b0;
											kind_w = 2'd0;
											pos_w = 1'sb0;
										end
										else
											pos_w = pos_w + 1'b1;
									end
									else begin
										active_w = 1'b0;
										kind_w = 2'd0;
										pos_w = 1'sb0;
										class_w = 4'hf;
										action_w = 2'b01;
									end
								default: begin
									active_w = 1'b0;
									kind_w = 2'd0;
									pos_w = 1'sb0;
									class_w = 4'hf;
									action_w = (is_k ? 2'b01 : 2'b00);
								end
							endcase
					end
					else if (is_k) begin
						if (is_frame_delimiter(ch))
							class_w = 4'h8;
						else
							class_w = 4'hf;
						action_w = (ch == pcie_gen12_phy_pkg_K_SKP ? 2'b10 : 2'b01);
					end
					else begin
						class_w = 4'h0;
						action_w = 2'b00;
					end
					if (lane == 0) begin
						lane0_class_c = class_w;
						lane0_action_c = action_w;
					end
					else begin
						lane1_class_c = class_w;
						lane1_action_c = action_w;
					end
				end
		end
		pre_active_d = active_w;
		pre_kind_d = kind_w;
		pre_pos_d = pos_w;
		pre_short_symbol_d = short_symbol_w;
		pre_short_class_d = short_class_w;
	end
	assign effective_disparity_c = rx_symbol_disparity_error_i & ~rx_symbol_code_error_i;
	assign comma_mismatch_c[0] = rx_symbol_is_comma_i[0] ^ ((!rx_symbol_code_error_i[0] && rx_symbol_is_k_i[0]) && (rx_symbol_data_i[7:0] == pcie_gen12_phy_pkg_K_COM));
	assign comma_mismatch_c[1] = rx_symbol_is_comma_i[1] ^ ((!rx_symbol_code_error_i[1] && rx_symbol_is_k_i[1]) && (rx_symbol_data_i[15:8] == pcie_gen12_phy_pkg_K_COM));
	always @(*) begin
		if (_sv2v_0)
			;
		os_rx_candidate_data_o = rx_symbol_data_i;
		os_rx_candidate_is_k_o = rx_symbol_is_k_i;
		os_rx_candidate_valid_o = rx_symbol_valid_i;
		os_rx_candidate_error_o = {|rx_symbol_code_error_i, |effective_disparity_c, !rx_byte_aligned_i, |comma_mismatch_c};
		rx_descr_data_o = rx_symbol_data_i;
		rx_descr_is_k_o = rx_symbol_is_k_i;
		rx_descr_valid_o = rx_symbol_valid_i;
		rx_descr_lfsr_action_o = {lane1_action_c, lane0_action_c};
		if (lane0_class_c == lane1_class_c)
			rx_descr_class_o = lane0_class_c;
		else if ((lane0_class_c == 4'h9) || (lane1_class_c == 4'h9))
			rx_descr_class_o = 4'h9;
		else if ((lane0_class_c == 4'hf) || (lane1_class_c == 4'hf))
			rx_descr_class_o = 4'hf;
		else if ((lane0_class_c == 4'h8) || (lane1_class_c == 4'h8))
			rx_descr_class_o = 4'h8;
		else
			rx_descr_class_o = lane0_class_c;
	end
	reg [1:0] frame_state_q;
	reg [1:0] frame_state_d;
	reg packet_kind_q;
	reg packet_kind_d;
	reg sop_pending_q;
	reg sop_pending_d;
	reg packet_poison_q;
	reg packet_poison_d;
	reg [BYTE_COUNT_W - 1:0] packet_byte_count_q;
	reg [BYTE_COUNT_W - 1:0] packet_byte_count_d;
	reg aligned_seen_q;
	reg emit_valid_d;
	reg [15:0] emit_data_d;
	reg [1:0] emit_keep_d;
	reg emit_sop_d;
	reg emit_eop_d;
	reg emit_kind_d;
	reg emit_abort_d;
	reg emit_drop_d;
	reg logical_idle_valid_d;
	reg [1:0] logical_idle_mask_d;
	reg invalid_k_evt_d;
	reg frame_error_evt_d;
	reg buffer_error_evt_d;
	reg packet_drop_evt_d;
	always @(*) begin : p_deframe_next
		reg [1:0] state_w;
		reg kind_w;
		reg sop_w;
		reg poison_w;
		reg [BYTE_COUNT_W - 1:0] byte_count_w;
		reg [15:0] data_w;
		reg [1:0] keep_w;
		reg eop_w;
		reg abort_w;
		reg sop_for_emit_w;
		reg beat_kind_w;
		reg [1:0] idle_mask_w;
		reg idle_observation_w;
		reg [7:0] raw_ch;
		reg [7:0] descr_ch;
		reg [3:0] char_class;
		reg is_k;
		reg code_bad;
		reg disp_bad;
		if (_sv2v_0)
			;
		state_w = frame_state_q;
		kind_w = packet_kind_q;
		sop_w = sop_pending_q;
		poison_w = packet_poison_q;
		byte_count_w = packet_byte_count_q;
		data_w = 1'sb0;
		keep_w = 1'sb0;
		eop_w = 1'b0;
		abort_w = 1'b0;
		sop_for_emit_w = 1'b0;
		beat_kind_w = packet_kind_q;
		idle_mask_w = 1'sb0;
		idle_observation_w = 1'b0;
		emit_valid_d = 1'b0;
		emit_data_d = 1'sb0;
		emit_keep_d = 1'sb0;
		emit_sop_d = 1'b0;
		emit_eop_d = 1'b0;
		emit_kind_d = packet_kind_q;
		emit_abort_d = 1'b0;
		emit_drop_d = 1'b0;
		logical_idle_valid_d = 1'b0;
		logical_idle_mask_d = 1'sb0;
		invalid_k_evt_d = 1'b0;
		frame_error_evt_d = 1'b0;
		buffer_error_evt_d = 1'b0;
		packet_drop_evt_d = 1'b0;
		if (!rx_byte_aligned_i) begin
			if (state_w == 2'd1) begin
				emit_drop_d = 1'b1;
				packet_drop_evt_d = 1'b1;
			end
			state_w = 2'd0;
			sop_w = 1'b0;
			poison_w = 1'b0;
			byte_count_w = 1'sb0;
		end
		else if (rx_descrambled_valid_i && rx_symbol_valid_i) begin
			begin : sv2v_autoblock_2
				reg [31:0] lane;
				for (lane = 0; lane < 2; lane = lane + 1)
					begin
						raw_ch = rx_symbol_data_i[lane * 8+:8];
						descr_ch = rx_descrambled_data_i[lane * 8+:8];
						char_class = (lane == 0 ? lane0_class_c : lane1_class_c);
						is_k = rx_symbol_is_k_i[lane];
						code_bad = rx_symbol_code_error_i[lane];
						disp_bad = effective_disparity_c[lane];
						if (code_bad) begin
							if (state_w == 2'd1)
								poison_w = 1'b1;
						end
						else if (!rx_byte_aligned_i) begin
							if (state_w == 2'd1)
								poison_w = 1'b1;
						end
						else if (is_k) begin
							if ((raw_ch == pcie_gen12_phy_pkg_K_STP) || (raw_ch == pcie_gen12_phy_pkg_K_SDP)) begin
								if (state_w == 2'd0) begin
									state_w = (rxbuf_pkt_ready_i ? 2'd1 : 2'd2);
									kind_w = raw_ch == pcie_gen12_phy_pkg_K_SDP;
									sop_w = 1'b1;
									poison_w = disp_bad;
									byte_count_w = 1'sb0;
									if (!rxbuf_pkt_ready_i) begin
										buffer_error_evt_d = 1'b1;
										packet_drop_evt_d = 1'b1;
										emit_drop_d = 1'b1;
									end
								end
								else begin
									frame_error_evt_d = 1'b1;
									invalid_k_evt_d = 1'b1;
									if (state_w == 2'd1) begin
										emit_drop_d = 1'b1;
										packet_drop_evt_d = 1'b1;
									end
									state_w = 2'd2;
									poison_w = 1'b1;
								end
							end
							else if ((raw_ch == pcie_gen12_phy_pkg_K_END) || (raw_ch == pcie_gen12_phy_pkg_K_EDB)) begin
								if (state_w == 2'd1) begin
									if ((byte_count_w == 0) || ((raw_ch == pcie_gen12_phy_pkg_K_EDB) && kind_w)) begin
										frame_error_evt_d = 1'b1;
										poison_w = 1'b1;
									end
									if (disp_bad)
										poison_w = 1'b1;
									if (poison_w) begin
										emit_drop_d = 1'b1;
										packet_drop_evt_d = 1'b1;
										keep_w = 1'sb0;
									end
									else begin
										beat_kind_w = kind_w;
										eop_w = 1'b1;
										abort_w = raw_ch == pcie_gen12_phy_pkg_K_EDB;
									end
									state_w = 2'd0;
									sop_w = 1'b0;
									poison_w = 1'b0;
									byte_count_w = 1'sb0;
								end
								else if (state_w == 2'd2) begin
									state_w = 2'd0;
									sop_w = 1'b0;
									poison_w = 1'b0;
									byte_count_w = 1'sb0;
								end
								else begin
									frame_error_evt_d = 1'b1;
									invalid_k_evt_d = 1'b1;
								end
							end
							else if (state_w == 2'd1) begin
								invalid_k_evt_d = 1'b1;
								frame_error_evt_d = 1'b1;
								emit_drop_d = 1'b1;
								packet_drop_evt_d = 1'b1;
								state_w = 2'd2;
								poison_w = 1'b1;
								keep_w = 1'sb0;
							end
							else if ((state_w == 2'd0) && (char_class == 4'hf))
								invalid_k_evt_d = 1'b1;
						end
						else if (state_w == 2'd1) begin
							if (byte_count_w >= PHY_MAX_PACKET_BYTES) begin
								frame_error_evt_d = 1'b1;
								buffer_error_evt_d = 1'b1;
								emit_drop_d = 1'b1;
								packet_drop_evt_d = 1'b1;
								state_w = 2'd2;
								poison_w = 1'b1;
								keep_w = 1'sb0;
							end
							else if (!rxbuf_pkt_ready_i) begin
								buffer_error_evt_d = 1'b1;
								emit_drop_d = 1'b1;
								packet_drop_evt_d = 1'b1;
								state_w = 2'd2;
								poison_w = 1'b1;
								keep_w = 1'sb0;
							end
							else begin
								if ((keep_w == 2'b00) && sop_w) begin
									sop_for_emit_w = 1'b1;
									sop_w = 1'b0;
								end
								if (keep_w == 2'b00)
									beat_kind_w = kind_w;
								if (!keep_w[0]) begin
									data_w[7:0] = descr_ch;
									keep_w[0] = 1'b1;
								end
								else begin
									data_w[15:8] = descr_ch;
									keep_w[1] = 1'b1;
								end
								byte_count_w = byte_count_w + 1'b1;
								if (disp_bad)
									poison_w = 1'b1;
							end
						end
						else if (state_w == 2'd0) begin
							if ((char_class == 4'h0) && !disp_bad) begin
								idle_observation_w = 1'b1;
								idle_mask_w[lane] = descr_ch == 8'h00;
							end
						end
					end
			end
			if (emit_drop_d) begin
				keep_w = 1'sb0;
				eop_w = 1'b0;
				abort_w = 1'b0;
			end
			else if ((keep_w != 2'b00) || eop_w) begin
				emit_valid_d = 1'b1;
				emit_data_d = data_w;
				emit_keep_d = keep_w;
				emit_sop_d = sop_for_emit_w && (keep_w != 2'b00);
				emit_eop_d = eop_w;
				emit_kind_d = beat_kind_w;
				emit_abort_d = abort_w;
			end
			if (idle_observation_w) begin
				logical_idle_valid_d = 1'b1;
				logical_idle_mask_d = idle_mask_w;
			end
		end
		frame_state_d = state_w;
		packet_kind_d = kind_w;
		sop_pending_d = sop_w;
		packet_poison_d = poison_w;
		packet_byte_count_d = byte_count_w;
	end
	always @(posedge sym_clk_i or negedge sym_rst_ni)
		if (!sym_rst_ni) begin
			pre_active_q <= 1'b0;
			pre_kind_q <= 2'd0;
			pre_pos_q <= 1'sb0;
			pre_short_symbol_q <= 1'sb0;
			pre_short_class_q <= 4'hf;
			frame_state_q <= 2'd0;
			packet_kind_q <= 1'b0;
			sop_pending_q <= 1'b0;
			packet_poison_q <= 1'b0;
			packet_byte_count_q <= 1'sb0;
			aligned_seen_q <= 1'b0;
			rxbuf_pkt_valid_o <= 1'b0;
			rxbuf_pkt_data_o <= 1'sb0;
			rxbuf_pkt_keep_o <= 1'sb0;
			rxbuf_pkt_sop_o <= 1'b0;
			rxbuf_pkt_eop_o <= 1'b0;
			rxbuf_pkt_kind_o <= 1'b0;
			rxbuf_pkt_abort_o <= 1'b0;
			rxbuf_pkt_drop_o <= 1'b0;
			rx_logical_idle_valid_o <= 1'b0;
			rx_logical_idle_char_mask_o <= 1'sb0;
			rx_align_loss_evt_o <= 1'b0;
			rx_invalid_k_evt_o <= 1'b0;
			rx_code_error_evt_o <= 1'b0;
			rx_disparity_error_evt_o <= 1'b0;
			rx_frame_error_evt_o <= 1'b0;
			rx_packet_buffer_error_evt_o <= 1'b0;
			rx_packet_drop_evt_o <= 1'b0;
			rx_packet_active_o <= 1'b0;
		end
		else begin
			if (!rx_byte_aligned_i) begin
				pre_active_q <= 1'b0;
				pre_kind_q <= 2'd0;
				pre_pos_q <= 1'sb0;
				pre_short_symbol_q <= 1'sb0;
				pre_short_class_q <= 4'hf;
			end
			else if (rx_symbol_valid_i) begin
				pre_active_q <= pre_active_d;
				pre_kind_q <= pre_kind_d;
				pre_pos_q <= pre_pos_d;
				pre_short_symbol_q <= pre_short_symbol_d;
				pre_short_class_q <= pre_short_class_d;
			end
			frame_state_q <= frame_state_d;
			packet_kind_q <= packet_kind_d;
			sop_pending_q <= sop_pending_d;
			packet_poison_q <= packet_poison_d;
			packet_byte_count_q <= packet_byte_count_d;
			rxbuf_pkt_valid_o <= emit_valid_d;
			rxbuf_pkt_data_o <= emit_data_d;
			rxbuf_pkt_keep_o <= emit_keep_d;
			rxbuf_pkt_sop_o <= emit_sop_d;
			rxbuf_pkt_eop_o <= emit_eop_d;
			rxbuf_pkt_kind_o <= emit_kind_d;
			rxbuf_pkt_abort_o <= emit_abort_d;
			rxbuf_pkt_drop_o <= emit_drop_d;
			rx_logical_idle_valid_o <= logical_idle_valid_d;
			rx_logical_idle_char_mask_o <= logical_idle_mask_d;
			rx_code_error_evt_o <= rx_symbol_valid_i && |rx_symbol_code_error_i;
			rx_disparity_error_evt_o <= rx_symbol_valid_i && |effective_disparity_c;
			rx_invalid_k_evt_o <= invalid_k_evt_d;
			rx_frame_error_evt_o <= frame_error_evt_d;
			rx_packet_buffer_error_evt_o <= buffer_error_evt_d;
			rx_packet_drop_evt_o <= packet_drop_evt_d;
			if (rx_symbol_valid_i && rx_byte_aligned_i)
				aligned_seen_q <= 1'b1;
			rx_align_loss_evt_o <= aligned_seen_q && !rx_byte_aligned_i;
			if (!rx_byte_aligned_i)
				aligned_seen_q <= 1'b0;
			rx_packet_active_o <= frame_state_d != 2'd0;
		end
	initial _sv2v_0 = 0;
endmodule
