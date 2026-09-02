interface phy_dll_if(input logic link_clk_i);
  timeunit 1ns;
  timeprecision 1ps;

  logic        rst_ni;
  logic        tx_valid;
  logic        tx_ready;
  logic [15:0] tx_data;
  logic [1:0]  tx_keep;
  logic        tx_sop;
  logic        tx_eop;
  logic        tx_kind;
  logic        tx_abort;
  logic        rx_valid;
  logic        rx_ready;
  logic [15:0] rx_data;
  logic [1:0]  rx_keep;
  logic        rx_sop;
  logic        rx_eop;
  logic        rx_kind;
  logic        rx_abort;

  task automatic drive_idle;
    begin
      tx_valid = 1'b0; tx_data = '0; tx_keep = '0; tx_sop = 1'b0;
      tx_eop = 1'b0; tx_kind = 1'b0; tx_abort = 1'b0; rx_ready = 1'b1;
    end
  endtask

  task automatic send_beat(input logic [15:0] data_i,
                           input logic [1:0] keep_i,
                           input logic sop_i,
                           input logic eop_i,
                           input logic kind_i,
                           input logic abort_i);
    begin
      @(negedge link_clk_i);
      tx_valid = 1'b1; tx_data = data_i; tx_keep = keep_i; tx_sop = sop_i;
      tx_eop = eop_i; tx_kind = kind_i; tx_abort = abort_i;
      do @(posedge link_clk_i); while (!tx_ready);
      @(negedge link_clk_i);
      tx_valid = 1'b0; tx_sop = 1'b0; tx_eop = 1'b0; tx_abort = 1'b0;
    end
  endtask

  task automatic send_pattern_packet(input int unsigned byte_count_i,
                                     input logic kind_i,
                                     input logic abort_i,
                                     input logic [7:0] seed_i);
    int unsigned offset;
    logic [15:0] word_v;
    logic [1:0] keep_v;
    begin
      offset = 0;
      @(negedge link_clk_i);
      // Packet-stream valid is continuous from accepted SOP through accepted
      // EOP.  This BFM therefore changes beats at negedges without inserting
      // the idle half-cycle used by the single-beat helper.
      while (offset < byte_count_i) begin
        word_v[7:0] = seed_i + offset[7:0];
        word_v[15:8] = seed_i + offset[7:0] + 1'b1;
        keep_v = ((offset + 1) == byte_count_i) ? 2'b01 : 2'b11;
        tx_valid = 1'b1;
        tx_data = word_v;
        tx_keep = keep_v;
        tx_sop = (offset == 0);
        tx_eop = (offset + 2 >= byte_count_i);
        tx_kind = kind_i;
        tx_abort = abort_i && tx_eop;
        do @(posedge link_clk_i); while (!tx_ready);
        offset = offset + ((keep_v == 2'b01) ? 1 : 2);
        @(negedge link_clk_i);
      end
      tx_valid = 1'b0;
      tx_sop = 1'b0;
      tx_eop = 1'b0;
      tx_abort = 1'b0;
    end
  endtask

  task automatic stall_rx(input int unsigned cycles);
    begin
      @(negedge link_clk_i); rx_ready = 1'b0;
      repeat (cycles) @(posedge link_clk_i);
      @(negedge link_clk_i); rx_ready = 1'b1;
    end
  endtask
endinterface
