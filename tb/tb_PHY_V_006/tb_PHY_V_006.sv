`timescale 1ns/1ps

module tb_PHY_V_006;
  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;
  import golden_ordered_set_pkg::*;
  import phy_tb_pkg::*;

  logic sym_clk_i = 1'b0;
  logic sym_rst_ni = 1'b0;
  always #2ns sym_clk_i = ~sym_clk_i;

  logic os_tx_req_valid_i;
  logic os_tx_req_ready_o;
  logic [2:0] os_tx_kind_i;
  logic [7:0] os_tx_link_num_i;
  logic [4:0] os_tx_lane_num_i;
  logic [7:0] os_tx_n_fts_i;
  logic [1:0] os_tx_rate_id_i;
  logic [7:0] os_tx_training_ctrl_i;
  logic os_tx_link_num_is_pad_i, os_tx_lane_num_is_pad_i;
  logic skp_tx_req_i, os_tx_gen2_rcvrlock_i, os_tx_consume_i;
  logic os_tx_skp_start_o;
  logic [15:0] os_tx_data_o;
  logic [1:0] os_tx_is_k_o;
  logic [3:0] os_tx_class_o;
  logic [2:0] os_tx_repeat_mode_i;
  logic os_tx_valid_o, os_tx_done_o, os_tx_skp_done_o;

  logic [15:0] os_rx_data_i;
  logic [1:0] os_rx_is_k_i;
  logic os_rx_valid_i;
  logic [3:0] os_rx_error_i;
  logic [5:0] os_rx_expected_state_i;
  logic rx_logical_idle_valid_i;
  logic [1:0] rx_logical_idle_char_mask_i;
  logic os_rx_ts1_qualified_evt_o, os_rx_ts2_qualified_evt_o;
  logic os_rx_fts_evt_o, os_rx_skp_evt_o, os_rx_eios_evt_o;
  logic os_rx_eieos_evt_o, rx_logical_idle_qualified_evt_o;
  logic os_rx_hot_reset_evt_o, os_rx_loopback_evt_o;
  logic os_rx_speed_change_evt_o;
  pcie_ts_fields_t os_rx_fields_o;
  logic [7:0] os_rx_error_o;

  phy_ordered_set dut (
    .sym_clk_i, .sym_rst_ni,
    .os_tx_req_valid_i, .os_tx_req_ready_o, .os_tx_kind_i,
    .os_tx_link_num_i, .os_tx_lane_num_i, .os_tx_n_fts_i,
    .os_tx_rate_id_i, .os_tx_training_ctrl_i,
    .os_tx_link_num_is_pad_i, .os_tx_lane_num_is_pad_i,
    .skp_tx_req_i, .os_tx_gen2_rcvrlock_i, .os_tx_repeat_mode_i, .os_tx_consume_i,
    .os_tx_skp_start_o, .os_tx_data_o, .os_tx_is_k_o,
    .os_tx_class_o, .os_tx_valid_o, .os_tx_done_o, .os_tx_skp_done_o,
    .os_rx_data_i, .os_rx_is_k_i, .os_rx_valid_i, .os_rx_error_i,
    .os_rx_expected_state_i, .rx_logical_idle_valid_i,
    .rx_logical_idle_char_mask_i,
    .os_rx_ts1_qualified_evt_o, .os_rx_ts2_qualified_evt_o,
    .os_rx_fts_evt_o, .os_rx_skp_evt_o, .os_rx_eios_evt_o,
    .os_rx_eieos_evt_o, .rx_logical_idle_qualified_evt_o,
    .os_rx_hot_reset_evt_o, .os_rx_loopback_evt_o,
    .os_rx_speed_change_evt_o, .os_rx_fields_o, .os_rx_error_o
  );

  phy_watchdog #(.MAX_CTRL_CYCLES(250000), .TEST_ID("PHY-V-006")) watchdog (
    .ctrl_clk_i(sym_clk_i), .ctrl_rst_ni(sym_rst_ni), .done_i(1'b0)
  );

  function automatic logic [3:0] class_for_kind(input pcie_os_kind_t kind_i);
    case (kind_i)
      OS_KIND_TS1, OS_KIND_TS2: return CHAR_CLASS_TS;
      OS_KIND_SKP: return CHAR_CLASS_SKP;
      OS_KIND_FTS: return CHAR_CLASS_FTS;
      OS_KIND_EIOS: return CHAR_CLASS_EIOS;
      OS_KIND_EIEOS: return CHAR_CLASS_EIEOS;
      default: return CHAR_CLASS_UNKNOWN;
    endcase
  endfunction

  task automatic initialize_inputs;
    begin
      os_tx_req_valid_i = 1'b0;
      os_tx_kind_i = OS_KIND_NONE;
      os_tx_link_num_i = '0;
      os_tx_lane_num_i = '0;
      os_tx_n_fts_i = '0;
      os_tx_rate_id_i = '0;
      os_tx_training_ctrl_i = '0;
      os_tx_link_num_is_pad_i = 1'b0;
      os_tx_lane_num_is_pad_i = 1'b0;
      skp_tx_req_i = 1'b0;
      os_tx_gen2_rcvrlock_i = 1'b0;
      os_tx_repeat_mode_i = OS_REPEAT_SINGLE;
      os_tx_consume_i = 1'b0;
      os_rx_data_i = '0;
      os_rx_is_k_i = '0;
      os_rx_valid_i = 1'b0;
      os_rx_error_i = '0;
      os_rx_expected_state_i = LTSSM_SS_POLLING_ACTIVE;
      rx_logical_idle_valid_i = 1'b0;
      rx_logical_idle_char_mask_i = '0;
    end
  endtask

  task automatic reset_dut(input logic [5:0] expected_state_i);
    begin
      @(negedge sym_clk_i);
      sym_rst_ni = 1'b0;
      initialize_inputs();
      os_rx_expected_state_i = expected_state_i;
      repeat (3) @(posedge sym_clk_i);
      @(negedge sym_clk_i);
      sym_rst_ni = 1'b1;
      // First active edge captures the selected expected-state epoch.
      repeat (2) @(posedge sym_clk_i);
    end
  endtask

  task automatic compare_tx_template(input pcie_os_kind_t kind_i,
                                     input pcie_ts_fields_t fields_i);
    int unsigned pairs;
    begin
      while (!os_tx_req_ready_o) @(posedge sym_clk_i);
      @(negedge sym_clk_i);
      os_tx_kind_i = kind_i;
      os_tx_link_num_i = fields_i.link_num;
      os_tx_lane_num_i = fields_i.lane_num;
      os_tx_n_fts_i = fields_i.n_fts;
      os_tx_rate_id_i = fields_i.rate_id;
      os_tx_training_ctrl_i = fields_i.training_ctrl;
      os_tx_link_num_is_pad_i = fields_i.link_num_is_pad;
      os_tx_lane_num_is_pad_i = fields_i.lane_num_is_pad;
      os_tx_req_valid_i = 1'b1;
      @(posedge sym_clk_i);
      @(negedge sym_clk_i);
      os_tx_req_valid_i = 1'b0;
      pairs = golden_os_length(kind_i) / 2;
      for (int unsigned pair_index = 0; pair_index < pairs; pair_index++) begin
        tb_check_eq1(os_tx_valid_o, 1'b1,
                     $sformatf("OS kind %0d pair %0d valid", kind_i, pair_index));
        tb_check_eq16(os_tx_data_o,
                      golden_os_pair_data(kind_i, pair_index, fields_i),
                      $sformatf("OS kind %0d pair %0d data", kind_i, pair_index));
        tb_check_eq2(os_tx_is_k_o,
                     golden_os_pair_is_k(kind_i, pair_index, fields_i),
                     $sformatf("OS kind %0d pair %0d K flags", kind_i, pair_index));
        tb_check_eq4(os_tx_class_o, class_for_kind(kind_i),
                     $sformatf("OS kind %0d pair %0d class", kind_i, pair_index));
        os_tx_consume_i = 1'b1;
        @(posedge sym_clk_i);
        @(negedge sym_clk_i);
      end
      os_tx_consume_i = 1'b0;
      tb_check_eq1(os_tx_done_o, 1'b1,
                   $sformatf("OS kind %0d completion pulse", kind_i));
      @(posedge sym_clk_i);
      @(negedge sym_clk_i);
      tb_check_eq1(os_tx_done_o, 1'b0,
                   $sformatf("OS kind %0d completion is one cycle", kind_i));
    end
  endtask

  task automatic drive_rx_pair(input logic [15:0] data_i,
                               input logic [1:0] is_k_i,
                               input logic [3:0] error_i,
                               output logic [7:0] event_vector_o,
                               output logic [7:0] local_error_o);
    begin
      @(negedge sym_clk_i);
      os_rx_data_i = data_i;
      os_rx_is_k_i = is_k_i;
      os_rx_error_i = error_i;
      os_rx_valid_i = 1'b1;
      @(posedge sym_clk_i);
      #1ps;
      event_vector_o = {rx_logical_idle_qualified_evt_o,
                        os_rx_speed_change_evt_o,
                        os_rx_eieos_evt_o, os_rx_eios_evt_o,
                        os_rx_fts_evt_o, os_rx_skp_evt_o,
                        os_rx_ts2_qualified_evt_o,
                        os_rx_ts1_qualified_evt_o};
      local_error_o = os_rx_error_o;
    end
  endtask

  task automatic feed_rx_template(input pcie_os_kind_t kind_i,
                                  input pcie_ts_fields_t fields_i,
                                  output logic [7:0] events_o,
                                  output logic [7:0] error_o);
    logic [7:0] pair_events, pair_error;
    begin
      events_o = '0;
      error_o = '0;
      for (int unsigned pair_index = 0;
           pair_index < golden_os_length(kind_i)/2; pair_index++) begin
        drive_rx_pair(golden_os_pair_data(kind_i, pair_index, fields_i),
                      golden_os_pair_is_k(kind_i, pair_index, fields_i),
                      4'h0, pair_events, pair_error);
        events_o |= pair_events;
        if (pair_error != 0) error_o = pair_error;
      end
      os_rx_valid_i = 1'b0;
      os_rx_data_i = '0;
      os_rx_is_k_i = '0;
    end
  endtask

  initial begin : test_sequence
    pcie_ts_fields_t pad_fields, numbered_fields, changed_fields;
    logic [7:0] events, error_code, pair_events;
    int unsigned qualified_count;
    int unsigned cadence_index, cadence_word;

    tb_start("PHY-V-006", 64'h0000_0000_0000_00ff);
    initialize_inputs();
    pad_fields = '0;
    pad_fields.valid = 1'b1;
    pad_fields.link_num_is_pad = 1'b1;
    pad_fields.lane_num_is_pad = 1'b1;
    pad_fields.n_fts = 8'd32;
    pad_fields.rate_id = 2'b11;

    numbered_fields = pad_fields;
    numbered_fields.link_num_is_pad = 1'b0;
    numbered_fields.lane_num_is_pad = 1'b0;
    numbered_fields.link_num = 8'h2a;
    numbered_fields.lane_num = 5'd0;

    // TX is compared character-for-character with an independent template.
    reset_dut(LTSSM_SS_POLLING_ACTIVE);
    compare_tx_template(OS_KIND_TS1, pad_fields);
    compare_tx_template(OS_KIND_TS2, numbered_fields);
    compare_tx_template(OS_KIND_SKP, pad_fields);
    compare_tx_template(OS_KIND_FTS, pad_fields);
    compare_tx_template(OS_KIND_EIOS, pad_fields);
    compare_tx_template(OS_KIND_EIEOS, pad_fields);

    // Recovery.RcvrLock at Gen2 inserts an initial EIEOS, then exactly one
    // EIEOS after each block of 32 continuously requested TS1 sequences.
    reset_dut(LTSSM_SS_RECOVERY_RCVRLOCK);
    @(negedge sym_clk_i);
    os_tx_kind_i = OS_KIND_TS1;
    os_tx_link_num_i = pad_fields.link_num;
    os_tx_lane_num_i = pad_fields.lane_num;
    os_tx_n_fts_i = pad_fields.n_fts;
    os_tx_rate_id_i = pad_fields.rate_id;
    os_tx_training_ctrl_i = pad_fields.training_ctrl;
    os_tx_link_num_is_pad_i = 1'b1;
    os_tx_lane_num_is_pad_i = 1'b1;
    os_tx_gen2_rcvrlock_i = 1'b1;
    os_tx_req_valid_i = 1'b1;
    @(posedge sym_clk_i);
    @(negedge sym_clk_i);
    for (cadence_index = 0; cadence_index < 34; cadence_index++) begin
      tb_check_eq1(os_tx_valid_o, 1'b1, "Gen2 recovery OS stream is contiguous");
      if ((cadence_index == 0) || (cadence_index == 33)) begin
        tb_check_eq16(os_tx_data_o,
                      golden_os_pair_data(OS_KIND_EIEOS, 0, pad_fields),
                      "EIEOS appears at the required 32-TS1 cadence");
      end else begin
        tb_check_eq16(os_tx_data_o,
                      golden_os_pair_data(OS_KIND_TS1, 0, pad_fields),
                      "only TS1 occupies each recovery cadence slot");
      end
      for (cadence_word = 0; cadence_word < 8; cadence_word++) begin
        os_tx_consume_i = 1'b1;
        @(posedge sym_clk_i);
        @(negedge sym_clk_i);
      end
      tb_check_eq1(os_tx_done_o, 1'b1, "each cadence OS completes atomically");
    end
    os_tx_consume_i = 1'b0;
    os_tx_req_valid_i = 1'b0;
    os_tx_gen2_rcvrlock_i = 1'b0;
    tb_hit(0);

    // A complete TS1 is not qualified until the exact consecutive threshold.
    reset_dut(LTSSM_SS_POLLING_ACTIVE);
    pad_fields.training_ctrl = TS_CTRL_HOT_RESET;
    qualified_count = 0;
    for (int unsigned repetition = 0;
         repetition < POLLING_ACTIVE_TS_QUAL_COUNT; repetition++) begin
      feed_rx_template(OS_KIND_TS1, pad_fields, events, error_code);
      tb_check_eq8(error_code, 8'h00, "legal TS1 has no parser error");
      if (events[0]) qualified_count++;
      if (repetition + 1 < POLLING_ACTIVE_TS_QUAL_COUNT)
        tb_check_eq1(events[0], 1'b0, "TS1 cannot qualify early");
    end
    tb_check(qualified_count == 1, "TS1 qualifies exactly once at threshold");
    tb_check_eq1(os_rx_fields_o.valid, 1'b1, "TS1 field snapshot valid");
    tb_check_eq8(os_rx_fields_o.n_fts, pad_fields.n_fts, "TS1 N_FTS parsed");
    tb_check_eq2(os_rx_fields_o.rate_id, pad_fields.rate_id, "TS1 Rate ID parsed");
    tb_check_eq8(os_rx_fields_o.training_ctrl, pad_fields.training_ctrl,
                 "TS1 Training Control parsed");
    tb_check_eq1(os_rx_hot_reset_evt_o, 1'b1,
                 "qualified TS1 exposes Hot Reset semantic");
    tb_hit(1);

    // TS2 has its own expected state and independent consecutive counter.
    reset_dut(LTSSM_SS_POLLING_CONFIGURATION);
    pad_fields.training_ctrl = '0;
    qualified_count = 0;
    for (int unsigned repetition = 0;
         repetition < POLLING_CONFIG_TS2_QUAL_COUNT; repetition++) begin
      feed_rx_template(OS_KIND_TS2, pad_fields, events, error_code);
      if (events[1]) qualified_count++;
    end
    tb_check(qualified_count == 1, "TS2 qualifies exactly at its threshold");
    tb_check_eq1(os_rx_fields_o.is_ts2, 1'b1, "TS2 field snapshot typed");
    tb_hit(2);

    // All four non-training ordered sets require their complete template.
    reset_dut(LTSSM_SS_POLLING_ACTIVE);
    feed_rx_template(OS_KIND_SKP, pad_fields, events, error_code);
    tb_check_eq1(events[2], 1'b1, "complete SKP recognized");
    feed_rx_template(OS_KIND_FTS, pad_fields, events, error_code);
    tb_check_eq1(events[3], 1'b1, "complete FTS recognized");
    feed_rx_template(OS_KIND_EIOS, pad_fields, events, error_code);
    tb_check_eq1(events[4], 1'b1, "complete EIOS recognized");
    feed_rx_template(OS_KIND_EIEOS, pad_fields, events, error_code);
    tb_check_eq1(events[5], 1'b1, "complete Gen2 EIEOS recognized");
    tb_hit(3);

    // A new COM before the previous 16-symbol TS completes is truncation.
    reset_dut(LTSSM_SS_POLLING_ACTIVE);
    drive_rx_pair(golden_os_pair_data(OS_KIND_TS1, 0, pad_fields),
                  golden_os_pair_is_k(OS_KIND_TS1, 0, pad_fields), 4'h0,
                  pair_events, error_code);
    drive_rx_pair(golden_os_pair_data(OS_KIND_SKP, 0, pad_fields),
                  golden_os_pair_is_k(OS_KIND_SKP, 0, pad_fields), 4'h0,
                  pair_events, error_code);
    tb_check_eq8(error_code, 8'h42, "new COM reports truncated TS");
    tb_check_eq1(pair_events[0] | pair_events[1], 1'b0,
                 "truncated TS cannot qualify");
    tb_hit(4);

    // A short OS with a tail from another kind is malformed/wrong-order.
    reset_dut(LTSSM_SS_POLLING_ACTIVE);
    drive_rx_pair(golden_os_pair_data(OS_KIND_FTS, 0, pad_fields),
                  golden_os_pair_is_k(OS_KIND_FTS, 0, pad_fields), 4'h0,
                  pair_events, error_code);
    drive_rx_pair({K_SKP, K_SKP}, 2'b11, 4'h0,
                  pair_events, error_code);
    tb_check_eq8(error_code, 8'h41, "wrong short-OS tail is malformed");
    tb_hit(5);

    // Invalid x1 lane field fails the field mask and never increments count.
    reset_dut(LTSSM_SS_CFG_COMPLETE);
    numbered_fields.lane_num = 5'd1;
    feed_rx_template(OS_KIND_TS2, numbered_fields, events, error_code);
    tb_check_eq8(error_code, 8'h44, "nonzero x1 lane rejected");
    tb_check_eq1(events[1], 1'b0, "invalid TS2 cannot qualify");
    tb_hit(6);

    // A candidate PCS error aborts an in-flight OS; changed fields break the
    // consecutive-count contract even though both individual TSs are legal.
    reset_dut(LTSSM_SS_POLLING_ACTIVE);
    drive_rx_pair(golden_os_pair_data(OS_KIND_TS1, 0, pad_fields),
                  golden_os_pair_is_k(OS_KIND_TS1, 0, pad_fields), 4'h0,
                  pair_events, error_code);
    drive_rx_pair(golden_os_pair_data(OS_KIND_TS1, 1, pad_fields),
                  golden_os_pair_is_k(OS_KIND_TS1, 1, pad_fields), 4'h1,
                  pair_events, error_code);
    tb_check_eq8(error_code, 8'h46, "PCS error aborts OS candidate");

    reset_dut(LTSSM_SS_POLLING_ACTIVE);
    feed_rx_template(OS_KIND_TS1, pad_fields, events, error_code);
    changed_fields = pad_fields;
    changed_fields.n_fts = pad_fields.n_fts + 1'b1;
    feed_rx_template(OS_KIND_TS1, changed_fields, events, error_code);
    tb_check_eq8(error_code, 8'h45, "field change breaks consecutive count");
    tb_check_eq1(events[0], 1'b0, "broken count does not qualify");
    tb_hit(7);

    @(negedge sym_clk_i);
    os_rx_valid_i = 1'b0;
    tb_finish("PHY-V-006");
  end
endmodule
