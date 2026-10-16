`timescale 1ns/1ps

// Verilog-2005 implementation. Shared encodings and packed structures
// are represented by module-local constants, vectors and functions.
// Port widths, state encodings and sequential behavior are preserved.

module phy_status_error (
	ctrl_clk_i,
	ctrl_rst_ni,
	port_reset_ni,
	link_clk_i,
	link_rst_ni,
	status_ready_i,
	status_state_i,
	status_substate_i,
	status_reason_i,
	status_rate_i,
	status_link_up_i,
	status_data_active_i,
	status_rx_lock_i,
	status_buffer_level_i,
	status_timer_id_i,
	status_timer_value_i,
	status_retry_count_i,
	status_clear_i,
	status_debug_counter_seed_valid_i,
	status_debug_counter_seed_index_i,
	status_debug_counter_seed_value_i,
	status_evt_valid_i,
	status_evt_source_i,
	status_evt_code_i,
	status_evt_info_i,
	status_evt_fatal_i,
	status_evt_ready_o,
	status_gt_fatal_evt_valid_i,
	status_gt_fatal_evt_code_i,
	status_gt_fatal_evt_info_i,
	status_buffer_fatal_evt_valid_i,
	status_buffer_fatal_evt_code_i,
	status_buffer_fatal_evt_info_i,
	status_alignment_evt_valid_i,
	status_alignment_evt_code_i,
	status_alignment_evt_info_i,
	status_framing_evt_valid_i,
	status_framing_evt_code_i,
	status_framing_evt_info_i,
	status_correctable_evt_valid_i,
	status_correctable_evt_code_i,
	status_correctable_evt_info_i,
	phy_ready_o,
	phy_link_up_o,
	phy_data_active_o,
	phy_current_rate_o,
	phy_ltssm_state_o,
	phy_ltssm_substate_o,
	phy_state_reason_o,
	phy_rx_locked_o,
	phy_dll_link_up_o,
	phy_dll_data_active_o,
	phy_dll_current_rate_o,
	phy_dll_link_down_evt_o,
	phy_err_valid_o,
	phy_err_ready_i,
	phy_err_code_o,
	phy_err_info_o,
	phy_csr_req_valid_i,
	phy_csr_req_ready_o,
	phy_csr_req_write_i,
	phy_csr_req_addr_i,
	phy_csr_req_wdata_i,
	phy_csr_req_wstrb_i,
	phy_csr_rsp_valid_o,
	phy_csr_rsp_ready_i,
	phy_csr_rsp_rdata_o,
	phy_csr_rsp_error_o
);
	reg _sv2v_0;
	input wire ctrl_clk_i;
	input wire ctrl_rst_ni;
	input wire port_reset_ni;
	input wire link_clk_i;
	input wire link_rst_ni;
	input wire status_ready_i;
	input wire [5:0] status_state_i;
	input wire [5:0] status_substate_i;
	input wire [7:0] status_reason_i;
	input wire status_rate_i;
	input wire status_link_up_i;
	input wire status_data_active_i;
	input wire status_rx_lock_i;
	input wire [15:0] status_buffer_level_i;
	input wire [5:0] status_timer_id_i;
	input wire [31:0] status_timer_value_i;
	input wire [7:0] status_retry_count_i;
	input wire status_clear_i;
	input wire status_debug_counter_seed_valid_i;
	input wire [4:0] status_debug_counter_seed_index_i;
	input wire [31:0] status_debug_counter_seed_value_i;
	input wire status_evt_valid_i;
	input wire [3:0] status_evt_source_i;
	input wire [7:0] status_evt_code_i;
	input wire [31:0] status_evt_info_i;
	input wire status_evt_fatal_i;
	output wire status_evt_ready_o;
	input wire status_gt_fatal_evt_valid_i;
	input wire [7:0] status_gt_fatal_evt_code_i;
	input wire [31:0] status_gt_fatal_evt_info_i;
	input wire status_buffer_fatal_evt_valid_i;
	input wire [7:0] status_buffer_fatal_evt_code_i;
	input wire [31:0] status_buffer_fatal_evt_info_i;
	input wire status_alignment_evt_valid_i;
	input wire [7:0] status_alignment_evt_code_i;
	input wire [31:0] status_alignment_evt_info_i;
	input wire status_framing_evt_valid_i;
	input wire [7:0] status_framing_evt_code_i;
	input wire [31:0] status_framing_evt_info_i;
	input wire status_correctable_evt_valid_i;
	input wire [7:0] status_correctable_evt_code_i;
	input wire [31:0] status_correctable_evt_info_i;
	output reg phy_ready_o;
	output reg phy_link_up_o;
	output reg phy_data_active_o;
	output reg phy_current_rate_o;
	output reg [5:0] phy_ltssm_state_o;
	output reg [5:0] phy_ltssm_substate_o;
	output reg [7:0] phy_state_reason_o;
	output reg phy_rx_locked_o;
	output reg phy_dll_link_up_o;
	output reg phy_dll_data_active_o;
	output reg phy_dll_current_rate_o;
	output reg phy_dll_link_down_evt_o;
	output wire phy_err_valid_o;
	input wire phy_err_ready_i;
	output wire [7:0] phy_err_code_o;
	output wire [31:0] phy_err_info_o;
	input wire phy_csr_req_valid_i;
	output wire phy_csr_req_ready_o;
	input wire phy_csr_req_write_i;
	input wire [11:0] phy_csr_req_addr_i;
	input wire [31:0] phy_csr_req_wdata_i;
	input wire [3:0] phy_csr_req_wstrb_i;
	output wire phy_csr_rsp_valid_o;
	input wire phy_csr_rsp_ready_i;
	output wire [31:0] phy_csr_rsp_rdata_o;
	output wire phy_csr_rsp_error_o;
	localparam [31:0] ERROR_CODE_COUNT = 19;
	localparam [31:0] PENDING_SLOTS = 6;
	localparam [31:0] ERROR_FIFO_DEPTH = 8;
	localparam [31:0] HISTORY_DEPTH = 8;
	localparam [31:0] ERROR_FIFO_PTR_W = 3;
	localparam [31:0] ERROR_FIFO_CNT_W = 4;
	localparam [31:0] HISTORY_PTR_W = 3;
	localparam [31:0] HISTORY_CNT_W = 4;
	wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;
	wire link_local_reset_ani = link_rst_ni & port_reset_ni;
	reg [45:0] pending_q [0:5];
	reg [45:0] incoming [0:5];
	reg [45:0] service_event;
	reg [45:0] incoming_best;
	reg service_valid;
	reg service_commit;
	reg service_is_overflow;
	reg incoming_best_valid;
	reg incoming_any_fatal;
	reg [2:0] service_priority;
	reg [2:0] incoming_best_priority;
	integer service_index;
	integer incoming_index;
	integer service_scan_index;
	integer best_scan_index;
	reg [18:0] sticky_bitmap_q;
	reg [31:0] error_counter_q [0:18];
	reg first_error_valid_q;
	reg first_error_fatal_q;
	reg [3:0] first_error_source_q;
	reg [7:0] first_error_code_q;
	reg [31:0] first_error_info_q;
	reg [5:0] first_error_state_q;
	reg [5:0] first_error_substate_q;
	reg first_error_rate_q;
	reg safety_fatal_q;
	reg overflow_pending_q;
	reg [31:0] history_meta_q [0:7];
	reg [31:0] history_info_q [0:7];
	reg [2:0] history_wr_ptr_q;
	reg [3:0] history_count_q;
	reg [7:0] error_fifo_code_q [0:7];
	reg [31:0] error_fifo_info_q [0:7];
	reg [2:0] error_fifo_wr_ptr_q;
	reg [2:0] error_fifo_rd_ptr_q;
	reg [3:0] error_fifo_count_q;
	wire error_fifo_pop;
	wire error_fifo_push;
	wire error_fifo_has_space;
	reg csr_rsp_valid_q;
	reg [31:0] csr_rsp_rdata_q;
	reg csr_rsp_error_q;
	wire [31:0] csr_write_mask;
	reg [2:0] snapshot_payload_q;
	reg [2:0] snapshot_last_sent_q;
	reg snapshot_req_toggle_q;
	reg snapshot_pending_q;
	reg [1:0] snapshot_ack_ctrl_sync_q;
	reg [1:0] snapshot_req_link_sync_q;
	reg snapshot_ack_link_q;
	function automatic signed [31:0] sv2v_cast_32_signed;
		input reg signed [31:0] inp;
		sv2v_cast_32_signed = inp;
	endfunction
	function automatic integer code_index;
		input reg [7:0] code;
		reg [0:1] _sv2v_jump;
		begin
			_sv2v_jump = 2'b00;
			if ((code >= 8'h01) && (code <= 8'h13)) begin
				code_index = sv2v_cast_32_signed(code) - 1;
				_sv2v_jump = 2'b11;
			end
			if (_sv2v_jump == 2'b00) begin
				code_index = -1;
				_sv2v_jump = 2'b11;
			end
		end
	endfunction
	function automatic [31:0] apply_write_strobes;
		input reg [31:0] data;
		input reg [3:0] strobes;
		reg [31:0] mask;
		integer byte_index;
		begin
			mask = 1'sb0;
			for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
				if (strobes[byte_index])
					mask[byte_index * 8+:8] = data[byte_index * 8+:8];
			apply_write_strobes = mask;
		end
	endfunction
	assign csr_write_mask = apply_write_strobes(phy_csr_req_wdata_i, phy_csr_req_wstrb_i);
	assign phy_csr_req_ready_o = !csr_rsp_valid_q;
	assign phy_csr_rsp_valid_o = csr_rsp_valid_q;
	assign phy_csr_rsp_rdata_o = csr_rsp_rdata_q;
	assign phy_csr_rsp_error_o = csr_rsp_error_q;
	assign error_fifo_pop = (error_fifo_count_q != 0) && phy_err_ready_i;
	assign error_fifo_has_space = (error_fifo_count_q < ERROR_FIFO_DEPTH) || error_fifo_pop;
	assign error_fifo_push = (service_commit && (service_event[39-:8] != 8'h00)) && error_fifo_has_space;
	assign phy_err_valid_o = error_fifo_count_q != 0;
	assign phy_err_code_o = (error_fifo_count_q != 0 ? error_fifo_code_q[error_fifo_rd_ptr_q] : 8'h00);
	assign phy_err_info_o = (error_fifo_count_q != 0 ? error_fifo_info_q[error_fifo_rd_ptr_q] : 32'd0);
	function automatic [2:0] pcie_gen12_phy_pkg_error_severity;
		input reg [7:0] code;
		(* full_case, parallel_case *)
		case (code)
			8'h01, 8'h02: pcie_gen12_phy_pkg_error_severity = 3'd1;
			8'h0e, 8'h13: pcie_gen12_phy_pkg_error_severity = 3'd2;
			8'h04, 8'h0f: pcie_gen12_phy_pkg_error_severity = 3'd3;
			8'h03, 8'h05, 8'h06, 8'h09, 8'h0a, 8'h0b, 8'h11: pcie_gen12_phy_pkg_error_severity = 3'd4;
			8'h07, 8'h08, 8'h0c, 8'h0d, 8'h10, 8'h12: pcie_gen12_phy_pkg_error_severity = 3'd5;
			default: pcie_gen12_phy_pkg_error_severity = 3'd0;
		endcase
	endfunction
	function automatic pcie_gen12_phy_pkg_error_is_fatal;
		input reg [7:0] code;
		pcie_gen12_phy_pkg_error_is_fatal = pcie_gen12_phy_pkg_error_severity(code) == 3'd5;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		for (incoming_index = 0; incoming_index < PENDING_SLOTS; incoming_index = incoming_index + 1)
			incoming[incoming_index] = 1'sb0;
		incoming[0][45] = status_gt_fatal_evt_valid_i;
		incoming[0][44] = 1'b1;
		incoming[0][43-:4] = 4'h6;
		incoming[0][39-:8] = (status_gt_fatal_evt_code_i == 8'h00 ? 8'h0c : status_gt_fatal_evt_code_i);
		incoming[0][31-:32] = status_gt_fatal_evt_info_i;
		incoming[1][45] = status_buffer_fatal_evt_valid_i;
		incoming[1][44] = 1'b1;
		incoming[1][43-:4] = 4'h7;
		incoming[1][39-:8] = (status_buffer_fatal_evt_code_i == 8'h00 ? 8'h08 : status_buffer_fatal_evt_code_i);
		incoming[1][31-:32] = status_buffer_fatal_evt_info_i;
		incoming[2][45] = status_alignment_evt_valid_i;
		incoming[2][44] = 1'b0;
		incoming[2][43-:4] = 4'h2;
		incoming[2][39-:8] = (status_alignment_evt_code_i == 8'h00 ? 8'h03 : status_alignment_evt_code_i);
		incoming[2][31-:32] = status_alignment_evt_info_i;
		incoming[3][45] = status_framing_evt_valid_i;
		incoming[3][44] = 1'b0;
		incoming[3][43-:4] = 4'h2;
		incoming[3][39-:8] = (status_framing_evt_code_i == 8'h00 ? 8'h0f : status_framing_evt_code_i);
		incoming[3][31-:32] = status_framing_evt_info_i;
		incoming[4][45] = status_correctable_evt_valid_i;
		incoming[4][44] = 1'b0;
		incoming[4][43-:4] = 4'h2;
		incoming[4][39-:8] = (status_correctable_evt_code_i == 8'h00 ? 8'h02 : status_correctable_evt_code_i);
		incoming[4][31-:32] = status_correctable_evt_info_i;
		incoming[5][45] = status_evt_valid_i && status_evt_ready_o;
		incoming[5][44] = status_evt_fatal_i || pcie_gen12_phy_pkg_error_is_fatal(status_evt_code_i);
		incoming[5][43-:4] = status_evt_source_i;
		incoming[5][39-:8] = status_evt_code_i;
		incoming[5][31-:32] = status_evt_info_i;
	end
	function automatic [2:0] pcie_gen12_phy_pkg_error_priority;
		input reg [7:0] code;
		(* full_case, parallel_case *)
		case (code)
			8'h0c, 8'h0d: pcie_gen12_phy_pkg_error_priority = 3'd0;
			8'h07, 8'h08, 8'h10, 8'h12: pcie_gen12_phy_pkg_error_priority = 3'd1;
			8'h03, 8'h11: pcie_gen12_phy_pkg_error_priority = 3'd2;
			8'h0e, 8'h0f, 8'h04, 8'h13: pcie_gen12_phy_pkg_error_priority = 3'd3;
			8'h02, 8'h01, 8'h05, 8'h06, 8'h09, 8'h0a, 8'h0b: pcie_gen12_phy_pkg_error_priority = 3'd4;
			default: pcie_gen12_phy_pkg_error_priority = 3'd7;
		endcase
	endfunction
	function automatic [7:0] sv2v_cast_8;
		input reg [7:0] inp;
		sv2v_cast_8 = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		service_valid = overflow_pending_q;
		service_is_overflow = overflow_pending_q;
		service_index = -1;
		service_priority = pcie_gen12_phy_pkg_error_priority(8'h12);
		service_event = 1'sb0;
		if (overflow_pending_q) begin
			service_event[45] = 1'b1;
			service_event[44] = 1'b1;
			service_event[43-:4] = 4'h7;
			service_event[39-:8] = 8'h12;
			service_event[31-:32] = {8'd0, status_state_i, status_substate_i, error_fifo_count_q, history_count_q, 4'd0};
		end
		for (service_scan_index = 0; service_scan_index < PENDING_SLOTS; service_scan_index = service_scan_index + 1)
			if (pending_q[service_scan_index][45] && (!service_valid || (pcie_gen12_phy_pkg_error_priority(sv2v_cast_8(pending_q[service_scan_index][39-:8])) < service_priority))) begin
				service_valid = 1'b1;
				service_is_overflow = 1'b0;
				service_index = service_scan_index;
				service_priority = pcie_gen12_phy_pkg_error_priority(sv2v_cast_8(pending_q[service_scan_index][39-:8]));
				service_event = pending_q[service_scan_index];
			end
		service_commit = service_valid && (!service_is_overflow || error_fifo_has_space);
	end
	assign status_evt_ready_o = !pending_q[5][45] || (service_commit && (service_index == 5));
	always @(*) begin
		if (_sv2v_0)
			;
		incoming_best = 1'sb0;
		incoming_best_valid = 1'b0;
		incoming_best_priority = 3'd7;
		incoming_any_fatal = 1'b0;
		for (best_scan_index = 0; best_scan_index < PENDING_SLOTS; best_scan_index = best_scan_index + 1)
			if (incoming[best_scan_index][45]) begin
				incoming_any_fatal = (incoming_any_fatal || incoming[best_scan_index][44]) || pcie_gen12_phy_pkg_error_is_fatal(sv2v_cast_8(incoming[best_scan_index][39-:8]));
				if (!incoming_best_valid || (pcie_gen12_phy_pkg_error_priority(sv2v_cast_8(incoming[best_scan_index][39-:8])) < incoming_best_priority)) begin
					incoming_best = incoming[best_scan_index];
					incoming_best_valid = 1'b1;
					incoming_best_priority = pcie_gen12_phy_pkg_error_priority(sv2v_cast_8(incoming[best_scan_index][39-:8]));
				end
			end
	end
	integer reset_index;
	integer selected_code_index;
	integer csr_array_index;
	reg slot_replaced;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_COUNTER_BASE = 12'h020;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_ERROR_STICKY = 12'h018;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_EVENT_STATUS = 12'h01c;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_FIRST_ERROR_CODE = 12'h010;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_FIRST_ERROR_INFO = 12'h014;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_HISTORY_BASE = 12'h080;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_ID_VERSION = 12'h000;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_LTSSM = 12'h008;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_OBSERVATION_CLEAR = 12'h0c0;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_STATE_REASON = 12'h00c;
	localparam [11:0] pcie_gen12_phy_pkg_CSR_STATUS = 12'h004;
	always @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani)
		if (!ctrl_local_reset_ani) begin
			phy_ready_o <= 1'b0;
			phy_link_up_o <= 1'b0;
			phy_data_active_o <= 1'b0;
			phy_current_rate_o <= 1'b0;
			phy_ltssm_state_o <= 6'h00;
			phy_ltssm_substate_o <= 6'h00;
			phy_state_reason_o <= 8'h00;
			phy_rx_locked_o <= 1'b0;
			sticky_bitmap_q <= 1'sb0;
			first_error_valid_q <= 1'b0;
			first_error_fatal_q <= 1'b0;
			first_error_source_q <= 1'sb0;
			first_error_code_q <= 8'h00;
			first_error_info_q <= 1'sb0;
			first_error_state_q <= 6'h00;
			first_error_substate_q <= 6'h00;
			first_error_rate_q <= 1'b0;
			safety_fatal_q <= 1'b0;
			overflow_pending_q <= 1'b0;
			history_wr_ptr_q <= 1'sb0;
			history_count_q <= 1'sb0;
			error_fifo_wr_ptr_q <= 1'sb0;
			error_fifo_rd_ptr_q <= 1'sb0;
			error_fifo_count_q <= 1'sb0;
			csr_rsp_valid_q <= 1'b0;
			csr_rsp_rdata_q <= 1'sb0;
			csr_rsp_error_q <= 1'b0;
			for (reset_index = 0; reset_index < PENDING_SLOTS; reset_index = reset_index + 1)
				pending_q[reset_index] <= 1'sb0;
			for (reset_index = 0; reset_index < ERROR_CODE_COUNT; reset_index = reset_index + 1)
				error_counter_q[reset_index] <= 1'sb0;
			for (reset_index = 0; reset_index < HISTORY_DEPTH; reset_index = reset_index + 1)
				begin
					history_meta_q[reset_index] <= 1'sb0;
					history_info_q[reset_index] <= 1'sb0;
				end
			for (reset_index = 0; reset_index < ERROR_FIFO_DEPTH; reset_index = reset_index + 1)
				begin
					error_fifo_code_q[reset_index] <= 8'h00;
					error_fifo_info_q[reset_index] <= 1'sb0;
				end
		end
		else begin
			phy_ready_o <= (status_ready_i && !safety_fatal_q) && !incoming_any_fatal;
			phy_link_up_o <= (status_link_up_i && !safety_fatal_q) && !incoming_any_fatal;
			phy_data_active_o <= (((status_data_active_i && status_ready_i) && status_rx_lock_i) && !safety_fatal_q) && !incoming_any_fatal;
			phy_current_rate_o <= status_rate_i;
			phy_ltssm_state_o <= status_state_i;
			phy_ltssm_substate_o <= status_substate_i;
			phy_state_reason_o <= status_reason_i;
			phy_rx_locked_o <= ((status_rx_lock_i && status_ready_i) && !safety_fatal_q) && !incoming_any_fatal;
			if (((safety_fatal_q && (status_state_i == 6'h00)) && status_ready_i) && !status_data_active_i)
				safety_fatal_q <= 1'b0;
			if (incoming_any_fatal || (service_commit && service_event[44]))
				safety_fatal_q <= 1'b1;
			if (csr_rsp_valid_q && phy_csr_rsp_ready_i)
				csr_rsp_valid_q <= 1'b0;
			csr_rsp_error_q <= 1'b0;
			for (reset_index = 0; reset_index < PENDING_SLOTS; reset_index = reset_index + 1)
				begin
					slot_replaced = incoming[reset_index][45];
					if (((service_commit && !service_is_overflow) && (service_index == reset_index)) && !slot_replaced)
						pending_q[reset_index][45] <= 1'b0;
					if (incoming[reset_index][45]) begin
						if (!pending_q[reset_index][45] || ((service_commit && !service_is_overflow) && (service_index == reset_index)))
							pending_q[reset_index] <= incoming[reset_index];
						else
							overflow_pending_q <= 1'b1;
					end
				end
			if (service_commit && service_is_overflow)
				overflow_pending_q <= 1'b0;
			if (((service_commit && !service_is_overflow) && (service_event[39-:8] != 8'h00)) && !error_fifo_has_space)
				overflow_pending_q <= 1'b1;
			if (service_commit) begin
				history_meta_q[history_wr_ptr_q] <= {6'd0, service_event[43-:4], service_event[44], status_rate_i, status_state_i, status_substate_i, service_event[39-:8]};
				history_info_q[history_wr_ptr_q] <= service_event[31-:32];
				history_wr_ptr_q <= history_wr_ptr_q + 1'b1;
				if (history_count_q < HISTORY_DEPTH)
					history_count_q <= history_count_q + 1'b1;
				selected_code_index = code_index(service_event[39-:8]);
				if (selected_code_index >= 0) begin
					sticky_bitmap_q[selected_code_index] <= 1'b1;
					if (error_counter_q[selected_code_index] != 32'hffffffff)
						error_counter_q[selected_code_index] <= error_counter_q[selected_code_index] + 1'b1;
				end
			end
			if (!first_error_valid_q) begin
				if (service_commit && (service_event[39-:8] != 8'h00)) begin
					first_error_valid_q <= 1'b1;
					first_error_fatal_q <= service_event[44];
					first_error_source_q <= service_event[43-:4];
					first_error_code_q <= service_event[39-:8];
					first_error_info_q <= service_event[31-:32];
					first_error_state_q <= status_state_i;
					first_error_substate_q <= status_substate_i;
					first_error_rate_q <= status_rate_i;
				end
				else if (incoming_best_valid && (incoming_best[39-:8] != 8'h00)) begin
					first_error_valid_q <= 1'b1;
					first_error_fatal_q <= incoming_best[44];
					first_error_source_q <= incoming_best[43-:4];
					first_error_code_q <= incoming_best[39-:8];
					first_error_info_q <= incoming_best[31-:32];
					first_error_state_q <= status_state_i;
					first_error_substate_q <= status_substate_i;
					first_error_rate_q <= status_rate_i;
				end
			end
			if (error_fifo_push) begin
				error_fifo_code_q[error_fifo_wr_ptr_q] <= service_event[39-:8];
				error_fifo_info_q[error_fifo_wr_ptr_q] <= service_event[31-:32];
				error_fifo_wr_ptr_q <= error_fifo_wr_ptr_q + 1'b1;
			end
			if (error_fifo_pop)
				error_fifo_rd_ptr_q <= error_fifo_rd_ptr_q + 1'b1;
			(* full_case, parallel_case *)
			case ({error_fifo_push, error_fifo_pop})
				2'b10: error_fifo_count_q <= error_fifo_count_q + 1'b1;
				2'b01: error_fifo_count_q <= error_fifo_count_q - 1'b1;
				default:
					;
			endcase
			if (status_clear_i) begin
				sticky_bitmap_q <= 1'sb0;
				first_error_valid_q <= 1'b0;
				first_error_fatal_q <= 1'b0;
				first_error_source_q <= 1'sb0;
				first_error_code_q <= 8'h00;
				first_error_info_q <= 1'sb0;
				history_wr_ptr_q <= 1'sb0;
				history_count_q <= 1'sb0;
				error_fifo_wr_ptr_q <= 1'sb0;
				error_fifo_rd_ptr_q <= 1'sb0;
				error_fifo_count_q <= 1'sb0;
				overflow_pending_q <= 1'b0;
				for (reset_index = 0; reset_index < PENDING_SLOTS; reset_index = reset_index + 1)
					pending_q[reset_index] <= 1'sb0;
				for (reset_index = 0; reset_index < ERROR_CODE_COUNT; reset_index = reset_index + 1)
					error_counter_q[reset_index] <= 1'sb0;
			end
			if (status_debug_counter_seed_valid_i && (status_debug_counter_seed_index_i < ERROR_CODE_COUNT))
				error_counter_q[status_debug_counter_seed_index_i] <= status_debug_counter_seed_value_i;
			if (phy_csr_req_valid_i && phy_csr_req_ready_o) begin
				csr_rsp_valid_q <= 1'b1;
				csr_rsp_rdata_q <= 1'sb0;
				csr_rsp_error_q <= 1'b0;
				if (phy_csr_req_write_i)
					(* full_case, parallel_case *)
					case (phy_csr_req_addr_i)
						pcie_gen12_phy_pkg_CSR_ERROR_STICKY: sticky_bitmap_q <= sticky_bitmap_q & ~csr_write_mask[18:0];
						pcie_gen12_phy_pkg_CSR_OBSERVATION_CLEAR: begin
							if (csr_write_mask[0]) begin
								first_error_valid_q <= 1'b0;
								first_error_fatal_q <= 1'b0;
								first_error_source_q <= 1'sb0;
								first_error_code_q <= 8'h00;
								first_error_info_q <= 1'sb0;
							end
							if (csr_write_mask[1])
								sticky_bitmap_q <= 1'sb0;
							if (csr_write_mask[2])
								for (reset_index = 0; reset_index < ERROR_CODE_COUNT; reset_index = reset_index + 1)
									error_counter_q[reset_index] <= 1'sb0;
							if (csr_write_mask[3]) begin
								history_wr_ptr_q <= 1'sb0;
								history_count_q <= 1'sb0;
							end
							if (csr_write_mask[4]) begin
								error_fifo_wr_ptr_q <= 1'sb0;
								error_fifo_rd_ptr_q <= 1'sb0;
								error_fifo_count_q <= 1'sb0;
							end
						end
						default: csr_rsp_error_q <= 1'b1;
					endcase
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_ID_VERSION)
					csr_rsp_rdata_q <= 32'h01000001;
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_STATUS)
					csr_rsp_rdata_q <= {status_buffer_level_i, status_retry_count_i, 3'b000, phy_rx_locked_o, phy_data_active_o, phy_link_up_o, phy_current_rate_o, phy_ready_o};
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_LTSSM)
					csr_rsp_rdata_q <= {8'd0, status_state_i, status_substate_i, status_timer_id_i, 6'd0};
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_STATE_REASON)
					csr_rsp_rdata_q <= {status_reason_i, status_timer_value_i[23:0]};
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_FIRST_ERROR_CODE)
					csr_rsp_rdata_q <= {5'd0, first_error_valid_q, first_error_fatal_q, first_error_source_q, first_error_rate_q, first_error_code_q, first_error_state_q, first_error_substate_q};
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_FIRST_ERROR_INFO)
					csr_rsp_rdata_q <= first_error_info_q;
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_ERROR_STICKY)
					csr_rsp_rdata_q <= {{13 {1'b0}}, sticky_bitmap_q};
				else if (phy_csr_req_addr_i == pcie_gen12_phy_pkg_CSR_EVENT_STATUS)
					csr_rsp_rdata_q <= {10'd0, overflow_pending_q, 3'd0, history_count_q, 4'd0, error_fifo_count_q, history_wr_ptr_q, error_fifo_wr_ptr_q};
				else if (((phy_csr_req_addr_i >= pcie_gen12_phy_pkg_CSR_COUNTER_BASE) && (phy_csr_req_addr_i < 108)) && (phy_csr_req_addr_i[1:0] == 2'b00)) begin
					csr_array_index = (phy_csr_req_addr_i - pcie_gen12_phy_pkg_CSR_COUNTER_BASE) >> 2;
					csr_rsp_rdata_q <= error_counter_q[csr_array_index];
				end
				else if (((phy_csr_req_addr_i >= pcie_gen12_phy_pkg_CSR_HISTORY_BASE) && (phy_csr_req_addr_i < 192)) && (phy_csr_req_addr_i[1:0] == 2'b00)) begin
					csr_array_index = (phy_csr_req_addr_i - pcie_gen12_phy_pkg_CSR_HISTORY_BASE) >> 3;
					if (phy_csr_req_addr_i[2])
						csr_rsp_rdata_q <= history_info_q[csr_array_index];
					else
						csr_rsp_rdata_q <= history_meta_q[csr_array_index];
				end
				else begin
					csr_rsp_rdata_q <= 32'd0;
					csr_rsp_error_q <= 1'b1;
				end
			end
		end
	always @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani)
		if (!ctrl_local_reset_ani) begin
			snapshot_payload_q <= 1'sb0;
			snapshot_last_sent_q <= 1'sb0;
			snapshot_req_toggle_q <= 1'b0;
			snapshot_pending_q <= 1'b0;
			snapshot_ack_ctrl_sync_q <= 1'sb0;
		end
		else begin
			snapshot_ack_ctrl_sync_q <= {snapshot_ack_ctrl_sync_q[0], snapshot_ack_link_q};
			if (snapshot_ack_ctrl_sync_q[1] == snapshot_req_toggle_q) begin
				if (snapshot_pending_q || ({phy_link_up_o, phy_data_active_o, phy_current_rate_o} != snapshot_last_sent_q)) begin
					snapshot_payload_q <= {phy_link_up_o, phy_data_active_o, phy_current_rate_o};
					snapshot_last_sent_q <= {phy_link_up_o, phy_data_active_o, phy_current_rate_o};
					snapshot_req_toggle_q <= ~snapshot_req_toggle_q;
					snapshot_pending_q <= 1'b0;
				end
			end
			else if ({phy_link_up_o, phy_data_active_o, phy_current_rate_o} != snapshot_last_sent_q)
				snapshot_pending_q <= 1'b1;
		end
	always @(posedge link_clk_i or negedge link_local_reset_ani)
		if (!link_local_reset_ani) begin
			snapshot_req_link_sync_q <= 1'sb0;
			snapshot_ack_link_q <= 1'b0;
			phy_dll_link_up_o <= 1'b0;
			phy_dll_data_active_o <= 1'b0;
			phy_dll_current_rate_o <= 1'b0;
			phy_dll_link_down_evt_o <= 1'b0;
		end
		else begin
			snapshot_req_link_sync_q <= {snapshot_req_link_sync_q[0], snapshot_req_toggle_q};
			phy_dll_link_down_evt_o <= 1'b0;
			if (snapshot_req_link_sync_q[1] != snapshot_ack_link_q) begin
				phy_dll_link_down_evt_o <= phy_dll_link_up_o && !snapshot_payload_q[2];
				phy_dll_link_up_o <= snapshot_payload_q[2];
				phy_dll_data_active_o <= snapshot_payload_q[1];
				phy_dll_current_rate_o <= snapshot_payload_q[0];
				snapshot_ack_link_q <= snapshot_req_link_sync_q[1];
			end
		end
	initial _sv2v_0 = 0;
endmodule
