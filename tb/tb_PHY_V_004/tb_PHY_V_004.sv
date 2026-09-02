`timescale 1ns/1ps
module tb_PHY_V_004;
  import pcie_gen12_phy_pkg::*;
  import golden_scrambler_pkg::*;
  import phy_tb_pkg::*;
  logic clk=0,rst_n=0;
  always #4ns clk=~clk;
  logic [15:0] tx_i,tx_o,rx_i,rx_o,tx_state,rx_state;
  logic [1:0] tx_k,tx_k_o,tx_action,rx_k;
  logic [3:0] tx_class,rx_class,rx_actions;
  logic rx_valid_i,rx_valid_o,sync_error;

  phy_scrambler_descrambler dut(
    .sym_clk_i(clk),.sym_rst_ni(rst_n),.tx_scr_data_i(tx_i),
    .tx_scr_is_k_i(tx_k),.tx_scr_class_i(tx_class),
    .tx_scr_lfsr_action_i(tx_action),.tx_scr_data_o(tx_o),
    .tx_scr_is_k_o(tx_k_o),.rx_descr_data_i(rx_i),
    .rx_descr_is_k_i(rx_k),.rx_descr_valid_i(rx_valid_i),
    .rx_descr_class_i(rx_class),.rx_descr_lfsr_action_i(rx_actions),
    .rx_descr_data_o(rx_o),.rx_descr_valid_o(rx_valid_o),
    .tx_scrambler_state_o(tx_state),.rx_descrambler_state_o(rx_state),
    .scrambler_sync_error_o(sync_error)
  );

  function automatic pcie_lfsr_action_t resolve_action(input logic [7:0] data,
      input logic is_k,input logic [3:0] cls,input logic [1:0] pair_action);
    if(is_k&&(data==K_COM))return LFSR_ACTION_RESET;
    if(cls==CHAR_CLASS_SKP)return LFSR_ACTION_HOLD;
    return pcie_lfsr_action_t'(pair_action);
  endfunction

  task automatic check_tx_pair(input logic [15:0] data,input logic [1:0] isk,
      input logic [3:0] cls,input logic [1:0] action,input string label);
    golden_scr_pair_result_t refv;
    logic [3:0] acts;
    logic [15:0] old_state;
    begin
      @(negedge clk);tx_i=data;tx_k=isk;tx_class=cls;tx_action=action;
      old_state=tx_state;
      acts={resolve_action(data[15:8],isk[1],cls,action),
            resolve_action(data[7:0],isk[0],cls,action)};
      refv=golden_scramble_pair(data,isk,pcie_character_class_t'(cls),acts,old_state);
      #1ps;tb_check_eq16(tx_o,refv.data,$sformatf("%s data",label));
      tb_check_eq2(tx_k_o,isk,$sformatf("%s K sideband",label));
      @(posedge clk);#1ps;tb_check_eq16(tx_state,refv.state,
                                       $sformatf("%s state",label));
    end
  endtask

  initial begin
    integer i;
    logic [31:0] prng;
    golden_scr_pair_result_t refv;
    logic [15:0] ref_tx_state,ref_rx_state;
    tb_start("PHY-V-004",64'h0000_0000_0000_00ff);
    tx_i=0;tx_k=0;tx_class=CHAR_CLASS_DATA;tx_action=LFSR_ACTION_ADV8;
    rx_i=0;rx_k=0;rx_valid_i=0;rx_class=CHAR_CLASS_DATA;
    rx_actions={LFSR_ACTION_ADV8,LFSR_ACTION_ADV8};
    repeat(3)@(posedge clk);rst_n=1;#1ps;
    tb_check_eq16(tx_state,16'hffff,"TX reset seed");
    tb_check_eq16(rx_state,16'hffff,"RX reset seed");tb_hit(0);

    check_tx_pair(16'h3412,2'b00,CHAR_CLASS_DATA,LFSR_ACTION_ADV8,"ordinary data");
    tb_hit(1);
    check_tx_pair(16'h0000,2'b00,CHAR_CLASS_LOGICAL_IDLE,LFSR_ACTION_ADV8,
                  "logical idle is scrambled");tb_hit(2);
    check_tx_pair({8'h55,K_STP},2'b01,CHAR_CLASS_FRAME,LFSR_ACTION_ADV8,
                  "K bypass with LFSR advance");tb_hit(3);
    check_tx_pair(16'h4a4a,2'b00,CHAR_CLASS_TS,LFSR_ACTION_BYPASS,
                  "training sequence bypass");
    check_tx_pair(16'hbcad,2'b00,CHAR_CLASS_COMPLIANCE,LFSR_ACTION_BYPASS,
                  "compliance bypass");tb_hit(4);
    check_tx_pair({K_SKP,K_COM},2'b11,CHAR_CLASS_SKP,LFSR_ACTION_HOLD,
                  "COM reset followed by SKP no-advance");
    tb_check_eq16(tx_state,16'hffff,"SKP does not advance reset seed");tb_hit(5);
    check_tx_pair({K_COM,8'h5a},2'b10,CHAR_CLASS_TS,LFSR_ACTION_BYPASS,
                  "upper-byte COM resets after lower character");
    tb_check_eq16(tx_state,16'hffff,"upper COM reset determines next state");tb_hit(6);

    // Restart both directions together and prove TX output is the inverse
    // input of an identically synchronized RX descrambler.
    rst_n=0;repeat(2)@(posedge clk);rst_n=1;#1ps;
    prng=32'h1bad_f00d;ref_tx_state=16'hffff;ref_rx_state=16'hffff;
    for(i=0;i<32;i=i+1)begin
      prng=tb_prng_next(prng);
      @(negedge clk);tx_i=prng[15:0];tx_k=0;tx_class=CHAR_CLASS_DATA;
      tx_action=LFSR_ACTION_ADV8;
      refv=golden_scramble_pair(prng[15:0],2'b00,CHAR_CLASS_DATA,
             {LFSR_ACTION_ADV8,LFSR_ACTION_ADV8},ref_tx_state);
      #1ps;tb_check_eq16(tx_o,refv.data,"TX random vector against bit-serial golden");
      rx_i=tx_o;rx_k=0;rx_valid_i=1;rx_class=CHAR_CLASS_DATA;
      rx_actions={LFSR_ACTION_ADV8,LFSR_ACTION_ADV8};
      #1ps;tb_check_eq16(rx_o,prng[15:0],"TX to RX reversibility");
      @(posedge clk);#1ps;ref_tx_state=refv.state;
      ref_rx_state=golden_advance_bytes(ref_rx_state,2);
      tb_check_eq16(tx_state,ref_tx_state,"TX state tracks golden");
      tb_check_eq16(rx_state,ref_rx_state,"RX state tracks golden");
    end
    @(negedge clk);rx_valid_i=0;
    tb_check_eq1(sync_error,0,"legal sequence does not raise synchronization error");tb_hit(7);
    tb_finish("PHY-V-004");
  end
endmodule
