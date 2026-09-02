`timescale 1ns/1ps
module tb_PHY_V_003;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;
  logic clk=0,rst_n=0;
  always #4ns clk=~clk;
  logic v,r;logic [15:0] din;logic [1:0]keep;logic sop,eop,kind,abort,pending;
  logic [3:0]mode;logic quiesce,packet_en;logic[5:0]state,substate;
  logic[15:0]os_data;logic[1:0]os_k;logic[3:0]os_class;logic os_v,os_done,os_consume;
  logic skp_due;logic[15:0]skp_deadline,dout;logic[1:0]dout_k,lfsr_action;
  logic[3:0]dout_class;logic packet_active,quiesced,idle_evt,err;logic[7:0]err_code;

  phy_tx_framer_scheduler dut(
    .sym_clk_i(clk),.sym_rst_ni(rst_n),.txbuf_pkt_valid_i(v),
    .txbuf_pkt_ready_o(r),.txbuf_pkt_data_i(din),.txbuf_pkt_keep_i(keep),
    .txbuf_pkt_sop_i(sop),.txbuf_pkt_eop_i(eop),.txbuf_pkt_kind_i(kind),
    .txbuf_pkt_abort_i(abort),.txbuf_pending_i(pending),.lt_tx_mode_i(mode),
    .lt_tx_quiesce_i(quiesce),.lt_packet_enable_i(packet_en),
    .lt_state_i(state),.lt_substate_i(substate),.os_tx_data_i(os_data),
    .os_tx_is_k_i(os_k),.os_tx_class_i(os_class),.os_tx_valid_i(os_v),
    .os_tx_done_i(os_done),.os_tx_consume_o(os_consume),.skp_due_i(skp_due),
    .skp_deadline_i(skp_deadline),.tx_sel_data_o(dout),.tx_sel_is_k_o(dout_k),
    .tx_symbol_class_o(dout_class),.tx_lfsr_action_o(lfsr_action),
    .tx_packet_active_o(packet_active),.tx_quiesced_o(quiesced),
    .tx_logical_idle_qualified_evt_o(idle_evt),
    .tx_scheduler_error_evt_o(err),.tx_scheduler_error_code_o(err_code)
  );

  task automatic apply_cycle(input logic iv,input logic[15:0]id,input logic[1:0]ik,
    input logic isop,input logic ieop,input logic ikind,input logic iabort,
    input logic[15:0]exp_data,input logic[1:0]exp_k,input string label);
    begin
      @(negedge clk);v=iv;din=id;keep=ik;sop=isop;eop=ieop;kind=ikind;abort=iabort;
      pending=iv;#1ps;
      tb_check_eq16(dout,exp_data,$sformatf("%s symbols",label));
      tb_check_eq2(dout_k,exp_k,$sformatf("%s K flags",label));
      @(posedge clk);#1ps;
    end
  endtask

  task automatic idle_cycle;
    begin
      apply_cycle(0,0,0,0,0,0,0,16'h0000,2'b00,"logical idle");
      pending=0;
    end
  endtask

  initial begin
    tb_start("PHY-V-003",64'h0000_0000_0000_00ff);
    v=0;din=0;keep=0;sop=0;eop=0;kind=0;abort=0;pending=0;
    mode=TX_MODE_PACKET;quiesce=0;packet_en=1;state=LTSSM_L0;
    substate=LTSSM_SS_L0_ACTIVE;os_data=0;os_k=0;os_class=CHAR_CLASS_TS;
    os_v=0;os_done=0;skp_due=0;skp_deadline=0;
    repeat(3)@(posedge clk);rst_n=1;#1ps;
    tb_check_eq16(dout,16'h0000,"idle data when no packet");
    tb_check_eq2(dout_k,2'b00,"idle is ordinary data");tb_hit(0);

    // First combinational cycle contains STP and byte0; the second contains
    // the saved high payload byte followed by END.
    @(negedge clk);v=1;din=16'h2211;keep=2'b11;sop=1;eop=1;kind=PKT_KIND_TLP;abort=0;pending=1;#1ps;
    tb_check_eq16(dout,{8'h11,K_STP},"TLP STP and first byte");tb_check_eq2(dout_k,2'b01,"STP K lane");
    @(posedge clk);@(negedge clk);v=0;pending=0;#1ps;
    tb_check_eq16(dout,{K_END,8'h22},"even TLP tail and END");tb_check_eq2(dout_k,2'b10,"END K lane");
    @(posedge clk);tb_hit(1);

    @(negedge clk);v=1;din=16'h0033;keep=2'b01;sop=1;eop=1;kind=PKT_KIND_TLP;abort=0;pending=1;#1ps;
    tb_check_eq16(dout,{8'h33,K_STP},"odd TLP STP and byte");
    @(posedge clk);@(negedge clk);v=0;pending=0;#1ps;
    tb_check_eq16(dout,{8'h00,K_END},"odd TLP END paired with idle");
    @(posedge clk);tb_hit(2);

    @(negedge clk);v=1;din=16'h6655;keep=2'b11;sop=1;eop=1;kind=PKT_KIND_DLLP;abort=0;pending=1;#1ps;
    tb_check_eq16(dout,{8'h55,K_SDP},"DLLP uses SDP");
    @(posedge clk);@(negedge clk);v=0;pending=0;#1ps;
    tb_check_eq16(dout,{K_END,8'h66},"DLLP normal END");@(posedge clk);tb_hit(3);

    @(negedge clk);v=1;din=16'h8877;keep=2'b11;sop=1;eop=1;kind=PKT_KIND_TLP;abort=1;pending=1;#1ps;
    tb_check_eq16(dout,{8'h77,K_STP},"aborted TLP still starts with STP");
    @(posedge clk);@(negedge clk);v=0;pending=0;#1ps;
    tb_check_eq16(dout,{K_EDB,8'h88},"TLP abort terminates with EDB");@(posedge clk);tb_hit(4);

    @(negedge clk);v=1;din=16'haa99;keep=2'b11;sop=0;eop=1;kind=PKT_KIND_TLP;abort=0;pending=1;#1ps;
    tb_check(err&&err_code==ERR_TX_FRAMING,"missing SOP is detected");
    tb_check_eq16(dout,{8'h00,K_EDB},"malformed candidate is visibly terminated");
    @(posedge clk);@(negedge clk);v=0;pending=0;tb_hit(5);

    @(negedge clk);v=1;din=16'hc0b0;keep=2'b11;sop=1;eop=0;kind=PKT_KIND_TLP;abort=0;pending=1;#1ps;
    tb_check_eq16(dout,{8'hb0,K_STP},"multi-beat packet start");@(posedge clk);
    @(negedge clk);v=0;pending=1;#1ps;
    tb_check(err&&err_code==ERR_TX_FRAMING,"committed packet bubble is detected");
    tb_check_eq16(dout,{K_EDB,8'hc0},"bubble forces EDB without stalling characters");
    @(posedge clk);@(negedge clk);v=1;din=16'h00d0;keep=2'b01;sop=0;eop=1;#1ps;
    @(posedge clk);@(negedge clk);v=0;pending=0;tb_hit(6);

    os_data=16'h4a4a;os_k=2'b00;os_class=CHAR_CLASS_TS;os_v=1;os_done=1;
    skp_due=1;
    @(negedge clk);v=1;din=16'h0201;keep=2'b11;sop=1;eop=1;pending=1;#1ps;
    tb_check_eq16(dout,16'h4a4a,"state-forced OS wins over SKP and packet");
    tb_check(os_consume&&!r,"packet is not consumed during higher-priority OS");
    @(posedge clk);@(negedge clk);os_v=0;skp_due=0;#1ps;
    tb_check_eq16(dout,{8'h01,K_STP},"packet begins at boundary after OS");
    @(posedge clk);@(negedge clk);v=0;pending=0;#1ps;
    tb_check_eq16(dout,{K_END,8'h02},"packet remains contiguous to END");
    @(posedge clk);tb_hit(7);
    tb_finish("PHY-V-003");
  end
endmodule
