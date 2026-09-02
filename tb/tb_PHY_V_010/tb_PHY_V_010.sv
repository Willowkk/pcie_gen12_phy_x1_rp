`timescale 1ns/1ps
module tb_PHY_V_010;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;

  phy_ltssm_tb_fixture h();
  logic test_done;

  phy_watchdog #(.MAX_CTRL_CYCLES(5000), .TEST_ID("PHY-V-010")) watchdog (
    .ctrl_clk_i(h.ctrl_clk_i), .ctrl_rst_ni(h.ctrl_rst_ni), .done_i(test_done)
  );

  property p_no_receiver_detect_in_l0;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      (h.lt_state_o == LTSSM_L0) |-> !h.lt_gt_detect_req_o;
  endproperty
  assert property (p_no_receiver_detect_in_l0)
    else tb_check(1'b0, "Receiver Detect was issued in L0");

  property p_recovery_blocks_packets;
    @(posedge h.ctrl_clk_i) disable iff (!h.ctrl_rst_ni || !h.port_reset_ni)
      (h.lt_state_o == LTSSM_RECOVERY) |->
        (!h.lt_data_active_o && !h.lt_packet_enable_o);
  endproperty
  assert property (p_recovery_blocks_packets)
    else tb_check(1'b0, "Recovery exposed packet traffic");

  task automatic recover_and_check;
    begin
      h.wait_state(LTSSM_RECOVERY, 16, "qualified link-loss enters Recovery");
      tb_check_eq1(h.lt_data_active_o, 1'b0, "link-loss clears data-active");
      tb_check_eq1(h.lt_link_up_o, 1'b1, "bounded Recovery retains link context");
      h.recovery_training_to_idle();
      tb_check_eq1(h.lt_data_active_o, 1'b1, "successful recovery reopens packet path");
    end
  endtask

  initial begin
    logic [3:0] response;
    tb_start("PHY-V-010", 64'h0000_0000_0000_003f);
    test_done = 1'b0;
    h.reset_and_enter_l0();
    repeat (8) begin
      @(posedge h.ctrl_clk_i);
      tb_check_eq1(h.lt_gt_detect_req_o, 1'b0, "L0 does not poll Receiver Detect");
    end
    tb_hit(0);

    @(negedge h.ctrl_clk_i); h.crr_rx_electrical_idle_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.crr_rx_electrical_idle_i = 1'b0;
    recover_and_check();
    tb_check_eq8(h.lt_entry_reason_o, REASON_IDLE_QUALIFIED,
                 "electrical-idle recovery completes through qualified Idle");
    tb_hit(1);

    @(negedge h.ctrl_clk_i); h.rx_align_loss_evt_i = 1'b1;
    @(negedge h.ctrl_clk_i); h.rx_align_loss_evt_i = 1'b0;
    recover_and_check();
    tb_hit(2);

    @(negedge h.ctrl_clk_i);
    h.rx_packet_active_i = 1'b1;
    h.datapath_recovery_req_i = 1'b1;
    #1ps;
    tb_check_eq1(h.lt_packet_drop_o, 1'b1,
                 "sustained decode-error threshold drops the in-flight packet");
    @(negedge h.ctrl_clk_i);
    h.datapath_recovery_req_i = 1'b0;
    h.rx_packet_active_i = 1'b0;
    recover_and_check();
    tb_hit(3);

    @(negedge h.ctrl_clk_i);
    h.crr_fault_code_i = ERR_GT_PLL_UNLOCK;
    h.crr_fault_i = 1'b1;
    @(posedge h.ctrl_clk_i);
    #1ps;
    tb_check_eq1(h.lt_packet_flush_o, 1'b1, "PLL loss flushes packet context");
    @(negedge h.ctrl_clk_i);
    h.crr_fault_i = 1'b0;
    h.crr_fault_code_i = ERR_NONE;
    h.wait_state(LTSSM_DETECT, 16, "fatal PLL loss returns to Detect");
    tb_check_eq1(h.lt_link_up_o, 1'b0, "fatal PLL loss clears link context");
    tb_check(h.lt_status_evt_valid_o && h.lt_status_evt_fatal_o &&
             (h.lt_status_evt_code_o == ERR_GT_PLL_UNLOCK),
             "PLL loss produces fatal status event");
    tb_hit(4);

    h.drive_detect_to_l0();
    h.issue_mgmt(PHY_CMD_RETRAIN, 8'h00);
    h.wait_state(LTSSM_RECOVERY, 16, "management retrain enters Recovery");
    tb_check_eq8(h.lt_entry_reason_o, REASON_MANAGEMENT_REQUEST,
                 "management retrain records its entry reason");
    h.recovery_training_to_idle();
    h.wait_mgmt_response(response, 32);
    tb_check_eq4(response, MGMT_RSP_OK, "management retrain completes at L0");
    tb_hit(5);

    test_done = 1'b1;
    tb_finish("PHY-V-010");
  end
endmodule
