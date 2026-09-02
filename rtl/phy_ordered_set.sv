module phy_ordered_set (
  input  logic        sym_clk_i,
  input  logic        sym_rst_ni,

  input  logic        os_tx_req_valid_i,
  output logic        os_tx_req_ready_o,
  input  logic [2:0]  os_tx_kind_i,
  // Private repeat contract from LTSSM. Fixed modes form one atomic batch;
  // autonomous SKP/EIEOS insertions never contribute to this count.
  input  logic [2:0]  os_tx_repeat_mode_i,
  input  logic [7:0]  os_tx_link_num_i,
  input  logic [4:0]  os_tx_lane_num_i,
  input  logic [7:0]  os_tx_n_fts_i,
  input  logic [1:0]  os_tx_rate_id_i,
  input  logic [7:0]  os_tx_training_ctrl_i,
  // Private TS metadata preserves PAD, which cannot be represented without
  // ambiguity in the frozen numeric Link/Lane ports.
  input  logic        os_tx_link_num_is_pad_i,
  input  logic        os_tx_lane_num_is_pad_i,
  // Private boundary arbitration inputs. consume advances one emitted pair;
  // skp_req is serviced only between complete ordered sets.
  input  logic        skp_tx_req_i,
  input  logic        os_tx_gen2_rcvrlock_i,
  input  logic        os_tx_consume_i,
  output logic        os_tx_skp_start_o,
  output logic        os_tx_skp_done_o,

  output logic [15:0] os_tx_data_o,
  output logic [1:0]  os_tx_is_k_o,
  output logic [3:0]  os_tx_class_o,
  output logic        os_tx_valid_o,
  output logic        os_tx_done_o,

  input  logic [15:0] os_rx_data_i,
  input  logic [1:0]  os_rx_is_k_i,
  input  logic        os_rx_valid_i,
  input  logic [3:0]  os_rx_error_i,
  // This is the frozen six-bit LTSSM substate index, not the main-state value.
  input  logic [5:0]  os_rx_expected_state_i,
  // Descrambled Logical Idle is intentionally a separate path from the raw OS
  // candidate stream. mask[0] is the first character in wire time.
  input  logic        rx_logical_idle_valid_i,
  input  logic [1:0]  rx_logical_idle_char_mask_i,

  output logic        os_rx_ts1_qualified_evt_o,
  output logic        os_rx_ts2_qualified_evt_o,
  output logic        os_rx_fts_evt_o,
  output logic        os_rx_skp_evt_o,
  output logic        os_rx_eios_evt_o,
  output logic        os_rx_eieos_evt_o,
  output logic        rx_logical_idle_qualified_evt_o,
  output logic        os_rx_hot_reset_evt_o,
  output logic        os_rx_loopback_evt_o,
  output logic        os_rx_speed_change_evt_o,
  output pcie_gen12_phy_pkg::pcie_ts_fields_t os_rx_fields_o,
  output logic [7:0]  os_rx_error_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

  // Detailed ordered-set diagnostics carried on os_rx_error_o. They are local
  // subcodes; the status aggregator maps any non-zero value to ERR_RX_OS_INVALID
  // while retaining this byte in event context.
  localparam logic [7:0] OS_RX_ERR_MALFORMED      = 8'h41;
  localparam logic [7:0] OS_RX_ERR_TRUNCATED      = 8'h42;
  localparam logic [7:0] OS_RX_ERR_UNEXPECTED     = 8'h43;
  localparam logic [7:0] OS_RX_ERR_FIELD_MISMATCH = 8'h44;
  localparam logic [7:0] OS_RX_ERR_COUNT_BROKEN   = 8'h45;
  localparam logic [7:0] OS_RX_ERR_CANDIDATE      = 8'h46;

  // --------------------------------------------------------------------------
  // TX template generator
  // --------------------------------------------------------------------------
  logic            tx_active_q;
  pcie_os_kind_t   tx_kind_q;
  logic [3:0]      tx_word_index_q;
  pcie_ts_fields_t tx_fields_q;
  logic [5:0]      gen2_ts_since_eieos_q;
  logic            gen2_context_q;
  logic            tx_requested_q;
  // A command is a desired level, not a pulse.  Its complete signature is
  // retained after the initial completion so SINGLE cannot be emitted twice
  // and fixed/stream commands can continue without an inter-OS gap.
  logic            command_valid_q;
  logic            command_done_reported_q;
  logic            fixed_initial_active_q;
  pcie_os_kind_t   command_kind_q;
  pcie_ts_fields_t command_fields_q;
  pcie_os_repeat_mode_t command_repeat_mode_q;
  localparam int unsigned REPEAT_COUNT_W =
      $clog2(POLLING_ACTIVE_MIN_TS1_TX + 1);
  logic [REPEAT_COUNT_W-1:0] fixed_remaining_q;

  logic cadence_due_c;
  logic cadence_boundary_due_c;
  logic desired_command_valid_c;
  logic desired_matches_command_c;
  logic current_segment_completes_c;
  logic [7:0] tx_link_symbol_c;
  logic [7:0] tx_lane_symbol_c;
  logic [7:0] tx_rate_symbol_c;
  logic [7:0] tx_training_symbol_c;
  pcie_ts_fields_t request_fields_c;

  function automatic logic [3:0] os_word_count(
    input pcie_os_kind_t kind
  );
    unique case (kind)
      OS_KIND_TS1,
      OS_KIND_TS2,
      OS_KIND_EIEOS: return 4'd8;
      OS_KIND_SKP,
      OS_KIND_FTS,
      OS_KIND_EIOS:  return 4'd2;
      default:       return 4'd0;
    endcase
  endfunction

  function automatic logic os_kind_is_valid(input logic [2:0] kind);
    return (kind == OS_KIND_TS1) || (kind == OS_KIND_TS2) ||
           (kind == OS_KIND_SKP) || (kind == OS_KIND_FTS) ||
           (kind == OS_KIND_EIOS) || (kind == OS_KIND_EIEOS);
  endfunction

  function automatic logic repeat_mode_is_fixed(
    input pcie_os_repeat_mode_t mode
  );
    unique case (mode)
      OS_REPEAT_FIXED_2,
      OS_REPEAT_FIXED_8,
      OS_REPEAT_FIXED_32,
      OS_REPEAT_FIXED_1024: return 1'b1;
      default:              return 1'b0;
    endcase
  endfunction

  function automatic logic repeat_mode_continues(
    input pcie_os_repeat_mode_t mode
  );
    return mode != OS_REPEAT_SINGLE;
  endfunction

  function automatic logic [REPEAT_COUNT_W-1:0] repeat_count(
    input pcie_os_repeat_mode_t mode
  );
    unique case (mode)
      OS_REPEAT_FIXED_2:
        return REPEAT_COUNT_W'(CFG_LINKWIDTH_TS_COUNT);
      OS_REPEAT_FIXED_8:
        return REPEAT_COUNT_W'(POLLING_CONFIG_TS2_QUAL_COUNT);
      OS_REPEAT_FIXED_32:
        return REPEAT_COUNT_W'(GEN2_EIEOS_TS1_PERIOD);
      OS_REPEAT_FIXED_1024:
        return REPEAT_COUNT_W'(POLLING_ACTIVE_MIN_TS1_TX);
      default:
        return REPEAT_COUNT_W'(1);
    endcase
  endfunction

  // Recovery.RcvrLock sends thirty-two complete TS1 ordered sets before each
  // autonomous EIEOS.  Entry into the substate does not create a leading
  // EIEOS; the counter advances only for requested TS1 completions.
  assign cadence_due_c = os_tx_gen2_rcvrlock_i &&
                         (gen2_ts_since_eieos_q >=
                          GEN2_EIEOS_TS1_PERIOD);
  assign cadence_boundary_due_c =
      (tx_kind_q != OS_KIND_EIEOS) &&
      os_tx_gen2_rcvrlock_i &&
      ((gen2_ts_since_eieos_q >= GEN2_EIEOS_TS1_PERIOD) ||
       ((tx_kind_q == OS_KIND_TS1) && tx_requested_q &&
        (gen2_ts_since_eieos_q + 1'b1 >= GEN2_EIEOS_TS1_PERIOD)));

  // The producer presents a coherent desired level.  Ready therefore denotes
  // an idle boundary; changes presented while busy are sampled atomically at
  // the next complete ordered-set boundary.
  assign os_tx_req_ready_o = !tx_active_q;
  assign os_tx_valid_o = tx_active_q;
  assign os_tx_skp_done_o = tx_active_q && os_tx_consume_i &&
                            (tx_kind_q == OS_KIND_SKP) &&
                            (tx_word_index_q + 1'b1 >=
                             os_word_count(tx_kind_q));

  always_comb begin
    request_fields_c                 = '0;
    request_fields_c.valid           = 1'b1;
    request_fields_c.is_ts2          = (os_tx_kind_i == OS_KIND_TS2);
    request_fields_c.link_num_is_pad = os_tx_link_num_is_pad_i;
    request_fields_c.lane_num_is_pad = os_tx_lane_num_is_pad_i;
    request_fields_c.link_num        = os_tx_link_num_i;
    request_fields_c.lane_num        = os_tx_lane_num_i;
    request_fields_c.n_fts           = os_tx_n_fts_i;
    request_fields_c.rate_id         = os_tx_rate_id_i;
    request_fields_c.training_ctrl   = os_tx_training_ctrl_i;
  end

  assign desired_command_valid_c = os_tx_req_valid_i &&
                                   os_kind_is_valid(os_tx_kind_i);
  assign desired_matches_command_c = desired_command_valid_c &&
                                     command_valid_q &&
      (pcie_os_kind_t'(os_tx_kind_i) == command_kind_q) &&
      (pcie_os_repeat_mode_t'(os_tx_repeat_mode_i) ==
       command_repeat_mode_q) &&
      (request_fields_c == command_fields_q);

  always_comb begin : p_segment_completion
    current_segment_completes_c = 1'b0;
    if (tx_requested_q && !command_done_reported_q) begin
      if (repeat_mode_is_fixed(command_repeat_mode_q)) begin
        current_segment_completes_c =
            fixed_initial_active_q &&
            (fixed_remaining_q <= REPEAT_COUNT_W'(1));
      end else begin
        // SINGLE, CONTINUOUS and UNTIL_ACCEPT all acknowledge their first
        // complete requested OS.  Only the latter two keep transmitting.
        current_segment_completes_c = 1'b1;
      end
    end
  end

  always_comb begin : p_tx_template
    tx_link_symbol_c = tx_fields_q.link_num_is_pad ? K_PAD :
                       tx_fields_q.link_num;
    tx_lane_symbol_c = tx_fields_q.lane_num_is_pad ? K_PAD :
                       {3'b000, tx_fields_q.lane_num};
    // Project rate_id[0]/[1] mean Gen1/Gen2 support. The PCIe 2.1 wire
    // positions are Symbol 4 bits 1/2; speed_change is wire bit 7.
    tx_rate_symbol_c = {
      tx_fields_q.training_ctrl[5], 4'b0000,
      tx_fields_q.rate_id[1], tx_fields_q.rate_id[0], 1'b0
    };
    // speed_change is abstracted in training_ctrl[5] by this project but is
    // encoded in the Rate Identifier byte, not in TS Symbol 5.
    tx_training_symbol_c = {3'b000, tx_fields_q.training_ctrl[4:0]};

    os_tx_data_o  = 16'h0000;
    os_tx_is_k_o  = 2'b00;
    os_tx_class_o = CHAR_CLASS_UNKNOWN;

    unique case (tx_kind_q)
      OS_KIND_TS1,
      OS_KIND_TS2: begin
        os_tx_class_o = CHAR_CLASS_TS;
        unique case (tx_word_index_q)
          4'd0: begin
            os_tx_data_o = {tx_link_symbol_c, K_COM};
            os_tx_is_k_o = {tx_fields_q.link_num_is_pad, 1'b1};
          end
          4'd1: begin
            os_tx_data_o = {tx_fields_q.n_fts, tx_lane_symbol_c};
            os_tx_is_k_o = {1'b0, tx_fields_q.lane_num_is_pad};
          end
          4'd2: begin
            os_tx_data_o = {tx_training_symbol_c, tx_rate_symbol_c};
            os_tx_is_k_o = 2'b00;
          end
          default: begin
            os_tx_data_o = (tx_kind_q == OS_KIND_TS2) ?
                           {D_TS2, D_TS2} : {D_TS1, D_TS1};
            os_tx_is_k_o = 2'b00;
          end
        endcase
      end

      OS_KIND_SKP: begin
        os_tx_class_o = CHAR_CLASS_SKP;
        os_tx_data_o  = (tx_word_index_q == 0) ?
                        {K_SKP, K_COM} : {K_SKP, K_SKP};
        os_tx_is_k_o  = 2'b11;
      end

      OS_KIND_FTS: begin
        os_tx_class_o = CHAR_CLASS_FTS;
        os_tx_data_o  = (tx_word_index_q == 0) ?
                        {K_FTS, K_COM} : {K_FTS, K_FTS};
        os_tx_is_k_o  = 2'b11;
      end

      OS_KIND_EIOS: begin
        os_tx_class_o = CHAR_CLASS_EIOS;
        os_tx_data_o  = (tx_word_index_q == 0) ?
                        {K_EIOS, K_COM} : {K_EIOS, K_EIOS};
        os_tx_is_k_o  = 2'b11;
      end

      OS_KIND_EIEOS: begin
        os_tx_class_o = CHAR_CLASS_EIEOS;
        if (tx_word_index_q == 0) begin
          os_tx_data_o = {K_EIE, K_COM};
          os_tx_is_k_o = 2'b11;
        end else if (tx_word_index_q == 7) begin
          // PCIe 2.1 EIEOS: COM, fourteen EIE K28.7, then D10.2.
          os_tx_data_o = {D_TS1, K_EIE};
          os_tx_is_k_o = 2'b01;
        end else begin
          os_tx_data_o = {K_EIE, K_EIE};
          os_tx_is_k_o = 2'b11;
        end
      end

      default: begin
        os_tx_data_o  = 16'h0000;
        os_tx_is_k_o  = 2'b00;
        os_tx_class_o = CHAR_CLASS_UNKNOWN;
      end
    endcase
  end

  // These tasks contain only nonblocking register assignments and are called
  // exclusively by p_tx_state.  Separating capture from launch is important:
  // a new desired command can be captured at a boundary while an autonomous
  // EIEOS is launched first, then resumed with the exact captured metadata.
  task automatic capture_desired_command(
    input pcie_os_kind_t         desired_kind,
    input pcie_ts_fields_t       desired_fields,
    input pcie_os_repeat_mode_t  desired_repeat
  );
    begin
      command_valid_q          <= 1'b1;
      command_kind_q           <= desired_kind;
      command_fields_q         <= desired_fields;
      command_repeat_mode_q    <= desired_repeat;
      command_done_reported_q  <= 1'b0;
      fixed_initial_active_q   <= repeat_mode_is_fixed(desired_repeat);
      fixed_remaining_q        <= repeat_count(desired_repeat);
    end
  endtask

  task automatic clear_desired_command;
    begin
      command_valid_q          <= 1'b0;
      command_kind_q           <= OS_KIND_NONE;
      command_fields_q         <= '0;
      command_repeat_mode_q    <= OS_REPEAT_SINGLE;
      command_done_reported_q  <= 1'b0;
      fixed_initial_active_q   <= 1'b0;
      fixed_remaining_q        <= '0;
    end
  endtask

  task automatic launch_requested_os(
    input pcie_os_kind_t    launch_kind,
    input pcie_ts_fields_t  launch_fields
  );
    begin
      tx_active_q      <= 1'b1;
      tx_kind_q        <= launch_kind;
      tx_fields_q      <= launch_fields;
      tx_word_index_q  <= '0;
      tx_requested_q   <= 1'b1;
    end
  endtask

  task automatic launch_autonomous_os(input pcie_os_kind_t launch_kind);
    begin
      tx_active_q      <= 1'b1;
      tx_kind_q        <= launch_kind;
      tx_word_index_q  <= '0;
      tx_requested_q   <= 1'b0;
    end
  endtask

  always_ff @(posedge sym_clk_i or negedge sym_rst_ni) begin : p_tx_state
    if (!sym_rst_ni) begin
      tx_active_q             <= 1'b0;
      tx_kind_q               <= OS_KIND_NONE;
      tx_word_index_q         <= '0;
      tx_fields_q             <= '0;
      gen2_ts_since_eieos_q   <= '0;
      gen2_context_q          <= 1'b0;
      tx_requested_q          <= 1'b0;
      command_valid_q         <= 1'b0;
      command_done_reported_q <= 1'b0;
      fixed_initial_active_q  <= 1'b0;
      command_kind_q          <= OS_KIND_NONE;
      command_fields_q        <= '0;
      command_repeat_mode_q   <= OS_REPEAT_SINGLE;
      fixed_remaining_q       <= '0;
      os_tx_done_o            <= 1'b0;
      os_tx_skp_start_o       <= 1'b0;
    end else begin
      os_tx_done_o      <= 1'b0;
      os_tx_skp_start_o <= 1'b0;
      gen2_context_q    <= os_tx_gen2_rcvrlock_i;

      if (!os_tx_gen2_rcvrlock_i) begin
        gen2_ts_since_eieos_q <= '0;
      end else if (!gen2_context_q) begin
        // The first TS1 after entry is number one of the next group of 32.
        gen2_ts_since_eieos_q <= '0;
      end

      if (tx_active_q && os_tx_consume_i) begin
        if ((tx_kind_q == OS_KIND_SKP) && (tx_word_index_q == 0)) begin
          os_tx_skp_start_o <= 1'b1;
        end

        if (tx_word_index_q + 1'b1 >= os_word_count(tx_kind_q)) begin
          tx_word_index_q <= '0;

          // Cadence accounting is deliberately independent of requested batch
          // accounting.  Autonomous SKP/EIEOS cannot consume a batch member.
          if (tx_kind_q == OS_KIND_EIEOS) begin
            gen2_ts_since_eieos_q <= '0;
          end else if (tx_requested_q && (tx_kind_q == OS_KIND_TS1) &&
                       os_tx_gen2_rcvrlock_i) begin
            if (gen2_ts_since_eieos_q < GEN2_EIEOS_TS1_PERIOD) begin
              gen2_ts_since_eieos_q <= gen2_ts_since_eieos_q + 1'b1;
            end
          end

          if (tx_requested_q) begin
            // The consumed OS belongs to the currently captured desired
            // command.  Report completion once per unchanged segment.
            if (current_segment_completes_c) begin
              os_tx_done_o <= 1'b1;
            end

            if (!desired_matches_command_c) begin
              // A dropped or changed desired level takes effect only here, at
              // a complete-OS boundary.  An incomplete fixed batch is
              // superseded without a false completion acknowledgement.
              if (desired_command_valid_c) begin
                capture_desired_command(
                    pcie_os_kind_t'(os_tx_kind_i), request_fields_c,
                    pcie_os_repeat_mode_t'(os_tx_repeat_mode_i));
              end else begin
                clear_desired_command();
              end

              if (cadence_boundary_due_c) begin
                launch_autonomous_os(OS_KIND_EIEOS);
              end else if (desired_command_valid_c) begin
                // A changed state-forced command outranks an overdue SKP.
                launch_requested_os(pcie_os_kind_t'(os_tx_kind_i),
                                    request_fields_c);
              end else if (skp_tx_req_i &&
                           (tx_kind_q != OS_KIND_SKP)) begin
                launch_autonomous_os(OS_KIND_SKP);
              end else begin
                tx_active_q    <= 1'b0;
                tx_kind_q      <= OS_KIND_NONE;
                tx_requested_q <= 1'b0;
              end
            end else begin
              // Update the initial completion contract for this unchanged
              // command.  Fixed modes count only requested OS completions.
              if (!command_done_reported_q) begin
                if (repeat_mode_is_fixed(command_repeat_mode_q)) begin
                  if (fixed_initial_active_q &&
                      (fixed_remaining_q > REPEAT_COUNT_W'(1))) begin
                    fixed_remaining_q <= fixed_remaining_q - 1'b1;
                  end else if (current_segment_completes_c) begin
                    fixed_remaining_q       <= '0;
                    fixed_initial_active_q  <= 1'b0;
                    command_done_reported_q <= 1'b1;
                  end
                end else if (current_segment_completes_c) begin
                  command_done_reported_q <= 1'b1;
                end
              end

              if (cadence_boundary_due_c) begin
                launch_autonomous_os(OS_KIND_EIEOS);
              end else if (skp_tx_req_i &&
                           (tx_kind_q != OS_KIND_SKP)) begin
                // SKP may preempt only between complete OS units and never
                // decrements fixed_remaining_q.
                launch_autonomous_os(OS_KIND_SKP);
              end else if (repeat_mode_continues(command_repeat_mode_q)) begin
                launch_requested_os(command_kind_q, command_fields_q);
              end else begin
                // SINGLE remains captured and completed until valid drops or
                // any part of the desired signature changes.
                tx_active_q    <= 1'b0;
                tx_kind_q      <= OS_KIND_NONE;
                tx_requested_q <= 1'b0;
              end
            end
          end else begin
            // An autonomous SKP/EIEOS completion never acknowledges nor
            // decrements the captured command.  It does, however, form an
            // atomic boundary at which the latest desired signature is read.
            if (!desired_matches_command_c) begin
              if (desired_command_valid_c) begin
                capture_desired_command(
                    pcie_os_kind_t'(os_tx_kind_i), request_fields_c,
                    pcie_os_repeat_mode_t'(os_tx_repeat_mode_i));
              end else begin
                clear_desired_command();
              end
            end

            if (cadence_boundary_due_c) begin
              launch_autonomous_os(OS_KIND_EIEOS);
            end else if (desired_command_valid_c &&
                         !desired_matches_command_c) begin
              // Resume or switch immediately after the inserted OS using the
              // latest coherent control snapshot.
              launch_requested_os(pcie_os_kind_t'(os_tx_kind_i),
                                  request_fields_c);
            end else if (desired_matches_command_c) begin
              if (skp_tx_req_i && (tx_kind_q != OS_KIND_SKP)) begin
                launch_autonomous_os(OS_KIND_SKP);
              end else if (repeat_mode_continues(command_repeat_mode_q) ||
                           !command_done_reported_q) begin
                launch_requested_os(command_kind_q, command_fields_q);
              end else begin
                tx_active_q    <= 1'b0;
                tx_kind_q      <= OS_KIND_NONE;
                tx_requested_q <= 1'b0;
              end
            end else if (skp_tx_req_i &&
                         (tx_kind_q != OS_KIND_SKP)) begin
              launch_autonomous_os(OS_KIND_SKP);
            end else begin
              tx_active_q    <= 1'b0;
              tx_kind_q      <= OS_KIND_NONE;
              tx_requested_q <= 1'b0;
            end
          end
        end else begin
          tx_word_index_q <= tx_word_index_q + 1'b1;
        end
      end else if (!tx_active_q) begin
        // While idle, dropping valid disarms SINGLE and all other captured
        // command state.  Reasserting the same signature is then a new segment.
        if (!desired_matches_command_c) begin
          if (desired_command_valid_c) begin
            capture_desired_command(
                pcie_os_kind_t'(os_tx_kind_i), request_fields_c,
                pcie_os_repeat_mode_t'(os_tx_repeat_mode_i));
          end else if (command_valid_q) begin
            clear_desired_command();
          end
        end

        if (cadence_due_c) begin
          launch_autonomous_os(OS_KIND_EIEOS);
        end else if (desired_command_valid_c &&
                     !desired_matches_command_c) begin
          // A newly presented/changed forced command has priority over SKP.
          launch_requested_os(pcie_os_kind_t'(os_tx_kind_i),
                              request_fields_c);
        end else if (desired_matches_command_c &&
                     (repeat_mode_continues(command_repeat_mode_q) ||
                      !command_done_reported_q)) begin
          if (skp_tx_req_i) begin
            launch_autonomous_os(OS_KIND_SKP);
          end else begin
            launch_requested_os(command_kind_q, command_fields_q);
          end
        end else if (skp_tx_req_i) begin
          launch_autonomous_os(OS_KIND_SKP);
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // RX full-sequence parser and per-substate qualification
  // --------------------------------------------------------------------------
  logic            rx_parse_active_q, rx_parse_active_d;
  pcie_os_kind_t   rx_parse_kind_q, rx_parse_kind_d;
  logic [4:0]      rx_symbol_index_q, rx_symbol_index_d;
  logic [7:0]      rx_short_symbol_q, rx_short_symbol_d;
  pcie_ts_fields_t rx_work_fields_q, rx_work_fields_d;
  logic            rx_encoding_error_q, rx_encoding_error_d;
  pcie_ts_fields_t rx_last_ts1_q, rx_last_ts1_d;
  pcie_ts_fields_t rx_last_ts2_q, rx_last_ts2_d;
  logic [7:0]      rx_ts1_count_q, rx_ts1_count_d;
  logic [7:0]      rx_ts2_count_q, rx_ts2_count_d;
  logic [7:0]      rx_idle_count_q, rx_idle_count_d;
  logic [5:0]      expected_state_q, expected_state_d;
  pcie_ts_fields_t rx_fields_out_d;

  logic rx_ts1_evt_d, rx_ts2_evt_d;
  logic rx_fts_evt_d, rx_skp_evt_d, rx_eios_evt_d, rx_eieos_evt_d;
  logic rx_idle_evt_d, rx_hot_reset_evt_d, rx_loopback_evt_d;
  logic rx_speed_change_evt_d;
  logic [7:0] rx_error_d;

  function automatic int unsigned ts_threshold(input logic [5:0] state_index);
    unique case (state_index)
      LTSSM_SS_POLLING_ACTIVE:
        return POLLING_ACTIVE_TS_QUAL_COUNT;
      LTSSM_SS_POLLING_CONFIGURATION:
        return POLLING_CONFIG_TS2_QUAL_COUNT;
      LTSSM_SS_CFG_LINKWIDTH_START,
      LTSSM_SS_CFG_LINKWIDTH_ACCEPT:
        return CFG_LINKWIDTH_TS_COUNT;
      LTSSM_SS_CFG_LANENUM_WAIT,
      LTSSM_SS_CFG_LANENUM_ACCEPT:
        return CFG_LANENUM_TS_COUNT;
      LTSSM_SS_CFG_COMPLETE:
        return CFG_COMPLETE_TS2_COUNT;
      LTSSM_SS_RECOVERY_RCVRLOCK,
      LTSSM_SS_RECOVERY_RCVRCFG:
        return RECOVERY_TS_COUNT;
      LTSSM_SS_L0_ACTIVE,
      LTSSM_SS_LOOPBACK_ENTRY,
      LTSSM_SS_LOOPBACK_EXIT,
      LTSSM_SS_HOT_RESET_ENTRY,
      LTSSM_SS_HOT_RESET_ACTIVE,
      LTSSM_SS_HOT_RESET_EXIT:
        return CFG_LINKWIDTH_TS_COUNT;
      default:
        return 1;
    endcase
  endfunction

  function automatic int unsigned idle_threshold(input logic [5:0] state_index);
    unique case (state_index)
      LTSSM_SS_CFG_IDLE:      return CFG_IDLE_COUNT;
      LTSSM_SS_RECOVERY_IDLE: return RECOVERY_IDLE_COUNT;
      default:                return LOGICAL_IDLE_QUAL_COUNT;
    endcase
  endfunction

  function automatic logic idle_state_enabled(input logic [5:0] state_index);
    return (state_index == LTSSM_SS_CFG_IDLE) ||
           (state_index == LTSSM_SS_RECOVERY_IDLE);
  endfunction

  function automatic logic expected_ts_kind(
    input logic [5:0] state_index,
    input logic       is_ts2
  );
    unique case (state_index)
      LTSSM_SS_POLLING_ACTIVE,
      LTSSM_SS_CFG_LINKWIDTH_START,
      LTSSM_SS_CFG_LINKWIDTH_ACCEPT,
      LTSSM_SS_CFG_LANENUM_WAIT,
      LTSSM_SS_RECOVERY_RCVRLOCK,
      LTSSM_SS_L0_ACTIVE,
      LTSSM_SS_LOOPBACK_ENTRY,
      LTSSM_SS_LOOPBACK_EXIT,
      LTSSM_SS_HOT_RESET_ENTRY,
      LTSSM_SS_HOT_RESET_ACTIVE,
      LTSSM_SS_HOT_RESET_EXIT:
        return !is_ts2;

      LTSSM_SS_POLLING_CONFIGURATION,
      LTSSM_SS_CFG_LANENUM_ACCEPT,
      LTSSM_SS_CFG_COMPLETE,
      LTSSM_SS_RECOVERY_RCVRCFG:
        return is_ts2;

      default:
        return 1'b0;
    endcase
  endfunction

  function automatic logic ts_fields_legal(
    input pcie_ts_fields_t fields,
    input logic [5:0]      state_index
  );
    logic exclusive_control;
    exclusive_control = $onehot0(fields.training_ctrl[2:0]);
    if (!fields.valid || !fields.rate_id[0] ||
        (fields.rate_id[1] && !fields.rate_id[0]) ||
        !exclusive_control || (fields.training_ctrl[7:6] != 0) ||
        (!fields.lane_num_is_pad && (fields.lane_num != 0))) begin
      return 1'b0;
    end
    if (fields.training_ctrl[5] &&
        (state_index != LTSSM_SS_RECOVERY_RCVRCFG)) begin
      return 1'b0;
    end
    unique case (state_index)
      LTSSM_SS_POLLING_ACTIVE,
      LTSSM_SS_POLLING_CONFIGURATION,
      LTSSM_SS_CFG_LINKWIDTH_START:
        return fields.link_num_is_pad && fields.lane_num_is_pad;
      LTSSM_SS_CFG_LINKWIDTH_ACCEPT:
        return !fields.link_num_is_pad && fields.lane_num_is_pad;
      LTSSM_SS_CFG_LANENUM_WAIT:
        return !fields.link_num_is_pad && fields.lane_num_is_pad;
      LTSSM_SS_CFG_LANENUM_ACCEPT,
      LTSSM_SS_CFG_COMPLETE:
        return !fields.link_num_is_pad && !fields.lane_num_is_pad &&
               (fields.lane_num == 0);
      default:
        return 1'b1;
    endcase
  endfunction

  always_comb begin : p_rx_parser
    logic [7:0] ch;
    logic       is_k;
    logic       complete_ts;
    logic       complete_short;
    logic       ts_is_ts2;
    logic       fields_legal;
    logic       kind_expected;
    logic [7:0] next_count;
    pcie_ts_fields_t completed_fields;

    rx_parse_active_d   = rx_parse_active_q;
    rx_parse_kind_d     = rx_parse_kind_q;
    rx_symbol_index_d   = rx_symbol_index_q;
    rx_short_symbol_d   = rx_short_symbol_q;
    rx_work_fields_d    = rx_work_fields_q;
    rx_encoding_error_d = rx_encoding_error_q;
    rx_last_ts1_d       = rx_last_ts1_q;
    rx_last_ts2_d       = rx_last_ts2_q;
    rx_ts1_count_d      = rx_ts1_count_q;
    rx_ts2_count_d      = rx_ts2_count_q;
    rx_idle_count_d     = rx_idle_count_q;
    expected_state_d    = os_rx_expected_state_i;
    rx_fields_out_d     = os_rx_fields_o;

    rx_ts1_evt_d         = 1'b0;
    rx_ts2_evt_d         = 1'b0;
    rx_fts_evt_d         = 1'b0;
    rx_skp_evt_d         = 1'b0;
    rx_eios_evt_d        = 1'b0;
    rx_eieos_evt_d       = 1'b0;
    rx_idle_evt_d        = 1'b0;
    rx_hot_reset_evt_d   = 1'b0;
    rx_loopback_evt_d    = 1'b0;
    rx_speed_change_evt_d = 1'b0;
    rx_error_d            = 8'h00;

    if (os_rx_expected_state_i != expected_state_q) begin
      rx_parse_active_d   = 1'b0;
      rx_parse_kind_d     = OS_KIND_NONE;
      rx_symbol_index_d   = '0;
      rx_encoding_error_d = 1'b0;
      rx_ts1_count_d      = '0;
      rx_ts2_count_d      = '0;
      rx_idle_count_d     = '0;
      rx_last_ts1_d       = '0;
      rx_last_ts2_d       = '0;
    end else begin
      // Logical Idle is counted only after descrambling and independently of
      // the raw ordered-set stream.
      if (rx_logical_idle_valid_i &&
          idle_state_enabled(os_rx_expected_state_i)) begin
        for (int unsigned idle_lane = 0; idle_lane < 2; idle_lane++) begin
          if (rx_logical_idle_char_mask_i[idle_lane]) begin
            if (rx_idle_count_d != 8'hff) begin
              next_count = rx_idle_count_d + 1'b1;
              rx_idle_count_d = next_count;
            end else begin
              next_count = rx_idle_count_d;
            end
            if (next_count == idle_threshold(os_rx_expected_state_i)) begin
              rx_idle_evt_d = 1'b1;
            end
          end else begin
            rx_idle_count_d = '0;
          end
        end
      end else if (!idle_state_enabled(os_rx_expected_state_i)) begin
        rx_idle_count_d = '0;
      end

      if (os_rx_valid_i) begin
        if (os_rx_error_i != 0) begin
          // A raw symbol error is also an explicit break of an in-progress
          // consecutive qualification run.  Errors outside a candidate/run
          // are reported by the classifier/GT error path, not duplicated here.
          if (rx_parse_active_q || (rx_ts1_count_q != 0) ||
              (rx_ts2_count_q != 0)) begin
            rx_error_d = OS_RX_ERR_CANDIDATE;
          end
          rx_parse_active_d   = 1'b0;
          rx_parse_kind_d     = OS_KIND_NONE;
          rx_symbol_index_d   = '0;
          rx_encoding_error_d = 1'b0;
          rx_ts1_count_d      = '0;
          rx_ts2_count_d      = '0;
        end else begin
          for (int unsigned lane = 0; lane < 2; lane++) begin
            ch             = os_rx_data_i[lane*8 +: 8];
            is_k           = os_rx_is_k_i[lane];
            complete_ts    = 1'b0;
            complete_short = 1'b0;

            if (is_k && (ch == K_COM)) begin
              if (rx_parse_active_d && (rx_error_d == 0)) begin
                rx_error_d = OS_RX_ERR_TRUNCATED;
                rx_ts1_count_d = '0;
                rx_ts2_count_d = '0;
              end
              rx_parse_active_d   = 1'b1;
              rx_parse_kind_d     = OS_KIND_NONE;
              rx_symbol_index_d   = 5'd1;
              rx_encoding_error_d = 1'b0;
              rx_work_fields_d    = '0;
              rx_idle_count_d     = '0;
            end else if (rx_parse_active_d) begin
              unique case (rx_symbol_index_d)
                5'd1: begin
                  if (is_k && (ch == K_SKP)) begin
                    rx_parse_kind_d   = OS_KIND_SKP;
                    rx_short_symbol_d = K_SKP;
                    rx_symbol_index_d = 5'd2;
                  end else if (is_k && (ch == K_FTS)) begin
                    rx_parse_kind_d   = OS_KIND_FTS;
                    rx_short_symbol_d = K_FTS;
                    rx_symbol_index_d = 5'd2;
                  end else if (is_k && (ch == K_EIOS)) begin
                    rx_parse_kind_d   = OS_KIND_EIOS;
                    rx_short_symbol_d = K_EIOS;
                    rx_symbol_index_d = 5'd2;
                  end else if (is_k && (ch == K_EIE)) begin
                    rx_parse_kind_d   = OS_KIND_EIEOS;
                    rx_symbol_index_d = 5'd2;
                  end else if (!is_k || (ch == K_PAD)) begin
                    rx_parse_kind_d = OS_KIND_NONE;
                    rx_work_fields_d.link_num_is_pad = is_k;
                    rx_work_fields_d.link_num = is_k ? 8'h00 : ch;
                    rx_symbol_index_d = 5'd2;
                  end else begin
                    rx_error_d          = OS_RX_ERR_MALFORMED;
                    rx_parse_active_d   = 1'b0;
                    rx_ts1_count_d      = '0;
                    rx_ts2_count_d      = '0;
                  end
                end

                5'd2: begin
                  if ((rx_parse_kind_d == OS_KIND_SKP) ||
                      (rx_parse_kind_d == OS_KIND_FTS) ||
                      (rx_parse_kind_d == OS_KIND_EIOS)) begin
                    if (is_k && (ch == rx_short_symbol_d)) begin
                      rx_symbol_index_d = 5'd3;
                    end else begin
                      rx_error_d        = OS_RX_ERR_MALFORMED;
                      rx_parse_active_d = 1'b0;
                      rx_ts1_count_d    = '0;
                      rx_ts2_count_d    = '0;
                    end
                  end else if (rx_parse_kind_d == OS_KIND_EIEOS) begin
                    if (is_k && (ch == K_EIE)) begin
                      rx_symbol_index_d = 5'd3;
                    end else begin
                      rx_error_d        = OS_RX_ERR_MALFORMED;
                      rx_parse_active_d = 1'b0;
                      rx_ts1_count_d    = '0;
                      rx_ts2_count_d    = '0;
                    end
                  end else if (!is_k || (ch == K_PAD)) begin
                    rx_work_fields_d.lane_num_is_pad = is_k;
                    rx_work_fields_d.lane_num = is_k ? 5'd0 : ch[4:0];
                    if (!is_k && (ch[7:5] != 0)) begin
                      rx_encoding_error_d = 1'b1;
                    end
                    rx_symbol_index_d = 5'd3;
                  end else begin
                    rx_error_d        = OS_RX_ERR_MALFORMED;
                    rx_parse_active_d = 1'b0;
                    rx_ts1_count_d    = '0;
                    rx_ts2_count_d    = '0;
                  end
                end

                5'd3: begin
                  if ((rx_parse_kind_d == OS_KIND_SKP) ||
                      (rx_parse_kind_d == OS_KIND_FTS) ||
                      (rx_parse_kind_d == OS_KIND_EIOS)) begin
                    if (is_k && (ch == rx_short_symbol_d)) begin
                      complete_short = 1'b1;
                    end else begin
                      rx_error_d     = OS_RX_ERR_MALFORMED;
                      rx_ts1_count_d = '0;
                      rx_ts2_count_d = '0;
                    end
                    rx_parse_active_d = 1'b0;
                    rx_symbol_index_d = '0;
                  end else if (rx_parse_kind_d == OS_KIND_EIEOS) begin
                    if (is_k && (ch == K_EIE)) begin
                      rx_symbol_index_d = 5'd4;
                    end else begin
                      rx_error_d        = OS_RX_ERR_MALFORMED;
                      rx_parse_active_d = 1'b0;
                      rx_ts1_count_d    = '0;
                      rx_ts2_count_d    = '0;
                    end
                  end else if (!is_k) begin
                    rx_work_fields_d.n_fts = ch;
                    rx_symbol_index_d = 5'd4;
                  end else begin
                    rx_error_d        = OS_RX_ERR_MALFORMED;
                    rx_parse_active_d = 1'b0;
                    rx_ts1_count_d    = '0;
                    rx_ts2_count_d    = '0;
                  end
                end

                5'd4: begin
                  if (rx_parse_kind_d == OS_KIND_EIEOS) begin
                    if (is_k && (ch == K_EIE)) begin
                      rx_symbol_index_d = 5'd5;
                    end else begin
                      rx_error_d        = OS_RX_ERR_MALFORMED;
                      rx_parse_active_d = 1'b0;
                      rx_ts1_count_d    = '0;
                      rx_ts2_count_d    = '0;
                    end
                  end else if (!is_k) begin
                    rx_work_fields_d.rate_id = {ch[2], ch[1]};
                    rx_work_fields_d.training_ctrl[5] = ch[7];
                    if (ch[0] || (ch[6:3] != 0)) begin
                      rx_encoding_error_d = 1'b1;
                    end
                    rx_symbol_index_d = 5'd5;
                  end else begin
                    rx_error_d        = OS_RX_ERR_MALFORMED;
                    rx_parse_active_d = 1'b0;
                    rx_ts1_count_d    = '0;
                    rx_ts2_count_d    = '0;
                  end
                end

                5'd5: begin
                  if (rx_parse_kind_d == OS_KIND_EIEOS) begin
                    if (is_k && (ch == K_EIE)) begin
                      rx_symbol_index_d = 5'd6;
                    end else begin
                      rx_error_d        = OS_RX_ERR_MALFORMED;
                      rx_parse_active_d = 1'b0;
                      rx_ts1_count_d    = '0;
                      rx_ts2_count_d    = '0;
                    end
                  end else if (!is_k) begin
                    rx_work_fields_d.training_ctrl[4:0] = ch[4:0];
                    if (ch[7:5] != 0) begin
                      rx_encoding_error_d = 1'b1;
                    end
                    rx_symbol_index_d = 5'd6;
                  end else begin
                    rx_error_d        = OS_RX_ERR_MALFORMED;
                    rx_parse_active_d = 1'b0;
                    rx_ts1_count_d    = '0;
                    rx_ts2_count_d    = '0;
                  end
                end

                5'd6: begin
                  if (rx_parse_kind_d == OS_KIND_EIEOS) begin
                    if (is_k && (ch == K_EIE)) begin
                      rx_symbol_index_d = 5'd7;
                    end else begin
                      rx_error_d        = OS_RX_ERR_MALFORMED;
                      rx_parse_active_d = 1'b0;
                      rx_ts1_count_d    = '0;
                      rx_ts2_count_d    = '0;
                    end
                  end else if (!is_k && ((ch == D_TS1) || (ch == D_TS2))) begin
                    rx_parse_kind_d = (ch == D_TS2) ? OS_KIND_TS2 : OS_KIND_TS1;
                    rx_work_fields_d.is_ts2 = (ch == D_TS2);
                    rx_symbol_index_d = 5'd7;
                  end else begin
                    rx_error_d        = OS_RX_ERR_MALFORMED;
                    rx_parse_active_d = 1'b0;
                    rx_ts1_count_d    = '0;
                    rx_ts2_count_d    = '0;
                  end
                end

                default: begin
                  if (rx_parse_kind_d == OS_KIND_EIEOS) begin
                    if ((rx_symbol_index_d <= 5'd14) && is_k &&
                        (ch == K_EIE)) begin
                      rx_symbol_index_d = rx_symbol_index_d + 1'b1;
                    end else if ((rx_symbol_index_d == 5'd15) && !is_k &&
                                 (ch == D_TS1)) begin
                      rx_eieos_evt_d     = 1'b1;
                      rx_parse_active_d  = 1'b0;
                      rx_symbol_index_d  = '0;
                    end else begin
                      rx_error_d         = OS_RX_ERR_MALFORMED;
                      rx_parse_active_d  = 1'b0;
                      rx_ts1_count_d     = '0;
                      rx_ts2_count_d     = '0;
                    end
                  end else if (!is_k &&
                               (((rx_parse_kind_d == OS_KIND_TS1) &&
                                 (ch == D_TS1)) ||
                                ((rx_parse_kind_d == OS_KIND_TS2) &&
                                 (ch == D_TS2)))) begin
                    if (rx_symbol_index_d == 5'd15) begin
                      complete_ts       = 1'b1;
                      rx_parse_active_d = 1'b0;
                      rx_symbol_index_d = '0;
                    end else begin
                      rx_symbol_index_d = rx_symbol_index_d + 1'b1;
                    end
                  end else begin
                    rx_error_d        = OS_RX_ERR_MALFORMED;
                    rx_parse_active_d = 1'b0;
                    rx_ts1_count_d    = '0;
                    rx_ts2_count_d    = '0;
                  end
                end
              endcase

              if (complete_short) begin
                unique case (rx_parse_kind_d)
                  OS_KIND_SKP: begin
                    rx_skp_evt_d = 1'b1;
                    // SKP is a legal interruption of consecutive TS traffic.
                  end
                  OS_KIND_FTS: begin
                    rx_fts_evt_d    = 1'b1;
                    rx_ts1_count_d  = '0;
                    rx_ts2_count_d  = '0;
                  end
                  OS_KIND_EIOS: begin
                    rx_eios_evt_d   = 1'b1;
                    rx_ts1_count_d  = '0;
                    rx_ts2_count_d  = '0;
                  end
                  default: ;
                endcase
              end

              if (complete_ts) begin
                completed_fields       = rx_work_fields_d;
                completed_fields.valid = 1'b1;
                ts_is_ts2 = (rx_parse_kind_d == OS_KIND_TS2);
                completed_fields.is_ts2 = ts_is_ts2;
                fields_legal = !rx_encoding_error_d &&
                    ts_fields_legal(completed_fields,
                                    os_rx_expected_state_i);
                kind_expected = expected_ts_kind(os_rx_expected_state_i,
                                                 ts_is_ts2);

                if (!fields_legal) begin
                  rx_error_d     = OS_RX_ERR_FIELD_MISMATCH;
                  rx_ts1_count_d = '0;
                  rx_ts2_count_d = '0;
                end else begin
                  rx_fields_out_d = completed_fields;
                  if (!kind_expected) begin
                    rx_error_d     = OS_RX_ERR_UNEXPECTED;
                    rx_ts1_count_d = '0;
                    rx_ts2_count_d = '0;
                  end else if (!ts_is_ts2) begin
                    rx_ts2_count_d = '0;
                    if (rx_last_ts1_q.valid &&
                        (completed_fields == rx_last_ts1_q)) begin
                      next_count = (rx_ts1_count_q == 8'hff) ? 8'hff :
                                   rx_ts1_count_q + 1'b1;
                    end else begin
                      next_count = 8'd1;
                      if (rx_ts1_count_q != 0) begin
                        rx_error_d = OS_RX_ERR_COUNT_BROKEN;
                      end
                    end
                    rx_last_ts1_d  = completed_fields;
                    rx_ts1_count_d = next_count;
                    if (next_count == ts_threshold(os_rx_expected_state_i)) begin
                      rx_ts1_evt_d = 1'b1;
                      rx_hot_reset_evt_d =
                          |(completed_fields.training_ctrl & TS_CTRL_HOT_RESET);
                      rx_loopback_evt_d =
                          |(completed_fields.training_ctrl & TS_CTRL_LOOPBACK);
                      rx_speed_change_evt_d =
                          |(completed_fields.training_ctrl & TS_CTRL_SPEED_CHANGE);
                    end
                  end else begin
                    rx_ts1_count_d = '0;
                    if (rx_last_ts2_q.valid &&
                        (completed_fields == rx_last_ts2_q)) begin
                      next_count = (rx_ts2_count_q == 8'hff) ? 8'hff :
                                   rx_ts2_count_q + 1'b1;
                    end else begin
                      next_count = 8'd1;
                      if (rx_ts2_count_q != 0) begin
                        rx_error_d = OS_RX_ERR_COUNT_BROKEN;
                      end
                    end
                    rx_last_ts2_d  = completed_fields;
                    rx_ts2_count_d = next_count;
                    if (next_count == ts_threshold(os_rx_expected_state_i)) begin
                      rx_ts2_evt_d = 1'b1;
                      rx_hot_reset_evt_d =
                          |(completed_fields.training_ctrl & TS_CTRL_HOT_RESET);
                      rx_loopback_evt_d =
                          |(completed_fields.training_ctrl & TS_CTRL_LOOPBACK);
                      rx_speed_change_evt_d =
                          |(completed_fields.training_ctrl & TS_CTRL_SPEED_CHANGE);
                    end
                  end
                end
                rx_encoding_error_d = 1'b0;
              end
            end else if ((rx_ts1_count_d != 0) ||
                         (rx_ts2_count_d != 0)) begin
              // Only SKP/EIEOS may interrupt consecutive TS ordered sets; both
              // begin with COM and therefore enter the parser above.
              rx_error_d     = OS_RX_ERR_COUNT_BROKEN;
              rx_ts1_count_d = '0;
              rx_ts2_count_d = '0;
            end
          end
        end
      end else begin
        // The GT character stream has no ready and cannot legally bubble while
        // an ordered set or a consecutive qualification run is in progress.
        // Reset partial context even when alignment loss suppresses RX valid.
        if (rx_parse_active_q) begin
          rx_error_d = OS_RX_ERR_TRUNCATED;
        end else if ((rx_ts1_count_q != 0) || (rx_ts2_count_q != 0)) begin
          rx_error_d = OS_RX_ERR_COUNT_BROKEN;
        end
        rx_parse_active_d   = 1'b0;
        rx_parse_kind_d     = OS_KIND_NONE;
        rx_symbol_index_d   = '0;
        rx_encoding_error_d = 1'b0;
        rx_ts1_count_d      = '0;
        rx_ts2_count_d      = '0;
        if (!rx_logical_idle_valid_i) begin
          rx_idle_count_d = '0;
        end
      end
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_rst_ni) begin : p_rx_state
    if (!sym_rst_ni) begin
      rx_parse_active_q                  <= 1'b0;
      rx_parse_kind_q                    <= OS_KIND_NONE;
      rx_symbol_index_q                  <= '0;
      rx_short_symbol_q                  <= '0;
      rx_work_fields_q                   <= '0;
      rx_encoding_error_q                <= 1'b0;
      rx_last_ts1_q                      <= '0;
      rx_last_ts2_q                      <= '0;
      rx_ts1_count_q                     <= '0;
      rx_ts2_count_q                     <= '0;
      rx_idle_count_q                    <= '0;
      expected_state_q                   <= '0;
      os_rx_fields_o                     <= '0;
      os_rx_ts1_qualified_evt_o          <= 1'b0;
      os_rx_ts2_qualified_evt_o          <= 1'b0;
      os_rx_fts_evt_o                    <= 1'b0;
      os_rx_skp_evt_o                    <= 1'b0;
      os_rx_eios_evt_o                   <= 1'b0;
      os_rx_eieos_evt_o                  <= 1'b0;
      rx_logical_idle_qualified_evt_o    <= 1'b0;
      os_rx_hot_reset_evt_o              <= 1'b0;
      os_rx_loopback_evt_o               <= 1'b0;
      os_rx_speed_change_evt_o           <= 1'b0;
      os_rx_error_o                      <= 8'h00;
    end else begin
      rx_parse_active_q   <= rx_parse_active_d;
      rx_parse_kind_q     <= rx_parse_kind_d;
      rx_symbol_index_q   <= rx_symbol_index_d;
      rx_short_symbol_q   <= rx_short_symbol_d;
      rx_work_fields_q    <= rx_work_fields_d;
      rx_encoding_error_q <= rx_encoding_error_d;
      rx_last_ts1_q       <= rx_last_ts1_d;
      rx_last_ts2_q       <= rx_last_ts2_d;
      rx_ts1_count_q      <= rx_ts1_count_d;
      rx_ts2_count_q      <= rx_ts2_count_d;
      rx_idle_count_q     <= rx_idle_count_d;
      expected_state_q    <= expected_state_d;
      os_rx_fields_o      <= rx_fields_out_d;

      os_rx_ts1_qualified_evt_o       <= rx_ts1_evt_d;
      os_rx_ts2_qualified_evt_o       <= rx_ts2_evt_d;
      os_rx_fts_evt_o                 <= rx_fts_evt_d;
      os_rx_skp_evt_o                 <= rx_skp_evt_d;
      os_rx_eios_evt_o                <= rx_eios_evt_d;
      os_rx_eieos_evt_o               <= rx_eieos_evt_d;
      rx_logical_idle_qualified_evt_o <= rx_idle_evt_d;
      os_rx_hot_reset_evt_o           <= rx_hot_reset_evt_d;
      os_rx_loopback_evt_o            <= rx_loopback_evt_d;
      os_rx_speed_change_evt_o        <= rx_speed_change_evt_d;
      os_rx_error_o                   <= rx_error_d;
    end
  end

endmodule
