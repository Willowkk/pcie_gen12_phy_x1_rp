`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_skp_clock_comp (
	sym_clk_i,
	sym_rst_ni,
	skp_current_rate_i,
	skp_tx_char_advance_i,
	skp_packet_boundary_i,
	skp_os_busy_i,
	skp_tx_accept_i,
	skp_due_o,
	skp_deadline_o,
	skp_deadline_missed_evt_o,
	gt_rx_clkcor_count_i,
	gt_rx_buffer_status_i,
	skp_rx_add_evt_o,
	skp_rx_skip_count_o,
	skp_rx_buffer_fault_evt_o,
	skp_rx_underflow_evt_o,
	skp_rx_overflow_evt_o,
	skp_rx_status_invalid_evt_o
);
	reg _sv2v_0;
	input wire sym_clk_i;
	input wire sym_rst_ni;
	input wire skp_current_rate_i;
	input wire [1:0] skp_tx_char_advance_i;
	input wire skp_packet_boundary_i;
	input wire skp_os_busy_i;
	input wire skp_tx_accept_i;
	output wire skp_due_o;
	output reg [15:0] skp_deadline_o;
	output reg skp_deadline_missed_evt_o;
	input wire [1:0] gt_rx_clkcor_count_i;
	input wire [2:0] gt_rx_buffer_status_i;
	output reg skp_rx_add_evt_o;
	output reg [1:0] skp_rx_skip_count_o;
	output reg skp_rx_buffer_fault_evt_o;
	output reg skp_rx_underflow_evt_o;
	output reg skp_rx_overflow_evt_o;
	output reg skp_rx_status_invalid_evt_o;
	localparam [31:0] pcie_gen12_phy_timing_pkg_SKP_LATEST_INTERVAL_SYMBOLS = 1538;
	localparam [31:0] COUNT_W = 11;
	reg [10:0] tx_symbol_count_q;
	reg deadline_reported_q;
	reg current_rate_q;
	reg [1:0] clkcor_previous_q;
	reg [2:0] rxbuf_previous_q;
	wire [COUNT_W:0] advanced_count_c;
	wire clkcor_event_c;
	wire rxbuf_status_changed_c;
	wire rxbuf_status_legal_c;
	assign advanced_count_c = {1'b0, tx_symbol_count_q} + skp_tx_char_advance_i;
	localparam [31:0] pcie_gen12_phy_timing_pkg_SKP_SCHEDULE_INTERVAL_SYMBOLS = 1180;
	assign skp_due_o = (tx_symbol_count_q >= pcie_gen12_phy_timing_pkg_SKP_SCHEDULE_INTERVAL_SYMBOLS) && skp_packet_boundary_i;
	always @(*) begin
		if (_sv2v_0)
			;
		if (tx_symbol_count_q >= pcie_gen12_phy_timing_pkg_SKP_LATEST_INTERVAL_SYMBOLS)
			skp_deadline_o = 16'h0000;
		else
			skp_deadline_o = pcie_gen12_phy_timing_pkg_SKP_LATEST_INTERVAL_SYMBOLS - tx_symbol_count_q;
	end
	assign clkcor_event_c = (gt_rx_clkcor_count_i != 2'b00) && (gt_rx_clkcor_count_i != clkcor_previous_q);
	assign rxbuf_status_changed_c = gt_rx_buffer_status_i != rxbuf_previous_q;
	assign rxbuf_status_legal_c = ((((gt_rx_buffer_status_i == 3'b000) || (gt_rx_buffer_status_i == 3'b001)) || (gt_rx_buffer_status_i == 3'b010)) || (gt_rx_buffer_status_i == 3'b101)) || (gt_rx_buffer_status_i == 3'b110);
	always @(posedge sym_clk_i or negedge sym_rst_ni)
		if (!sym_rst_ni) begin
			tx_symbol_count_q <= 1'sb0;
			deadline_reported_q <= 1'b0;
			current_rate_q <= 1'b0;
			clkcor_previous_q <= 2'b00;
			rxbuf_previous_q <= 3'b000;
			skp_deadline_missed_evt_o <= 1'b0;
			skp_rx_add_evt_o <= 1'b0;
			skp_rx_skip_count_o <= 2'b00;
			skp_rx_buffer_fault_evt_o <= 1'b0;
			skp_rx_underflow_evt_o <= 1'b0;
			skp_rx_overflow_evt_o <= 1'b0;
			skp_rx_status_invalid_evt_o <= 1'b0;
		end
		else begin
			skp_deadline_missed_evt_o <= 1'b0;
			skp_rx_add_evt_o <= 1'b0;
			skp_rx_skip_count_o <= 2'b00;
			skp_rx_buffer_fault_evt_o <= 1'b0;
			skp_rx_underflow_evt_o <= 1'b0;
			skp_rx_overflow_evt_o <= 1'b0;
			skp_rx_status_invalid_evt_o <= 1'b0;
			current_rate_q <= skp_current_rate_i;
			clkcor_previous_q <= gt_rx_clkcor_count_i;
			rxbuf_previous_q <= gt_rx_buffer_status_i;
			if (skp_current_rate_i != current_rate_q) begin
				tx_symbol_count_q <= 1'sb0;
				deadline_reported_q <= 1'b0;
			end
			else if (skp_tx_accept_i) begin
				tx_symbol_count_q <= 1'sb0;
				deadline_reported_q <= 1'b0;
			end
			else if (advanced_count_c >= pcie_gen12_phy_timing_pkg_SKP_LATEST_INTERVAL_SYMBOLS) begin
				tx_symbol_count_q <= pcie_gen12_phy_timing_pkg_SKP_LATEST_INTERVAL_SYMBOLS;
				if (!deadline_reported_q) begin
					skp_deadline_missed_evt_o <= 1'b1;
					deadline_reported_q <= 1'b1;
				end
			end
			else
				tx_symbol_count_q <= advanced_count_c[10:0];
			if (clkcor_event_c)
				(* full_case, parallel_case *)
				case (gt_rx_clkcor_count_i)
					2'b01: skp_rx_skip_count_o <= 2'd1;
					2'b10: skp_rx_skip_count_o <= 2'd2;
					2'b11: skp_rx_add_evt_o <= 1'b1;
					default:
						;
				endcase
			if (rxbuf_status_changed_c)
				(* full_case, parallel_case *)
				case (gt_rx_buffer_status_i)
					3'b101: begin
						skp_rx_underflow_evt_o <= 1'b1;
						skp_rx_buffer_fault_evt_o <= 1'b1;
					end
					3'b110: begin
						skp_rx_overflow_evt_o <= 1'b1;
						skp_rx_buffer_fault_evt_o <= 1'b1;
					end
					default:
						if (!rxbuf_status_legal_c) begin
							skp_rx_status_invalid_evt_o <= 1'b1;
							skp_rx_buffer_fault_evt_o <= 1'b1;
						end
				endcase
		end
	initial _sv2v_0 = 0;
endmodule
