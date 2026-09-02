module phy_skp_clock_comp (
  input  logic        sym_clk_i,
  input  logic        sym_rst_ni,
  input  logic        skp_current_rate_i,
  input  logic [1:0]  skp_tx_char_advance_i,
  input  logic        skp_packet_boundary_i,
  input  logic        skp_os_busy_i,
  input  logic        skp_tx_accept_i,
  output logic        skp_due_o,
  output logic [15:0] skp_deadline_o,
  output logic        skp_deadline_missed_evt_o,
  input  logic [1:0]  gt_rx_clkcor_count_i,
  input  logic [2:0]  gt_rx_buffer_status_i,
  output logic        skp_rx_add_evt_o,
  output logic [1:0]  skp_rx_skip_count_o,
  output logic        skp_rx_buffer_fault_evt_o,
  // Private detail events preserve the normalized GT status distinction.
  output logic        skp_rx_underflow_evt_o,
  output logic        skp_rx_overflow_evt_o,
  output logic        skp_rx_status_invalid_evt_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

  localparam int unsigned COUNT_W =
      (SKP_LATEST_INTERVAL_SYMBOLS < 2) ? 2 :
      $clog2(SKP_LATEST_INTERVAL_SYMBOLS + 4);

  logic [COUNT_W-1:0] tx_symbol_count_q;
  logic               deadline_reported_q;
  logic               current_rate_q;
  logic [1:0]         clkcor_previous_q;
  logic [2:0]         rxbuf_previous_q;

  logic [COUNT_W:0] advanced_count_c;
  logic              clkcor_event_c;
  logic              rxbuf_status_changed_c;
  logic              rxbuf_status_legal_c;

  assign advanced_count_c = {1'b0, tx_symbol_count_q} +
                            skp_tx_char_advance_i;

  // Reaching the nominal point is an implicit persistent pending condition in
  // tx_symbol_count_q. OS busy must not hide it: a fixed/repeated OS batch may
  // sample the request at its next complete-OS boundary. Packet transmission
  // remains non-preemptible because packet_boundary stays low inside a packet.
  assign skp_due_o = (tx_symbol_count_q >=
                      SKP_SCHEDULE_INTERVAL_SYMBOLS) &&
                     skp_packet_boundary_i;

  always_comb begin
    if (tx_symbol_count_q >= SKP_LATEST_INTERVAL_SYMBOLS) begin
      skp_deadline_o = 16'h0000;
    end else begin
      skp_deadline_o = SKP_LATEST_INTERVAL_SYMBOLS - tx_symbol_count_q;
    end
  end

  assign clkcor_event_c = (gt_rx_clkcor_count_i != GT_CLKCOR_NONE) &&
                          (gt_rx_clkcor_count_i != clkcor_previous_q);
  assign rxbuf_status_changed_c =
      (gt_rx_buffer_status_i != rxbuf_previous_q);
  assign rxbuf_status_legal_c =
      (gt_rx_buffer_status_i == GT_RXBUF_NOMINAL) ||
      (gt_rx_buffer_status_i == GT_RXBUF_BELOW_MIN) ||
      (gt_rx_buffer_status_i == GT_RXBUF_ABOVE_MAX) ||
      (gt_rx_buffer_status_i == GT_RXBUF_UNDERFLOW) ||
      (gt_rx_buffer_status_i == GT_RXBUF_OVERFLOW);

  always_ff @(posedge sym_clk_i or negedge sym_rst_ni) begin
    if (!sym_rst_ni) begin
      tx_symbol_count_q               <= '0;
      deadline_reported_q             <= 1'b0;
      current_rate_q                  <= 1'b0;
      clkcor_previous_q               <= GT_CLKCOR_NONE;
      rxbuf_previous_q                <= GT_RXBUF_NOMINAL;
      skp_deadline_missed_evt_o       <= 1'b0;
      skp_rx_add_evt_o                <= 1'b0;
      skp_rx_skip_count_o             <= 2'b00;
      skp_rx_buffer_fault_evt_o       <= 1'b0;
      skp_rx_underflow_evt_o          <= 1'b0;
      skp_rx_overflow_evt_o           <= 1'b0;
      skp_rx_status_invalid_evt_o     <= 1'b0;
    end else begin
      skp_deadline_missed_evt_o   <= 1'b0;
      skp_rx_add_evt_o            <= 1'b0;
      skp_rx_skip_count_o         <= 2'b00;
      skp_rx_buffer_fault_evt_o   <= 1'b0;
      skp_rx_underflow_evt_o      <= 1'b0;
      skp_rx_overflow_evt_o       <= 1'b0;
      skp_rx_status_invalid_evt_o <= 1'b0;

      current_rate_q    <= skp_current_rate_i;
      clkcor_previous_q <= gt_rx_clkcor_count_i;
      rxbuf_previous_q  <= gt_rx_buffer_status_i;

      // A rate transition starts a fresh scheduling epoch; no old-rate symbol
      // count is allowed to create a new-rate deadline.
      if (skp_current_rate_i != current_rate_q) begin
        tx_symbol_count_q   <= '0;
        deadline_reported_q <= 1'b0;
      end else if (skp_tx_accept_i) begin
        // Despite the frozen signal name, integration qualifies this with the
        // ordered-set generator's full-SKP-consumed pulse, not merely request
        // arbitration or the first SKP pair.
        tx_symbol_count_q   <= '0;
        deadline_reported_q <= 1'b0;
      end else begin
        if (advanced_count_c >= SKP_LATEST_INTERVAL_SYMBOLS) begin
          tx_symbol_count_q <= SKP_LATEST_INTERVAL_SYMBOLS;
          if (!deadline_reported_q) begin
            skp_deadline_missed_evt_o <= 1'b1;
            deadline_reported_q       <= 1'b1;
          end
        end else begin
          tx_symbol_count_q <= advanced_count_c[COUNT_W-1:0];
        end
      end

      // RX Clock Correction is performed exclusively by the GTY elastic
      // buffer. This block only converts its normalized event/status codes.
      if (clkcor_event_c) begin
        unique case (gt_rx_clkcor_count_i)
          GT_CLKCOR_SKIP1: skp_rx_skip_count_o <= 2'd1;
          GT_CLKCOR_SKIP2: skp_rx_skip_count_o <= 2'd2;
          GT_CLKCOR_ADD1:  skp_rx_add_evt_o    <= 1'b1;
          default: ;
        endcase
      end

      if (rxbuf_status_changed_c) begin
        unique case (gt_rx_buffer_status_i)
          GT_RXBUF_UNDERFLOW: begin
            skp_rx_underflow_evt_o    <= 1'b1;
            skp_rx_buffer_fault_evt_o <= 1'b1;
          end
          GT_RXBUF_OVERFLOW: begin
            skp_rx_overflow_evt_o     <= 1'b1;
            skp_rx_buffer_fault_evt_o <= 1'b1;
          end
          default: begin
            if (!rxbuf_status_legal_c) begin
              skp_rx_status_invalid_evt_o <= 1'b1;
              skp_rx_buffer_fault_evt_o   <= 1'b1;
            end
          end
        endcase
      end
    end
  end

endmodule
