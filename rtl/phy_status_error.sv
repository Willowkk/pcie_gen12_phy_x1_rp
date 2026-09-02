module phy_status_error (
  input  logic        ctrl_clk_i,
  input  logic        ctrl_rst_ni,
  input  logic        port_reset_ni,
  input  logic        link_clk_i,
  input  logic        link_rst_ni,
  input  logic        status_ready_i,
  input  logic [5:0]  status_state_i,
  input  logic [5:0]  status_substate_i,
  input  logic [7:0]  status_reason_i,
  input  logic        status_rate_i,
  input  logic        status_link_up_i,
  input  logic        status_data_active_i,
  input  logic        status_rx_lock_i,
  input  logic [15:0] status_buffer_level_i,
  input  logic [5:0]  status_timer_id_i,
  input  logic [31:0] status_timer_value_i,
  input  logic [7:0]  status_retry_count_i,
  input  logic        status_clear_i,
  input  logic        status_debug_counter_seed_valid_i,
  input  logic [4:0]  status_debug_counter_seed_index_i,
  input  logic [31:0] status_debug_counter_seed_value_i,

  // General ready/valid event input retained from the frozen interface.
  input  logic        status_evt_valid_i,
  input  logic [3:0]  status_evt_source_i,
  input  logic [7:0]  status_evt_code_i,
  input  logic [31:0] status_evt_info_i,
  input  logic        status_evt_fatal_i,
  output logic        status_evt_ready_o,

  // Dedicated category inputs preserve all same-cycle errors until the
  // section 8.2 priority arbiter has selected the first error.
  input  logic        status_gt_fatal_evt_valid_i,
  input  logic [7:0]  status_gt_fatal_evt_code_i,
  input  logic [31:0] status_gt_fatal_evt_info_i,
  input  logic        status_buffer_fatal_evt_valid_i,
  input  logic [7:0]  status_buffer_fatal_evt_code_i,
  input  logic [31:0] status_buffer_fatal_evt_info_i,
  input  logic        status_alignment_evt_valid_i,
  input  logic [7:0]  status_alignment_evt_code_i,
  input  logic [31:0] status_alignment_evt_info_i,
  input  logic        status_framing_evt_valid_i,
  input  logic [7:0]  status_framing_evt_code_i,
  input  logic [31:0] status_framing_evt_info_i,
  input  logic        status_correctable_evt_valid_i,
  input  logic [7:0]  status_correctable_evt_code_i,
  input  logic [31:0] status_correctable_evt_info_i,

  output logic        phy_ready_o,
  output logic        phy_link_up_o,
  output logic        phy_data_active_o,
  output logic        phy_current_rate_o,
  output logic [5:0]  phy_ltssm_state_o,
  output logic [5:0]  phy_ltssm_substate_o,
  output logic [7:0]  phy_state_reason_o,
  output logic        phy_rx_locked_o,
  output logic        phy_dll_link_up_o,
  output logic        phy_dll_data_active_o,
  output logic        phy_dll_current_rate_o,
  output logic        phy_dll_link_down_evt_o,
  output logic        phy_err_valid_o,
  input  logic        phy_err_ready_i,
  output logic [7:0]  phy_err_code_o,
  output logic [31:0] phy_err_info_o,
  input  logic        phy_csr_req_valid_i,
  output logic        phy_csr_req_ready_o,
  input  logic        phy_csr_req_write_i,
  input  logic [11:0] phy_csr_req_addr_i,
  input  logic [31:0] phy_csr_req_wdata_i,
  input  logic [3:0]  phy_csr_req_wstrb_i,
  output logic        phy_csr_rsp_valid_o,
  input  logic        phy_csr_rsp_ready_i,
  output logic [31:0] phy_csr_rsp_rdata_o,
  output logic        phy_csr_rsp_error_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  localparam int unsigned ERROR_CODE_COUNT = 19;
  localparam int unsigned PENDING_SLOTS    = 6;
  localparam int unsigned ERROR_FIFO_DEPTH = 8;
  localparam int unsigned HISTORY_DEPTH    = 8;
  localparam int unsigned ERROR_FIFO_PTR_W = 3;
  localparam int unsigned ERROR_FIFO_CNT_W = 4;
  localparam int unsigned HISTORY_PTR_W    = 3;
  localparam int unsigned HISTORY_CNT_W    = 4;

  typedef struct packed {
    logic       valid;
    logic       fatal;
    logic [3:0] source;
    logic [7:0] code;
    logic [31:0] info;
  } status_event_t;

  wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;
  wire link_local_reset_ani = link_rst_ni & port_reset_ni;

  status_event_t pending_q [0:PENDING_SLOTS-1];
  status_event_t incoming [0:PENDING_SLOTS-1];
  status_event_t service_event;
  status_event_t incoming_best;
  logic service_valid;
  logic service_commit;
  logic service_is_overflow;
  logic incoming_best_valid;
  logic incoming_any_fatal;
  logic [2:0] service_priority;
  logic [2:0] incoming_best_priority;
  integer service_index;
  integer incoming_index;
  integer service_scan_index;
  integer best_scan_index;

  logic [ERROR_CODE_COUNT-1:0] sticky_bitmap_q;
  logic [31:0] error_counter_q [0:ERROR_CODE_COUNT-1];
  logic first_error_valid_q;
  logic first_error_fatal_q;
  logic [3:0] first_error_source_q;
  logic [7:0] first_error_code_q;
  logic [31:0] first_error_info_q;
  logic [5:0] first_error_state_q;
  logic [5:0] first_error_substate_q;
  logic first_error_rate_q;
  logic safety_fatal_q;
  logic overflow_pending_q;

  logic [31:0] history_meta_q [0:HISTORY_DEPTH-1];
  logic [31:0] history_info_q [0:HISTORY_DEPTH-1];
  logic [HISTORY_PTR_W-1:0] history_wr_ptr_q;
  logic [HISTORY_CNT_W-1:0] history_count_q;

  logic [7:0] error_fifo_code_q [0:ERROR_FIFO_DEPTH-1];
  logic [31:0] error_fifo_info_q [0:ERROR_FIFO_DEPTH-1];
  logic [ERROR_FIFO_PTR_W-1:0] error_fifo_wr_ptr_q;
  logic [ERROR_FIFO_PTR_W-1:0] error_fifo_rd_ptr_q;
  logic [ERROR_FIFO_CNT_W-1:0] error_fifo_count_q;
  logic error_fifo_pop;
  logic error_fifo_push;
  logic error_fifo_has_space;

  logic csr_rsp_valid_q;
  logic [31:0] csr_rsp_rdata_q;
  logic csr_rsp_error_q;
  logic [31:0] csr_write_mask;

  // ctrl_clk -> link_clk coherent status snapshot.  The three status bits are
  // held stable from request-toggle until acknowledgement-toggle returns.
  logic [2:0] snapshot_payload_q;
  logic [2:0] snapshot_last_sent_q;
  logic snapshot_req_toggle_q;
  logic snapshot_pending_q;
  logic [1:0] snapshot_ack_ctrl_sync_q;
  logic [1:0] snapshot_req_link_sync_q;
  logic snapshot_ack_link_q;

  function automatic integer code_index(input logic [7:0] code);
    if ((code >= ERR_RX_DISPARITY) && (code <= ERR_RATE_NOT_QUIESCED))
      return integer'(code) - 1;
    return -1;
  endfunction

  function automatic logic [31:0] apply_write_strobes(
    input logic [31:0] data,
    input logic [3:0] strobes
  );
    logic [31:0] mask;
    integer byte_index;
    begin
      mask = '0;
      for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
        if (strobes[byte_index]) mask[byte_index*8 +: 8] = data[byte_index*8 +: 8];
      return mask;
    end
  endfunction

  assign csr_write_mask = apply_write_strobes(phy_csr_req_wdata_i, phy_csr_req_wstrb_i);
  assign phy_csr_req_ready_o = !csr_rsp_valid_q;
  assign phy_csr_rsp_valid_o = csr_rsp_valid_q;
  assign phy_csr_rsp_rdata_o = csr_rsp_rdata_q;
  assign phy_csr_rsp_error_o = csr_rsp_error_q;

  assign error_fifo_pop       = (error_fifo_count_q != 0) && phy_err_ready_i;
  assign error_fifo_has_space = (error_fifo_count_q < ERROR_FIFO_DEPTH) || error_fifo_pop;
  assign error_fifo_push      = service_commit && (service_event.code != ERR_NONE) &&
                                error_fifo_has_space;
  assign phy_err_valid_o      = (error_fifo_count_q != 0);
  assign phy_err_code_o       = (error_fifo_count_q != 0) ?
                                error_fifo_code_q[error_fifo_rd_ptr_q] : ERR_NONE;
  assign phy_err_info_o       = (error_fifo_count_q != 0) ?
                                error_fifo_info_q[error_fifo_rd_ptr_q] : 32'd0;

  always_comb begin
    for (incoming_index = 0; incoming_index < PENDING_SLOTS; incoming_index = incoming_index + 1)
      incoming[incoming_index] = '0;

    incoming[0].valid  = status_gt_fatal_evt_valid_i;
    incoming[0].fatal  = 1'b1;
    incoming[0].source = EVT_SRC_GTY;
    incoming[0].code   = (status_gt_fatal_evt_code_i == ERR_NONE) ?
                         ERR_GT_PLL_UNLOCK : status_gt_fatal_evt_code_i;
    incoming[0].info   = status_gt_fatal_evt_info_i;

    incoming[1].valid  = status_buffer_fatal_evt_valid_i;
    incoming[1].fatal  = 1'b1;
    incoming[1].source = EVT_SRC_CDC;
    incoming[1].code   = (status_buffer_fatal_evt_code_i == ERR_NONE) ?
                         ERR_RXBUF_OVERFLOW : status_buffer_fatal_evt_code_i;
    incoming[1].info   = status_buffer_fatal_evt_info_i;

    incoming[2].valid  = status_alignment_evt_valid_i;
    incoming[2].fatal  = 1'b0;
    incoming[2].source = EVT_SRC_RX;
    incoming[2].code   = (status_alignment_evt_code_i == ERR_NONE) ?
                         ERR_RX_ALIGN_LOSS : status_alignment_evt_code_i;
    incoming[2].info   = status_alignment_evt_info_i;

    incoming[3].valid  = status_framing_evt_valid_i;
    incoming[3].fatal  = 1'b0;
    incoming[3].source = EVT_SRC_RX;
    incoming[3].code   = (status_framing_evt_code_i == ERR_NONE) ?
                         ERR_RX_FRAMING : status_framing_evt_code_i;
    incoming[3].info   = status_framing_evt_info_i;

    incoming[4].valid  = status_correctable_evt_valid_i;
    incoming[4].fatal  = 1'b0;
    incoming[4].source = EVT_SRC_RX;
    incoming[4].code   = (status_correctable_evt_code_i == ERR_NONE) ?
                         ERR_RX_CODE : status_correctable_evt_code_i;
    incoming[4].info   = status_correctable_evt_info_i;

    incoming[5].valid  = status_evt_valid_i && status_evt_ready_o;
    incoming[5].fatal  = status_evt_fatal_i ||
                         error_is_fatal(pcie_phy_error_code_t'(status_evt_code_i));
    incoming[5].source = status_evt_source_i;
    incoming[5].code   = status_evt_code_i;
    incoming[5].info   = status_evt_info_i;
  end

  // Old pending events are serviced one per cycle.  Priority is determined by
  // the package's unique section 8.2 mapping; equal priorities retain slot
  // order.  The dedicated overflow event participates as a buffer-fatal error.
  always_comb begin
    service_valid       = overflow_pending_q;
    service_is_overflow = overflow_pending_q;
    service_index       = -1;
    service_priority    = error_priority(ERR_CDC_EVENT_OVERFLOW);
    service_event       = '0;
    if (overflow_pending_q) begin
      service_event.valid  = 1'b1;
      service_event.fatal  = 1'b1;
      service_event.source = EVT_SRC_CDC;
      service_event.code   = ERR_CDC_EVENT_OVERFLOW;
      service_event.info   = {8'd0, status_state_i, status_substate_i,
                              error_fifo_count_q, history_count_q, 4'd0};
    end
    for (service_scan_index = 0; service_scan_index < PENDING_SLOTS;
         service_scan_index = service_scan_index + 1) begin
      if (pending_q[service_scan_index].valid &&
          (!service_valid ||
           (error_priority(pcie_phy_error_code_t'(pending_q[service_scan_index].code)) <
            service_priority))) begin
        service_valid       = 1'b1;
        service_is_overflow = 1'b0;
        service_index       = service_scan_index;
        service_priority    = error_priority(pcie_phy_error_code_t'(pending_q[service_scan_index].code));
        service_event       = pending_q[service_scan_index];
      end
    end
    service_commit = service_valid && (!service_is_overflow || error_fifo_has_space);
  end

  assign status_evt_ready_o = !pending_q[5].valid ||
                              (service_commit && (service_index == 5));

  // Select the highest-priority event accepted in this cycle for first-error
  // capture when no older pending event exists.
  always_comb begin
    incoming_best          = '0;
    incoming_best_valid    = 1'b0;
    incoming_best_priority = 3'd7;
    incoming_any_fatal     = 1'b0;
    for (best_scan_index = 0; best_scan_index < PENDING_SLOTS;
         best_scan_index = best_scan_index + 1) begin
      if (incoming[best_scan_index].valid) begin
        incoming_any_fatal = incoming_any_fatal || incoming[best_scan_index].fatal ||
                             error_is_fatal(pcie_phy_error_code_t'(incoming[best_scan_index].code));
        if (!incoming_best_valid ||
            (error_priority(pcie_phy_error_code_t'(incoming[best_scan_index].code)) <
             incoming_best_priority)) begin
          incoming_best          = incoming[best_scan_index];
          incoming_best_valid    = 1'b1;
          incoming_best_priority = error_priority(pcie_phy_error_code_t'(incoming[best_scan_index].code));
        end
      end
    end
  end

  integer reset_index;
  integer selected_code_index;
  integer csr_array_index;
  logic slot_replaced;

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani) begin
    if (!ctrl_local_reset_ani) begin
      phy_ready_o              <= 1'b0;
      phy_link_up_o            <= 1'b0;
      phy_data_active_o        <= 1'b0;
      phy_current_rate_o       <= 1'b0;
      phy_ltssm_state_o        <= LTSSM_RESET;
      phy_ltssm_substate_o     <= LTSSM_SS_RESET_WAIT_READY;
      phy_state_reason_o       <= REASON_RESET_ASSERTED;
      phy_rx_locked_o          <= 1'b0;
      sticky_bitmap_q          <= '0;
      first_error_valid_q      <= 1'b0;
      first_error_fatal_q      <= 1'b0;
      first_error_source_q     <= '0;
      first_error_code_q       <= ERR_NONE;
      first_error_info_q       <= '0;
      first_error_state_q      <= LTSSM_RESET;
      first_error_substate_q   <= LTSSM_SS_RESET_WAIT_READY;
      first_error_rate_q       <= 1'b0;
      safety_fatal_q           <= 1'b0;
      overflow_pending_q       <= 1'b0;
      history_wr_ptr_q         <= '0;
      history_count_q          <= '0;
      error_fifo_wr_ptr_q      <= '0;
      error_fifo_rd_ptr_q      <= '0;
      error_fifo_count_q       <= '0;
      csr_rsp_valid_q          <= 1'b0;
      csr_rsp_rdata_q          <= '0;
      csr_rsp_error_q          <= 1'b0;
      for (reset_index = 0; reset_index < PENDING_SLOTS; reset_index = reset_index + 1)
        pending_q[reset_index] <= '0;
      for (reset_index = 0; reset_index < ERROR_CODE_COUNT; reset_index = reset_index + 1)
        error_counter_q[reset_index] <= '0;
      for (reset_index = 0; reset_index < HISTORY_DEPTH; reset_index = reset_index + 1) begin
        history_meta_q[reset_index] <= '0;
        history_info_q[reset_index] <= '0;
      end
      for (reset_index = 0; reset_index < ERROR_FIFO_DEPTH; reset_index = reset_index + 1) begin
        error_fifo_code_q[reset_index] <= ERR_NONE;
        error_fifo_info_q[reset_index] <= '0;
      end
    end else begin
      phy_ready_o            <= status_ready_i && !safety_fatal_q && !incoming_any_fatal;
      phy_link_up_o          <= status_link_up_i && !safety_fatal_q && !incoming_any_fatal;
      phy_data_active_o      <= status_data_active_i && status_ready_i &&
                                status_rx_lock_i && !safety_fatal_q && !incoming_any_fatal;
      phy_current_rate_o     <= status_rate_i;
      phy_ltssm_state_o      <= status_state_i;
      phy_ltssm_substate_o   <= status_substate_i;
      phy_state_reason_o     <= status_reason_i;
      phy_rx_locked_o        <= status_rx_lock_i && status_ready_i &&
                                !safety_fatal_q && !incoming_any_fatal;

      if (safety_fatal_q && (status_state_i == LTSSM_RESET) &&
          status_ready_i && !status_data_active_i)
        safety_fatal_q <= 1'b0;
      if (incoming_any_fatal || (service_commit && service_event.fatal))
        safety_fatal_q <= 1'b1;

      if (csr_rsp_valid_q && phy_csr_rsp_ready_i) csr_rsp_valid_q <= 1'b0;
      csr_rsp_error_q <= 1'b0;

      // Consume one old slot, then permit a same-cycle arrival to refill it.
      for (reset_index = 0; reset_index < PENDING_SLOTS; reset_index = reset_index + 1) begin
        slot_replaced = incoming[reset_index].valid;
        if (service_commit && !service_is_overflow && (service_index == reset_index) &&
            !slot_replaced)
          pending_q[reset_index].valid <= 1'b0;
        if (incoming[reset_index].valid) begin
          if (!pending_q[reset_index].valid ||
              (service_commit && !service_is_overflow && (service_index == reset_index))) begin
            pending_q[reset_index] <= incoming[reset_index];
          end else begin
            overflow_pending_q <= 1'b1;
          end
        end
      end

      if (service_commit && service_is_overflow) overflow_pending_q <= 1'b0;
      if (service_commit && !service_is_overflow &&
          (service_event.code != ERR_NONE) && !error_fifo_has_space)
        overflow_pending_q <= 1'b1;

      if (service_commit) begin
        history_meta_q[history_wr_ptr_q] <= {
          6'd0, service_event.source, service_event.fatal,
          status_rate_i, status_state_i, status_substate_i, service_event.code
        };
        history_info_q[history_wr_ptr_q] <= service_event.info;
        history_wr_ptr_q <= history_wr_ptr_q + 1'b1;
        if (history_count_q < HISTORY_DEPTH) history_count_q <= history_count_q + 1'b1;

        selected_code_index = code_index(service_event.code);
        if (selected_code_index >= 0) begin
          sticky_bitmap_q[selected_code_index] <= 1'b1;
          if (error_counter_q[selected_code_index] != 32'hffff_ffff)
            error_counter_q[selected_code_index] <= error_counter_q[selected_code_index] + 1'b1;
        end
      end

      // Old events win chronologically; events captured in the same cycle are
      // then ordered by the frozen error-priority function.
      if (!first_error_valid_q) begin
        if (service_commit && (service_event.code != ERR_NONE)) begin
          first_error_valid_q    <= 1'b1;
          first_error_fatal_q    <= service_event.fatal;
          first_error_source_q   <= service_event.source;
          first_error_code_q     <= service_event.code;
          first_error_info_q     <= service_event.info;
          first_error_state_q    <= status_state_i;
          first_error_substate_q <= status_substate_i;
          first_error_rate_q     <= status_rate_i;
        end else if (incoming_best_valid && (incoming_best.code != ERR_NONE)) begin
          first_error_valid_q    <= 1'b1;
          first_error_fatal_q    <= incoming_best.fatal;
          first_error_source_q   <= incoming_best.source;
          first_error_code_q     <= incoming_best.code;
          first_error_info_q     <= incoming_best.info;
          first_error_state_q    <= status_state_i;
          first_error_substate_q <= status_substate_i;
          first_error_rate_q     <= status_rate_i;
        end
      end

      if (error_fifo_push) begin
        error_fifo_code_q[error_fifo_wr_ptr_q] <= service_event.code;
        error_fifo_info_q[error_fifo_wr_ptr_q] <= service_event.info;
        error_fifo_wr_ptr_q <= error_fifo_wr_ptr_q + 1'b1;
      end
      if (error_fifo_pop) error_fifo_rd_ptr_q <= error_fifo_rd_ptr_q + 1'b1;
      unique case ({error_fifo_push, error_fifo_pop})
        2'b10: error_fifo_count_q <= error_fifo_count_q + 1'b1;
        2'b01: error_fifo_count_q <= error_fifo_count_q - 1'b1;
        default: ;
      endcase

      // Management clear is observation-only.  It never changes state, GT
      // control, packet admission, or the non-observational safety latch.
      if (status_clear_i) begin
        sticky_bitmap_q        <= '0;
        first_error_valid_q    <= 1'b0;
        first_error_fatal_q    <= 1'b0;
        first_error_source_q   <= '0;
        first_error_code_q     <= ERR_NONE;
        first_error_info_q     <= '0;
        history_wr_ptr_q       <= '0;
        history_count_q        <= '0;
        error_fifo_wr_ptr_q    <= '0;
        error_fifo_rd_ptr_q    <= '0;
        error_fifo_count_q     <= '0;
        overflow_pending_q     <= 1'b0;
        for (reset_index = 0; reset_index < PENDING_SLOTS; reset_index = reset_index + 1)
          pending_q[reset_index] <= '0;
        for (reset_index = 0; reset_index < ERROR_CODE_COUNT; reset_index = reset_index + 1)
          error_counter_q[reset_index] <= '0;
      end

      if (status_debug_counter_seed_valid_i &&
          (status_debug_counter_seed_index_i < ERROR_CODE_COUNT))
        error_counter_q[status_debug_counter_seed_index_i] <=
            status_debug_counter_seed_value_i;

      if (phy_csr_req_valid_i && phy_csr_req_ready_o) begin
        csr_rsp_valid_q <= 1'b1;
        csr_rsp_rdata_q <= '0;
        csr_rsp_error_q <= 1'b0;
        if (phy_csr_req_write_i) begin
          unique case (phy_csr_req_addr_i)
            CSR_ERROR_STICKY: begin
              sticky_bitmap_q <= sticky_bitmap_q & ~csr_write_mask[ERROR_CODE_COUNT-1:0];
            end
            CSR_OBSERVATION_CLEAR: begin
              if (csr_write_mask[0]) begin
                first_error_valid_q  <= 1'b0;
                first_error_fatal_q  <= 1'b0;
                first_error_source_q <= '0;
                first_error_code_q   <= ERR_NONE;
                first_error_info_q   <= '0;
              end
              if (csr_write_mask[1]) sticky_bitmap_q <= '0;
              if (csr_write_mask[2]) begin
                for (reset_index = 0; reset_index < ERROR_CODE_COUNT; reset_index = reset_index + 1)
                  error_counter_q[reset_index] <= '0;
              end
              if (csr_write_mask[3]) begin
                history_wr_ptr_q <= '0;
                history_count_q  <= '0;
              end
              if (csr_write_mask[4]) begin
                error_fifo_wr_ptr_q <= '0;
                error_fifo_rd_ptr_q <= '0;
                error_fifo_count_q  <= '0;
              end
            end
            default: csr_rsp_error_q <= 1'b1;
          endcase
        end else begin
          if (phy_csr_req_addr_i == CSR_ID_VERSION) begin
            csr_rsp_rdata_q <= 32'h0100_0001;
          end else if (phy_csr_req_addr_i == CSR_STATUS) begin
            csr_rsp_rdata_q <= {status_buffer_level_i, status_retry_count_i, 3'b000,
                                phy_rx_locked_o, phy_data_active_o, phy_link_up_o,
                                phy_current_rate_o, phy_ready_o};
          end else if (phy_csr_req_addr_i == CSR_LTSSM) begin
            csr_rsp_rdata_q <= {8'd0, status_state_i, status_substate_i,
                                status_timer_id_i, 6'd0};
          end else if (phy_csr_req_addr_i == CSR_STATE_REASON) begin
            csr_rsp_rdata_q <= {status_reason_i, status_timer_value_i[23:0]};
          end else if (phy_csr_req_addr_i == CSR_FIRST_ERROR_CODE) begin
            csr_rsp_rdata_q <= {5'd0, first_error_valid_q, first_error_fatal_q,
                                first_error_source_q, first_error_rate_q,
                                first_error_code_q, first_error_state_q,
                                first_error_substate_q};
          end else if (phy_csr_req_addr_i == CSR_FIRST_ERROR_INFO) begin
            csr_rsp_rdata_q <= first_error_info_q;
          end else if (phy_csr_req_addr_i == CSR_ERROR_STICKY) begin
            csr_rsp_rdata_q <= {{(32-ERROR_CODE_COUNT){1'b0}}, sticky_bitmap_q};
          end else if (phy_csr_req_addr_i == CSR_EVENT_STATUS) begin
            csr_rsp_rdata_q <= {10'd0, overflow_pending_q, 3'd0,
                                history_count_q, 4'd0, error_fifo_count_q,
                                history_wr_ptr_q, error_fifo_wr_ptr_q};
          end else if ((phy_csr_req_addr_i >= CSR_COUNTER_BASE) &&
                       (phy_csr_req_addr_i < (CSR_COUNTER_BASE + ERROR_CODE_COUNT*4)) &&
                       (phy_csr_req_addr_i[1:0] == 2'b00)) begin
            csr_array_index = (phy_csr_req_addr_i - CSR_COUNTER_BASE) >> 2;
            csr_rsp_rdata_q <= error_counter_q[csr_array_index];
          end else if ((phy_csr_req_addr_i >= CSR_HISTORY_BASE) &&
                       (phy_csr_req_addr_i < (CSR_HISTORY_BASE + HISTORY_DEPTH*8)) &&
                       (phy_csr_req_addr_i[1:0] == 2'b00)) begin
            csr_array_index = (phy_csr_req_addr_i - CSR_HISTORY_BASE) >> 3;
            if (phy_csr_req_addr_i[2])
              csr_rsp_rdata_q <= history_info_q[csr_array_index];
            else
              csr_rsp_rdata_q <= history_meta_q[csr_array_index];
          end else begin
            csr_rsp_rdata_q <= 32'd0;
            csr_rsp_error_q <= 1'b1;
          end
        end
      end
    end
  end

  // Launch a bundled status update only while no earlier update is in flight.
  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani) begin
    if (!ctrl_local_reset_ani) begin
      snapshot_payload_q       <= '0;
      snapshot_last_sent_q     <= '0;
      snapshot_req_toggle_q    <= 1'b0;
      snapshot_pending_q       <= 1'b0;
      snapshot_ack_ctrl_sync_q <= '0;
    end else begin
      snapshot_ack_ctrl_sync_q <= {snapshot_ack_ctrl_sync_q[0], snapshot_ack_link_q};
      if (snapshot_ack_ctrl_sync_q[1] == snapshot_req_toggle_q) begin
        if (snapshot_pending_q ||
            ({phy_link_up_o, phy_data_active_o, phy_current_rate_o} != snapshot_last_sent_q)) begin
          snapshot_payload_q    <= {phy_link_up_o, phy_data_active_o, phy_current_rate_o};
          snapshot_last_sent_q  <= {phy_link_up_o, phy_data_active_o, phy_current_rate_o};
          snapshot_req_toggle_q <= ~snapshot_req_toggle_q;
          snapshot_pending_q    <= 1'b0;
        end
      end else if ({phy_link_up_o, phy_data_active_o, phy_current_rate_o} !=
                   snapshot_last_sent_q) begin
        snapshot_pending_q <= 1'b1;
      end
    end
  end

  // The payload is stable for at least two link clocks before req_sync changes,
  // then remains stable until this acknowledgement returns to ctrl_clk.
  always_ff @(posedge link_clk_i or negedge link_local_reset_ani) begin
    if (!link_local_reset_ani) begin
      snapshot_req_link_sync_q   <= '0;
      snapshot_ack_link_q        <= 1'b0;
      phy_dll_link_up_o           <= 1'b0;
      phy_dll_data_active_o       <= 1'b0;
      phy_dll_current_rate_o      <= 1'b0;
      phy_dll_link_down_evt_o     <= 1'b0;
    end else begin
      snapshot_req_link_sync_q <= {snapshot_req_link_sync_q[0], snapshot_req_toggle_q};
      phy_dll_link_down_evt_o   <= 1'b0;
      if (snapshot_req_link_sync_q[1] != snapshot_ack_link_q) begin
        phy_dll_link_down_evt_o <= phy_dll_link_up_o && !snapshot_payload_q[2];
        phy_dll_link_up_o       <= snapshot_payload_q[2];
        phy_dll_data_active_o   <= snapshot_payload_q[1];
        phy_dll_current_rate_o  <= snapshot_payload_q[0];
        snapshot_ack_link_q     <= snapshot_req_link_sync_q[1];
      end
    end
  end

endmodule
