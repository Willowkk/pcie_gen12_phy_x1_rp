module phy_tx_packet_buffer_cdc #(
  parameter int unsigned PHY_MAX_PACKET_BYTES =
    pcie_gen12_phy_timing_pkg::PHY_MAX_PACKET_BYTES,
  parameter int unsigned PHY_TX_PACKET_SLOTS =
    pcie_gen12_phy_timing_pkg::PHY_TX_WHOLE_PACKET_SLOTS
) (
  input  logic        link_clk_i,
  input  logic        link_rst_ni,
  input  logic        port_reset_ni,
  input  logic        sym_clk_i,
  input  logic        sym_rst_ni,

  input  logic        dll_tx_valid_i,
  output logic        dll_tx_ready_o,
  input  logic [15:0] dll_tx_data_i,
  input  logic [1:0]  dll_tx_keep_i,
  input  logic        dll_tx_sop_i,
  input  logic        dll_tx_eop_i,
  input  logic        dll_tx_kind_i,
  input  logic        dll_tx_abort_i,

  // link_clk_i-domain coherent copy of phy_dll_data_active_o.  It gates only
  // a new SOP; once an SOP is accepted, ready remains asserted through EOP.
  input  logic        txbuf_admission_enable_i,
  // A glitch-free level request.  Assertion is asynchronous in both domains;
  // release is synchronized independently by the reset-release pipelines.
  input  logic        txbuf_flush_i,

  output logic        txbuf_pkt_valid_o,
  input  logic        txbuf_pkt_ready_i,
  output logic [15:0] txbuf_pkt_data_o,
  output logic [1:0]  txbuf_pkt_keep_o,
  output logic        txbuf_pkt_sop_o,
  output logic        txbuf_pkt_eop_o,
  output logic        txbuf_pkt_kind_o,
  output logic        txbuf_pkt_abort_o,

  // These status signals are intentionally in their named domains.  A top
  // level consumer crossing them must use a coherent snapshot/event CDC.
  output logic        txbuf_capture_active_o, // link_clk_i domain
  output logic        txbuf_pending_o,        // sym_clk_i domain
  output logic [7:0]  txbuf_level_o,          // sym_clk_i domain
  output logic        txbuf_error_evt_o,      // link_clk_i domain pulse
  output logic [7:0]  txbuf_error_code_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  localparam int unsigned MAX_PACKET_BEATS =
    (PHY_MAX_PACKET_BYTES + 1) / 2;
  localparam int unsigned SLOT_ADDR_WIDTH =
    (PHY_TX_PACKET_SLOTS <= 2) ? 1 : $clog2(PHY_TX_PACKET_SLOTS);
  localparam int unsigned POINTER_WIDTH = SLOT_ADDR_WIDTH + 1;
  localparam int unsigned BEAT_COUNT_WIDTH =
    (MAX_PACKET_BEATS < 2) ? 1 : $clog2(MAX_PACKET_BEATS + 1);
  localparam int unsigned BYTE_COUNT_WIDTH =
    (PHY_MAX_PACKET_BYTES < 2) ? 1 : $clog2(PHY_MAX_PACKET_BYTES + 1);

  // Payload and metadata form bundled data.  The writer never modifies a slot
  // after advancing wr_ptr_gray_q, and it cannot reuse that slot until the
  // synchronized read pointer advances.  The two Gray synchronizers are the
  // only multi-clock path that grants slot ownership or qualifies RAM data;
  // the single-bit alive/pending synchronizers below are status/reset aids.
  (* ram_style = "block" *)
  logic [15:0] packet_data_mem [0:PHY_TX_PACKET_SLOTS-1]
                                 [0:MAX_PACKET_BEATS-1];
  logic [1:0] packet_keep_mem [0:PHY_TX_PACKET_SLOTS-1]
                                [0:MAX_PACKET_BEATS-1];
  logic [BEAT_COUNT_WIDTH-1:0] packet_beat_count_mem
                                [0:PHY_TX_PACKET_SLOTS-1];
  logic packet_kind_mem  [0:PHY_TX_PACKET_SLOTS-1];
  logic packet_abort_mem [0:PHY_TX_PACKET_SLOTS-1];

  logic [POINTER_WIDTH-1:0] wr_ptr_bin_q;
  logic [POINTER_WIDTH-1:0] wr_ptr_gray_q;
  logic [POINTER_WIDTH-1:0] rd_ptr_bin_q;
  logic [POINTER_WIDTH-1:0] rd_ptr_gray_q;

  (* ASYNC_REG = "TRUE" *) logic [POINTER_WIDTH-1:0] rd_gray_link_meta_q;
  (* ASYNC_REG = "TRUE" *) logic [POINTER_WIDTH-1:0] rd_gray_link_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [POINTER_WIDTH-1:0] wr_gray_sym_meta_q;
  (* ASYNC_REG = "TRUE" *) logic [POINTER_WIDTH-1:0] wr_gray_sym_sync_q;

  logic [1:0] link_reset_release_q;
  logic [1:0] sym_reset_release_q;
  logic       link_domain_reset_ni;
  logic       sym_domain_reset_ni;
  wire        link_async_reset_ni =
    link_rst_ni && port_reset_ni && !txbuf_flush_i;
  wire        sym_async_reset_ni =
    sym_rst_ni && port_reset_ni && !txbuf_flush_i;

  logic link_domain_alive_q;
  logic sym_domain_alive_q;
  (* ASYNC_REG = "TRUE" *) logic sym_alive_link_meta_q;
  (* ASYNC_REG = "TRUE" *) logic sym_alive_link_sync_q;
  (* ASYNC_REG = "TRUE" *) logic link_alive_sym_meta_q;
  (* ASYNC_REG = "TRUE" *) logic link_alive_sym_sync_q;

  logic [BEAT_COUNT_WIDTH-1:0] wr_beat_count_q;
  logic [BYTE_COUNT_WIDTH-1:0] wr_byte_count_q;
  logic                        wr_in_packet_q;
  logic                        wr_packet_bad_q;
  logic                        wr_error_reported_q;
  logic                        wr_packet_kind_q;

  logic [BEAT_COUNT_WIDTH-1:0] rd_beat_index_q;

  logic        stall_sample_valid_q;
  logic [21:0] stall_sample_q;

  logic [POINTER_WIDTH-1:0] wr_ptr_gray_after_commit;
  logic [POINTER_WIDTH-1:0] rd_ptr_gray_full_compare;
  logic [POINTER_WIDTH-1:0] wr_ptr_bin_sym;
  logic [POINTER_WIDTH-1:0] committed_packet_count_sym;
  logic                     slot_fifo_full;
  logic                     slot_fifo_empty;
  logic [1:0]               incoming_byte_count;
  logic [BYTE_COUNT_WIDTH:0] continuation_byte_total;
  logic                     start_beat_bad;
  logic                     continuation_beat_bad;
  logic                     continuation_fits;

  function automatic logic [POINTER_WIDTH-1:0] binary_to_gray(
    input logic [POINTER_WIDTH-1:0] binary_value
  );
    return (binary_value >> 1) ^ binary_value;
  endfunction

  function automatic logic [POINTER_WIDTH-1:0] gray_to_binary(
    input logic [POINTER_WIDTH-1:0] gray_value
  );
    logic [POINTER_WIDTH-1:0] binary_value;
    int bit_index;
    begin
      binary_value[POINTER_WIDTH-1] = gray_value[POINTER_WIDTH-1];
      for (bit_index = POINTER_WIDTH-2; bit_index >= 0; bit_index--) begin
        binary_value[bit_index] =
          binary_value[bit_index+1] ^ gray_value[bit_index];
      end
      return binary_value;
    end
  endfunction

  function automatic logic keep_is_legal(
    input logic [1:0] keep,
    input logic       eop
  );
    if (eop) begin
      return (keep == 2'b01) || (keep == 2'b11);
    end
    return keep == 2'b11;
  endfunction

  // The design contract requires a power-of-two slot count for the Gray-ring
  // full comparison.  This elaboration guard is static and has no RTL body.
  generate
    if ((PHY_TX_PACKET_SLOTS < 2) ||
        ((PHY_TX_PACKET_SLOTS & (PHY_TX_PACKET_SLOTS - 1)) != 0)) begin : g_bad_slot_count
      initial $error("PHY_TX_PACKET_SLOTS must be a power of two and >= 2");
    end
    if (PHY_MAX_PACKET_BYTES < 1) begin : g_bad_packet_size
      initial $error("PHY_MAX_PACKET_BYTES must be non-zero");
    end
  endgenerate

  // Asynchronous assertion and per-domain synchronous release, including the
  // common functional flush request.
  always_ff @(posedge link_clk_i or negedge link_async_reset_ni) begin
    if (!link_async_reset_ni) begin
      link_reset_release_q <= 2'b00;
    end else begin
      link_reset_release_q <= {link_reset_release_q[0], 1'b1};
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_async_reset_ni) begin
    if (!sym_async_reset_ni) begin
      sym_reset_release_q <= 2'b00;
    end else begin
      sym_reset_release_q <= {sym_reset_release_q[0], 1'b1};
    end
  end

  assign link_domain_reset_ni = link_reset_release_q[1];
  assign sym_domain_reset_ni  = sym_reset_release_q[1];

  always_ff @(posedge link_clk_i or negedge link_domain_reset_ni) begin
    if (!link_domain_reset_ni) begin
      link_domain_alive_q <= 1'b0;
    end else begin
      link_domain_alive_q <= 1'b1;
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin
    if (!sym_domain_reset_ni) begin
      sym_domain_alive_q <= 1'b0;
    end else begin
      sym_domain_alive_q <= 1'b1;
    end
  end

  // Reset/alive coherency prevents one independently reset side from exposing
  // stale slots left by the other side.
  always_ff @(posedge link_clk_i or negedge link_domain_reset_ni) begin
    if (!link_domain_reset_ni) begin
      sym_alive_link_meta_q <= 1'b0;
      sym_alive_link_sync_q <= 1'b0;
    end else begin
      sym_alive_link_meta_q <= sym_domain_alive_q;
      sym_alive_link_sync_q <= sym_alive_link_meta_q;
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin
    if (!sym_domain_reset_ni) begin
      link_alive_sym_meta_q <= 1'b0;
      link_alive_sym_sync_q <= 1'b0;
    end else begin
      link_alive_sym_meta_q <= link_domain_alive_q;
      link_alive_sym_sync_q <= link_alive_sym_meta_q;
    end
  end

  always_ff @(posedge link_clk_i or negedge link_domain_reset_ni) begin
    if (!link_domain_reset_ni) begin
      rd_gray_link_meta_q <= '0;
      rd_gray_link_sync_q <= '0;
    end else begin
      rd_gray_link_meta_q <= rd_ptr_gray_q;
      rd_gray_link_sync_q <= rd_gray_link_meta_q;
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin
    if (!sym_domain_reset_ni) begin
      wr_gray_sym_meta_q <= '0;
      wr_gray_sym_sync_q <= '0;
    end else begin
      wr_gray_sym_meta_q <= wr_ptr_gray_q;
      wr_gray_sym_sync_q <= wr_gray_sym_meta_q;
    end
  end

  always_comb begin
    wr_ptr_gray_after_commit = binary_to_gray(wr_ptr_bin_q + 1'b1);
    rd_ptr_gray_full_compare = rd_gray_link_sync_q;
    rd_ptr_gray_full_compare[POINTER_WIDTH-1 -: 2] =
      ~rd_gray_link_sync_q[POINTER_WIDTH-1 -: 2];
    slot_fifo_full  = (wr_ptr_gray_after_commit == rd_ptr_gray_full_compare);
    slot_fifo_empty = (rd_ptr_gray_q == wr_gray_sym_sync_q);

    incoming_byte_count = {1'b0, dll_tx_keep_i[0]} +
                          {1'b0, dll_tx_keep_i[1]};
    continuation_byte_total = {1'b0, wr_byte_count_q} +
                              incoming_byte_count;
    continuation_fits =
      (wr_beat_count_q < MAX_PACKET_BEATS) &&
      (continuation_byte_total <= PHY_MAX_PACKET_BYTES);

    start_beat_bad =
      !dll_tx_sop_i ||
      !keep_is_legal(dll_tx_keep_i, dll_tx_eop_i) ||
      (incoming_byte_count == 0) ||
      (incoming_byte_count > PHY_MAX_PACKET_BYTES) ||
      (dll_tx_abort_i &&
       (!dll_tx_eop_i || (dll_tx_kind_i == PKT_KIND_DLLP)));

    continuation_beat_bad =
      dll_tx_sop_i ||
      !keep_is_legal(dll_tx_keep_i, dll_tx_eop_i) ||
      (incoming_byte_count == 0) ||
      !continuation_fits ||
      (dll_tx_abort_i &&
       (!dll_tx_eop_i || (wr_packet_kind_q == PKT_KIND_DLLP)));

    if (!link_domain_reset_ni || !sym_alive_link_sync_q) begin
      dll_tx_ready_o = 1'b0;
    end else if (wr_in_packet_q) begin
      dll_tx_ready_o = 1'b1;
    end else begin
      dll_tx_ready_o = txbuf_admission_enable_i && !slot_fifo_full;
    end
  end

  // link_clk_i writer.  A pointer advance is the atomic packet commit.  Any
  // malformed packet is consumed through its EOP but never advances the
  // pointer, so it is never observable in the symbol domain.
  always_ff @(posedge link_clk_i or negedge link_domain_reset_ni) begin
    if (!link_domain_reset_ni) begin
      wr_ptr_bin_q             <= '0;
      wr_ptr_gray_q            <= '0;
      wr_beat_count_q          <= '0;
      wr_byte_count_q          <= '0;
      wr_in_packet_q           <= 1'b0;
      wr_packet_bad_q          <= 1'b0;
      wr_error_reported_q      <= 1'b0;
      wr_packet_kind_q         <= PKT_KIND_TLP;
      stall_sample_valid_q     <= 1'b0;
      stall_sample_q           <= '0;
      txbuf_capture_active_o   <= 1'b0;
      txbuf_error_evt_o        <= 1'b0;
      txbuf_error_code_o       <= ERR_NONE;
    end else begin
      txbuf_error_evt_o  <= 1'b0;
      txbuf_error_code_o <= ERR_NONE;

      // Validate the producer's mandatory hold-under-backpressure rule.
      if (dll_tx_valid_i && !dll_tx_ready_o) begin
        if (!stall_sample_valid_q) begin
          stall_sample_valid_q <= 1'b1;
          stall_sample_q <= {
            dll_tx_data_i, dll_tx_keep_i, dll_tx_sop_i, dll_tx_eop_i,
            dll_tx_kind_i, dll_tx_abort_i
          };
        end else if (stall_sample_q != {
          dll_tx_data_i, dll_tx_keep_i, dll_tx_sop_i, dll_tx_eop_i,
          dll_tx_kind_i, dll_tx_abort_i
        }) begin
          txbuf_error_evt_o  <= 1'b1;
          txbuf_error_code_o <= ERR_TX_FRAMING;
        end
      end else if (stall_sample_valid_q && !dll_tx_valid_i) begin
        // Once valid has been presented under backpressure it must remain
        // asserted, with the sampled bundle unchanged, until acceptance.
        stall_sample_valid_q <= 1'b0;
        txbuf_error_evt_o     <= 1'b1;
        txbuf_error_code_o    <= ERR_TX_FRAMING;
      end else begin
        stall_sample_valid_q <= 1'b0;
      end

      if (!sym_alive_link_sync_q) begin
        wr_ptr_bin_q           <= '0;
        wr_ptr_gray_q          <= '0;
        wr_beat_count_q        <= '0;
        wr_byte_count_q        <= '0;
        wr_in_packet_q         <= 1'b0;
        wr_packet_bad_q        <= 1'b0;
        wr_error_reported_q    <= 1'b0;
        txbuf_capture_active_o <= 1'b0;
      end else if (wr_in_packet_q) begin
        // A packet beat is required every cycle after SOP.  ready is held high,
        // so a missing valid is an observable no-bubble contract violation.
        if (!dll_tx_valid_i) begin
          wr_packet_bad_q <= 1'b1;
          if (!wr_error_reported_q) begin
            wr_error_reported_q     <= 1'b1;
            txbuf_error_evt_o       <= 1'b1;
            txbuf_error_code_o      <= ERR_TX_FRAMING;
          end
        end else begin
          if (continuation_fits) begin
            packet_data_mem
              [wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][wr_beat_count_q]
                <= dll_tx_data_i;
            packet_keep_mem
              [wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][wr_beat_count_q]
                <= dll_tx_keep_i;
          end

          if (continuation_beat_bad) begin
            wr_packet_bad_q <= 1'b1;
            if (!wr_error_reported_q) begin
              wr_error_reported_q     <= 1'b1;
              txbuf_error_evt_o       <= 1'b1;
              txbuf_error_code_o      <= ERR_TX_FRAMING;
            end
          end

          if (dll_tx_eop_i) begin
            if (!wr_packet_bad_q && !continuation_beat_bad) begin
              packet_beat_count_mem
                [wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]]
                  <= wr_beat_count_q + 1'b1;
              packet_kind_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]]
                  <= wr_packet_kind_q;
              packet_abort_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]]
                  <= dll_tx_abort_i;
              wr_ptr_bin_q  <= wr_ptr_bin_q + 1'b1;
              wr_ptr_gray_q <= binary_to_gray(wr_ptr_bin_q + 1'b1);
            end
            wr_beat_count_q        <= '0;
            wr_byte_count_q        <= '0;
            wr_in_packet_q         <= 1'b0;
            wr_packet_bad_q        <= 1'b0;
            wr_error_reported_q    <= 1'b0;
            txbuf_capture_active_o <= 1'b0;
          end else begin
            if (continuation_fits) begin
              wr_beat_count_q <= wr_beat_count_q + 1'b1;
              wr_byte_count_q <= continuation_byte_total[BYTE_COUNT_WIDTH-1:0];
            end
          end
        end
      end else if (dll_tx_valid_i && dll_tx_ready_o) begin
        if (!start_beat_bad) begin
          packet_data_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][0]
            <= dll_tx_data_i;
          packet_keep_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][0]
            <= dll_tx_keep_i;
          wr_packet_kind_q <= dll_tx_kind_i;

          if (dll_tx_eop_i) begin
            packet_beat_count_mem
              [wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]] <=
                {{(BEAT_COUNT_WIDTH-1){1'b0}}, 1'b1};
            packet_kind_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]]
              <= dll_tx_kind_i;
            packet_abort_mem[wr_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]]
              <= dll_tx_abort_i;
            wr_ptr_bin_q  <= wr_ptr_bin_q + 1'b1;
            wr_ptr_gray_q <= binary_to_gray(wr_ptr_bin_q + 1'b1);
          end else begin
            wr_beat_count_q        <=
              {{(BEAT_COUNT_WIDTH-1){1'b0}}, 1'b1};
            wr_byte_count_q        <= BYTE_COUNT_WIDTH'(incoming_byte_count);
            wr_in_packet_q         <= 1'b1;
            wr_packet_bad_q        <= 1'b0;
            wr_error_reported_q    <= 1'b0;
            txbuf_capture_active_o <= 1'b1;
          end
        end else begin
          txbuf_error_evt_o  <= 1'b1;
          txbuf_error_code_o <= ERR_TX_FRAMING;
          // If this malformed transfer claims to start a multi-beat packet,
          // consume through its EOP while keeping the slot uncommitted.
          if (dll_tx_sop_i && !dll_tx_eop_i) begin
            wr_beat_count_q        <= '0;
            wr_byte_count_q        <= '0;
            wr_in_packet_q         <= 1'b1;
            wr_packet_bad_q        <= 1'b1;
            wr_error_reported_q    <= 1'b1;
            wr_packet_kind_q       <= dll_tx_kind_i;
            txbuf_capture_active_o <= 1'b1;
          end
        end
      end
    end
  end

  // Synchronize the writer's in-progress flag only for quiesce observability;
  // it is never used to qualify RAM data or ownership.
  (* ASYNC_REG = "TRUE" *) logic capture_active_sym_meta_q;
  (* ASYNC_REG = "TRUE" *) logic capture_active_sym_sync_q;
  always_ff @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin
    if (!sym_domain_reset_ni) begin
      capture_active_sym_meta_q <= 1'b0;
      capture_active_sym_sync_q <= 1'b0;
    end else begin
      capture_active_sym_meta_q <= txbuf_capture_active_o;
      capture_active_sym_sync_q <= capture_active_sym_meta_q;
    end
  end

  // sym_clk_i reader.  The registered output stage is a one-entry prefetch
  // buffer: it holds every beat stable under backpressure and reloads the next
  // beat on the same edge that accepts the current one, so a committed packet
  // has no internal bubbles.
  always_ff @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin
    if (!sym_domain_reset_ni) begin
      rd_ptr_bin_q          <= '0;
      rd_ptr_gray_q         <= '0;
      rd_beat_index_q       <= '0;
      txbuf_pkt_valid_o     <= 1'b0;
      txbuf_pkt_data_o      <= '0;
      txbuf_pkt_keep_o      <= '0;
      txbuf_pkt_sop_o       <= 1'b0;
      txbuf_pkt_eop_o       <= 1'b0;
      txbuf_pkt_kind_o      <= PKT_KIND_TLP;
      txbuf_pkt_abort_o     <= 1'b0;
    end else if (!link_alive_sym_sync_q) begin
      rd_ptr_bin_q          <= '0;
      rd_ptr_gray_q         <= '0;
      rd_beat_index_q       <= '0;
      txbuf_pkt_valid_o     <= 1'b0;
      txbuf_pkt_data_o      <= '0;
      txbuf_pkt_keep_o      <= '0;
      txbuf_pkt_sop_o       <= 1'b0;
      txbuf_pkt_eop_o       <= 1'b0;
      txbuf_pkt_kind_o      <= PKT_KIND_TLP;
      txbuf_pkt_abort_o     <= 1'b0;
    end else if (!txbuf_pkt_valid_o) begin
      if (!slot_fifo_empty) begin
        rd_beat_index_q   <= '0;
        txbuf_pkt_valid_o <= 1'b1;
        txbuf_pkt_data_o  <=
          packet_data_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][0];
        txbuf_pkt_keep_o  <=
          packet_keep_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][0];
        txbuf_pkt_sop_o   <= 1'b1;
        txbuf_pkt_eop_o   <=
          (packet_beat_count_mem
            [rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]] == 1);
        txbuf_pkt_kind_o  <=
          packet_kind_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]];
        txbuf_pkt_abort_o <=
          packet_abort_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]] &&
          (packet_beat_count_mem
            [rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]] == 1);
      end
    end else if (txbuf_pkt_ready_i) begin
      if (txbuf_pkt_eop_o) begin
        rd_ptr_bin_q      <= rd_ptr_bin_q + 1'b1;
        rd_ptr_gray_q     <= binary_to_gray(rd_ptr_bin_q + 1'b1);
        rd_beat_index_q   <= '0;
        txbuf_pkt_valid_o <= 1'b0;
        txbuf_pkt_sop_o   <= 1'b0;
        txbuf_pkt_eop_o   <= 1'b0;
        txbuf_pkt_abort_o <= 1'b0;
      end else begin
        rd_beat_index_q   <= rd_beat_index_q + 1'b1;
        txbuf_pkt_data_o  <= packet_data_mem
          [rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][rd_beat_index_q + 1'b1];
        txbuf_pkt_keep_o  <= packet_keep_mem
          [rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]][rd_beat_index_q + 1'b1];
        txbuf_pkt_sop_o   <= 1'b0;
        txbuf_pkt_eop_o   <=
          ((rd_beat_index_q + 2) == packet_beat_count_mem
            [rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]]);
        txbuf_pkt_abort_o <=
          packet_abort_mem[rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]] &&
          ((rd_beat_index_q + 2) == packet_beat_count_mem
            [rd_ptr_bin_q[SLOT_ADDR_WIDTH-1:0]]);
      end
    end
  end

  always_comb begin
    wr_ptr_bin_sym = gray_to_binary(wr_gray_sym_sync_q);
    committed_packet_count_sym = wr_ptr_bin_sym - rd_ptr_bin_q;

    txbuf_pending_o = sym_domain_reset_ni &&
                      (txbuf_pkt_valid_o || !slot_fifo_empty ||
                       capture_active_sym_sync_q);

    // Descriptor occupancy includes the packet currently presented to the
    // scheduler until its EOP beat is accepted.  It excludes the link-domain
    // packet under construction because the write pointer is its atomic
    // commit indication.  The synchronized pointer naturally gives this
    // debug value the normal two-flop CDC observation latency.
    if (!sym_domain_reset_ni || !link_alive_sym_sync_q) begin
      txbuf_level_o = 8'h00;
    end else if (committed_packet_count_sym > 8'hff) begin
      txbuf_level_o = 8'hff;
    end else begin
      txbuf_level_o = 8'(committed_packet_count_sym);
    end
  end

endmodule
