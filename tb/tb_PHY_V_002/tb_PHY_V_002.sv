`timescale 1ns/1ps
module tb_PHY_V_002;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;
  logic clk=0, rst_n=0;
  always #5ns clk=~clk;

  logic req_p,req_a,req_i,req_t;
  logic busy_p,done_p,present_p,ready_p,fault_p; logic [7:0] fcode_p;
  logic busy_a,done_a,present_a,ready_a,fault_a; logic [7:0] fcode_a;
  logic busy_i,done_i,present_i,ready_i,fault_i; logic [7:0] fcode_i;
  logic busy_t,done_t,present_t,ready_t,fault_t; logic [7:0] fcode_t;
  logic [3:0] unused_sym_clk, unused_sym_rst_n, unused_rx_valid, unused_rx_aligned;
  logic [3:0] unused_rx_realign, unused_txbuf_fault, unused_rate_busy, unused_rate_done;
  logic [3:0] unused_rate_fail, unused_tx_ei_active, unused_rx_ei, unused_power_busy;
  logic [3:0] unused_power_done, unused_power_fail;
  logic [63:0] unused_rx_data;
  logic [7:0] unused_rx_is_k, unused_rx_disp, unused_rx_code, unused_rx_comma;
  logic [7:0] unused_clkcor;
  logic [11:0] unused_rxbuf;

  phy_gt_model_probe #(.DETECT_STATUS(3'b011)) present_case (
    .ctrl_clk_i(clk),.ctrl_rst_ni(rst_n),.tx_data_i(16'h0000),.tx_is_k_i(2'b00),
    .detect_req_i(req_p),.rate_req_i(1'b0),.rate_target_i(1'b0),
    .power_req_i(1'b0),.power_state_i(PHY_POWER_P0),.tx_ei_i(1'b1),
    .rx_polarity_i(1'b0),.rx_p_i(1'b0),.rx_n_i(1'b1),
    .sym_clk_o(unused_sym_clk[0]),.sym_rst_no(unused_sym_rst_n[0]),
    .rx_data_o(unused_rx_data[15:0]),.rx_is_k_o(unused_rx_is_k[1:0]),
    .rx_disp_o(unused_rx_disp[1:0]),.rx_code_o(unused_rx_code[1:0]),
    .rx_comma_o(unused_rx_comma[1:0]),.rx_valid_o(unused_rx_valid[0]),
    .rx_aligned_o(unused_rx_aligned[0]),.rx_realign_o(unused_rx_realign[0]),
    .clkcor_o(unused_clkcor[1:0]),.rxbuf_o(unused_rxbuf[2:0]),
    .txbuf_fault_o(unused_txbuf_fault[0]),
    .detect_busy_o(busy_p),.detect_done_o(done_p),
    .receiver_present_o(present_p),.rate_busy_o(unused_rate_busy[0]),
    .rate_done_o(unused_rate_done[0]),.rate_fail_o(unused_rate_fail[0]),
    .tx_ei_active_o(unused_tx_ei_active[0]),.rx_ei_o(unused_rx_ei[0]),
    .power_busy_o(unused_power_busy[0]),.power_done_o(unused_power_done[0]),
    .power_fail_o(unused_power_fail[0]),.ready_o(ready_p),.fault_o(fault_p),
    .fault_code_o(fcode_p)
  );
  phy_gt_model_probe #(.DETECT_STATUS(3'b000)) absent_case (
    .ctrl_clk_i(clk),.ctrl_rst_ni(rst_n),.tx_data_i(16'h0000),.tx_is_k_i(2'b00),
    .detect_req_i(req_a),.rate_req_i(1'b0),.rate_target_i(1'b0),
    .power_req_i(1'b0),.power_state_i(PHY_POWER_P0),.tx_ei_i(1'b1),
    .rx_polarity_i(1'b0),.rx_p_i(1'b0),.rx_n_i(1'b1),
    .sym_clk_o(unused_sym_clk[1]),.sym_rst_no(unused_sym_rst_n[1]),
    .rx_data_o(unused_rx_data[31:16]),.rx_is_k_o(unused_rx_is_k[3:2]),
    .rx_disp_o(unused_rx_disp[3:2]),.rx_code_o(unused_rx_code[3:2]),
    .rx_comma_o(unused_rx_comma[3:2]),.rx_valid_o(unused_rx_valid[1]),
    .rx_aligned_o(unused_rx_aligned[1]),.rx_realign_o(unused_rx_realign[1]),
    .clkcor_o(unused_clkcor[3:2]),.rxbuf_o(unused_rxbuf[5:3]),
    .txbuf_fault_o(unused_txbuf_fault[1]),
    .detect_busy_o(busy_a),.detect_done_o(done_a),
    .receiver_present_o(present_a),.rate_busy_o(unused_rate_busy[1]),
    .rate_done_o(unused_rate_done[1]),.rate_fail_o(unused_rate_fail[1]),
    .tx_ei_active_o(unused_tx_ei_active[1]),.rx_ei_o(unused_rx_ei[1]),
    .power_busy_o(unused_power_busy[1]),.power_done_o(unused_power_done[1]),
    .power_fail_o(unused_power_fail[1]),.ready_o(ready_a),.fault_o(fault_a),
    .fault_code_o(fcode_a)
  );
  phy_gt_model_probe #(.DETECT_STATUS(3'b101)) illegal_case (
    .ctrl_clk_i(clk),.ctrl_rst_ni(rst_n),.tx_data_i(16'h0000),.tx_is_k_i(2'b00),
    .detect_req_i(req_i),.rate_req_i(1'b0),.rate_target_i(1'b0),
    .power_req_i(1'b0),.power_state_i(PHY_POWER_P0),.tx_ei_i(1'b1),
    .rx_polarity_i(1'b0),.rx_p_i(1'b0),.rx_n_i(1'b1),
    .sym_clk_o(unused_sym_clk[2]),.sym_rst_no(unused_sym_rst_n[2]),
    .rx_data_o(unused_rx_data[47:32]),.rx_is_k_o(unused_rx_is_k[5:4]),
    .rx_disp_o(unused_rx_disp[5:4]),.rx_code_o(unused_rx_code[5:4]),
    .rx_comma_o(unused_rx_comma[5:4]),.rx_valid_o(unused_rx_valid[2]),
    .rx_aligned_o(unused_rx_aligned[2]),.rx_realign_o(unused_rx_realign[2]),
    .clkcor_o(unused_clkcor[5:4]),.rxbuf_o(unused_rxbuf[8:6]),
    .txbuf_fault_o(unused_txbuf_fault[2]),
    .detect_busy_o(busy_i),.detect_done_o(done_i),
    .receiver_present_o(present_i),.rate_busy_o(unused_rate_busy[2]),
    .rate_done_o(unused_rate_done[2]),.rate_fail_o(unused_rate_fail[2]),
    .tx_ei_active_o(unused_tx_ei_active[2]),.rx_ei_o(unused_rx_ei[2]),
    .power_busy_o(unused_power_busy[2]),.power_done_o(unused_power_done[2]),
    .power_fail_o(unused_power_fail[2]),.ready_o(ready_i),.fault_o(fault_i),
    .fault_code_o(fcode_i)
  );
  phy_gt_model_probe #(.DETECT_STATUS(3'b011),.DETECT_TIMEOUT(1'b1),
      .DETECT_TIMEOUT_CYCLES(12)) timeout_case (
    .ctrl_clk_i(clk),.ctrl_rst_ni(rst_n),.tx_data_i(16'h0000),.tx_is_k_i(2'b00),
    .detect_req_i(req_t),.rate_req_i(1'b0),.rate_target_i(1'b0),
    .power_req_i(1'b0),.power_state_i(PHY_POWER_P0),.tx_ei_i(1'b1),
    .rx_polarity_i(1'b0),.rx_p_i(1'b0),.rx_n_i(1'b1),
    .sym_clk_o(unused_sym_clk[3]),.sym_rst_no(unused_sym_rst_n[3]),
    .rx_data_o(unused_rx_data[63:48]),.rx_is_k_o(unused_rx_is_k[7:6]),
    .rx_disp_o(unused_rx_disp[7:6]),.rx_code_o(unused_rx_code[7:6]),
    .rx_comma_o(unused_rx_comma[7:6]),.rx_valid_o(unused_rx_valid[3]),
    .rx_aligned_o(unused_rx_aligned[3]),.rx_realign_o(unused_rx_realign[3]),
    .clkcor_o(unused_clkcor[7:6]),.rxbuf_o(unused_rxbuf[11:9]),
    .txbuf_fault_o(unused_txbuf_fault[3]),
    .detect_busy_o(busy_t),.detect_done_o(done_t),
    .receiver_present_o(present_t),.rate_busy_o(unused_rate_busy[3]),
    .rate_done_o(unused_rate_done[3]),.rate_fail_o(unused_rate_fail[3]),
    .tx_ei_active_o(unused_tx_ei_active[3]),.rx_ei_o(unused_rx_ei[3]),
    .power_busy_o(unused_power_busy[3]),.power_done_o(unused_power_done[3]),
    .power_fail_o(unused_power_fail[3]),.ready_o(ready_t),.fault_o(fault_t),
    .fault_code_o(fcode_t)
  );

  initial begin
    integer age;
    logic seen;
    tb_start("PHY-V-002",64'hf);
    req_p=0;req_a=0;req_i=0;req_t=0;
    repeat(3) @(posedge clk); rst_n=1;
    repeat(8) @(posedge clk);
    tb_check(ready_p&&ready_a&&ready_i&&ready_t,"all model instances reached ready");

    @(negedge clk); req_p=1; seen=0;
    for(age=0;age<40;age=age+1) begin
      @(posedge clk);
      if(done_p) begin
        seen=1; tb_check_eq1(present_p,1,"present result is atomic with done");
      end else tb_check_eq1(present_p,0,"present is not a persistent status");
    end
    @(negedge clk);req_p=0;
    tb_check(seen&&!fault_p,"present transaction completed without fault");tb_hit(0);

    @(negedge clk);req_a=1;seen=0;
    for(age=0;age<40;age=age+1) begin @(posedge clk); if(done_a) begin
      seen=1;tb_check_eq1(present_a,0,"absent result accompanies done");end end
    @(negedge clk);req_a=0;
    tb_check(seen&&!fault_a,"absent transaction completed normally");tb_hit(1);

    @(negedge clk);req_i=1;seen=0;
    for(age=0;age<40;age=age+1) begin @(posedge clk); if(done_i) begin
      seen=1;tb_check(!present_i,"illegal status is never reported present");
      tb_check(fault_i&&(fcode_i!=ERR_NONE),"illegal native status raises fault");end end
    @(negedge clk);req_i=0;tb_check(seen,"illegal transaction terminates");tb_hit(2);

    @(negedge clk);req_t=1;seen=0;
    for(age=0;age<80;age=age+1) begin @(posedge clk); if(done_t) begin
      seen=1;tb_check(fault_t&&!present_t,"timeout terminates with fault and absent result");
      tb_check_eq8(fcode_t,ERR_DETECT_TIMEOUT,"timeout fault code");end end
    @(negedge clk);req_t=0;tb_check(seen,"timeout is bounded");tb_hit(3);
    tb_finish("PHY-V-002");
  end
endmodule
