`timescale 1ns/1ps

module tb_PHY_V_014;
  import pcie_gen12_phy_pkg::*;
  import phy_tb_pkg::*;

  logic clk = 1'b0, lclk = 1'b0;
  logic rst_n = 1'b0, lrst_n = 1'b0, port_rst_n = 1'b0;
  always #5ns clk = ~clk;
  always #2ns lclk = ~lclk;

  logic ready_i;
  logic [5:0] state_i, sub_i, timer_id_i;
  logic [7:0] reason_i, retry_i;
  logic [31:0] timer_value_i;
  logic rate_i, link_i, active_i, lock_i, status_clear_i;
  logic debug_counter_seed_valid_i;
  logic [4:0] debug_counter_seed_index_i;
  logic [31:0] debug_counter_seed_value_i;
  logic [15:0] level_i;
  logic ev_v, ev_r;
  logic [3:0] ev_src;
  logic [7:0] ev_code;
  logic [31:0] ev_info;
  logic ev_fatal;

  logic gt_v, buffer_v, align_v, framing_v, correctable_v;
  logic [7:0] gt_code, buffer_code, align_code, framing_code;
  logic [7:0] correctable_code;
  logic [31:0] gt_info, buffer_info, align_info, framing_info;
  logic [31:0] correctable_info;

  logic ready_o, link_o, active_o, rate_o;
  logic [5:0] state_o, sub_o;
  logic [7:0] reason_o;
  logic lock_o, dll_link, dll_active, dll_rate, link_down;
  logic err_v, err_r;
  logic [7:0] err_code;
  logic [31:0] err_info;
  logic csr_v, csr_r, csr_w;
  logic [11:0] csr_addr;
  logic [31:0] csr_wdata;
  logic [3:0] csr_strb;
  logic csr_rsp_v, csr_rsp_r;
  logic [31:0] csr_rdata;
  logic csr_rsp_err;

  phy_status_error dut (
    .ctrl_clk_i(clk), .ctrl_rst_ni(rst_n), .port_reset_ni(port_rst_n),
    .link_clk_i(lclk), .link_rst_ni(lrst_n),
    .status_ready_i(ready_i), .status_state_i(state_i),
    .status_substate_i(sub_i), .status_reason_i(reason_i),
    .status_rate_i(rate_i), .status_link_up_i(link_i),
    .status_data_active_i(active_i), .status_rx_lock_i(lock_i),
    .status_buffer_level_i(level_i), .status_timer_id_i(timer_id_i),
    .status_timer_value_i(timer_value_i), .status_retry_count_i(retry_i),
    .status_clear_i(status_clear_i),
    .status_debug_counter_seed_valid_i(debug_counter_seed_valid_i),
    .status_debug_counter_seed_index_i(debug_counter_seed_index_i),
    .status_debug_counter_seed_value_i(debug_counter_seed_value_i),
    .status_evt_valid_i(ev_v), .status_evt_source_i(ev_src),
    .status_evt_code_i(ev_code), .status_evt_info_i(ev_info),
    .status_evt_fatal_i(ev_fatal), .status_evt_ready_o(ev_r),
    .status_gt_fatal_evt_valid_i(gt_v),
    .status_gt_fatal_evt_code_i(gt_code),
    .status_gt_fatal_evt_info_i(gt_info),
    .status_buffer_fatal_evt_valid_i(buffer_v),
    .status_buffer_fatal_evt_code_i(buffer_code),
    .status_buffer_fatal_evt_info_i(buffer_info),
    .status_alignment_evt_valid_i(align_v),
    .status_alignment_evt_code_i(align_code),
    .status_alignment_evt_info_i(align_info),
    .status_framing_evt_valid_i(framing_v),
    .status_framing_evt_code_i(framing_code),
    .status_framing_evt_info_i(framing_info),
    .status_correctable_evt_valid_i(correctable_v),
    .status_correctable_evt_code_i(correctable_code),
    .status_correctable_evt_info_i(correctable_info),
    .phy_ready_o(ready_o), .phy_link_up_o(link_o),
    .phy_data_active_o(active_o), .phy_current_rate_o(rate_o),
    .phy_ltssm_state_o(state_o), .phy_ltssm_substate_o(sub_o),
    .phy_state_reason_o(reason_o), .phy_rx_locked_o(lock_o),
    .phy_dll_link_up_o(dll_link), .phy_dll_data_active_o(dll_active),
    .phy_dll_current_rate_o(dll_rate), .phy_dll_link_down_evt_o(link_down),
    .phy_err_valid_o(err_v), .phy_err_ready_i(err_r),
    .phy_err_code_o(err_code), .phy_err_info_o(err_info),
    .phy_csr_req_valid_i(csr_v), .phy_csr_req_ready_o(csr_r),
    .phy_csr_req_write_i(csr_w), .phy_csr_req_addr_i(csr_addr),
    .phy_csr_req_wdata_i(csr_wdata), .phy_csr_req_wstrb_i(csr_strb),
    .phy_csr_rsp_valid_o(csr_rsp_v), .phy_csr_rsp_ready_i(csr_rsp_r),
    .phy_csr_rsp_rdata_o(csr_rdata), .phy_csr_rsp_error_o(csr_rsp_err)
  );

  task automatic send_event(input logic [7:0] code_i,
                            input logic [31:0] info_i,
                            input logic [3:0] source_i);
    begin
      @(negedge clk);
      ev_code = code_i;
      ev_info = info_i;
      ev_src = source_i;
      ev_fatal = (golden_error_priority(code_i) < 2);
      ev_v = 1'b1;
      do @(posedge clk); while (!ev_r);
      @(negedge clk);
      ev_v = 1'b0;
    end
  endtask

  task automatic csr_read(input logic [11:0] addr_i,
                          output logic [31:0] data_o,
                          output logic bad_o);
    begin
      @(negedge clk);
      csr_addr = addr_i;
      csr_w = 1'b0;
      csr_v = 1'b1;
      do @(posedge clk); while (!csr_r);
      @(negedge clk);
      csr_v = 1'b0;
      while (!csr_rsp_v) @(posedge clk);
      #1ps;
      data_o = csr_rdata;
      bad_o = csr_rsp_err;
    end
  endtask

  task automatic csr_write(input logic [11:0] addr_i,
                           input logic [31:0] data_i,
                           input logic [3:0] strb_i,
                           output logic bad_o);
    begin
      @(negedge clk);
      csr_addr = addr_i;
      csr_w = 1'b1;
      csr_wdata = data_i;
      csr_strb = strb_i;
      csr_v = 1'b1;
      do @(posedge clk); while (!csr_r);
      @(negedge clk);
      csr_v = 1'b0;
      while (!csr_rsp_v) @(posedge clk);
      #1ps;
      bad_o = csr_rsp_err;
    end
  endtask

  task automatic clear_observation;
    begin
      @(negedge clk);
      status_clear_i = 1'b1;
      @(posedge clk);
      @(negedge clk);
      status_clear_i = 1'b0;
      repeat (2) @(posedge clk);
    end
  endtask

  task automatic pulse_all_categories;
    begin
      @(negedge clk);
      gt_v = 1'b1;
      buffer_v = 1'b1;
      align_v = 1'b1;
      framing_v = 1'b1;
      correctable_v = 1'b1;
      @(posedge clk);
      @(negedge clk);
      gt_v = 1'b0;
      buffer_v = 1'b0;
      align_v = 1'b0;
      framing_v = 1'b0;
      correctable_v = 1'b0;
    end
  endtask

  initial begin : test_sequence
    logic [31:0] rd;
    logic bad;
    int unsigned latest_slot;

    tb_start("PHY-V-014", 64'h0000_0000_0000_00ff);
    ready_i = 1'b0;
    state_i = LTSSM_RESET;
    sub_i = LTSSM_SS_RESET_WAIT_READY;
    reason_i = '0;
    timer_id_i = '0;
    timer_value_i = '0;
    retry_i = '0;
    rate_i = 1'b0;
    link_i = 1'b0;
    active_i = 1'b0;
    lock_i = 1'b0;
    status_clear_i = 1'b0;
    debug_counter_seed_valid_i = 1'b0;
    debug_counter_seed_index_i = '0;
    debug_counter_seed_value_i = '0;
    level_i = '0;
    ev_v = 1'b0;
    ev_src = '0;
    ev_code = ERR_NONE;
    ev_info = '0;
    ev_fatal = 1'b0;
    gt_v = 1'b0; buffer_v = 1'b0; align_v = 1'b0;
    framing_v = 1'b0; correctable_v = 1'b0;
    gt_code = ERR_GT_PLL_UNLOCK; gt_info = 32'h4754_0001;
    buffer_code = ERR_RXBUF_OVERFLOW; buffer_info = 32'h4255_0002;
    align_code = ERR_RX_ALIGN_LOSS; align_info = 32'h414c_0003;
    framing_code = ERR_RX_FRAMING; framing_info = 32'h4652_0004;
    correctable_code = ERR_RX_CODE; correctable_info = 32'h434f_0005;
    err_r = 1'b0;
    csr_v = 1'b0;
    csr_w = 1'b0;
    csr_addr = '0;
    csr_wdata = '0;
    csr_strb = '0;
    csr_rsp_r = 1'b1;

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst_n = 1'b1;
    lrst_n = 1'b1;
    port_rst_n = 1'b1;

    ready_i = 1'b1;
    state_i = LTSSM_L0;
    sub_i = LTSSM_SS_L0_ACTIVE;
    reason_i = REASON_IDLE_QUALIFIED;
    timer_id_i = 6'h15;
    timer_value_i = 32'h0012_3456;
    retry_i = 8'd2;
    rate_i = 1'b1;
    link_i = 1'b1;
    active_i = 1'b1;
    lock_i = 1'b1;
    level_i = 16'h1234;
    repeat (4) @(posedge clk);
    repeat (4) @(posedge lclk);
    tb_check(ready_o && link_o && active_o && rate_o && lock_o,
             "control-domain snapshot is visible");
    tb_check(dll_link && dll_active && dll_rate,
             "link-domain coherent view updates together");
    tb_hit(0);

    send_event(ERR_RX_CODE, 32'h1111_2222, EVT_SRC_RX);
    repeat (2) @(posedge clk);
    tb_check(err_v, "first error is presented");
    tb_check_eq8(err_code, ERR_RX_CODE, "first error output code");
    tb_check_eq32(err_info, 32'h1111_2222, "first error output context");
    send_event(ERR_GT_PLL_UNLOCK, 32'haaaa_5555, EVT_SRC_GTY);
    repeat (2) @(posedge clk);
    tb_check_eq8(err_code, ERR_RX_CODE, "stalled error output remains stable");
    tb_check_eq32(err_info, 32'h1111_2222,
                  "stalled error context remains stable");
    tb_hit(1);

    csr_read(CSR_FIRST_ERROR_CODE, rd, bad);
    tb_check(!bad, "first-error CSR read is legal");
    tb_check_eq8(rd[19:12], ERR_RX_CODE,
                 "first-error snapshot is never overwritten");
    csr_read(CSR_ERROR_STICKY, rd, bad);
    tb_check(rd[1] && rd[11], "sticky bitmap accumulates code 02 and code 0c");
    tb_hit(2);

    csr_write(CSR_ERROR_STICKY, 32'h0000_0002, 4'b0001, bad);
    tb_check(!bad, "W1C write accepted");
    csr_read(CSR_ERROR_STICKY, rd, bad);
    tb_check(!rd[1] && rd[11], "W1C clears only the selected sticky bit");
    tb_hit(3);

    @(negedge clk);
    debug_counter_seed_index_i = 5'd0;
    debug_counter_seed_value_i = 32'hffff_fffe;
    debug_counter_seed_valid_i = 1'b1;
    @(posedge clk);
    @(negedge clk);
    debug_counter_seed_valid_i = 1'b0;
    send_event(ERR_RX_DISPARITY, 32'h0000_0001, EVT_SRC_RX);
    send_event(ERR_RX_DISPARITY, 32'h0000_0002, EVT_SRC_RX);
    repeat (4) @(posedge clk);
    tb_check_eq32(dut.error_counter_q[0], 32'hffff_ffff,
                  "counter saturates without wrapping");
    tb_hit(4);

    err_r = 1'b1;
    clear_observation();
    for (int unsigned item = 0; item < 10; item++)
      send_event(8'h01 + item[7:0], 32'h9000_0000 + item, EVT_SRC_LTSSM);
    repeat (16) @(posedge clk);
    latest_slot = (dut.history_wr_ptr_q + 7) % 8;
    csr_read(12'(CSR_HISTORY_BASE + latest_slot*8), rd, bad);
    tb_check_eq8(rd[7:0], 8'h0a, "history wrap retains newest error code");
    csr_read(12'(CSR_HISTORY_BASE + latest_slot*8 + 4), rd, bad);
    tb_check_eq32(rd, 32'h9000_0009, "history wrap retains newest context");
    tb_hit(5);

    clear_observation();
    err_r = 1'b0;
    repeat (6) pulse_all_categories();
    repeat (6) @(posedge clk);
    csr_read(CSR_EVENT_STATUS, rd, bad);
    tb_check(rd[21], "event FIFO overflow is exposed in event status");
    err_r = 1'b1;
    repeat (32) @(posedge clk);
    csr_read(CSR_ERROR_STICKY, rd, bad);
    tb_check(rd[17], "event FIFO overflow records ERR_CDC_EVENT_OVERFLOW");
    tb_hit(6);

    clear_observation();
    pulse_all_categories();
    repeat (4) @(posedge clk);
    csr_read(CSR_FIRST_ERROR_CODE, rd, bad);
    tb_check_eq8(rd[19:12], ERR_GT_PLL_UNLOCK,
                 "same-cycle priority selects GT fatal as first error");
    tb_check(golden_error_priority(ERR_GT_PLL_UNLOCK) <
             golden_error_priority(ERR_RXBUF_OVERFLOW),
             "reference priority orders GT ahead of buffer");
    tb_check(golden_error_priority(ERR_RXBUF_OVERFLOW) <
             golden_error_priority(ERR_RX_ALIGN_LOSS),
             "reference priority orders buffer ahead of alignment");
    tb_check(golden_error_priority(ERR_RX_ALIGN_LOSS) <
             golden_error_priority(ERR_RX_FRAMING),
             "reference priority orders alignment ahead of framing");
    tb_check(golden_error_priority(ERR_RX_FRAMING) <
             golden_error_priority(ERR_RX_CODE),
             "reference priority orders framing ahead of correctable");
    csr_read(12'hffc, rd, bad);
    tb_check(bad, "illegal CSR address returns an error response");
    tb_hit(7);

    tb_finish("PHY-V-014");
  end
endmodule
