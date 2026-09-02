module phy_rx_classifier_deframer #(
  parameter int unsigned PHY_MAX_PACKET_BYTES =
      pcie_gen12_phy_timing_pkg::PHY_MAX_PACKET_BYTES
) (
  input  logic        sym_clk_i,
  input  logic        sym_rst_ni,

  input  logic [15:0] rx_symbol_data_i,
  input  logic [1:0]  rx_symbol_is_k_i,
  input  logic        rx_symbol_valid_i,
  input  logic [1:0]  rx_symbol_is_comma_i,
  input  logic [1:0]  rx_symbol_code_error_i,
  input  logic [1:0]  rx_symbol_disparity_error_i,
  input  logic        rx_byte_aligned_i,

  output logic [15:0] os_rx_candidate_data_o,
  output logic [1:0]  os_rx_candidate_is_k_o,
  output logic        os_rx_candidate_valid_o,
  output logic [3:0]  os_rx_candidate_error_o,

  output logic [15:0] rx_descr_data_o,
  output logic [1:0]  rx_descr_is_k_o,
  output logic        rx_descr_valid_o,
  output logic [3:0]  rx_descr_class_o,
  // Private extension required because the two characters can have different
  // LFSR actions (for example, a payload byte followed by END, or COM in lane 1).
  output logic [3:0]  rx_descr_lfsr_action_o,
  input  logic [15:0] rx_descrambled_data_i,
  input  logic        rx_descrambled_valid_i,

  output logic        rxbuf_pkt_valid_o,
  input  logic        rxbuf_pkt_ready_i,
  output logic [15:0] rxbuf_pkt_data_o,
  output logic [1:0]  rxbuf_pkt_keep_o,
  output logic        rxbuf_pkt_sop_o,
  output logic        rxbuf_pkt_eop_o,
  output logic        rxbuf_pkt_kind_o,
  output logic        rxbuf_pkt_abort_o,
  // Private candidate-cancel channel. It is independent of ready because the
  // serial receive path can never be backpressured.
  output logic        rxbuf_pkt_drop_o,

  // Descrambled Logical Idle observation for phy_ordered_set. valid denotes
  // an outside-packet, non-OS data pair; mask is in wire-time character order.
  output logic        rx_logical_idle_valid_o,
  output logic [1:0]  rx_logical_idle_char_mask_o,

  output logic        rx_align_loss_evt_o,
  output logic        rx_invalid_k_evt_o,
  output logic        rx_code_error_evt_o,
  output logic        rx_disparity_error_evt_o,
  output logic        rx_frame_error_evt_o,
  output logic        rx_packet_buffer_error_evt_o,
  output logic        rx_packet_drop_evt_o,
  output logic        rx_packet_active_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  localparam int unsigned BYTE_COUNT_W =
      (PHY_MAX_PACKET_BYTES < 2) ? 1 : $clog2(PHY_MAX_PACKET_BYTES + 1);

  typedef enum logic [1:0] {
    PRE_NONE,
    PRE_TS,
    PRE_SHORT,
    PRE_EIEOS
  } pre_kind_t;

  typedef enum logic [1:0] {
    RX_HUNT,
    RX_CAPTURE,
    RX_DISCARD
  } rx_frame_state_t;

  // --------------------------------------------------------------------------
  // Raw pre-classification. This logic is deliberately before descrambling.
  // --------------------------------------------------------------------------
  logic       pre_active_q, pre_active_d;
  pre_kind_t  pre_kind_q, pre_kind_d;
  logic [4:0] pre_pos_q, pre_pos_d;
  logic [7:0] pre_short_symbol_q, pre_short_symbol_d;
  logic [3:0] pre_short_class_q, pre_short_class_d;

  logic [3:0] lane0_class_c, lane1_class_c;
  logic [1:0] lane0_action_c, lane1_action_c;
  logic [1:0] effective_disparity_c;
  logic [1:0] comma_mismatch_c;

  function automatic logic is_frame_delimiter(input logic [7:0] ch);
    return (ch == K_STP) || (ch == K_SDP) ||
           (ch == K_END) || (ch == K_EDB);
  endfunction

  always_comb begin : p_preclass
    logic       active_w;
    pre_kind_t  kind_w;
    logic [4:0] pos_w;
    logic [7:0] short_symbol_w;
    logic [3:0] short_class_w;
    logic [7:0] ch;
    logic       is_k;
    logic       code_bad;
    logic [3:0] class_w;
    logic [1:0] action_w;

    active_w       = pre_active_q;
    kind_w         = pre_kind_q;
    pos_w          = pre_pos_q;
    short_symbol_w = pre_short_symbol_q;
    short_class_w  = pre_short_class_q;
    lane0_class_c  = CHAR_CLASS_UNKNOWN;
    lane1_class_c  = CHAR_CLASS_UNKNOWN;
    lane0_action_c = LFSR_ACTION_HOLD;
    lane1_action_c = LFSR_ACTION_HOLD;

    for (int unsigned lane = 0; lane < 2; lane++) begin
      ch       = rx_symbol_data_i[lane*8 +: 8];
      is_k     = rx_symbol_is_k_i[lane];
      code_bad = rx_symbol_code_error_i[lane];
      class_w  = CHAR_CLASS_UNKNOWN;
      action_w = LFSR_ACTION_HOLD;

      // Alignment loss invalidates the pair. Within an aligned pair, a
      // not-in-table code has priority over K, disparity and comma metadata.
      if (!rx_byte_aligned_i || code_bad) begin
        active_w = 1'b0;
        kind_w   = PRE_NONE;
        pos_w    = '0;
      end else if (is_k && (ch == K_COM)) begin
        class_w  = CHAR_CLASS_COM;
        action_w = LFSR_ACTION_RESET;
        active_w = 1'b1;
        kind_w   = PRE_NONE;
        pos_w    = 5'd1;
      end else if (active_w) begin
        if (pos_w == 5'd1) begin
          if (!is_k || (ch == K_PAD)) begin
            // A TS Link Number may be a Data symbol or PAD (K23.7).
            kind_w   = PRE_TS;
            class_w  = is_k ? CHAR_CLASS_PAD : CHAR_CLASS_TS;
            action_w = LFSR_ACTION_BYPASS;
            pos_w    = 5'd2;
          end else begin
            unique case (ch)
              K_SKP: begin
                kind_w          = PRE_SHORT;
                short_symbol_w  = K_SKP;
                short_class_w   = CHAR_CLASS_SKP;
                class_w         = CHAR_CLASS_SKP;
                action_w        = LFSR_ACTION_HOLD;
                pos_w           = 5'd2;
              end
              K_FTS: begin
                kind_w          = PRE_SHORT;
                short_symbol_w  = K_FTS;
                short_class_w   = CHAR_CLASS_FTS;
                class_w         = CHAR_CLASS_FTS;
                action_w        = LFSR_ACTION_BYPASS;
                pos_w           = 5'd2;
              end
              K_EIOS: begin
                kind_w          = PRE_SHORT;
                short_symbol_w  = K_EIOS;
                short_class_w   = CHAR_CLASS_EIOS;
                class_w         = CHAR_CLASS_EIOS;
                action_w        = LFSR_ACTION_BYPASS;
                pos_w           = 5'd2;
              end
              K_EIE: begin
                kind_w   = PRE_EIEOS;
                class_w  = CHAR_CLASS_EIEOS;
                action_w = LFSR_ACTION_BYPASS;
                pos_w    = 5'd2;
              end
              default: begin
                active_w = 1'b0;
                kind_w   = PRE_NONE;
                pos_w    = '0;
                class_w  = CHAR_CLASS_UNKNOWN;
                action_w = LFSR_ACTION_BYPASS;
              end
            endcase
          end
        end else begin
          unique case (kind_w)
            PRE_SHORT: begin
              if (is_k && (ch == short_symbol_w)) begin
                class_w  = short_class_w;
                action_w = (short_symbol_w == K_SKP) ?
                           LFSR_ACTION_HOLD : LFSR_ACTION_BYPASS;
                if (pos_w == 5'd3) begin
                  active_w = 1'b0;
                  kind_w   = PRE_NONE;
                  pos_w    = '0;
                end else begin
                  pos_w = pos_w + 1'b1;
                end
              end else begin
                active_w = 1'b0;
                kind_w   = PRE_NONE;
                pos_w    = '0;
                // The mismatching character belongs to a malformed candidate,
                // so it must not leak into Logical Idle classification.
                class_w  = CHAR_CLASS_UNKNOWN;
                action_w = is_k ? LFSR_ACTION_BYPASS : LFSR_ACTION_ADV8;
              end
            end

            PRE_EIEOS: begin
              if ((pos_w <= 5'd14) && is_k && (ch == K_EIE)) begin
                class_w  = CHAR_CLASS_EIEOS;
                action_w = LFSR_ACTION_BYPASS;
                pos_w    = pos_w + 1'b1;
              end else if ((pos_w == 5'd15) && !is_k && (ch == D_TS1)) begin
                class_w  = CHAR_CLASS_EIEOS;
                action_w = LFSR_ACTION_BYPASS;
                active_w = 1'b0;
                kind_w   = PRE_NONE;
                pos_w    = '0;
              end else begin
                active_w = 1'b0;
                kind_w   = PRE_NONE;
                pos_w    = '0;
                class_w  = CHAR_CLASS_UNKNOWN;
                action_w = is_k ? LFSR_ACTION_BYPASS : LFSR_ACTION_ADV8;
              end
            end

            PRE_TS: begin
              // TS symbols 1..5 may include PAD only in the Link/Lane fields;
              // symbols 6..15 are the repeated Data identifier.
              if (((pos_w <= 5'd2) && (!is_k || (ch == K_PAD))) ||
                  ((pos_w >= 5'd3) && !is_k)) begin
                class_w  = is_k ? CHAR_CLASS_PAD : CHAR_CLASS_TS;
                action_w = LFSR_ACTION_BYPASS;
                if (pos_w == 5'd15) begin
                  active_w = 1'b0;
                  kind_w   = PRE_NONE;
                  pos_w    = '0;
                end else begin
                  pos_w = pos_w + 1'b1;
                end
              end else begin
                active_w = 1'b0;
                kind_w   = PRE_NONE;
                pos_w    = '0;
                class_w  = CHAR_CLASS_UNKNOWN;
                action_w = LFSR_ACTION_BYPASS;
              end
            end

            default: begin
              active_w = 1'b0;
              kind_w   = PRE_NONE;
              pos_w    = '0;
              class_w  = CHAR_CLASS_UNKNOWN;
              action_w = is_k ? LFSR_ACTION_BYPASS : LFSR_ACTION_ADV8;
            end
          endcase
        end
      end else if (is_k) begin
        if (is_frame_delimiter(ch)) begin
          class_w = CHAR_CLASS_FRAME;
        end else begin
          class_w = CHAR_CLASS_UNKNOWN;
        end
        action_w = (ch == K_SKP) ? LFSR_ACTION_HOLD : LFSR_ACTION_BYPASS;
      end else begin
        class_w  = CHAR_CLASS_DATA;
        action_w = LFSR_ACTION_ADV8;
      end

      if (lane == 0) begin
        lane0_class_c  = class_w;
        lane0_action_c = action_w;
      end else begin
        lane1_class_c  = class_w;
        lane1_action_c = action_w;
      end
    end

    pre_active_d       = active_w;
    pre_kind_d         = kind_w;
    pre_pos_d          = pos_w;
    pre_short_symbol_d = short_symbol_w;
    pre_short_class_d  = short_class_w;
  end

  assign effective_disparity_c = rx_symbol_disparity_error_i &
                                  ~rx_symbol_code_error_i;
  assign comma_mismatch_c[0] = rx_symbol_is_comma_i[0] ^
      (!rx_symbol_code_error_i[0] && rx_symbol_is_k_i[0] &&
       (rx_symbol_data_i[7:0] == K_COM));
  assign comma_mismatch_c[1] = rx_symbol_is_comma_i[1] ^
      (!rx_symbol_code_error_i[1] && rx_symbol_is_k_i[1] &&
       (rx_symbol_data_i[15:8] == K_COM));

  always_comb begin
    os_rx_candidate_data_o  = rx_symbol_data_i;
    os_rx_candidate_is_k_o  = rx_symbol_is_k_i;
    os_rx_candidate_valid_o = rx_symbol_valid_i;
    os_rx_candidate_error_o = {
      |rx_symbol_code_error_i,
      |effective_disparity_c,
      !rx_byte_aligned_i,
      |comma_mismatch_c
    };

    rx_descr_data_o        = rx_symbol_data_i;
    rx_descr_is_k_o        = rx_symbol_is_k_i;
    rx_descr_valid_o       = rx_symbol_valid_i;
    rx_descr_lfsr_action_o = {lane1_action_c, lane0_action_c};

    if (lane0_class_c == lane1_class_c) begin
      rx_descr_class_o = lane0_class_c;
    end else if ((lane0_class_c == CHAR_CLASS_COM) ||
                 (lane1_class_c == CHAR_CLASS_COM)) begin
      rx_descr_class_o = CHAR_CLASS_COM;
    end else if ((lane0_class_c == CHAR_CLASS_UNKNOWN) ||
                 (lane1_class_c == CHAR_CLASS_UNKNOWN)) begin
      rx_descr_class_o = CHAR_CLASS_UNKNOWN;
    end else if ((lane0_class_c == CHAR_CLASS_FRAME) ||
                 (lane1_class_c == CHAR_CLASS_FRAME)) begin
      rx_descr_class_o = CHAR_CLASS_FRAME;
    end else begin
      // Mixed positions within one ordered set remain bypassed by the private
      // action vector; this summary class is only for debug/legacy consumers.
      rx_descr_class_o = lane0_class_c;
    end
  end

  // --------------------------------------------------------------------------
  // Deframer. The scrambler/descrambler contract is a combinational data result
  // with registered LFSR state, so raw sideband and returned data remain in the
  // same cycle. The loop consumes lane 0 before lane 1; markers may therefore
  // start/end on either lane and may cross beat boundaries.
  // --------------------------------------------------------------------------
  rx_frame_state_t frame_state_q, frame_state_d;
  logic            packet_kind_q, packet_kind_d;
  logic            sop_pending_q, sop_pending_d;
  logic            packet_poison_q, packet_poison_d;
  logic [BYTE_COUNT_W-1:0] packet_byte_count_q, packet_byte_count_d;
  logic            aligned_seen_q;

  logic        emit_valid_d;
  logic [15:0] emit_data_d;
  logic [1:0]  emit_keep_d;
  logic        emit_sop_d;
  logic        emit_eop_d;
  logic        emit_kind_d;
  logic        emit_abort_d;
  logic        emit_drop_d;
  logic        logical_idle_valid_d;
  logic [1:0]  logical_idle_mask_d;
  logic        invalid_k_evt_d;
  logic        frame_error_evt_d;
  logic        buffer_error_evt_d;
  logic        packet_drop_evt_d;

  always_comb begin : p_deframe_next
    rx_frame_state_t state_w;
    logic            kind_w;
    logic            sop_w;
    logic            poison_w;
    logic [BYTE_COUNT_W-1:0] byte_count_w;
    logic [15:0] data_w;
    logic [1:0]  keep_w;
    logic        eop_w;
    logic        abort_w;
    logic        sop_for_emit_w;
    logic        beat_kind_w;
    logic [1:0]  idle_mask_w;
    logic        idle_observation_w;
    logic [7:0]  raw_ch;
    logic [7:0]  descr_ch;
    logic [3:0]  char_class;
    logic        is_k;
    logic        code_bad;
    logic        disp_bad;

    state_w            = frame_state_q;
    kind_w             = packet_kind_q;
    sop_w              = sop_pending_q;
    poison_w           = packet_poison_q;
    byte_count_w       = packet_byte_count_q;
    data_w             = '0;
    keep_w             = '0;
    eop_w              = 1'b0;
    abort_w            = 1'b0;
    sop_for_emit_w     = 1'b0;
    beat_kind_w        = packet_kind_q;
    idle_mask_w        = '0;
    idle_observation_w = 1'b0;

    emit_valid_d          = 1'b0;
    emit_data_d           = '0;
    emit_keep_d           = '0;
    emit_sop_d            = 1'b0;
    emit_eop_d            = 1'b0;
    emit_kind_d           = packet_kind_q;
    emit_abort_d          = 1'b0;
    emit_drop_d           = 1'b0;
    logical_idle_valid_d  = 1'b0;
    logical_idle_mask_d   = '0;
    invalid_k_evt_d       = 1'b0;
    frame_error_evt_d     = 1'b0;
    buffer_error_evt_d    = 1'b0;
    packet_drop_evt_d     = 1'b0;

    if (!rx_byte_aligned_i) begin
      // A lost symbol boundary invalidates an entire candidate immediately;
      // waiting for another decoded character could otherwise retain stale
      // packet/OS context across a period where GT valid is intentionally low.
      if (state_w == RX_CAPTURE) begin
        emit_drop_d       = 1'b1;
        packet_drop_evt_d = 1'b1;
      end
      state_w      = RX_HUNT;
      sop_w        = 1'b0;
      poison_w     = 1'b0;
      byte_count_w = '0;
    end else if (rx_descrambled_valid_i && rx_symbol_valid_i) begin
      for (int unsigned lane = 0; lane < 2; lane++) begin
        raw_ch     = rx_symbol_data_i[lane*8 +: 8];
        descr_ch   = rx_descrambled_data_i[lane*8 +: 8];
        char_class = (lane == 0) ? lane0_class_c : lane1_class_c;
        is_k       = rx_symbol_is_k_i[lane];
        code_bad   = rx_symbol_code_error_i[lane];
        disp_bad   = effective_disparity_c[lane];

        // Not-in-table has priority: do not interpret the accompanying K bit.
        if (code_bad) begin
          if (state_w == RX_CAPTURE) begin
            poison_w = 1'b1;
          end
        end else if (!rx_byte_aligned_i) begin
          if (state_w == RX_CAPTURE) begin
            poison_w = 1'b1;
          end
        end else if (is_k) begin
          if ((raw_ch == K_STP) || (raw_ch == K_SDP)) begin
            if (state_w == RX_HUNT) begin
              state_w      = rxbuf_pkt_ready_i ? RX_CAPTURE : RX_DISCARD;
              kind_w       = (raw_ch == K_SDP);
              sop_w        = 1'b1;
              poison_w     = disp_bad;
              byte_count_w = '0;
              if (!rxbuf_pkt_ready_i) begin
                buffer_error_evt_d = 1'b1;
                packet_drop_evt_d  = 1'b1;
                emit_drop_d        = 1'b1;
              end
            end else begin
              // Nested packet boundary: cancel the current slot and discard
              // through its terminator so corrupt payload cannot be re-framed.
              frame_error_evt_d = 1'b1;
              invalid_k_evt_d   = 1'b1;
              if (state_w == RX_CAPTURE) begin
                emit_drop_d       = 1'b1;
                packet_drop_evt_d = 1'b1;
              end
              state_w  = RX_DISCARD;
              poison_w = 1'b1;
            end
          end else if ((raw_ch == K_END) || (raw_ch == K_EDB)) begin
            if (state_w == RX_CAPTURE) begin
              if ((byte_count_w == 0) ||
                  ((raw_ch == K_EDB) && kind_w)) begin
                // Empty frames and EDB-terminated DLLPs are malformed.
                frame_error_evt_d = 1'b1;
                poison_w          = 1'b1;
              end

              if (disp_bad) begin
                poison_w = 1'b1;
              end

              if (poison_w) begin
                emit_drop_d       = 1'b1;
                packet_drop_evt_d = 1'b1;
                keep_w            = '0;
              end else begin
                // keep==00 is a private control-only terminator. The packet
                // slot converts it into EOP on the previously stored beat.
                beat_kind_w = kind_w;
                eop_w   = 1'b1;
                abort_w = (raw_ch == K_EDB);
              end
              state_w      = RX_HUNT;
              sop_w        = 1'b0;
              poison_w     = 1'b0;
              byte_count_w = '0;
            end else if (state_w == RX_DISCARD) begin
              state_w      = RX_HUNT;
              sop_w        = 1'b0;
              poison_w     = 1'b0;
              byte_count_w = '0;
            end else begin
              frame_error_evt_d = 1'b1;
              invalid_k_evt_d   = 1'b1;
            end
          end else if (state_w == RX_CAPTURE) begin
            // OS K characters are legal only outside a packet.
            invalid_k_evt_d   = 1'b1;
            frame_error_evt_d = 1'b1;
            emit_drop_d       = 1'b1;
            packet_drop_evt_d = 1'b1;
            state_w           = RX_DISCARD;
            poison_w          = 1'b1;
            keep_w            = '0;
          end else if ((state_w == RX_HUNT) &&
                       (char_class == CHAR_CLASS_UNKNOWN)) begin
            // A control symbol is legal outside a packet only as a recognized
            // member of a complete ordered-set candidate.  This catches stray
            // SKP/FTS/EIE/PAD controls without misclassifying packet markers.
            invalid_k_evt_d = 1'b1;
          end
        end else if (state_w == RX_CAPTURE) begin
          if (byte_count_w >= PHY_MAX_PACKET_BYTES) begin
            frame_error_evt_d  = 1'b1;
            buffer_error_evt_d = 1'b1;
            emit_drop_d        = 1'b1;
            packet_drop_evt_d  = 1'b1;
            state_w            = RX_DISCARD;
            poison_w           = 1'b1;
            keep_w             = '0;
          end else if (!rxbuf_pkt_ready_i) begin
            // Never hold/retry an RX character pair; cancel the candidate.
            buffer_error_evt_d = 1'b1;
            emit_drop_d        = 1'b1;
            packet_drop_evt_d  = 1'b1;
            state_w            = RX_DISCARD;
            poison_w           = 1'b1;
            keep_w             = '0;
          end else begin
            if ((keep_w == 2'b00) && sop_w) begin
              sop_for_emit_w = 1'b1;
              sop_w          = 1'b0;
            end
            if (keep_w == 2'b00) begin
              beat_kind_w = kind_w;
            end
            if (!keep_w[0]) begin
              data_w[7:0] = descr_ch;
              keep_w[0]   = 1'b1;
            end else begin
              data_w[15:8] = descr_ch;
              keep_w[1]    = 1'b1;
            end
            byte_count_w = byte_count_w + 1'b1;
            if (disp_bad) begin
              poison_w = 1'b1;
            end
          end
        end else if (state_w == RX_HUNT) begin
          // Only ordinary descrambled data outside a packet participates in
          // Logical Idle qualification. TS/EIEOS Data symbols are excluded.
          if ((char_class == CHAR_CLASS_DATA) && !disp_bad) begin
            idle_observation_w = 1'b1;
            idle_mask_w[lane]  = (descr_ch == 8'h00);
          end
        end
      end

      if (emit_drop_d) begin
        keep_w  = '0;
        eop_w   = 1'b0;
        abort_w = 1'b0;
      end else if ((keep_w != 2'b00) || eop_w) begin
        emit_valid_d = 1'b1;
        emit_data_d  = data_w;
        emit_keep_d  = keep_w;
        emit_sop_d   = sop_for_emit_w && (keep_w != 2'b00);
        emit_eop_d   = eop_w;
        // The second character may already start the next packet after a
        // lane-0 END/EDB.  Preserve the kind belonging to this emitted beat.
        emit_kind_d  = beat_kind_w;
        emit_abort_d = abort_w;
      end

      // Use the sequentially updated state, not the state at the start of the
      // pair: when END/EDB is in lane 0, lane 1 may already be the first
      // Logical Idle character following the packet.
      if (idle_observation_w) begin
        logical_idle_valid_d = 1'b1;
        logical_idle_mask_d  = idle_mask_w;
      end
    end

    frame_state_d       = state_w;
    packet_kind_d       = kind_w;
    sop_pending_d       = sop_w;
    packet_poison_d     = poison_w;
    packet_byte_count_d = byte_count_w;
  end

  always_ff @(posedge sym_clk_i or negedge sym_rst_ni) begin
    if (!sym_rst_ni) begin
      pre_active_q                    <= 1'b0;
      pre_kind_q                      <= PRE_NONE;
      pre_pos_q                       <= '0;
      pre_short_symbol_q              <= '0;
      pre_short_class_q               <= CHAR_CLASS_UNKNOWN;
      frame_state_q                   <= RX_HUNT;
      packet_kind_q                   <= PKT_KIND_TLP;
      sop_pending_q                   <= 1'b0;
      packet_poison_q                 <= 1'b0;
      packet_byte_count_q             <= '0;
      aligned_seen_q                  <= 1'b0;
      rxbuf_pkt_valid_o               <= 1'b0;
      rxbuf_pkt_data_o                <= '0;
      rxbuf_pkt_keep_o                <= '0;
      rxbuf_pkt_sop_o                 <= 1'b0;
      rxbuf_pkt_eop_o                 <= 1'b0;
      rxbuf_pkt_kind_o                <= PKT_KIND_TLP;
      rxbuf_pkt_abort_o               <= 1'b0;
      rxbuf_pkt_drop_o                <= 1'b0;
      rx_logical_idle_valid_o         <= 1'b0;
      rx_logical_idle_char_mask_o     <= '0;
      rx_align_loss_evt_o             <= 1'b0;
      rx_invalid_k_evt_o              <= 1'b0;
      rx_code_error_evt_o             <= 1'b0;
      rx_disparity_error_evt_o        <= 1'b0;
      rx_frame_error_evt_o            <= 1'b0;
      rx_packet_buffer_error_evt_o    <= 1'b0;
      rx_packet_drop_evt_o            <= 1'b0;
      rx_packet_active_o              <= 1'b0;
    end else begin
      if (!rx_byte_aligned_i) begin
        pre_active_q       <= 1'b0;
        pre_kind_q         <= PRE_NONE;
        pre_pos_q          <= '0;
        pre_short_symbol_q <= '0;
        pre_short_class_q  <= CHAR_CLASS_UNKNOWN;
      end else if (rx_symbol_valid_i) begin
        pre_active_q           <= pre_active_d;
        pre_kind_q             <= pre_kind_d;
        pre_pos_q              <= pre_pos_d;
        pre_short_symbol_q     <= pre_short_symbol_d;
        pre_short_class_q      <= pre_short_class_d;
      end

      frame_state_q       <= frame_state_d;
      packet_kind_q       <= packet_kind_d;
      sop_pending_q       <= sop_pending_d;
      packet_poison_q     <= packet_poison_d;
      packet_byte_count_q <= packet_byte_count_d;

      rxbuf_pkt_valid_o           <= emit_valid_d;
      rxbuf_pkt_data_o            <= emit_data_d;
      rxbuf_pkt_keep_o            <= emit_keep_d;
      rxbuf_pkt_sop_o             <= emit_sop_d;
      rxbuf_pkt_eop_o             <= emit_eop_d;
      rxbuf_pkt_kind_o            <= emit_kind_d;
      rxbuf_pkt_abort_o           <= emit_abort_d;
      rxbuf_pkt_drop_o            <= emit_drop_d;
      rx_logical_idle_valid_o     <= logical_idle_valid_d;
      rx_logical_idle_char_mask_o <= logical_idle_mask_d;

      rx_code_error_evt_o      <= rx_symbol_valid_i &&
                                  (|rx_symbol_code_error_i);
      rx_disparity_error_evt_o <= rx_symbol_valid_i &&
                                  (|effective_disparity_c);
      rx_invalid_k_evt_o       <= invalid_k_evt_d;
      rx_frame_error_evt_o     <= frame_error_evt_d;
      rx_packet_buffer_error_evt_o <= buffer_error_evt_d;
      rx_packet_drop_evt_o     <= packet_drop_evt_d;

      if (rx_symbol_valid_i && rx_byte_aligned_i) begin
        aligned_seen_q <= 1'b1;
      end
      rx_align_loss_evt_o <= aligned_seen_q && !rx_byte_aligned_i;
      if (!rx_byte_aligned_i) begin
        aligned_seen_q <= 1'b0;
      end

      rx_packet_active_o <= (frame_state_d != RX_HUNT);
    end
  end

endmodule
