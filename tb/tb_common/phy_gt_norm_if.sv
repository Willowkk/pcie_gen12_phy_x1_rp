interface phy_gt_norm_if(input logic ctrl_clk_i, input logic sym_clk_i);
  timeunit 1ns;
  timeprecision 1ps;

  logic [15:0] tx_data, rx_data;
  logic [1:0] tx_is_k, rx_is_k, rx_disp_err, rx_code_err, rx_comma;
  logic rx_valid, rx_aligned, rx_realign;
  logic [1:0] clkcor;
  logic [2:0] rxbuf;
  logic txbuf_fault;
  logic detect_req, detect_busy, detect_done, receiver_present;
  logic rate_req, rate_target_gen2, rate_busy, rate_done, rate_fail;
  logic power_req, power_busy, power_done, power_fail;
  logic [1:0] power_state;
  logic tx_ei, tx_ei_active, rx_ei, rx_polarity;
  logic tx_deemphasis, tx_swing, compliance;
  logic [2:0] tx_margin, loopback;
  logic ready, fault;
  logic [7:0] fault_code;

  task automatic drive_safe;
    begin
      tx_data='0; tx_is_k='0; detect_req=0; rate_req=0; rate_target_gen2=0;
      power_req=0; power_state=2'b00; tx_ei=1; rx_polarity=0;
      tx_deemphasis=0; tx_swing=0; tx_margin='0; compliance=0; loopback='0;
    end
  endtask

  task automatic request_detect;
    begin
      @(negedge ctrl_clk_i); detect_req=1;
      do @(posedge ctrl_clk_i); while (!detect_busy && !detect_done && !fault);
      do @(posedge ctrl_clk_i); while (!detect_done && !fault);
      @(negedge ctrl_clk_i); detect_req=0;
    end
  endtask

  task automatic request_rate(input logic gen2_i);
    begin
      @(negedge ctrl_clk_i); rate_target_gen2=gen2_i; rate_req=1;
      do @(posedge ctrl_clk_i); while (!rate_busy && !rate_done && !rate_fail);
      do @(posedge ctrl_clk_i); while (!rate_done && !rate_fail);
      @(negedge ctrl_clk_i); rate_req=0;
    end
  endtask
endinterface
