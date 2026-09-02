`timescale 1ns/1ps
module tb_PHY_V_015;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;
  phy_top_harness h();
  logic [31:0] cold_boot_count,retrain_count,fallback_count;
  logic saw_gen1,saw_gen2;
  logic [63:0] tx_bytes,rx_bytes;
  logic [31:0] data_errors;

  task automatic rehearse_board_observation(input logic link_valid_i,
      input logic rate_gen2_i,input logic retrain_i,input logic fallback_i,
      input logic[31:0]tx_bytes_i,input logic[31:0]rx_bytes_i,
      input logic data_error_i);
    begin
      @(posedge h.ctrl_clk);
      if(link_valid_i&&rate_gen2_i)saw_gen2=1;
      if(link_valid_i&&!rate_gen2_i)saw_gen1=1;
      if(retrain_i)retrain_count=retrain_count+1;
      if(fallback_i)fallback_count=fallback_count+1;
      tx_bytes=tx_bytes+tx_bytes_i;rx_bytes=rx_bytes+rx_bytes_i;
      if(data_error_i)data_errors=data_errors+1;
    end
  endtask

  initial begin
    integer boot;
    tb_start("PHY-V-015_PREBOARD_E1",64'h0000_0000_0000_001f);
    cold_boot_count=0;retrain_count=0;fallback_count=0;saw_gen1=0;saw_gen2=0;
    tx_bytes=0;rx_bytes=0;data_errors=0;
    h.release_resets();repeat(48)@(posedge h.ctrl_clk);

    // These are digital rehearsals of the board procedure, not physical
    // power cycles. Each cycle verifies reset-safe PHY outputs and that a new
    // ENABLE transaction is required after port reset.
    for(boot=0;boot<3;boot=boot+1)begin
      h.clocks.pulse_port_reset(3,time'(boot+1));repeat(5)@(posedge h.ctrl_clk);
      cold_boot_count=cold_boot_count+1;
      tb_check(!h.phy_link_up&&!h.phy_data_active,"rehearsed cold start is reset-safe");
      tb_check_eq6(h.phy_state,LTSSM_RESET,"each rehearsed boot returns to Reset");
      h.send_mgmt(PHY_CMD_ENABLE,8'h00,64);repeat(4)@(posedge h.ctrl_clk);
    end
    tb_check_eq32(cold_boot_count,3,"all planned cold-start sequences executed");tb_hit(0);

    // Feed a deterministic synthetic observation stream through the same
    // accounting that the future board harness will populate from ILA/host
    // logs. It validates scenario ordering and counters only.
    rehearse_board_observation(1,0,0,0,32'd4096,32'd4096,0);
    tb_check(saw_gen1&&!saw_gen2,"cold-start observation begins at Gen1");tb_hit(1);
    rehearse_board_observation(1,1,0,0,32'd8192,32'd8192,0);
    tb_check(saw_gen1&&saw_gen2,"synthetic partner negotiated both rates");tb_hit(2);
    rehearse_board_observation(0,1,1,0,0,0,0);
    rehearse_board_observation(1,1,0,0,32'd2048,32'd2048,0);
    tb_check_eq32(retrain_count,1,"retrain scenario was accounted");tb_hit(3);
    rehearse_board_observation(0,1,1,1,0,0,0);
    rehearse_board_observation(1,0,0,0,32'd16384,32'd16384,0);
    tb_check((fallback_count==1)&&saw_gen1,"Gen2 failure fallback rehearsal completed");
    tb_check((tx_bytes==rx_bytes)&&(tx_bytes!=0)&&(data_errors==0),
             "sustained-traffic accounting has matching nonzero byte counts");tb_hit(4);

    if((tb_required_scenarios&~tb_hit_scenarios)!=0||tb_failures!=0||tb_checks==0)
      $fatal(1,"[TB_RESULT] PHY-V-015_PREBOARD_E1 FAIL checks=%0d failures=%0d",
             tb_checks,tb_failures);
    else begin
      $display("[TB_RESULT] PHY-V-015_PREBOARD_E1 PASS checks=%0d",tb_checks);
      $display("[REQ_RESULT] PHY-V-015 E3 NOT_RUN reason=requires_real_fpga_endpoint_ila_and_host_logs");
      $display("[EVIDENCE_BOUNDARY] behavioral_GT_and_digital_cold_start_rehearsal_are_not_board_interoperability");
      $finish;
    end
  end
endmodule
