module phy_rx_packet_buffer_cdc #(
  parameter int unsigned PHY_MAX_PACKET_BYTES =
      pcie_gen12_phy_timing_pkg::PHY_MAX_PACKET_BYTES,
  parameter int unsigned PHY_RX_PACKET_SLOTS =
      pcie_gen12_phy_timing_pkg::PHY_RX_WHOLE_PACKET_SLOTS,
  parameter int unsigned PHY_RX_BACKPRESSURE_MAX_CYCLES =
      pcie_gen12_phy_timing_pkg::PHY_RX_BACKPRESSURE_MAX_CYCLES
) (
  input  logic        sym_clk_i,
  input  logic        sym_rst_ni,
  input  logic        port_reset_ni,
  // Active-high cross-domain flush.  Assertion is asynchronous so a stopped
  // clock cannot leave a committed packet visible; release is synchronized
  // independently in the producer and consumer domains below.
  input  logic        rxbuf_flush_i,
  input  logic        link_clk_i,
  input  logic        link_rst_ni,

  input  logic        rxbuf_pkt_valid_i,
  output logic        rxbuf_pkt_ready_o,
  input  logic [15:0] rxbuf_pkt_data_i,
  input  logic [1:0]  rxbuf_pkt_keep_i,
  input  logic        rxbuf_pkt_sop_i,
  input  logic        rxbuf_pkt_eop_i,
  input  logic        rxbuf_pkt_kind_i,
  input  logic        rxbuf_pkt_abort_i,
  input  logic        rxbuf_drop_i,

  output logic        dll_rx_valid_o,
  input  logic        dll_rx_ready_i,
  output logic [15:0] dll_rx_data_o,
  output logic [1:0]  dll_rx_keep_o,
  output logic        dll_rx_sop_o,
  output logic        dll_rx_eop_o,
  output logic        dll_rx_kind_o,
  output logic        dll_rx_abort_o,

  // sym_clk-domain capacity/overflow event retained from the frozen interface.
  output logic        rxbuf_overflow_evt_o,
  // Private observability: malformed candidate drop is distinct from capacity
  // overflow, and the bounded DLL backpressure watchdog lives in link_clk.
  output logic        rxbuf_candidate_drop_evt_o,
  output logic        rxbuf_backpressure_timeout_evt_o,
  // sym_clk-domain occupied packet slots: committed slots plus the reserved
  // in-progress candidate slot.  Values above the debug width saturate.
  output logic [7:0]  rxbuf_level_o
);

  timeunit 1ns;
  timeprecision 1ps;

  localparam int unsigned SLOT_ADDR_W =
      (PHY_RX_PACKET_SLOTS <= 2) ? 1 : $clog2(PHY_RX_PACKET_SLOTS);
  localparam int unsigned PTR_W = SLOT_ADDR_W + 1;
  localparam int unsigned BYTE_COUNT_W =
      (PHY_MAX_PACKET_BYTES < 2) ? 1 : $clog2(PHY_MAX_PACKET_BYTES + 1);
  localparam int unsigned BP_COUNT_W =
      (PHY_RX_BACKPRESSURE_MAX_CYCLES < 2) ? 1 :
      $clog2(PHY_RX_BACKPRESSURE_MAX_CYCLES + 1);

  // Payload is stored as bytes so a frame delimiter in either character lane
  // cannot create a partial non-EOP beat at the DLL interface.
  logic [7:0] packet_byte_mem [0:PHY_RX_PACKET_SLOTS-1]
                              [0:PHY_MAX_PACKET_BYTES-1];
  logic [BYTE_COUNT_W-1:0] packet_bytes_mem [0:PHY_RX_PACKET_SLOTS-1];
  logic packet_kind_mem  [0:PHY_RX_PACKET_SLOTS-1];
  logic packet_abort_mem [0:PHY_RX_PACKET_SLOTS-1];

  logic [PTR_W-1:0] wr_bin_q, wr_gray_q;
  logic [PTR_W-1:0] rd_bin_q, rd_gray_q;
  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] rd_gray_sync1_q;
  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] rd_gray_sync2_q;
  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] wr_gray_sync1_q;
  (* ASYNC_REG = "TRUE" *) logic [PTR_W-1:0] wr_gray_sync2_q;

  logic [PTR_W-1:0] rd_bin_sync_c;
  logic              fifo_full_c;
  logic              fifo_empty_c;
  logic [PTR_W:0]     rxbuf_level_ext_c;

  logic                   wr_active_q;
  logic [BYTE_COUNT_W-1:0] wr_byte_count_q;
  logic [BYTE_COUNT_W-1:0] rd_byte_index_q;
  logic [BP_COUNT_W-1:0]   backpressure_count_q;
  logic                    backpressure_reported_q;

  (* ASYNC_REG = "TRUE" *) logic [1:0] sym_domain_release_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] link_domain_release_sync_q;
  wire sym_domain_reset_ni  = sym_rst_ni  &&
                              sym_domain_release_sync_q[1];
  wire link_domain_reset_ni = link_rst_ni &&
                              link_domain_release_sync_q[1];

  logic [1:0] incoming_byte_count_c;

  function automatic logic [PTR_W-1:0] bin_to_gray(
    input logic [PTR_W-1:0] value
  );
    return (value >> 1) ^ value;
  endfunction

  function automatic logic [PTR_W-1:0] gray_to_bin(
    input logic [PTR_W-1:0] value
  );
    logic [PTR_W-1:0] result;
    result[PTR_W-1] = value[PTR_W-1];
    for (int bit_index = PTR_W-2; bit_index >= 0; bit_index--) begin
      result[bit_index] = result[bit_index+1] ^ value[bit_index];
    end
    return result;
  endfunction

  initial begin : p_parameter_guards
    if ((PHY_RX_PACKET_SLOTS < 2) ||
        ((PHY_RX_PACKET_SLOTS & (PHY_RX_PACKET_SLOTS-1)) != 0)) begin
      $error("PHY_RX_PACKET_SLOTS must be a power of two and at least two");
    end
    if ((PHY_MAX_PACKET_BYTES == 0) ||
        (PHY_RX_BACKPRESSURE_MAX_CYCLES == 0)) begin
      $error("RX packet and backpressure limits must be non-zero");
    end
  end

  assign incoming_byte_count_c = {1'b0, rxbuf_pkt_keep_i[0]} +
                                 {1'b0, rxbuf_pkt_keep_i[1]};

  // Both the external port reset and an in-service buffer flush assert local
  // reset without a clock.  Each domain then observes two local clock edges
  // before releasing its pointer, candidate, and presentation state.  Resetting
  // both commit pointers invalidates every descriptor/payload slot atomically;
  // the memories need not be cleared because no stale slot remains reachable.
  always_ff @(posedge sym_clk_i or negedge sym_rst_ni or
             negedge port_reset_ni or posedge rxbuf_flush_i) begin
    if (!sym_rst_ni || !port_reset_ni || rxbuf_flush_i) begin
      sym_domain_release_sync_q <= 2'b00;
    end else begin
      sym_domain_release_sync_q <= {sym_domain_release_sync_q[0], 1'b1};
    end
  end

  always_ff @(posedge link_clk_i or negedge link_rst_ni or
             negedge port_reset_ni or posedge rxbuf_flush_i) begin
    if (!link_rst_ni || !port_reset_ni || rxbuf_flush_i) begin
      link_domain_release_sync_q <= 2'b00;
    end else begin
      link_domain_release_sync_q <= {link_domain_release_sync_q[0], 1'b1};
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin
    if (!sym_domain_reset_ni) begin
      rd_gray_sync1_q <= '0;
      rd_gray_sync2_q <= '0;
    end else begin
      rd_gray_sync1_q <= rd_gray_q;
      rd_gray_sync2_q <= rd_gray_sync1_q;
    end
  end

  always_ff @(posedge link_clk_i or negedge link_domain_reset_ni) begin
    if (!link_domain_reset_ni) begin
      wr_gray_sync1_q <= '0;
      wr_gray_sync2_q <= '0;
    end else begin
      wr_gray_sync1_q <= wr_gray_q;
      wr_gray_sync2_q <= wr_gray_sync1_q;
    end
  end

  assign rd_bin_sync_c = gray_to_bin(rd_gray_sync2_q);
  assign fifo_full_c =
      (wr_bin_q[SLOT_ADDR_W-1:0] == rd_bin_sync_c[SLOT_ADDR_W-1:0]) &&
      (wr_bin_q[PTR_W-1] != rd_bin_sync_c[PTR_W-1]);
  assign fifo_empty_c = (rd_gray_q == wr_gray_sync2_q);

  always_comb begin
    rxbuf_level_ext_c =
        {1'b0, (wr_bin_q - rd_bin_sync_c)} + {{PTR_W{1'b0}}, wr_active_q};
    if (rxbuf_level_ext_c > 8'hff) begin
      rxbuf_level_o = 8'hff;
    end else begin
      rxbuf_level_o = 8'(rxbuf_level_ext_c);
    end
  end

  // A reserved slot accepts every legal byte through END/EDB. A zero-keep EOP
  // is the classifier's control-only terminator and consumes no payload space.
  always_comb begin
    if (!sym_domain_reset_ni) begin
      rxbuf_pkt_ready_o = 1'b0;
    end else if (!wr_active_q) begin
      rxbuf_pkt_ready_o = !fifo_full_c;
    end else if ((rxbuf_pkt_keep_i == 2'b00) && rxbuf_pkt_eop_i) begin
      rxbuf_pkt_ready_o = 1'b1;
    end else begin
      rxbuf_pkt_ready_o =
          (wr_byte_count_q + incoming_byte_count_c <= PHY_MAX_PACKET_BYTES);
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_domain_reset_ni) begin : p_write
    logic [SLOT_ADDR_W-1:0] slot_index;
    logic [BYTE_COUNT_W-1:0] byte_count_w;
    logic invalid_candidate;
    if (!sym_domain_reset_ni) begin
      wr_bin_q                   <= '0;
      wr_gray_q                  <= '0;
      wr_active_q                <= 1'b0;
      wr_byte_count_q            <= '0;
      rxbuf_overflow_evt_o       <= 1'b0;
      rxbuf_candidate_drop_evt_o <= 1'b0;
    end else begin
      rxbuf_overflow_evt_o       <= 1'b0;
      rxbuf_candidate_drop_evt_o <= 1'b0;

      if (rxbuf_drop_i) begin
        if (wr_active_q) begin
          rxbuf_candidate_drop_evt_o <= 1'b1;
        end
        wr_active_q     <= 1'b0;
        wr_byte_count_q <= '0;
      end else if (rxbuf_pkt_valid_i && !rxbuf_pkt_ready_o) begin
        // There is no retry path toward the serial receiver.
        rxbuf_overflow_evt_o       <= 1'b1;
        rxbuf_candidate_drop_evt_o <= wr_active_q;
        wr_active_q                <= 1'b0;
        wr_byte_count_q            <= '0;
      end else if (rxbuf_pkt_valid_i && rxbuf_pkt_ready_o) begin
        slot_index        = wr_bin_q[SLOT_ADDR_W-1:0];
        byte_count_w      = wr_byte_count_q;
        invalid_candidate = 1'b0;

        if (!wr_active_q) begin
          if (!rxbuf_pkt_sop_i || (rxbuf_pkt_keep_i == 2'b00)) begin
            invalid_candidate = 1'b1;
          end else begin
            wr_active_q                   <= 1'b1;
            packet_kind_mem[slot_index]   <= rxbuf_pkt_kind_i;
          end
        end else if (rxbuf_pkt_sop_i) begin
          invalid_candidate = 1'b1;
        end

        // keep=10 has a hole in wire-time order and is never legal.
        if (rxbuf_pkt_keep_i == 2'b10) begin
          invalid_candidate = 1'b1;
        end
        if (!rxbuf_pkt_eop_i && (rxbuf_pkt_keep_i == 2'b00)) begin
          invalid_candidate = 1'b1;
        end
        if (rxbuf_pkt_abort_i &&
            (!rxbuf_pkt_eop_i || rxbuf_pkt_kind_i)) begin
          invalid_candidate = 1'b1;
        end

        if (!invalid_candidate) begin
          if (rxbuf_pkt_keep_i[0]) begin
            packet_byte_mem[slot_index][byte_count_w] <=
                rxbuf_pkt_data_i[7:0];
            byte_count_w = byte_count_w + 1'b1;
          end
          if (rxbuf_pkt_keep_i[1]) begin
            packet_byte_mem[slot_index][byte_count_w] <=
                rxbuf_pkt_data_i[15:8];
            byte_count_w = byte_count_w + 1'b1;
          end
        end

        if (invalid_candidate) begin
          rxbuf_candidate_drop_evt_o <= 1'b1;
          wr_active_q                 <= 1'b0;
          wr_byte_count_q             <= '0;
        end else if (rxbuf_pkt_eop_i) begin
          if (byte_count_w == 0) begin
            rxbuf_candidate_drop_evt_o <= 1'b1;
          end else begin
            packet_bytes_mem[slot_index] <= byte_count_w;
            packet_abort_mem[slot_index] <= rxbuf_pkt_abort_i;
            // Commit is the sole write-pointer transition.
            wr_bin_q  <= wr_bin_q + 1'b1;
            wr_gray_q <= bin_to_gray(wr_bin_q + 1'b1);
          end
          wr_active_q     <= 1'b0;
          wr_byte_count_q <= '0;
        end else begin
          wr_byte_count_q <= byte_count_w;
        end
      end
    end
  end

  // Read only after the synchronized commit pointer arrives. The selected slot
  // cannot be reused by the writer until this read pointer crosses back.
  always_comb begin : p_read_output
    logic [SLOT_ADDR_W-1:0] slot_index;
    logic [BYTE_COUNT_W-1:0] bytes_remaining;
    slot_index      = rd_bin_q[SLOT_ADDR_W-1:0];
    bytes_remaining = '0;
    dll_rx_valid_o   = link_domain_reset_ni && !fifo_empty_c;
    dll_rx_data_o    = '0;
    dll_rx_keep_o    = '0;
    dll_rx_sop_o     = 1'b0;
    dll_rx_eop_o     = 1'b0;
    dll_rx_kind_o    = 1'b0;
    dll_rx_abort_o   = 1'b0;

    if (dll_rx_valid_o) begin
      bytes_remaining = packet_bytes_mem[slot_index] - rd_byte_index_q;
      dll_rx_data_o = {
        (bytes_remaining >= 2) ?
            packet_byte_mem[slot_index][rd_byte_index_q+1'b1] : 8'h00,
        packet_byte_mem[slot_index][rd_byte_index_q]
      };
      dll_rx_keep_o  = (bytes_remaining >= 2) ? 2'b11 : 2'b01;
      dll_rx_sop_o   = (rd_byte_index_q == 0);
      dll_rx_eop_o   = (bytes_remaining <= 2);
      dll_rx_kind_o  = packet_kind_mem[slot_index];
      dll_rx_abort_o = dll_rx_eop_o && packet_abort_mem[slot_index];
    end
  end

  always_ff @(posedge link_clk_i or negedge link_domain_reset_ni) begin
    if (!link_domain_reset_ni) begin
      rd_bin_q                         <= '0;
      rd_gray_q                        <= '0;
      rd_byte_index_q                  <= '0;
      backpressure_count_q             <= '0;
      backpressure_reported_q          <= 1'b0;
      rxbuf_backpressure_timeout_evt_o <= 1'b0;
    end else begin
      rxbuf_backpressure_timeout_evt_o <= 1'b0;

      if (dll_rx_valid_o && dll_rx_ready_i) begin
        if (dll_rx_eop_o) begin
          rd_bin_q        <= rd_bin_q + 1'b1;
          rd_gray_q       <= bin_to_gray(rd_bin_q + 1'b1);
          rd_byte_index_q <= '0;
        end else begin
          rd_byte_index_q <= rd_byte_index_q + 2;
        end
      end

      if (dll_rx_valid_o && !dll_rx_ready_i) begin
        if (backpressure_count_q < PHY_RX_BACKPRESSURE_MAX_CYCLES) begin
          backpressure_count_q <= backpressure_count_q + 1'b1;
        end
        if (!backpressure_reported_q &&
            (backpressure_count_q + 1'b1 >=
             PHY_RX_BACKPRESSURE_MAX_CYCLES)) begin
          rxbuf_backpressure_timeout_evt_o <= 1'b1;
          backpressure_reported_q          <= 1'b1;
        end
      end else begin
        backpressure_count_q    <= '0;
        backpressure_reported_q <= 1'b0;
      end
    end
  end

endmodule
