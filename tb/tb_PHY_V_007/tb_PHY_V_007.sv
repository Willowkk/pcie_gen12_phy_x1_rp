`timescale 1ns/1ps

module tb_PHY_V_007;
  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;
  import phy_tb_pkg::*;

  localparam int unsigned MODEL_COUNT = 3;
  localparam int unsigned PAYLOAD_COUNT = 20;
  localparam logic [15:0] ALIGN_PAIR = {8'h00, K_COM};
  localparam logic [15:0] MARKER_PAIR = {D_TS2, K_COM};

  logic ctrl_clk_i = 1'b0;
  logic sched_clk_i = 1'b0;
  always #5ns ctrl_clk_i = ~ctrl_clk_i;
  always #2ns sched_clk_i = ~sched_clk_i;

  logic ctrl_rst_ni;
  logic [15:0] model_tx_data_i;
  logic [1:0] model_tx_is_k_i;
  logic model_tx_ei_i;
  logic [MODEL_COUNT-1:0] model_sym_clk;
  logic [MODEL_COUNT-1:0] model_sym_rst_n;
  logic [MODEL_COUNT-1:0][15:0] model_rx_data;
  logic [MODEL_COUNT-1:0][1:0] model_rx_is_k;
  logic [MODEL_COUNT-1:0] model_rx_valid;
  logic [MODEL_COUNT-1:0][1:0] model_clkcor;
  logic [MODEL_COUNT-1:0][2:0] model_rxbuf;
  logic [MODEL_COUNT-1:0] model_ready;
  logic [MODEL_COUNT-1:0] model_fault;
  logic [MODEL_COUNT-1:0] stream_started;
  integer unsigned stream_payload_count [0:MODEL_COUNT-1];
  integer unsigned stream_mismatch_count [0:MODEL_COUNT-1];
  logic [MODEL_COUNT-1:0] correction_seen;

  function automatic logic [15:0] payload_word(input int unsigned index_i);
    return {8'h80 + index_i[7:0], 8'h10 + index_i[7:0]};
  endfunction

  function automatic logic pair_is_complete_skp_fragment(
    input logic [15:0] data_i,
    input logic [1:0] is_k_i
  );
    return (is_k_i == 2'b11) &&
           ((data_i == {K_SKP, K_COM}) || (data_i == {K_SKP, K_SKP}));
  endfunction

  for (genvar model_index = 0; model_index < MODEL_COUNT; model_index++) begin : g_model
    phy_gt_model_probe #(
      .ELASTIC_CORRECTION_MODE(model_index + 1),
      .CLOCK_COR_INTERVAL(1),
      .READY_LATENCY_CYCLES(3)
    ) probe (
      .ctrl_clk_i(ctrl_clk_i), .ctrl_rst_ni(ctrl_rst_ni),
      .tx_data_i(model_tx_data_i), .tx_is_k_i(model_tx_is_k_i),
      .detect_req_i(1'b0), .rate_req_i(1'b0), .rate_target_i(1'b0),
      .power_req_i(1'b0), .power_state_i(PHY_POWER_P0),
      .tx_ei_i(model_tx_ei_i), .rx_polarity_i(1'b0),
      .rx_p_i(1'b1), .rx_n_i(1'b0),
      .sym_clk_o(model_sym_clk[model_index]),
      .sym_rst_no(model_sym_rst_n[model_index]),
      .rx_data_o(model_rx_data[model_index]),
      .rx_is_k_o(model_rx_is_k[model_index]),
      .rx_disp_o(), .rx_code_o(), .rx_comma_o(),
      .rx_valid_o(model_rx_valid[model_index]), .rx_aligned_o(),
      .rx_realign_o(), .clkcor_o(model_clkcor[model_index]),
      .rxbuf_o(model_rxbuf[model_index]), .txbuf_fault_o(),
      .detect_busy_o(), .detect_done_o(), .receiver_present_o(),
      .rate_busy_o(), .rate_done_o(), .rate_fail_o(),
      .tx_ei_active_o(), .rx_ei_o(), .power_busy_o(), .power_done_o(),
      .power_fail_o(), .ready_o(model_ready[model_index]),
      .fault_o(model_fault[model_index]), .fault_code_o()
    );

    // This scoreboard deliberately ignores only the two pairs that constitute
    // a legal SKP OS.  Every other received pair must retain source order.
    always @(negedge model_sym_clk[model_index]) begin
      if (!model_sym_rst_n[model_index]) begin
        stream_started[model_index] <= 1'b0;
        stream_payload_count[model_index] <= 0;
        stream_mismatch_count[model_index] <= 0;
        correction_seen[model_index] <= 1'b0;
      end else begin
        if (model_clkcor[model_index] == model_index + 1)
          correction_seen[model_index] <= 1'b1;
        if (model_rx_valid[model_index]) begin
          if (!stream_started[model_index]) begin
            if ((model_rx_data[model_index] == MARKER_PAIR) &&
                (model_rx_is_k[model_index] == 2'b01)) begin
              stream_started[model_index] <= 1'b1;
              stream_payload_count[model_index] <= 0;
            end
          end else if ((stream_payload_count[model_index] < PAYLOAD_COUNT) &&
                       !pair_is_complete_skp_fragment(
                         model_rx_data[model_index], model_rx_is_k[model_index])) begin
            if ((model_rx_is_k[model_index] != 2'b00) ||
                (model_rx_data[model_index] !=
                 payload_word(stream_payload_count[model_index])))
              stream_mismatch_count[model_index] <=
                  stream_mismatch_count[model_index] + 1;
            stream_payload_count[model_index] <=
                stream_payload_count[model_index] + 1;
          end
        end
      end
    end
  end

  task automatic drive_model_pair(input logic [15:0] data_i,
                                  input logic [1:0] is_k_i);
    begin
      @(negedge model_sym_clk[0]);
      model_tx_data_i = data_i;
      model_tx_is_k_i = is_k_i;
    end
  endtask

  logic sched_rst_ni;
  logic skp_current_rate_i;
  logic [1:0] skp_tx_char_advance_i;
  logic skp_packet_boundary_i, skp_os_busy_i, skp_tx_accept_i;
  logic skp_due_o;
  logic [15:0] skp_deadline_o;
  logic skp_deadline_missed_evt_o;
  logic [1:0] gt_rx_clkcor_count_i;
  logic [2:0] gt_rx_buffer_status_i;
  logic skp_rx_add_evt_o;
  logic [1:0] skp_rx_skip_count_o;
  logic skp_rx_buffer_fault_evt_o;
  logic skp_rx_underflow_evt_o, skp_rx_overflow_evt_o;
  logic skp_rx_status_invalid_evt_o;

  phy_skp_clock_comp scheduler_monitor (
    .sym_clk_i(sched_clk_i), .sym_rst_ni(sched_rst_ni),
    .skp_current_rate_i, .skp_tx_char_advance_i,
    .skp_packet_boundary_i, .skp_os_busy_i, .skp_tx_accept_i,
    .skp_due_o, .skp_deadline_o, .skp_deadline_missed_evt_o,
    .gt_rx_clkcor_count_i, .gt_rx_buffer_status_i,
    .skp_rx_add_evt_o, .skp_rx_skip_count_o,
    .skp_rx_buffer_fault_evt_o, .skp_rx_underflow_evt_o,
    .skp_rx_overflow_evt_o, .skp_rx_status_invalid_evt_o
  );

  phy_watchdog #(.MAX_CTRL_CYCLES(400000), .TEST_ID("PHY-V-007")) watchdog (
    .ctrl_clk_i(sched_clk_i), .ctrl_rst_ni(sched_rst_ni), .done_i(1'b0)
  );

  task automatic sched_cycle;
    begin
      @(posedge sched_clk_i);
      @(negedge sched_clk_i);
    end
  endtask

  task automatic set_clkcor(input logic [1:0] value_i);
    begin
      @(negedge sched_clk_i);
      gt_rx_clkcor_count_i = value_i;
      sched_cycle();
    end
  endtask

  task automatic set_rxbuf(input logic [2:0] value_i);
    begin
      @(negedge sched_clk_i);
      gt_rx_buffer_status_i = value_i;
      sched_cycle();
    end
  endtask

  initial begin : test_sequence
    int unsigned payload_index;
    int unsigned wait_cycles;

    tb_start("PHY-V-007", 64'h0000_0000_0000_00ff);
    ctrl_rst_ni = 1'b0;
    model_tx_data_i = ALIGN_PAIR;
    model_tx_is_k_i = 2'b01;
    model_tx_ei_i = 1'b1;
    stream_started = '0;
    correction_seen = '0;

    sched_rst_ni = 1'b0;
    skp_current_rate_i = 1'b0;
    skp_tx_char_advance_i = 2'd0;
    skp_packet_boundary_i = 1'b1;
    skp_os_busy_i = 1'b0;
    skp_tx_accept_i = 1'b0;
    gt_rx_clkcor_count_i = GT_CLKCOR_NONE;
    gt_rx_buffer_status_i = GT_RXBUF_NOMINAL;

    repeat (4) @(posedge ctrl_clk_i);
    ctrl_rst_ni = 1'b1;
    repeat (4) @(posedge sched_clk_i);
    @(negedge sched_clk_i);
    sched_rst_ni = 1'b1;
    wait (&model_ready);
    wait (&model_sym_rst_n);
    tb_check_eq1(|model_fault, 1'b0, "all elastic models initialize without fault");
    tb_hit(0);

    // Align first, then delimit the checked stream with a unique COM pair.
    // Two adjacent SKP OSs exercise skip-one, skip-two and add-one correction
    // at the most aggressive modeled clock-correction interval.
    @(negedge ctrl_clk_i);
    model_tx_ei_i = 1'b0;
    repeat (16) drive_model_pair(ALIGN_PAIR, 2'b01);
    drive_model_pair(MARKER_PAIR, 2'b01);
    payload_index = 0;
    for (int unsigned epoch = 0; epoch < 4; epoch++) begin
      for (int unsigned item = 0; item < 5; item++) begin
        drive_model_pair(payload_word(payload_index), 2'b00);
        payload_index++;
      end
      drive_model_pair({K_SKP, K_COM}, 2'b11);
      drive_model_pair({K_SKP, K_SKP}, 2'b11);
      drive_model_pair({K_SKP, K_COM}, 2'b11);
      drive_model_pair({K_SKP, K_SKP}, 2'b11);
    end
    model_tx_data_i = payload_word(PAYLOAD_COUNT-1);
    model_tx_is_k_i = 2'b00;

    wait_cycles = 0;
    while (((stream_payload_count[0] < PAYLOAD_COUNT) ||
            (stream_payload_count[1] < PAYLOAD_COUNT) ||
            (stream_payload_count[2] < PAYLOAD_COUNT)) &&
           (wait_cycles < 2000)) begin
      @(posedge model_sym_clk[0]);
      wait_cycles++;
    end
    tb_check(wait_cycles < 2000, "all correction modes drain bounded payload");
    for (int unsigned model_index = 0;
         model_index < MODEL_COUNT; model_index++) begin
      tb_check_eq1(stream_started[model_index], 1'b1,
                   $sformatf("elastic mode %0d sees stream marker", model_index+1));
      tb_check(stream_payload_count[model_index] == PAYLOAD_COUNT,
               $sformatf("elastic mode %0d preserves non-SKP count", model_index+1));
      tb_check(stream_mismatch_count[model_index] == 0,
               $sformatf("elastic mode %0d preserves non-SKP order/data", model_index+1));
      tb_check_eq1(correction_seen[model_index], 1'b1,
                   $sformatf("elastic mode %0d emits normalized correction", model_index+1));
    end
    tb_hit(1); // skip one
    tb_hit(2); // skip two
    tb_hit(3); // add one

    // Verify the exact nominal and latest scheduling thresholds from timing_pkg.
    @(negedge sched_clk_i);
    skp_tx_char_advance_i = 2'd2;
    repeat (SKP_SCHEDULE_INTERVAL_SYMBOLS/2) sched_cycle();
    tb_check_eq1(skp_due_o, 1'b1, "SKP becomes due at nominal 1180 symbols");
    tb_check_eq16(skp_deadline_o,
                  SKP_LATEST_INTERVAL_SYMBOLS-SKP_SCHEDULE_INTERVAL_SYMBOLS,
                  "deadline reports remaining character budget");
    tb_hit(4);

    skp_packet_boundary_i = 1'b0;
    tb_check_eq1(skp_due_o, 1'b0, "due waits for a legal packet boundary");
    repeat ((SKP_LATEST_INTERVAL_SYMBOLS-SKP_SCHEDULE_INTERVAL_SYMBOLS)/2)
      sched_cycle();
    tb_check_eq1(skp_deadline_missed_evt_o, 1'b1,
                 "latest deadline produces one missed event");
    tb_check_eq16(skp_deadline_o, 16'h0000,
                  "deadline saturates at zero rather than wrapping");
    sched_cycle();
    tb_check_eq1(skp_deadline_missed_evt_o, 1'b0,
                 "missed-deadline event is not repeated");
    tb_hit(5);

    // Accept and rate-change each begin a fresh epoch.  OS busy also gates due.
    skp_tx_accept_i = 1'b1;
    sched_cycle();
    skp_tx_accept_i = 1'b0;
    tb_check_eq16(skp_deadline_o, SKP_LATEST_INTERVAL_SYMBOLS,
                  "SKP accept resets deadline epoch");
    repeat (20) sched_cycle();
    skp_current_rate_i = 1'b1;
    sched_cycle();
    tb_check_eq16(skp_deadline_o, SKP_LATEST_INTERVAL_SYMBOLS,
                  "rate change discards old-rate symbol count");
    skp_packet_boundary_i = 1'b1;
    skp_os_busy_i = 1'b1;
    repeat (SKP_SCHEDULE_INTERVAL_SYMBOLS/2) sched_cycle();
    tb_check_eq1(skp_due_o, 1'b0, "ordered-set busy gates SKP acceptance");
    skp_os_busy_i = 1'b0;
    tb_check_eq1(skp_due_o, 1'b1, "due remains pending after busy clears");
    tb_hit(6);

    // PL only decodes GTY status: it never performs a second deletion.
    skp_tx_char_advance_i = 2'd0;
    set_clkcor(GT_CLKCOR_SKIP1);
    tb_check_eq2(skp_rx_skip_count_o, 2'd1, "skip-one status normalized");
    set_clkcor(GT_CLKCOR_NONE);
    set_clkcor(GT_CLKCOR_SKIP2);
    tb_check_eq2(skp_rx_skip_count_o, 2'd2, "skip-two status normalized");
    set_clkcor(GT_CLKCOR_NONE);
    set_clkcor(GT_CLKCOR_ADD1);
    tb_check_eq1(skp_rx_add_evt_o, 1'b1, "add-one status normalized");

    set_rxbuf(GT_RXBUF_UNDERFLOW);
    tb_check_eq1(skp_rx_underflow_evt_o, 1'b1, "underflow detail injected");
    tb_check_eq1(skp_rx_buffer_fault_evt_o, 1'b1, "underflow raises buffer fault");
    set_rxbuf(GT_RXBUF_NOMINAL);
    set_rxbuf(GT_RXBUF_OVERFLOW);
    tb_check_eq1(skp_rx_overflow_evt_o, 1'b1, "overflow detail injected");
    tb_check_eq1(skp_rx_buffer_fault_evt_o, 1'b1, "overflow raises buffer fault");
    set_rxbuf(GT_RXBUF_NOMINAL);
    set_rxbuf(3'b111);
    tb_check_eq1(skp_rx_status_invalid_evt_o, 1'b1,
                 "reserved RXBUF status cannot be accepted silently");
    tb_check_eq1(skp_rx_buffer_fault_evt_o, 1'b1,
                 "reserved RXBUF status raises buffer fault");
    tb_hit(7);

    tb_finish("PHY-V-007");
  end
endmodule
