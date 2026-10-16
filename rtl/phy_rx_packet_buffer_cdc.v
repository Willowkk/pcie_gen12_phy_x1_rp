`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_rx_packet_buffer_cdc (
	sym_clk_i,
	sym_rst_ni,
	port_reset_ni,
	rxbuf_flush_i,
	link_clk_i,
	link_rst_ni,
	rxbuf_pkt_valid_i,
	rxbuf_pkt_ready_o,
	rxbuf_pkt_data_i,
	rxbuf_pkt_keep_i,
	rxbuf_pkt_sop_i,
	rxbuf_pkt_eop_i,
	rxbuf_pkt_kind_i,
	rxbuf_pkt_abort_i,
	rxbuf_drop_i,
	dll_rx_valid_o,
	dll_rx_ready_i,
	dll_rx_data_o,
	dll_rx_keep_o,
	dll_rx_sop_o,
	dll_rx_eop_o,
	dll_rx_kind_o,
	dll_rx_abort_o,
	rxbuf_overflow_evt_o,
	rxbuf_candidate_drop_evt_o,
	rxbuf_backpressure_timeout_evt_o,
	rxbuf_level_o
);
	reg _sv2v_0;
	localparam [31:0] pcie_gen12_phy_timing_pkg_PHY_MAX_PACKET_BYTES = 4128;
	parameter [31:0] PHY_MAX_PACKET_BYTES = pcie_gen12_phy_timing_pkg_PHY_MAX_PACKET_BYTES;
	localparam [31:0] pcie_gen12_phy_timing_pkg_PHY_RX_WHOLE_PACKET_SLOTS = 2;
	parameter [31:0] PHY_RX_PACKET_SLOTS = pcie_gen12_phy_timing_pkg_PHY_RX_WHOLE_PACKET_SLOTS;
	localparam [31:0] pcie_gen12_phy_timing_pkg_PHY_RX_BACKPRESSURE_MAX_CYCLES = 4096;
	parameter [31:0] PHY_RX_BACKPRESSURE_MAX_CYCLES = pcie_gen12_phy_timing_pkg_PHY_RX_BACKPRESSURE_MAX_CYCLES;
	input wire sym_clk_i;
	input wire sym_rst_ni;
	input wire port_reset_ni;
	input wire rxbuf_flush_i;
	input wire link_clk_i;
	input wire link_rst_ni;
	input wire rxbuf_pkt_valid_i;
	output reg rxbuf_pkt_ready_o;
	input wire [15:0] rxbuf_pkt_data_i;
	input wire [1:0] rxbuf_pkt_keep_i;
	input wire rxbuf_pkt_sop_i;
	input wire rxbuf_pkt_eop_i;
	input wire rxbuf_pkt_kind_i;
	input wire rxbuf_pkt_abort_i;
	input wire rxbuf_drop_i;
	output reg dll_rx_valid_o;
	input wire dll_rx_ready_i;
	output reg [15:0] dll_rx_data_o;
	output reg [1:0] dll_rx_keep_o;
	output reg dll_rx_sop_o;
	output reg dll_rx_eop_o;
	output reg dll_rx_kind_o;
	output reg dll_rx_abort_o;
	output reg rxbuf_overflow_evt_o;
	output reg rxbuf_candidate_drop_evt_o;
	output reg rxbuf_backpressure_timeout_evt_o;
	output reg [7:0] rxbuf_level_o;
	localparam [31:0] SLOT_ADDR_W = (PHY_RX_PACKET_SLOTS <= 2 ? 1 : $clog2(PHY_RX_PACKET_SLOTS));
	localparam [31:0] PTR_W = SLOT_ADDR_W + 1;
	localparam [31:0] BYTE_COUNT_W = (PHY_MAX_PACKET_BYTES < 2 ? 1 : $clog2(PHY_MAX_PACKET_BYTES + 1));
	localparam [31:0] BP_COUNT_W = (PHY_RX_BACKPRESSURE_MAX_CYCLES < 2 ? 1 : $clog2(PHY_RX_BACKPRESSURE_MAX_CYCLES + 1));
	reg [7:0] packet_byte_mem [0:PHY_RX_PACKET_SLOTS - 1][0:PHY_MAX_PACKET_BYTES - 1];
	reg [BYTE_COUNT_W - 1:0] packet_bytes_mem [0:PHY_RX_PACKET_SLOTS - 1];
	reg packet_kind_mem [0:PHY_RX_PACKET_SLOTS - 1];
	reg packet_abort_mem [0:PHY_RX_PACKET_SLOTS - 1];
	reg [PTR_W - 1:0] wr_bin_q;
	reg [PTR_W - 1:0] wr_gray_q;
	reg [PTR_W - 1:0] rd_bin_q;
	reg [PTR_W - 1:0] rd_gray_q;
	(* ASYNC_REG = "TRUE" *) reg [PTR_W - 1:0] rd_gray_sync1_q;
	(* ASYNC_REG = "TRUE" *) reg [PTR_W - 1:0] rd_gray_sync2_q;
	(* ASYNC_REG = "TRUE" *) reg [PTR_W - 1:0] wr_gray_sync1_q;
	(* ASYNC_REG = "TRUE" *) reg [PTR_W - 1:0] wr_gray_sync2_q;
	wire [PTR_W - 1:0] rd_bin_sync_c;
	wire fifo_full_c;
	wire fifo_empty_c;
	reg [PTR_W:0] rxbuf_level_ext_c;
	reg wr_active_q;
	reg [BYTE_COUNT_W - 1:0] wr_byte_count_q;
	reg [BYTE_COUNT_W - 1:0] rd_byte_index_q;
	reg [BP_COUNT_W - 1:0] backpressure_count_q;
	reg backpressure_reported_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] sym_domain_release_sync_q;
	(* ASYNC_REG = "TRUE" *) reg [1:0] link_domain_release_sync_q;
	wire sym_domain_reset_ni = sym_rst_ni && sym_domain_release_sync_q[1];
	wire link_domain_reset_ni = link_rst_ni && link_domain_release_sync_q[1];
	wire [1:0] incoming_byte_count_c;
	function automatic [PTR_W - 1:0] bin_to_gray;
		input reg [PTR_W - 1:0] value;
		bin_to_gray = (value >> 1) ^ value;
	endfunction
	function automatic [PTR_W - 1:0] gray_to_bin;
		input reg [PTR_W - 1:0] value;
		reg [PTR_W - 1:0] result;
		begin
			result[PTR_W - 1] = value[PTR_W - 1];
			begin : sv2v_autoblock_1
				reg signed [31:0] bit_index;
				for (bit_index = PTR_W - 2; bit_index >= 0; bit_index = bit_index - 1)
					result[bit_index] = result[bit_index + 1] ^ value[bit_index];
			end
			gray_to_bin = result;
		end
	endfunction
	initial begin : p_parameter_guards
		if ((PHY_RX_PACKET_SLOTS < 2) || ((PHY_RX_PACKET_SLOTS & (PHY_RX_PACKET_SLOTS - 1)) != 0))
			$display("Error [%0t] rtl/phy_rx_packet_buffer_cdc.sv:116:7 - phy_rx_packet_buffer_cdc.p_parameter_guards.<unnamed_block>\n msg: ", $time, "PHY_RX_PACKET_SLOTS must be a power of two and at least two");
		if ((PHY_MAX_PACKET_BYTES == 0) || (PHY_RX_BACKPRESSURE_MAX_CYCLES == 0))
			$display("Error [%0t] rtl/phy_rx_packet_buffer_cdc.sv:120:7 - phy_rx_packet_buffer_cdc.p_parameter_guards.<unnamed_block>\n msg: ", $time, "RX packet and backpressure limits must be non-zero");
	end
	assign incoming_byte_count_c = {1'b0, rxbuf_pkt_keep_i[0]} + {1'b0, rxbuf_pkt_keep_i[1]};
	always @(posedge sym_clk_i or negedge sym_rst_ni or negedge port_reset_ni or posedge rxbuf_flush_i)
		if ((!sym_rst_ni || !port_reset_ni) || rxbuf_flush_i)
			sym_domain_release_sync_q <= 2'b00;
		else
			sym_domain_release_sync_q <= {sym_domain_release_sync_q[0], 1'b1};
	always @(posedge link_clk_i or negedge link_rst_ni or negedge port_reset_ni or posedge rxbuf_flush_i)
		if ((!link_rst_ni || !port_reset_ni) || rxbuf_flush_i)
			link_domain_release_sync_q <= 2'b00;
		else
			link_domain_release_sync_q <= {link_domain_release_sync_q[0], 1'b1};
	always @(posedge sym_clk_i or negedge sym_domain_reset_ni)
		if (!sym_domain_reset_ni) begin
			rd_gray_sync1_q <= 1'sb0;
			rd_gray_sync2_q <= 1'sb0;
		end
		else begin
			rd_gray_sync1_q <= rd_gray_q;
			rd_gray_sync2_q <= rd_gray_sync1_q;
		end
	always @(posedge link_clk_i or negedge link_domain_reset_ni)
		if (!link_domain_reset_ni) begin
			wr_gray_sync1_q <= 1'sb0;
			wr_gray_sync2_q <= 1'sb0;
		end
		else begin
			wr_gray_sync1_q <= wr_gray_q;
			wr_gray_sync2_q <= wr_gray_sync1_q;
		end
	assign rd_bin_sync_c = gray_to_bin(rd_gray_sync2_q);
	assign fifo_full_c = (wr_bin_q[SLOT_ADDR_W - 1:0] == rd_bin_sync_c[SLOT_ADDR_W - 1:0]) && (wr_bin_q[PTR_W - 1] != rd_bin_sync_c[PTR_W - 1]);
	assign fifo_empty_c = rd_gray_q == wr_gray_sync2_q;
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		rxbuf_level_ext_c = {1'b0, wr_bin_q - rd_bin_sync_c} + {{PTR_W {1'b0}}, wr_active_q};
		if (rxbuf_level_ext_c > 8'hff)
			rxbuf_level_o = 8'hff;
		else
			rxbuf_level_o = sv2v_cast_8(rxbuf_level_ext_c);
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (!sym_domain_reset_ni)
			rxbuf_pkt_ready_o = 1'b0;
		else if (!wr_active_q)
			rxbuf_pkt_ready_o = !fifo_full_c;
		else if ((rxbuf_pkt_keep_i == 2'b00) && rxbuf_pkt_eop_i)
			rxbuf_pkt_ready_o = 1'b1;
		else
			rxbuf_pkt_ready_o = (wr_byte_count_q + incoming_byte_count_c) <= PHY_MAX_PACKET_BYTES;
	end
	always @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin : p_write
		reg [SLOT_ADDR_W - 1:0] slot_index;
		reg [BYTE_COUNT_W - 1:0] byte_count_w;
		reg invalid_candidate;
		if (!sym_domain_reset_ni) begin
			wr_bin_q <= 1'sb0;
			wr_gray_q <= 1'sb0;
			wr_active_q <= 1'b0;
			wr_byte_count_q <= 1'sb0;
			rxbuf_overflow_evt_o <= 1'b0;
			rxbuf_candidate_drop_evt_o <= 1'b0;
		end
		else begin
			rxbuf_overflow_evt_o <= 1'b0;
			rxbuf_candidate_drop_evt_o <= 1'b0;
			if (rxbuf_drop_i) begin
				if (wr_active_q)
					rxbuf_candidate_drop_evt_o <= 1'b1;
				wr_active_q <= 1'b0;
				wr_byte_count_q <= 1'sb0;
			end
			else if (rxbuf_pkt_valid_i && !rxbuf_pkt_ready_o) begin
				rxbuf_overflow_evt_o <= 1'b1;
				rxbuf_candidate_drop_evt_o <= wr_active_q;
				wr_active_q <= 1'b0;
				wr_byte_count_q <= 1'sb0;
			end
			else if (rxbuf_pkt_valid_i && rxbuf_pkt_ready_o) begin
				slot_index = wr_bin_q[SLOT_ADDR_W - 1:0];
				byte_count_w = wr_byte_count_q;
				invalid_candidate = 1'b0;
				if (!wr_active_q) begin
					if (!rxbuf_pkt_sop_i || (rxbuf_pkt_keep_i == 2'b00))
						invalid_candidate = 1'b1;
					else begin
						wr_active_q <= 1'b1;
						packet_kind_mem[slot_index] <= rxbuf_pkt_kind_i;
					end
				end
				else if (rxbuf_pkt_sop_i)
					invalid_candidate = 1'b1;
				if (rxbuf_pkt_keep_i == 2'b10)
					invalid_candidate = 1'b1;
				if (!rxbuf_pkt_eop_i && (rxbuf_pkt_keep_i == 2'b00))
					invalid_candidate = 1'b1;
				if (rxbuf_pkt_abort_i && (!rxbuf_pkt_eop_i || rxbuf_pkt_kind_i))
					invalid_candidate = 1'b1;
				if (!invalid_candidate) begin
					if (rxbuf_pkt_keep_i[0]) begin
						packet_byte_mem[slot_index][byte_count_w] <= rxbuf_pkt_data_i[7:0];
						byte_count_w = byte_count_w + 1'b1;
					end
					if (rxbuf_pkt_keep_i[1]) begin
						packet_byte_mem[slot_index][byte_count_w] <= rxbuf_pkt_data_i[15:8];
						byte_count_w = byte_count_w + 1'b1;
					end
				end
				if (invalid_candidate) begin
					rxbuf_candidate_drop_evt_o <= 1'b1;
					wr_active_q <= 1'b0;
					wr_byte_count_q <= 1'sb0;
				end
				else if (rxbuf_pkt_eop_i) begin
					if (byte_count_w == 0)
						rxbuf_candidate_drop_evt_o <= 1'b1;
					else begin
						packet_bytes_mem[slot_index] <= byte_count_w;
						packet_abort_mem[slot_index] <= rxbuf_pkt_abort_i;
						wr_bin_q <= wr_bin_q + 1'b1;
						wr_gray_q <= bin_to_gray(wr_bin_q + 1'b1);
					end
					wr_active_q <= 1'b0;
					wr_byte_count_q <= 1'sb0;
				end
				else
					wr_byte_count_q <= byte_count_w;
			end
		end
	end
	always @(*) begin : p_read_output
		reg [SLOT_ADDR_W - 1:0] slot_index;
		reg [BYTE_COUNT_W - 1:0] bytes_remaining;
		if (_sv2v_0)
			;
		slot_index = rd_bin_q[SLOT_ADDR_W - 1:0];
		bytes_remaining = 1'sb0;
		dll_rx_valid_o = link_domain_reset_ni && !fifo_empty_c;
		dll_rx_data_o = 1'sb0;
		dll_rx_keep_o = 1'sb0;
		dll_rx_sop_o = 1'b0;
		dll_rx_eop_o = 1'b0;
		dll_rx_kind_o = 1'b0;
		dll_rx_abort_o = 1'b0;
		if (dll_rx_valid_o) begin
			bytes_remaining = packet_bytes_mem[slot_index] - rd_byte_index_q;
			dll_rx_data_o = {(bytes_remaining >= 2 ? packet_byte_mem[slot_index][rd_byte_index_q + 1'b1] : 8'h00), packet_byte_mem[slot_index][rd_byte_index_q]};
			dll_rx_keep_o = (bytes_remaining >= 2 ? 2'b11 : 2'b01);
			dll_rx_sop_o = rd_byte_index_q == 0;
			dll_rx_eop_o = bytes_remaining <= 2;
			dll_rx_kind_o = packet_kind_mem[slot_index];
			dll_rx_abort_o = dll_rx_eop_o && packet_abort_mem[slot_index];
		end
	end
	always @(posedge link_clk_i or negedge link_domain_reset_ni)
		if (!link_domain_reset_ni) begin
			rd_bin_q <= 1'sb0;
			rd_gray_q <= 1'sb0;
			rd_byte_index_q <= 1'sb0;
			backpressure_count_q <= 1'sb0;
			backpressure_reported_q <= 1'b0;
			rxbuf_backpressure_timeout_evt_o <= 1'b0;
		end
		else begin
			rxbuf_backpressure_timeout_evt_o <= 1'b0;
			if (dll_rx_valid_o && dll_rx_ready_i) begin
				if (dll_rx_eop_o) begin
					rd_bin_q <= rd_bin_q + 1'b1;
					rd_gray_q <= bin_to_gray(rd_bin_q + 1'b1);
					rd_byte_index_q <= 1'sb0;
				end
				else
					rd_byte_index_q <= rd_byte_index_q + 2;
			end
			if (dll_rx_valid_o && !dll_rx_ready_i) begin
				if (backpressure_count_q < PHY_RX_BACKPRESSURE_MAX_CYCLES)
					backpressure_count_q <= backpressure_count_q + 1'b1;
				if (!backpressure_reported_q && ((backpressure_count_q + 1'b1) >= PHY_RX_BACKPRESSURE_MAX_CYCLES)) begin
					rxbuf_backpressure_timeout_evt_o <= 1'b1;
					backpressure_reported_q <= 1'b1;
				end
			end
			else begin
				backpressure_count_q <= 1'sb0;
				backpressure_reported_q <= 1'b0;
			end
		end
	initial _sv2v_0 = 0;
endmodule
