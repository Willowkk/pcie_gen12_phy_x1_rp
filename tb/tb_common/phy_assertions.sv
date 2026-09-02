module phy_assertions #(
  parameter int unsigned REQUEST_BOUND = 4096
) (
  input logic ctrl_clk_i,
  input logic ctrl_rst_ni,
  input logic link_clk_i,
  input logic link_rst_ni,
  input logic port_reset_ni,
  input logic phy_ready_i,
  input logic phy_link_up_i,
  input logic phy_data_active_i,
  input logic dll_tx_valid_i,
  input logic dll_tx_ready_i,
  input logic [15:0] dll_tx_data_i,
  input logic [1:0] dll_tx_keep_i,
  input logic dll_tx_sop_i,
  input logic dll_tx_eop_i,
  input logic dll_tx_kind_i,
  input logic dll_tx_abort_i,
  input logic dll_rx_valid_i,
  input logic dll_rx_ready_i,
  input logic [15:0] dll_rx_data_i,
  input logic [1:0] dll_rx_keep_i,
  input logic dll_rx_sop_i,
  input logic dll_rx_eop_i,
  input logic dll_rx_kind_i,
  input logic dll_rx_abort_i,
  input logic request_i,
  input logic done_i,
  input logic fail_i
);
  timeunit 1ns;
  timeprecision 1ps;

  logic [31:0] request_age_q;
  logic request_pending_q;

  property p_tx_stable_while_stalled;
    @(posedge link_clk_i) disable iff (!link_rst_ni || !port_reset_ni)
      dll_tx_valid_i && !dll_tx_ready_i |=> dll_tx_valid_i &&
        $stable({dll_tx_data_i,dll_tx_keep_i,dll_tx_sop_i,dll_tx_eop_i,
                 dll_tx_kind_i,dll_tx_abort_i});
  endproperty
  assert property (p_tx_stable_while_stalled);

  property p_rx_stable_while_stalled;
    @(posedge link_clk_i) disable iff (!link_rst_ni || !port_reset_ni)
      dll_rx_valid_i && !dll_rx_ready_i |=> dll_rx_valid_i &&
        $stable({dll_rx_data_i,dll_rx_keep_i,dll_rx_sop_i,dll_rx_eop_i,
                 dll_rx_kind_i,dll_rx_abort_i});
  endproperty
  assert property (p_rx_stable_while_stalled);

  property p_inactive_blocks_packet_boundaries;
    @(posedge link_clk_i) disable iff (!link_rst_ni || !port_reset_ni)
      !phy_data_active_i |-> !(dll_tx_valid_i && dll_tx_ready_i && dll_tx_sop_i) &&
                             !(dll_rx_valid_i && dll_rx_sop_i);
  endproperty
  assert property (p_inactive_blocks_packet_boundaries);

  property p_reset_safe;
    @(posedge ctrl_clk_i) (!ctrl_rst_ni || !port_reset_ni || !phy_ready_i)
      |-> (!phy_link_up_i && !phy_data_active_i);
  endproperty
  assert property (p_reset_safe);

  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni || !port_reset_ni) begin
      request_age_q <= 0;
      request_pending_q <= 1'b0;
    end else begin
      if (request_i && !request_pending_q) begin
        request_pending_q <= 1'b1;
        request_age_q <= 0;
      end else if (request_pending_q && (done_i || fail_i)) begin
        request_pending_q <= 1'b0;
      end else if (request_pending_q) begin
        request_age_q <= request_age_q + 1'b1;
        assert (request_age_q < REQUEST_BOUND)
          else $error("bounded request did not terminate");
      end
      assert (!(done_i && fail_i)) else $error("done and fail must be exclusive");
    end
  end
endmodule
