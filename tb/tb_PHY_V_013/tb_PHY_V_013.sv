`timescale 1ns/1ps
module tb_PHY_V_013;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;
  logic link_clk=0,sym_clk=0,link_rst_n=0,sym_rst_n=0,port_rst_n=0;
  always #2ns link_clk=~link_clk;
  always #4ns sym_clk=~sym_clk;

  logic tx_valid,tx_ready; logic [15:0] tx_data; logic [1:0] tx_keep;
  logic tx_sop,tx_eop,tx_kind,tx_abort,tx_admit,tx_flush;
  logic txo_valid,txo_ready; logic [15:0] txo_data; logic [1:0] txo_keep;
  logic txo_sop,txo_eop,txo_kind,txo_abort,tx_capture,tx_pending;
  logic [7:0] tx_level_unused, rx_level_unused;
  logic tx_error;logic [7:0] tx_error_code,tx_error_code_seen;logic tx_error_seen;

  logic rxi_valid,rxi_ready;logic [15:0] rxi_data;logic [1:0] rxi_keep;
  logic rxi_sop,rxi_eop,rxi_kind,rxi_abort,rxi_drop,rx_flush;
  logic rxo_valid,rxo_ready;logic [15:0] rxo_data;logic [1:0] rxo_keep;
  logic rxo_sop,rxo_eop,rxo_kind,rxo_abort;
  logic rx_overflow,rx_drop_evt,rx_bp_evt;
  logic rx_overflow_seen,rx_drop_seen,rx_bp_seen;

  phy_tx_packet_buffer_cdc #(.PHY_MAX_PACKET_BYTES(8),.PHY_TX_PACKET_SLOTS(2)) tx_dut (
    .link_clk_i(link_clk),.link_rst_ni(link_rst_n),.port_reset_ni(port_rst_n),
    .sym_clk_i(sym_clk),.sym_rst_ni(sym_rst_n),.dll_tx_valid_i(tx_valid),
    .dll_tx_ready_o(tx_ready),.dll_tx_data_i(tx_data),.dll_tx_keep_i(tx_keep),
    .dll_tx_sop_i(tx_sop),.dll_tx_eop_i(tx_eop),.dll_tx_kind_i(tx_kind),
    .dll_tx_abort_i(tx_abort),.txbuf_admission_enable_i(tx_admit),
    .txbuf_flush_i(tx_flush),.txbuf_pkt_valid_o(txo_valid),
    .txbuf_pkt_ready_i(txo_ready),.txbuf_pkt_data_o(txo_data),
    .txbuf_pkt_keep_o(txo_keep),.txbuf_pkt_sop_o(txo_sop),
    .txbuf_pkt_eop_o(txo_eop),.txbuf_pkt_kind_o(txo_kind),
    .txbuf_pkt_abort_o(txo_abort),.txbuf_capture_active_o(tx_capture),
    .txbuf_pending_o(tx_pending),.txbuf_error_evt_o(tx_error),
    .txbuf_error_code_o(tx_error_code),.txbuf_level_o(tx_level_unused)
  );

  phy_rx_packet_buffer_cdc #(.PHY_MAX_PACKET_BYTES(8),.PHY_RX_PACKET_SLOTS(2),
      .PHY_RX_BACKPRESSURE_MAX_CYCLES(4)) rx_dut (
    .sym_clk_i(sym_clk),.sym_rst_ni(sym_rst_n),.port_reset_ni(port_rst_n),
    .rxbuf_flush_i(rx_flush),
    .link_clk_i(link_clk),.link_rst_ni(link_rst_n),.rxbuf_pkt_valid_i(rxi_valid),
    .rxbuf_pkt_ready_o(rxi_ready),.rxbuf_pkt_data_i(rxi_data),
    .rxbuf_pkt_keep_i(rxi_keep),.rxbuf_pkt_sop_i(rxi_sop),
    .rxbuf_pkt_eop_i(rxi_eop),.rxbuf_pkt_kind_i(rxi_kind),
    .rxbuf_pkt_abort_i(rxi_abort),.rxbuf_drop_i(rxi_drop),
    .dll_rx_valid_o(rxo_valid),.dll_rx_ready_i(rxo_ready),
    .dll_rx_data_o(rxo_data),.dll_rx_keep_o(rxo_keep),
    .dll_rx_sop_o(rxo_sop),.dll_rx_eop_o(rxo_eop),
    .dll_rx_kind_o(rxo_kind),.dll_rx_abort_o(rxo_abort),
    .rxbuf_overflow_evt_o(rx_overflow),
    .rxbuf_candidate_drop_evt_o(rx_drop_evt),
    .rxbuf_backpressure_timeout_evt_o(rx_bp_evt),.rxbuf_level_o(rx_level_unused)
  );

  always @(posedge link_clk) begin
    if(tx_error)begin tx_error_seen<=1;tx_error_code_seen<=tx_error_code;end
    if(rx_bp_evt)rx_bp_seen<=1;
  end
  always @(posedge sym_clk) begin
    if(rx_overflow)rx_overflow_seen<=1;
    if(rx_drop_evt)rx_drop_seen<=1;
  end

  task automatic tx_beat(input logic [15:0] data_i,input logic [1:0] keep_i,
                         input logic sop_i,input logic eop_i,input logic kind_i,
                         input logic abort_i);
    begin
      @(negedge link_clk);tx_data=data_i;tx_keep=keep_i;tx_sop=sop_i;
      tx_eop=eop_i;tx_kind=kind_i;tx_abort=abort_i;tx_valid=1;
      do @(posedge link_clk);while(!tx_ready);
      @(negedge link_clk);tx_valid=0;tx_sop=0;tx_eop=0;tx_abort=0;
    end
  endtask

  task automatic rx_beat(input logic [15:0] data_i,input logic [1:0] keep_i,
                         input logic sop_i,input logic eop_i,input logic kind_i,
                         input logic abort_i);
    begin
      @(negedge sym_clk);rxi_data=data_i;rxi_keep=keep_i;rxi_sop=sop_i;
      rxi_eop=eop_i;rxi_kind=kind_i;rxi_abort=abort_i;rxi_valid=1;
      @(posedge sym_clk);
      tb_check(rxi_ready,"RX serial-side candidate had reserved capacity");
      @(negedge sym_clk);rxi_valid=0;rxi_sop=0;rxi_eop=0;rxi_abort=0;
    end
  endtask

  task automatic tx_pattern_packet(input integer byte_count,
                                   input logic [7:0] seed,
                                   input logic kind_i);
    integer offset;
    logic [1:0] beat_keep;
    begin
      offset=0;
      @(negedge link_clk);
      while(offset<byte_count)begin
        beat_keep=((offset+1)==byte_count)?2'b01:2'b11;
        tx_data={seed+offset[7:0]+1'b1,seed+offset[7:0]};
        tx_keep=beat_keep;tx_sop=(offset==0);tx_eop=(offset+2>=byte_count);
        tx_kind=kind_i;tx_abort=0;tx_valid=1;
        do @(posedge link_clk);while(!tx_ready);
        offset=offset+((beat_keep==2'b01)?1:2);
        @(negedge link_clk);
      end
      tx_valid=0;tx_sop=0;tx_eop=0;tx_abort=0;
    end
  endtask

  task automatic rx_pattern_packet(input integer byte_count,
                                   input logic [7:0] seed,
                                   input logic kind_i);
    integer offset;
    logic [1:0] beat_keep;
    begin
      offset=0;
      @(negedge sym_clk);
      while(offset<byte_count)begin
        beat_keep=((offset+1)==byte_count)?2'b01:2'b11;
        rxi_data={seed+offset[7:0]+1'b1,seed+offset[7:0]};
        rxi_keep=beat_keep;rxi_sop=(offset==0);rxi_eop=(offset+2>=byte_count);
        rxi_kind=kind_i;rxi_abort=0;rxi_valid=1;
        @(posedge sym_clk);tb_check(rxi_ready,"RX contiguous candidate accepted");
        offset=offset+((beat_keep==2'b01)?1:2);
        @(negedge sym_clk);
      end
      rxi_valid=0;rxi_sop=0;rxi_eop=0;rxi_abort=0;
    end
  endtask

  task automatic wait_txo(input logic [15:0] data_e,input logic [1:0] keep_e,
                          input logic sop_e,input logic eop_e,input logic kind_e,
                          input logic abort_e);
    integer age;
    begin
      age=0;while(!txo_valid&&age<30)begin @(posedge sym_clk);age=age+1;end
      tb_check(txo_valid,"committed TX beat became visible");
      tb_check_eq16(txo_data,data_e,"TX CDC payload");tb_check_eq2(txo_keep,keep_e,"TX keep");
      tb_check_eq1(txo_sop,sop_e,"TX SOP");tb_check_eq1(txo_eop,eop_e,"TX EOP");
      tb_check_eq1(txo_kind,kind_e,"TX kind");tb_check_eq1(txo_abort,abort_e,"TX abort");
      @(posedge sym_clk);
      @(negedge sym_clk);
    end
  endtask

  task automatic wait_rxo(input logic [15:0] data_e,input logic [1:0] keep_e,
                          input logic sop_e,input logic eop_e,input logic kind_e,
                          input logic abort_e);
    integer age;
    begin
      age=0;while(!rxo_valid&&age<40)begin @(posedge link_clk);age=age+1;end
      tb_check(rxo_valid,"committed RX beat became visible");
      tb_check_eq16(rxo_data,data_e,"RX CDC payload");tb_check_eq2(rxo_keep,keep_e,"RX keep");
      tb_check_eq1(rxo_sop,sop_e,"RX SOP");tb_check_eq1(rxo_eop,eop_e,"RX EOP");
      tb_check_eq1(rxo_kind,kind_e,"RX kind");tb_check_eq1(rxo_abort,abort_e,"RX abort");
      @(posedge link_clk);
      @(negedge link_clk);
    end
  endtask

  initial begin
    integer i;
    tb_start("PHY-V-013",64'h0000_0000_0000_00ff);
    tx_valid=0;tx_data=0;tx_keep=0;tx_sop=0;tx_eop=0;tx_kind=0;tx_abort=0;
    tx_admit=0;tx_flush=0;txo_ready=0;rxi_valid=0;rxi_data=0;rxi_keep=0;
    rxi_sop=0;rxi_eop=0;rxi_kind=0;rxi_abort=0;rxi_drop=0;rx_flush=0;rxo_ready=1;
    tx_error_seen=0;tx_error_code_seen=ERR_NONE;
    rx_overflow_seen=0;rx_drop_seen=0;rx_bp_seen=0;
    repeat(4)@(posedge link_clk);link_rst_n=1;sym_rst_n=1;port_rst_n=1;
    repeat(8)@(posedge link_clk);

    @(negedge link_clk);tx_valid=1;tx_sop=1;tx_eop=1;tx_keep=2'b01;tx_data=16'h0011;
    @(posedge link_clk);tb_check_eq1(tx_ready,0,"non-L0 admission rejects a new SOP");
    @(negedge link_clk);tx_valid=0;tx_sop=0;tx_eop=0;tx_admit=1;tb_hit(0);

    // Nominal multi-beat packets obey the frozen no-bubble contract: valid
    // remains asserted and beat two follows on the next link-clock edge.
    @(negedge link_clk);tx_data=16'h2211;tx_keep=2'b11;tx_sop=1;tx_eop=0;
    tx_kind=PKT_KIND_TLP;tx_abort=0;tx_valid=1;
    @(posedge link_clk);tb_check(tx_ready,"TX first beat accepted");
    @(negedge link_clk);
    tb_check_eq1(txo_valid,0,"TX packet is hidden before EOP commit");
    tx_data=16'h0033;tx_keep=2'b01;tx_sop=0;tx_eop=1;
    @(posedge link_clk);tb_check(tx_ready,"TX consecutive EOP beat accepted");
    @(negedge link_clk);tx_valid=0;tx_eop=0;
    repeat(6)@(posedge sym_clk);txo_ready=1;
    wait_txo(16'h2211,2'b11,1,0,PKT_KIND_TLP,0);
    wait_txo(16'h0033,2'b01,0,1,PKT_KIND_TLP,0);tb_hit(1);

    // Exact configured maximum length commits; the test holds the consumer
    // so all four beats remain available for deterministic checking.
    txo_ready=0;
    tx_pattern_packet(8,8'h40,PKT_KIND_TLP);
    repeat(6)@(posedge sym_clk);tb_check(txo_valid&&txo_sop,"maximum TX frame commits whole");
    txo_ready=1;
    wait_txo(16'h4140,2'b11,1,0,PKT_KIND_TLP,0);
    wait_txo(16'h4342,2'b11,0,0,PKT_KIND_TLP,0);
    wait_txo(16'h4544,2'b11,0,0,PKT_KIND_TLP,0);
    wait_txo(16'h4746,2'b11,0,1,PKT_KIND_TLP,0);

    tx_beat(16'h55aa,2'b11,1,0,PKT_KIND_TLP,0);
    repeat(2)@(posedge link_clk);
    tb_check(tx_error_seen,"packet bubble produces ERR_TX_FRAMING");tb_hit(2);
    tb_check_eq8(tx_error_code_seen,ERR_TX_FRAMING,"bubble error code");
    tx_beat(16'h0000,2'b01,0,1,PKT_KIND_TLP,0);
    repeat(2)@(posedge link_clk);@(negedge link_clk);tx_error_seen=0;
    tx_beat(16'h7788,2'b11,1,1,PKT_KIND_DLLP,1);
    repeat(2)@(posedge link_clk);
    tb_check(tx_error_seen,"DLLP abort is rejected");
    tb_check_eq8(tx_error_code_seen,ERR_TX_FRAMING,"DLLP abort error code");tb_hit(3);

    rxo_ready=0;
    @(negedge sym_clk);rxi_data=16'ha1a0;rxi_keep=2'b11;rxi_sop=1;
    rxi_eop=0;rxi_kind=PKT_KIND_TLP;rxi_abort=0;rxi_valid=1;
    @(posedge sym_clk);tb_check(rxi_ready,"RX first beat accepted");
    @(negedge sym_clk);tb_check_eq1(rxo_valid,0,"RX packet hidden before END/EDB");
    rxi_data=16'h00a2;rxi_keep=2'b01;rxi_sop=0;rxi_eop=1;
    @(posedge sym_clk);tb_check(rxi_ready,"RX consecutive EOP beat accepted");
    @(negedge sym_clk);rxi_valid=0;rxi_eop=0;
    repeat(8)@(posedge link_clk);tb_check(rxo_valid&&rxo_sop,"RX packet appears only after commit");
    rxo_ready=1;wait_rxo(16'ha1a0,2'b11,1,0,PKT_KIND_TLP,0);
    wait_rxo(16'h00a2,2'b01,0,1,PKT_KIND_TLP,0);tb_hit(4);

    rxo_ready=0;
    rx_pattern_packet(8,8'h60,PKT_KIND_TLP);
    repeat(8)@(posedge link_clk);tb_check(rxo_valid&&rxo_sop,"maximum RX frame commits whole");
    rxo_ready=1;
    wait_rxo(16'h6160,2'b11,1,0,PKT_KIND_TLP,0);
    wait_rxo(16'h6362,2'b11,0,0,PKT_KIND_TLP,0);
    wait_rxo(16'h6564,2'b11,0,0,PKT_KIND_TLP,0);
    wait_rxo(16'h6766,2'b11,0,1,PKT_KIND_TLP,0);

    rx_beat(16'h00e1,2'b01,1,1,PKT_KIND_TLP,1);
    wait_rxo(16'h00e1,2'b01,1,1,PKT_KIND_TLP,1);tb_hit(5);

    rx_beat(16'h1234,2'b11,1,0,PKT_KIND_TLP,0);
    @(negedge sym_clk);rxi_drop=1;@(posedge sym_clk);@(negedge sym_clk);rxi_drop=0;
    repeat(12)@(posedge link_clk);
    tb_check(rx_drop_seen&&!rxo_valid,"poisoned RX candidate is dropped atomically");tb_hit(6);

    rx_beat(16'hbeef,2'b11,1,1,PKT_KIND_DLLP,0);
    rxo_ready=0;while(!rxo_valid)@(posedge link_clk);
    repeat(3) begin
      @(posedge link_clk);
      tb_check_eq16(rxo_data,16'hbeef,"RX data stable under bounded backpressure");
      tb_check(rxo_sop&&rxo_eop,"RX boundary stable under bounded backpressure");
    end
    tb_check(!rx_bp_seen,"bounded backpressure does not report timeout");
    repeat(3)@(posedge link_clk);
    tb_check(rx_bp_seen,"backpressure beyond contract reports timeout");
    rxo_ready=1;tb_hit(7);

    tb_finish("PHY-V-013");
  end
endmodule
