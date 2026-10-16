`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_tx_packet_buffer_cdc (
	link_clk_i,
	link_rst_ni,
	port_reset_ni,
	sym_clk_i,
	sym_rst_ni,
	dll_tx_valid_i,
	dll_tx_ready_o,
	dll_tx_data_i,
	dll_tx_keep_i,
	dll_tx_sop_i,
	dll_tx_eop_i,
	dll_tx_kind_i,
	dll_tx_abort_i,
	txbuf_admission_enable_i,
	txbuf_flush_i,
	txbuf_pkt_valid_o,
	txbuf_pkt_ready_i,
	txbuf_pkt_data_o,
	txbuf_pkt_keep_o,
	txbuf_pkt_sop_o,
	txbuf_pkt_eop_o,
	txbuf_pkt_kind_o,
	txbuf_pkt_abort_o,
	txbuf_capture_active_o,
	txbuf_pending_o,
	txbuf_level_o,
	txbuf_error_evt_o,
	txbuf_error_code_o
);
	reg _sv2v_0;
	localparam [31:0] pcie_gen12_phy_timing_pkg_PHY_MAX_PACKET_BYTES = 4128;
	parameter [31:0] PHY_MAX_PACKET_BYTES = pcie_gen12_phy_timing_pkg_PHY_MAX_PACKET_BYTES;
	localparam [31:0] pcie_gen12_phy_timing_pkg_PHY_TX_WHOLE_PACKET_SLOTS = 2;
	parameter [31:0] PHY_TX_PACKET_SLOTS = pcie_gen12_phy_timing_pkg_PHY_TX_WHOLE_PACKET_SLOTS;
	input wire link_clk_i;
	input wire link_rst_ni;
	input wire port_reset_ni;
	input wire sym_clk_i;
	input wire sym_rst_ni;
	input wire dll_tx_valid_i;
	output reg dll_tx_ready_o;
	input wire [15:0] dll_tx_data_i;
	input wire [1:0] dll_tx_keep_i;
	input wire dll_tx_sop_i;
	input wire dll_tx_eop_i;
	input wire dll_tx_kind_i;
	input wire dll_tx_abort_i;
	input wire txbuf_admission_enable_i;
	input wire txbuf_flush_i;
	output reg txbuf_pkt_valid_o;
	input wire txbuf_pkt_ready_i;
	output reg [15:0] txbuf_pkt_data_o;
	output reg [1:0] txbuf_pkt_keep_o;
	output reg txbuf_pkt_sop_o;
	output reg txbuf_pkt_eop_o;
	output reg txbuf_pkt_kind_o;
	output reg txbuf_pkt_abort_o;
	output reg txbuf_capture_active_o;
	output reg txbuf_pending_o;
	output reg [7:0] txbuf_level_o;
	output reg txbuf_error_evt_o;
	output reg [7:0] txbuf_error_code_o;
	localparam [31:0] MAX_PACKET_BEATS = (PHY_MAX_PACKET_BYTES + 1) / 2;
	localparam [31:0] SLOT_ADDR_WIDTH = (PHY_TX_PACKET_SLOTS <= 2 ? 1 : $clog2(PHY_TX_PACKET_SLOTS));
	localparam [31:0] POINTER_WIDTH = SLOT_ADDR_WIDTH + 1;
	localparam [31:0] BEAT_COUNT_WIDTH = (MAX_PACKET_BEATS < 2 ? 1 : $clog2(MAX_PACKET_BEATS + 1));
	localparam [31:0] BYTE_COUNT_WIDTH = (PHY_MAX_PACKET_BYTES < 2 ? 1 : $clog2(PHY_MAX_PACKET_BYTES + 1));
	(* ram_style = "block" *) reg [15:0] packet_data_mem [0:PHY_TX_PACKET_SLOTS - 1][0:MAX_PACKET_BEATS - 1];
	reg [1:0] packet_keep_mem [0:PHY_TX_PACKET_SLOTS - 1][0:MAX_PACKET_BEATS - 1];
	reg [BEAT_COUNT_WIDTH - 1:0] packet_beat_count_mem [0:PHY_TX_PACKET_SLOTS - 1];
	reg packet_kind_mem [0:PHY_TX_PACKET_SLOTS - 1];
	reg packet_abort_mem [0:PHY_TX_PACKET_SLOTS - 1];
	reg [POINTER_WIDTH - 1:0] wr_ptr_bin_q;
	reg [POINTER_WIDTH - 1:0] wr_ptr_gray_q;
	reg [POINTER_WIDTH - 1:0] rd_ptr_bin_q;
	reg [POINTER_WIDTH - 1:0] rd_ptr_gray_q;
	(* ASYNC_REG = "TRUE" *) reg [POINTER_WIDTH - 1:0] rd_gray_link_meta_q;
	(* ASYNC_REG = "TRUE" *) reg [POINTER_WIDTH - 1:0] rd_gray_link_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [POINTER_WIDTH - 1:0] wr_gray_sym_meta_q;
	(* ASYNC_REG = "TRUE" *) reg [POINTER_WIDTH - 1:0] wr_gray_sym_sync_q;
	reg [1:0] link_reset_release_q;
	reg [1:0] sym_reset_release_q;
	wire link_domain_reset_ni;
	wire sym_domain_reset_ni;
	wire link_async_reset_ni = (link_rst_ni && port_reset_ni) && !txbuf_flush_i;
	wire sym_async_reset_ni = (sym_rst_ni && port_reset_ni) && !txbuf_flush_i;
	reg link_domain_alive_q;
	reg sym_domain_alive_q;
	(* ASYNC_REG = "TRUE" *) reg sym_alive_link_meta_q;
	(* ASYNC_REG = "TRUE" *) reg sym_alive_link_sync_q;
	(* ASYNC_REG = "TRUE" *) reg link_alive_sym_meta_q;
	(* ASYNC_REG = "TRUE" *) reg link_alive_sym_sync_q;
	reg [BEAT_COUNT_WIDTH - 1:0] wr_beat_count_q;
	reg [BYTE_COUNT_WIDTH - 1:0] wr_byte_count_q;
	reg wr_in_packet_q;
	reg wr_packet_bad_q;
	reg wr_error_reported_q;
	reg wr_packet_kind_q;
	reg [BEAT_COUNT_WIDTH - 1:0] rd_beat_index_q;
	reg stall_sample_valid_q;
	reg [21:0] stall_sample_q;
	reg [POINTER_WIDTH - 1:0] wr_ptr_gray_after_commit;
	reg [POINTER_WIDTH - 1:0] rd_ptr_gray_full_compare;
	reg [POINTER_WIDTH - 1:0] wr_ptr_bin_sym;
	reg [POINTER_WIDTH - 1:0] committed_packet_count_sym;
	reg slot_fifo_full;
	reg slot_fifo_empty;
	reg [1:0] incoming_byte_count;
	reg [BYTE_COUNT_WIDTH:0] continuation_byte_total;
	reg start_beat_bad;
	reg continuation_beat_bad;
	reg continuation_fits;
	function automatic [POINTER_WIDTH - 1:0] binary_to_gray;
		input reg [POINTER_WIDTH - 1:0] binary_value;
		binary_to_gray = (binary_value >> 1) ^ binary_value;
	endfunction
	function automatic [POINTER_WIDTH - 1:0] gray_to_binary;
		input reg [POINTER_WIDTH - 1:0] gray_value;
		reg [POINTER_WIDTH - 1:0] binary_value;
		reg signed [31:0] bit_index;
		begin
			binary_value[POINTER_WIDTH - 1] = gray_value[POINTER_WIDTH - 1];
			for (bit_index = POINTER_WIDTH - 2; bit_index >= 0; bit_index = bit_index - 1)
				binary_value[bit_index] = binary_value[bit_index + 1] ^ gray_value[bit_index];
			gray_to_binary = binary_value;
		end
	endfunction
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
	generate
		if ((PHY_TX_PACKET_SLOTS < 2) || ((PHY_TX_PACKET_SLOTS & (PHY_TX_PACKET_SLOTS - 1)) != 0)) begin : g_bad_slot_count
			initial $display("Error [%0t] rtl/phy_tx_packet_buffer_cdc.sv:163:15 - phy_tx_packet_buffer_cdc.g_bad_slot_count.<unnamed_block>\n msg: ", $time, "PHY_TX_PACKET_SLOTS must be a power of two and >= 2");
		end
		if (PHY_MAX_PACKET_BYTES < 1) begin : g_bad_packet_size
			initial $display("Error [%0t] rtl/phy_tx_packet_buffer_cdc.sv:166:15 - phy_tx_packet_buffer_cdc.g_bad_packet_size.<unnamed_block>\n msg: ", $time, "PHY_MAX_PACKET_BYTES must be non-zero");
		end
	endgenerate
	always @(posedge link_clk_i or negedge link_async_reset_ni)
		if (!link_async_reset_ni)
			link_reset_release_q <= 2'b00;
		else
			link_reset_release_q <= {link_reset_release_q[0], 1'b1};
	always @(posedge sym_clk_i or negedge sym_async_reset_ni)
		if (!sym_async_reset_ni)
			sym_reset_release_q <= 2'b00;
		else
			sym_reset_release_q <= {sym_reset_release_q[0], 1'b1};
	assign link_domain_reset_ni = link_reset_release_q[1];
	assign sym_domain_reset_ni = sym_reset_release_q[1];
	always @(posedge link_clk_i or negedge link_domain_reset_ni)
		if (!link_domain_reset_ni)
			link_domain_alive_q <= 1'b0;
		else
			link_domain_alive_q <= 1'b1;
	always @(posedge sym_clk_i or negedge sym_domain_reset_ni)
		if (!sym_domain_reset_ni)
			sym_domain_alive_q <= 1'b0;
		else
			sym_domain_alive_q <= 1'b1;
	always @(posedge link_clk_i or negedge link_domain_reset_ni)
		if (!link_domain_reset_ni) begin
			sym_alive_link_meta_q <= 1'b0;
			sym_alive_link_sync_q <= 1'b0;
		end
		else begin
			sym_alive_link_meta_q <= sym_domain_alive_q;
			sym_alive_link_sync_q <= sym_alive_link_meta_q;
		end
	always @(posedge sym_clk_i or negedge sym_domain_reset_ni)
		if (!sym_domain_reset_ni) begin
			link_alive_sym_meta_q <= 1'b0;
			link_alive_sym_sync_q <= 1'b0;
		end
		else begin
			link_alive_sym_meta_q <= link_domain_alive_q;
			link_alive_sym_sync_q <= link_alive_sym_meta_q;
		end
	always @(posedge link_clk_i or negedge link_domain_reset_ni)
		if (!link_domain_reset_ni) begin
			rd_gray_link_meta_q <= 1'sb0;
			rd_gray_link_sync_q <= 1'sb0;
		end
		else begin
			rd_gray_link_meta_q <= rd_ptr_gray_q;
			rd_gray_link_sync_q <= rd_gray_link_meta_q;
		end
	always @(posedge sym_clk_i or negedge sym_domain_reset_ni)
		if (!sym_domain_reset_ni) begin
			wr_gray_sym_meta_q <= 1'sb0;
			wr_gray_sym_sync_q <= 1'sb0;
		end
		else begin
			wr_gray_sym_meta_q <= wr_ptr_gray_q;
			wr_gray_sym_sync_q <= wr_gray_sym_meta_q;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		wr_ptr_gray_after_commit = binary_to_gray(wr_ptr_bin_q + 1'b1);
		rd_ptr_gray_full_compare = rd_gray_link_sync_q;
		rd_ptr_gray_full_compare[POINTER_WIDTH - 1-:2] = ~rd_gray_link_sync_q[POINTER_WIDTH - 1-:2];
		slot_fifo_full = wr_ptr_gray_after_commit == rd_ptr_gray_full_compare;
		slot_fifo_empty = rd_ptr_gray_q == wr_gray_sym_sync_q;
		incoming_byte_count = {1'b0, dll_tx_keep_i[0]} + {1'b0, dll_tx_keep_i[1]};
		continuation_byte_total = {1'b0, wr_byte_count_q} + incoming_byte_count;
		continuation_fits = (wr_beat_count_q < MAX_PACKET_BEATS) && (continuation_byte_total <= PHY_MAX_PACKET_BYTES);
		start_beat_bad = (((!dll_tx_sop_i || !keep_is_legal(dll_tx_keep_i, dll_tx_eop_i)) || (incoming_byte_count == 0)) || (incoming_byte_count > PHY_MAX_PACKET_BYTES)) || (dll_tx_abort_i && (!dll_tx_eop_i || (dll_tx_kind_i == 1'b1)));
		continuation_beat_bad = (((dll_tx_sop_i || !keep_is_legal(dll_tx_keep_i, dll_tx_eop_i)) || (incoming_byte_count == 0)) || !continuation_fits) || (dll_tx_abort_i && (!dll_tx_eop_i || (wr_packet_kind_q == 1'b1)));
		if (!link_domain_reset_ni || !sym_alive_link_sync_q)
			dll_tx_ready_o = 1'b0;
		else if (wr_in_packet_q)
			dll_tx_ready_o = 1'b1;
		else
			dll_tx_ready_o = txbuf_admission_enable_i && !slot_fifo_full;
	end
	function automatic [BYTE_COUNT_WIDTH - 1:0] sv2v_cast_55A1A;
		input reg [BYTE_COUNT_WIDTH - 1:0] inp;
		sv2v_cast_55A1A = inp;
	endfunction
	always @(posedge link_clk_i or negedge link_domain_reset_ni)
		if (!link_domain_reset_ni) begin
			wr_ptr_bin_q <= 1'sb0;
			wr_ptr_gray_q <= 1'sb0;
			wr_beat_count_q <= 1'sb0;
			wr_byte_count_q <= 1'sb0;
			wr_in_packet_q <= 1'b0;
			wr_packet_bad_q <= 1'b0;
			wr_error_reported_q <= 1'b0;
			wr_packet_kind_q <= 1'b0;
			stall_sample_valid_q <= 1'b0;
			stall_sample_q <= 1'sb0;
			txbuf_capture_active_o <= 1'b0;
			txbuf_error_evt_o <= 1'b0;
			txbuf_error_code_o <= 8'h00;
		end
		else begin
			txbuf_error_evt_o <= 1'b0;
			txbuf_error_code_o <= 8'h00;
			if (dll_tx_valid_i && !dll_tx_ready_o) begin
				if (!stall_sample_valid_q) begin
					stall_sample_valid_q <= 1'b1;
					stall_sample_q <= {dll_tx_data_i, dll_tx_keep_i, dll_tx_sop_i, dll_tx_eop_i, dll_tx_kind_i, dll_tx_abort_i};
				end
				else if (stall_sample_q != {dll_tx_data_i, dll_tx_keep_i, dll_tx_sop_i, dll_tx_eop_i, dll_tx_kind_i, dll_tx_abort_i}) begin
					txbuf_error_evt_o <= 1'b1;
					txbuf_error_code_o <= 8'h0e;
				end
			end
			else if (stall_sample_valid_q && !dll_tx_valid_i) begin
				stall_sample_valid_q <= 1'b0;
				txbuf_error_evt_o <= 1'b1;
				txbuf_error_code_o <= 8'h0e;
			end
			else
				stall_sample_valid_q <= 1'b0;
			if (!sym_alive_link_sync_q) begin
				wr_ptr_bin_q <= 1'sb0;
				wr_ptr_gray_q <= 1'sb0;
				wr_beat_count_q <= 1'sb0;
				wr_byte_count_q <= 1'sb0;
				wr_in_packet_q <= 1'b0;
				wr_packet_bad_q <= 1'b0;
				wr_error_reported_q <= 1'b0;
				txbuf_capture_active_o <= 1'b0;
			end
			else if (wr_in_packet_q) begin
				if (!dll_tx_valid_i) begin
					wr_packet_bad_q <= 1'b1;
					if (!wr_error_reported_q) begin
						wr_error_reported_q <= 1'b1;
						txbuf_error_evt_o <= 1'b1;
						txbuf_error_code_o <= 8'h0e;
					end
				end
				else begin
					if (continuation_fits) begin
						packet_data_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][wr_beat_count_q] <= dll_tx_data_i;
						packet_keep_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][wr_beat_count_q] <= dll_tx_keep_i;
					end
					if (continuation_beat_bad) begin
						wr_packet_bad_q <= 1'b1;
						if (!wr_error_reported_q) begin
							wr_error_reported_q <= 1'b1;
							txbuf_error_evt_o <= 1'b1;
							txbuf_error_code_o <= 8'h0e;
						end
					end
					if (dll_tx_eop_i) begin
						if (!wr_packet_bad_q && !continuation_beat_bad) begin
							packet_beat_count_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] <= wr_beat_count_q + 1'b1;
							packet_kind_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] <= wr_packet_kind_q;
							packet_abort_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] <= dll_tx_abort_i;
							wr_ptr_bin_q <= wr_ptr_bin_q + 1'b1;
							wr_ptr_gray_q <= binary_to_gray(wr_ptr_bin_q + 1'b1);
						end
						wr_beat_count_q <= 1'sb0;
						wr_byte_count_q <= 1'sb0;
						wr_in_packet_q <= 1'b0;
						wr_packet_bad_q <= 1'b0;
						wr_error_reported_q <= 1'b0;
						txbuf_capture_active_o <= 1'b0;
					end
					else if (continuation_fits) begin
						wr_beat_count_q <= wr_beat_count_q + 1'b1;
						wr_byte_count_q <= continuation_byte_total[BYTE_COUNT_WIDTH - 1:0];
					end
				end
			end
			else if (dll_tx_valid_i && dll_tx_ready_o) begin
				if (!start_beat_bad) begin
					packet_data_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][0] <= dll_tx_data_i;
					packet_keep_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][0] <= dll_tx_keep_i;
					wr_packet_kind_q <= dll_tx_kind_i;
					if (dll_tx_eop_i) begin
						packet_beat_count_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] <= {{BEAT_COUNT_WIDTH - 1 {1'b0}}, 1'b1};
						packet_kind_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] <= dll_tx_kind_i;
						packet_abort_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] <= dll_tx_abort_i;
						wr_ptr_bin_q <= wr_ptr_bin_q + 1'b1;
						wr_ptr_gray_q <= binary_to_gray(wr_ptr_bin_q + 1'b1);
					end
					else begin
						wr_beat_count_q <= {{BEAT_COUNT_WIDTH - 1 {1'b0}}, 1'b1};
						wr_byte_count_q <= sv2v_cast_55A1A(incoming_byte_count);
						wr_in_packet_q <= 1'b1;
						wr_packet_bad_q <= 1'b0;
						wr_error_reported_q <= 1'b0;
						txbuf_capture_active_o <= 1'b1;
					end
				end
				else begin
					txbuf_error_evt_o <= 1'b1;
					txbuf_error_code_o <= 8'h0e;
					if (dll_tx_sop_i && !dll_tx_eop_i) begin
						wr_beat_count_q <= 1'sb0;
						wr_byte_count_q <= 1'sb0;
						wr_in_packet_q <= 1'b1;
						wr_packet_bad_q <= 1'b1;
						wr_error_reported_q <= 1'b1;
						wr_packet_kind_q <= dll_tx_kind_i;
						txbuf_capture_active_o <= 1'b1;
					end
				end
			end
		end
	(* ASYNC_REG = "TRUE" *) reg capture_active_sym_meta_q;
	(* ASYNC_REG = "TRUE" *) reg capture_active_sym_sync_q;
	always @(posedge sym_clk_i or negedge sym_domain_reset_ni)
		if (!sym_domain_reset_ni) begin
			capture_active_sym_meta_q <= 1'b0;
			capture_active_sym_sync_q <= 1'b0;
		end
		else begin
			capture_active_sym_meta_q <= txbuf_capture_active_o;
			capture_active_sym_sync_q <= capture_active_sym_meta_q;
		end
	always @(posedge sym_clk_i or negedge sym_domain_reset_ni)
		if (!sym_domain_reset_ni) begin
			rd_ptr_bin_q <= 1'sb0;
			rd_ptr_gray_q <= 1'sb0;
			rd_beat_index_q <= 1'sb0;
			txbuf_pkt_valid_o <= 1'b0;
			txbuf_pkt_data_o <= 1'sb0;
			txbuf_pkt_keep_o <= 1'sb0;
			txbuf_pkt_sop_o <= 1'b0;
			txbuf_pkt_eop_o <= 1'b0;
			txbuf_pkt_kind_o <= 1'b0;
			txbuf_pkt_abort_o <= 1'b0;
		end
		else if (!link_alive_sym_sync_q) begin
			rd_ptr_bin_q <= 1'sb0;
			rd_ptr_gray_q <= 1'sb0;
			rd_beat_index_q <= 1'sb0;
			txbuf_pkt_valid_o <= 1'b0;
			txbuf_pkt_data_o <= 1'sb0;
			txbuf_pkt_keep_o <= 1'sb0;
			txbuf_pkt_sop_o <= 1'b0;
			txbuf_pkt_eop_o <= 1'b0;
			txbuf_pkt_kind_o <= 1'b0;
			txbuf_pkt_abort_o <= 1'b0;
		end
		else if (!txbuf_pkt_valid_o) begin
			if (!slot_fifo_empty) begin
				rd_beat_index_q <= 1'sb0;
				txbuf_pkt_valid_o <= 1'b1;
				txbuf_pkt_data_o <= packet_data_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][0];
				txbuf_pkt_keep_o <= packet_keep_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][0];
				txbuf_pkt_sop_o <= 1'b1;
				txbuf_pkt_eop_o <= packet_beat_count_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] == 1;
				txbuf_pkt_kind_o <= packet_kind_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]];
				txbuf_pkt_abort_o <= packet_abort_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] && (packet_beat_count_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] == 1);
			end
		end
		else if (txbuf_pkt_ready_i) begin
			if (txbuf_pkt_eop_o) begin
				rd_ptr_bin_q <= rd_ptr_bin_q + 1'b1;
				rd_ptr_gray_q <= binary_to_gray(rd_ptr_bin_q + 1'b1);
				rd_beat_index_q <= 1'sb0;
				txbuf_pkt_valid_o <= 1'b0;
				txbuf_pkt_sop_o <= 1'b0;
				txbuf_pkt_eop_o <= 1'b0;
				txbuf_pkt_abort_o <= 1'b0;
			end
			else begin
				rd_beat_index_q <= rd_beat_index_q + 1'b1;
				txbuf_pkt_data_o <= packet_data_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][rd_beat_index_q + 1'b1];
				txbuf_pkt_keep_o <= packet_keep_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]][rd_beat_index_q + 1'b1];
				txbuf_pkt_sop_o <= 1'b0;
				txbuf_pkt_eop_o <= (rd_beat_index_q + 2) == packet_beat_count_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]];
				txbuf_pkt_abort_o <= packet_abort_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]] && ((rd_beat_index_q + 2) == packet_beat_count_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH - 1:0]]);
			end
		end
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		wr_ptr_bin_sym = gray_to_binary(wr_gray_sym_sync_q);
		committed_packet_count_sym = wr_ptr_bin_sym - rd_ptr_bin_q;
		txbuf_pending_o = sym_domain_reset_ni && ((txbuf_pkt_valid_o || !slot_fifo_empty) || capture_active_sym_sync_q);
		if (!sym_domain_reset_ni || !link_alive_sym_sync_q)
			txbuf_level_o = 8'h00;
		else if (committed_packet_count_sym > 8'hff)
			txbuf_level_o = 8'hff;
		else
			txbuf_level_o = sv2v_cast_8(committed_packet_count_sym);
	end
	initial _sv2v_0 = 0;
endmodule
