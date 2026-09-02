module phy_tx_framer_scheduler (
  input  logic        sym_clk_i,
  input  logic        sym_rst_ni,

  input  logic        txbuf_pkt_valid_i,
  output logic        txbuf_pkt_ready_o,
  input  logic [15:0] txbuf_pkt_data_i,
  input  logic [1:0]  txbuf_pkt_keep_i,
  input  logic        txbuf_pkt_sop_i,
  input  logic        txbuf_pkt_eop_i,
  input  logic        txbuf_pkt_kind_i,
  input  logic        txbuf_pkt_abort_i,
  input  logic        txbuf_pending_i,

  input  logic [3:0]  lt_tx_mode_i,
  input  logic        lt_tx_quiesce_i,
  input  logic        lt_packet_enable_i,
  input  logic [5:0]  lt_state_i,
  input  logic [5:0]  lt_substate_i,

  input  logic [15:0] os_tx_data_i,
  input  logic [1:0]  os_tx_is_k_i,
  input  logic [3:0]  os_tx_class_i,
  input  logic        os_tx_valid_i,
  input  logic        os_tx_done_i,
  output logic        os_tx_consume_o,

  input  logic        skp_due_i,
  input  logic [15:0] skp_deadline_i,

  output logic [15:0] tx_sel_data_o,
  output logic [1:0]  tx_sel_is_k_o,
  output logic [3:0]  tx_symbol_class_o,
  // Frozen two-bit port: one common pcie_lfsr_action_t for this character
  // pair.  COM reset and K bypass remain per-character rules in the scrambler.
  output logic [1:0]  tx_lfsr_action_o,
  output logic        tx_packet_active_o,
  output logic        tx_quiesced_o,
  output logic        tx_logical_idle_qualified_evt_o,
  output logic        tx_scheduler_error_evt_o,
  output logic [7:0]  tx_scheduler_error_code_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

  localparam int unsigned TX_CHARACTERS_PER_CYCLE = 2;
  localparam int unsigned IDLE_COUNT_WIDTH =
    (CFG_IDLE_COUNT < 2) ? 1 : $clog2(CFG_IDLE_COUNT + 1);

  typedef enum logic [1:0] {
    TX_SCHED_BOUNDARY,
    TX_SCHED_PAYLOAD,
    TX_SCHED_TERMINATE,
    TX_SCHED_DROP
  } tx_scheduler_state_t;

  tx_scheduler_state_t state_q;
  tx_scheduler_state_t state_d;

  logic [7:0] carry_byte_q;
  logic [7:0] carry_byte_d;
  logic       carry_ends_packet_q;
  logic       carry_ends_packet_d;
  logic       packet_abort_q;
  logic       packet_abort_d;
  logic       packet_kind_q;
  logic       packet_kind_d;
  logic       os_active_q;
  logic       os_active_d;
  logic       os_gap_reported_q;
  logic       os_gap_reported_d;
  logic       mode_conflict_reported_q;
  logic       mode_conflict_reported_d;
  logic       compliance_phase_q;
  logic       selected_compliance_pair;

  logic [IDLE_COUNT_WIDTH-1:0] logical_idle_count_q;
  logic [IDLE_COUNT_WIDTH:0]   logical_idle_count_plus_pair;
  logic                        selected_logical_idle_pair;

  logic mode_requires_sequence;
  logic start_beat_legal;
  logic continuation_beat_legal;
  logic packet_source_allowed;
  logic request_sequence_now;
  logic character_stream_enabled;

  function automatic logic keep_is_legal(
    input logic [1:0] keep,
    input logic       eop
  );
    if (eop) begin
      return (keep == 2'b01) || (keep == 2'b11);
    end
    return keep == 2'b11;
  endfunction

  function automatic logic mode_owns_character_stream(
    input logic [3:0] mode
  );
    unique case (mode)
      TX_MODE_TS1,
      TX_MODE_TS2,
      TX_MODE_SKP,
      TX_MODE_FTS,
      TX_MODE_EIOS,
      TX_MODE_EIEOS,
      TX_MODE_COMPLIANCE,
      TX_MODE_LOOPBACK:
        return 1'b1;
      default:
        return 1'b0;
    endcase
  endfunction

  function automatic pcie_lfsr_action_t class_lfsr_action(
    input logic [3:0] character_class
  );
    unique case (character_class)
      CHAR_CLASS_DATA,
      CHAR_CLASS_FRAME,
      CHAR_CLASS_LOGICAL_IDLE:
        return LFSR_ACTION_ADV8;
      CHAR_CLASS_SKP:
        return LFSR_ACTION_HOLD;
      default:
        return LFSR_ACTION_BYPASS;
    endcase
  endfunction

  always_comb begin
    mode_requires_sequence = mode_owns_character_stream(lt_tx_mode_i);
    packet_source_allowed =
      (lt_tx_mode_i == TX_MODE_PACKET) && lt_packet_enable_i;
    character_stream_enabled =
      (lt_tx_mode_i != TX_MODE_ELECTRICAL_IDLE);
    request_sequence_now =
      os_active_q ||
      (mode_requires_sequence && (lt_tx_mode_i != TX_MODE_COMPLIANCE)) ||
      (skp_due_i && character_stream_enabled);

    start_beat_legal =
      txbuf_pkt_sop_i &&
      keep_is_legal(txbuf_pkt_keep_i, txbuf_pkt_eop_i) &&
      (!txbuf_pkt_abort_i ||
       (txbuf_pkt_eop_i && (txbuf_pkt_kind_i == PKT_KIND_TLP)));

    continuation_beat_legal =
      !txbuf_pkt_sop_i &&
      (txbuf_pkt_kind_i == packet_kind_q) &&
      keep_is_legal(txbuf_pkt_keep_i, txbuf_pkt_eop_i) &&
      (!txbuf_pkt_abort_i ||
       (txbuf_pkt_eop_i && (packet_kind_q == PKT_KIND_TLP)));

    state_d                    = state_q;
    carry_byte_d               = carry_byte_q;
    carry_ends_packet_d        = carry_ends_packet_q;
    packet_abort_d             = packet_abort_q;
    packet_kind_d              = packet_kind_q;
    os_active_d                = os_active_q;
    os_gap_reported_d          = os_gap_reported_q;
    mode_conflict_reported_d   = mode_conflict_reported_q;

    txbuf_pkt_ready_o          = 1'b0;
    os_tx_consume_o            = 1'b0;
    tx_sel_data_o              = {D_LOGICAL_IDLE, D_LOGICAL_IDLE};
    tx_sel_is_k_o              = 2'b00;
    tx_symbol_class_o          = CHAR_CLASS_LOGICAL_IDLE;
    tx_lfsr_action_o           = LFSR_ACTION_ADV8;
    tx_packet_active_o         = 1'b0;
    tx_quiesced_o              = 1'b0;
    tx_scheduler_error_evt_o   = 1'b0;
    tx_scheduler_error_code_o  = ERR_NONE;
    selected_compliance_pair   = 1'b0;

    unique case (state_q)
      TX_SCHED_BOUNDARY: begin
        mode_conflict_reported_d = 1'b0;

        // Boundary priority is fixed by SPEC 6.1: state-forced sequence,
        // then an overdue SKP sequence, then an already committed packet,
        // and finally Logical Idle.  The ordered-set generator resolves a
        // forced-sequence/SKP collision only at its own sequence boundary.
        if ((lt_tx_mode_i == TX_MODE_COMPLIANCE) && !os_active_q) begin
          // PCIe 2.1 4.2.8 Compliance Pattern, emitted continuously as
          // K28.5,D21.5,K28.5,D10.2.  The GT adapter separately owns the
          // electrical compliance/RD configuration.
          tx_sel_data_o = compliance_phase_q ?
            {D_COMPLIANCE_D10_2, K_COM} :
            {D_COMPLIANCE_D21_5, K_COM};
          tx_sel_is_k_o            = 2'b01;
          tx_symbol_class_o        = CHAR_CLASS_COMPLIANCE;
          tx_lfsr_action_o         = LFSR_ACTION_BYPASS;
          selected_compliance_pair = 1'b1;
        end else if (request_sequence_now) begin
          if (os_tx_valid_i) begin
            tx_sel_data_o       = os_tx_data_i;
            tx_sel_is_k_o       = os_tx_is_k_i;
            tx_symbol_class_o   = os_tx_class_i;
            tx_lfsr_action_o    = class_lfsr_action(os_tx_class_i);
            os_tx_consume_o     = 1'b1;
            // A source may align done with its last valid pair.  If done is
            // registered one cycle later, the no-valid branch below clears the
            // retained ownership.  Continuous forced modes remain requested
            // independently and therefore tolerate an immediate reload.
            os_active_d         = !os_tx_done_i;
            os_gap_reported_d   = 1'b0;
          end else if (os_active_q && os_tx_done_i) begin
            os_active_d       = 1'b0;
            os_gap_reported_d = 1'b0;
          end else begin
            // Waiting for a required source never opens a packet.  Logical
            // Idle preserves the continuous-rate GT interface in the gap.
            // Latch the request because skp_due_i may deassert as soon as the
            // ordered-set generator reports busy, one cycle before valid.
            os_active_d = 1'b1;
            if (os_active_q && !os_gap_reported_q) begin
              tx_scheduler_error_evt_o  = 1'b1;
              tx_scheduler_error_code_o = ERR_TX_FRAMING;
              os_gap_reported_d         = 1'b1;
            end
          end
        end else if (packet_source_allowed) begin
          // Drain every packet already accepted by the link-domain buffer even
          // after admission quiesce is requested.  Admission itself is gated
          // before SOP in phy_tx_packet_buffer_cdc.
          txbuf_pkt_ready_o = 1'b1;
          if (txbuf_pkt_valid_i) begin
            tx_packet_active_o = 1'b1;
            if (start_beat_legal) begin
              tx_sel_data_o       = {
                txbuf_pkt_data_i[7:0],
                (txbuf_pkt_kind_i == PKT_KIND_DLLP) ? K_SDP : K_STP
              };
              tx_sel_is_k_o       = 2'b01;
              tx_symbol_class_o   = CHAR_CLASS_FRAME;
              tx_lfsr_action_o    = LFSR_ACTION_ADV8;
              packet_kind_d       = txbuf_pkt_kind_i;
              packet_abort_d      = txbuf_pkt_abort_i;

              if (txbuf_pkt_eop_i) begin
                if (txbuf_pkt_keep_i == 2'b01) begin
                  state_d = TX_SCHED_TERMINATE;
                end else begin
                  carry_byte_d        = txbuf_pkt_data_i[15:8];
                  carry_ends_packet_d = 1'b1;
                  state_d             = TX_SCHED_PAYLOAD;
                end
              end else begin
                carry_byte_d        = txbuf_pkt_data_i[15:8];
                carry_ends_packet_d = 1'b0;
                state_d             = TX_SCHED_PAYLOAD;
              end
            end else begin
              // The committed-buffer contract makes this path unreachable in
              // normal operation.  Consume the bad candidate, put an EDB on
              // the line, and drain the rest without exposing payload.
              tx_sel_data_o              = {D_LOGICAL_IDLE, K_EDB};
              tx_sel_is_k_o              = 2'b01;
              tx_symbol_class_o          = CHAR_CLASS_FRAME;
              tx_lfsr_action_o           = LFSR_ACTION_ADV8;
              tx_scheduler_error_evt_o   = 1'b1;
              tx_scheduler_error_code_o  = ERR_TX_FRAMING;
              state_d = txbuf_pkt_eop_i ? TX_SCHED_BOUNDARY : TX_SCHED_DROP;
            end
          end
        end

        // Frozen tx_quiesced semantics: no packet on the line, no unfinished
        // ordered set, and a safe Logical Idle output.  Queued whole packets
        // do not violate this stream-level condition while admission is shut.
        tx_quiesced_o =
          !request_sequence_now &&
          !os_tx_valid_i &&
          !tx_packet_active_o &&
          !(txbuf_pkt_valid_i && packet_source_allowed) &&
          (tx_symbol_class_o == CHAR_CLASS_LOGICAL_IDLE) &&
          !tx_sel_is_k_o;
      end

      TX_SCHED_PAYLOAD: begin
        tx_packet_active_o   = 1'b1;
        tx_symbol_class_o    = CHAR_CLASS_FRAME;
        tx_lfsr_action_o     = LFSR_ACTION_ADV8;

        if (mode_requires_sequence && !mode_conflict_reported_q) begin
          // A normal quiesce leaves mode at PACKET until drain completes.  A
          // forced mode arriving here is therefore a sequencing violation;
          // the packet still wins until its legal END/EDB boundary.
          tx_scheduler_error_evt_o  = 1'b1;
          tx_scheduler_error_code_o = ERR_RATE_NOT_QUIESCED;
          mode_conflict_reported_d   = 1'b1;
        end

        if (carry_ends_packet_q) begin
          tx_sel_data_o = {
            packet_abort_q ? K_EDB : K_END,
            carry_byte_q
          };
          tx_sel_is_k_o       = 2'b10;
          state_d             = TX_SCHED_BOUNDARY;
          carry_ends_packet_d = 1'b0;
        end else begin
          // Whole-packet commit guarantees this valid is continuous.  If that
          // invariant is violated, terminate with EDB rather than stalling the
          // fixed-rate character stream.
          txbuf_pkt_ready_o = 1'b1;
          if (txbuf_pkt_valid_i && continuation_beat_legal) begin
            tx_sel_data_o = {txbuf_pkt_data_i[7:0], carry_byte_q};
            tx_sel_is_k_o = 2'b00;

            if (txbuf_pkt_eop_i) begin
              packet_abort_d = txbuf_pkt_abort_i;
              if (txbuf_pkt_keep_i == 2'b01) begin
                state_d = TX_SCHED_TERMINATE;
              end else begin
                carry_byte_d        = txbuf_pkt_data_i[15:8];
                carry_ends_packet_d = 1'b1;
              end
            end else begin
              carry_byte_d        = txbuf_pkt_data_i[15:8];
              carry_ends_packet_d = 1'b0;
            end
          end else begin
            tx_sel_data_o              = {K_EDB, carry_byte_q};
            tx_sel_is_k_o              = 2'b10;
            tx_scheduler_error_evt_o   = 1'b1;
            tx_scheduler_error_code_o  = ERR_TX_FRAMING;
            state_d = (txbuf_pkt_valid_i && txbuf_pkt_eop_i) ?
                      TX_SCHED_BOUNDARY : TX_SCHED_DROP;
          end
        end
      end

      TX_SCHED_TERMINATE: begin
        // Odd-byte packets need one additional character.  Pair the low-byte
        // terminator with the first following Logical Idle character.
        tx_sel_data_o       = {
          D_LOGICAL_IDLE,
          packet_abort_q ? K_EDB : K_END
        };
        tx_sel_is_k_o       = 2'b01;
        tx_symbol_class_o   = CHAR_CLASS_FRAME;
        tx_lfsr_action_o    = LFSR_ACTION_ADV8;
        tx_packet_active_o  = 1'b1;
        state_d             = TX_SCHED_BOUNDARY;
      end

      default: begin // TX_SCHED_DROP
        // Drain an impossible malformed committed packet.  It has already been
        // terminated with EDB, so only normal Logical Idle is emitted here.
        txbuf_pkt_ready_o = 1'b1;
        tx_packet_active_o = 1'b1;
        if (txbuf_pkt_valid_i && txbuf_pkt_eop_i) begin
          state_d = TX_SCHED_BOUNDARY;
        end
      end
    endcase

    if (!sym_rst_ni) begin
      txbuf_pkt_ready_o         = 1'b0;
      os_tx_consume_o           = 1'b0;
      tx_sel_data_o             = {D_LOGICAL_IDLE, D_LOGICAL_IDLE};
      tx_sel_is_k_o             = 2'b00;
      tx_symbol_class_o         = CHAR_CLASS_LOGICAL_IDLE;
      tx_lfsr_action_o          = LFSR_ACTION_ADV8;
      tx_packet_active_o        = 1'b0;
      tx_quiesced_o             = 1'b1;
      tx_scheduler_error_evt_o  = 1'b0;
      tx_scheduler_error_code_o = ERR_NONE;
      selected_compliance_pair  = 1'b0;
    end

    selected_logical_idle_pair =
      (state_q == TX_SCHED_BOUNDARY) &&
      (lt_tx_mode_i == TX_MODE_LOGICAL_IDLE) &&
      (tx_symbol_class_o == CHAR_CLASS_LOGICAL_IDLE) &&
      (tx_sel_is_k_o == 2'b00) &&
      (tx_sel_data_o == {D_LOGICAL_IDLE, D_LOGICAL_IDLE});
    logical_idle_count_plus_pair = logical_idle_count_q +
                                   TX_CHARACTERS_PER_CYCLE;
  end

  always_ff @(posedge sym_clk_i or negedge sym_rst_ni) begin
    if (!sym_rst_ni) begin
      state_q                         <= TX_SCHED_BOUNDARY;
      carry_byte_q                    <= D_LOGICAL_IDLE;
      carry_ends_packet_q             <= 1'b0;
      packet_abort_q                  <= 1'b0;
      packet_kind_q                   <= PKT_KIND_TLP;
      os_active_q                     <= 1'b0;
      os_gap_reported_q               <= 1'b0;
      mode_conflict_reported_q        <= 1'b0;
      compliance_phase_q              <= 1'b0;
      logical_idle_count_q            <= '0;
      tx_logical_idle_qualified_evt_o <= 1'b0;
    end else begin
      state_q                   <= state_d;
      carry_byte_q              <= carry_byte_d;
      carry_ends_packet_q       <= carry_ends_packet_d;
      packet_abort_q            <= packet_abort_d;
      packet_kind_q             <= packet_kind_d;
      os_active_q               <= os_active_d;
      os_gap_reported_q         <= os_gap_reported_d;
      mode_conflict_reported_q  <= mode_conflict_reported_d;

      if (selected_compliance_pair) begin
        compliance_phase_q <= ~compliance_phase_q;
      end else if (lt_tx_mode_i != TX_MODE_COMPLIANCE) begin
        compliance_phase_q <= 1'b0;
      end

      tx_logical_idle_qualified_evt_o <= 1'b0;
      if (selected_logical_idle_pair) begin
        if (logical_idle_count_q < CFG_IDLE_COUNT) begin
          if (logical_idle_count_plus_pair >= CFG_IDLE_COUNT) begin
            logical_idle_count_q <= CFG_IDLE_COUNT[IDLE_COUNT_WIDTH-1:0];
            tx_logical_idle_qualified_evt_o <= 1'b1;
          end else begin
            logical_idle_count_q <=
              logical_idle_count_plus_pair[IDLE_COUNT_WIDTH-1:0];
          end
        end
      end else begin
        logical_idle_count_q <= '0;
      end
    end
  end

endmodule
