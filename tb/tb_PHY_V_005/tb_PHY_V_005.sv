`timescale 1ns/1ps
module tb_PHY_V_005;
  import pcie_gen12_phy_pkg::*;
  import golden_8b10b_pkg::*;
  import phy_tb_pkg::*;

  logic clk=0, rst_n=0, polarity;
  logic sym_clk,sym_rst_n;
  logic [15:0] tx_data,rx_data;
  logic [1:0] tx_k,rx_k,rx_disp,rx_code,rx_comma;
  logic rx_valid,rx_aligned,rx_realign,ready,fault;
  logic [7:0] fault_code;
  logic [1:0] unused_clkcor;
  logic [2:0] unused_rxbuf;
  logic unused_txbuf_fault, unused_detect_busy, unused_detect_done;
  logic unused_receiver_present, unused_rate_busy, unused_rate_done;
  logic unused_rate_fail, unused_tx_ei_active, unused_rx_ei;
  logic unused_power_busy, unused_power_done, unused_power_fail;
  always #5ns clk=~clk;

  phy_gt_model_probe #(.LINK_POLARITY_INVERTED(1'b1)) probe (
    .ctrl_clk_i(clk),.ctrl_rst_ni(rst_n),.tx_data_i(tx_data),.tx_is_k_i(tx_k),
    .detect_req_i(1'b0),.rate_req_i(1'b0),.rate_target_i(1'b0),
    .power_req_i(1'b0),.power_state_i(PHY_POWER_P0),.tx_ei_i(1'b0),
    .rx_polarity_i(polarity),.rx_p_i(1'b0),.rx_n_i(1'b1),
    .sym_clk_o(sym_clk),.sym_rst_no(sym_rst_n),.rx_data_o(rx_data),
    .rx_is_k_o(rx_k),.rx_disp_o(rx_disp),.rx_code_o(rx_code),
    .rx_comma_o(rx_comma),.rx_valid_o(rx_valid),.rx_aligned_o(rx_aligned),
    .rx_realign_o(rx_realign),.clkcor_o(unused_clkcor),.rxbuf_o(unused_rxbuf),
    .txbuf_fault_o(unused_txbuf_fault),.detect_busy_o(unused_detect_busy),
    .detect_done_o(unused_detect_done),
    .receiver_present_o(unused_receiver_present),.rate_busy_o(unused_rate_busy),
    .rate_done_o(unused_rate_done),.rate_fail_o(unused_rate_fail),
    .tx_ei_active_o(unused_tx_ei_active),.rx_ei_o(unused_rx_ei),
    .power_busy_o(unused_power_busy),.power_done_o(unused_power_done),
    .power_fail_o(unused_power_fail),.ready_o(ready),.fault_o(fault),
    .fault_code_o(fault_code)
  );

  initial begin
    typedef logic [11:0] dec_result_bits_t;
    integer d,rd,k,c;
    logic [11:0] dut_enc,dut_dec;
    golden_enc_result_t ref_enc;
    golden_dec_result_t ref_dec;
    logic saw_code,saw_disp,saw_comma,saw_inversion_error;
    tb_start("PHY-V-005",64'h0000_0000_0000_003f);
    tx_data={K_COM,K_COM};tx_k=2'b11;polarity=0;
    repeat(3) @(posedge clk);rst_n=1;
    #1ns;

    for(rd=0;rd<2;rd=rd+1) begin
      for(d=0;d<256;d=d+1) begin
        ref_enc=golden_encode_8b10b(d[7:0],1'b0,rd[0]);
        dut_enc=probe.model.encode_8b10b(d[7:0],1'b0,rd[0]);
        tb_check_eq1(dut_enc[11],!ref_enc.legal,"D symbol legality");
        tb_check_eq1(dut_enc[10],ref_enc.rd_out,"D symbol RD output");
        tb_check_eq10(dut_enc[9:0],ref_enc.code,"D symbol code group");
      end
    end
    tb_hit(0);

    for(rd=0;rd<2;rd=rd+1) begin
      for(k=0;k<256;k=k+1) begin
        ref_enc=golden_encode_8b10b(k[7:0],1'b1,rd[0]);
        dut_enc=probe.model.encode_8b10b(k[7:0],1'b1,rd[0]);
        tb_check_eq1(dut_enc[11],!ref_enc.legal,"K legality classification");
        if(ref_enc.legal) begin
          tb_check_eq1(dut_enc[10],ref_enc.rd_out,"legal K RD output");
          tb_check_eq10(dut_enc[9:0],ref_enc.code,"legal K code group");
        end
      end
    end
    tb_hit(1);

    saw_code=0;saw_disp=0;
    for(rd=0;rd<2;rd=rd+1) begin
      for(c=0;c<1024;c=c+1) begin
        ref_dec=golden_decode_8b10b(c[9:0],rd[0]);
        dut_dec=probe.model.decode_8b10b(c[9:0],rd[0]);
        tb_check(dut_dec===dec_result_bits_t'(ref_dec),
                 $sformatf("decode code=%03h rd=%0d",c,rd));
        saw_code|=ref_dec.code_error;saw_disp|=ref_dec.disparity_error;
      end
    end
    tb_check(saw_code,"not-in-table codes were exercised");tb_hit(2);
    tb_check(saw_disp,"wrong-RD codes were exercised");tb_hit(3);

    // The physical lane is inverted in this instance. A single bad character
    // may not establish alignment; applying the trained polarity correction
    // must recover comma/alignment and decoded K sidebands.
    saw_inversion_error=0;
    repeat(24) begin
      @(posedge sym_clk);
      if(rx_valid) saw_inversion_error|=(|rx_code)||(|rx_disp);
    end
    tb_check(saw_inversion_error,
             "uncompensated inverted lane is not silently accepted");
    polarity=1;saw_comma=0;
    repeat(40) begin
      @(posedge sym_clk);
      if(rx_valid&&(|rx_comma)) begin
        saw_comma=1;
        tb_check_eq16(rx_data,{K_COM,K_COM},"polarity corrected COM data");
        tb_check_eq2(rx_k,2'b11,"polarity corrected K flags");
        tb_check_eq2(rx_code,2'b00,"legal comma has no code error");
      end
    end
    tb_check(saw_comma&&rx_aligned,"comma alignment recovered after polarity correction");
    tb_hit(4);
    tb_check(golden_is_comma(K_COM,1'b1)&&!golden_is_comma(K_COM,1'b0),
             "comma reference distinguishes K28.5 from data");tb_hit(5);
    tb_finish("PHY-V-005");
  end
endmodule
