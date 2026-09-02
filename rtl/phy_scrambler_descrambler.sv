module phy_scrambler_descrambler (
  input  logic        sym_clk_i,
  input  logic        sym_rst_ni,

  input  logic [15:0] tx_scr_data_i,
  input  logic [1:0]  tx_scr_is_k_i,
  input  logic [3:0]  tx_scr_class_i,
  input  logic [1:0]  tx_scr_lfsr_action_i,
  output logic [15:0] tx_scr_data_o,
  output logic [1:0]  tx_scr_is_k_o,

  input  logic [15:0] rx_descr_data_i,
  input  logic [1:0]  rx_descr_is_k_i,
  input  logic        rx_descr_valid_i,
  input  logic [3:0]  rx_descr_class_i,
  // Two packed pcie_lfsr_action_t values: character 0 is [1:0], character 1
  // is [3:2].  Pre-classification therefore remains correct for mixed pairs.
  input  logic [3:0]  rx_descr_lfsr_action_i,
  output logic [15:0] rx_descr_data_o,
  output logic        rx_descr_valid_o,

  output logic [15:0] tx_scrambler_state_o,
  output logic [15:0] rx_descrambler_state_o,
  output logic        scrambler_sync_error_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  typedef struct packed {
    logic [7:0]  data;
    logic [15:0] state;
  } lfsr_character_result_t;

  logic [15:0] tx_lfsr_q;
  logic [15:0] rx_lfsr_q;
  logic [15:0] tx_lfsr_next;
  logic [15:0] rx_lfsr_next;
  logic        tx_rule_error;
  logic        rx_rule_error;

  lfsr_character_result_t tx_char0_result;
  lfsr_character_result_t tx_char1_result;
  lfsr_character_result_t rx_char0_result;
  lfsr_character_result_t rx_char1_result;

  pcie_lfsr_action_t tx_pair_action;
  pcie_lfsr_action_t tx_char0_action;
  pcie_lfsr_action_t tx_char1_action;
  pcie_lfsr_action_t rx_char0_action;
  pcie_lfsr_action_t rx_char1_action;

  function automatic logic [15:0] lfsr_step(
    input logic [15:0] state
  );
    logic feedback;
    begin
      feedback =
        state[PCIE_SCRAMBLER_TAP_16] ^
        state[PCIE_SCRAMBLER_TAP_5]  ^
        state[PCIE_SCRAMBLER_TAP_4]  ^
        state[PCIE_SCRAMBLER_TAP_3];
      return {state[14:0], feedback};
    end
  endfunction

  function automatic lfsr_character_result_t process_character(
    input logic [7:0]        data,
    input logic              is_k,
    input pcie_lfsr_action_t action,
    input logic [15:0]       state
  );
    lfsr_character_result_t result;
    logic [15:0] working_state;
    int unsigned bit_index;
    begin
      result.data   = data;
      result.state  = state;
      working_state = state;

      unique case (action)
        LFSR_ACTION_RESET: begin
          // COM itself is never scrambled.  The reset takes effect after COM,
          // so the following character in the same 16-bit pair sees the seed.
          result.state = PCIE_SCRAMBLER_SEED;
        end

        LFSR_ACTION_HOLD: begin
          // SKP is neither XORed nor counted by the LFSR.
          result.state = state;
        end

        LFSR_ACTION_BYPASS: begin
          // Training/test data bypasses XOR but, unlike SKP, consumes eight
          // serial LFSR steps.
          for (bit_index = 0; bit_index < 8; bit_index++) begin
            working_state = lfsr_step(working_state);
          end
          result.state = working_state;
        end

        default: begin // LFSR_ACTION_ADV8
          // PCIe bytes are processed least-significant serial bit first.  K
          // characters bypass the XOR but still advance unless they are COM or
          // SKP, whose actions were resolved before entering this function.
          for (bit_index = 0; bit_index < 8; bit_index++) begin
            if (!is_k) begin
              result.data[bit_index] =
                data[bit_index] ^ working_state[PCIE_SCRAMBLER_TAP_16];
            end
            working_state = lfsr_step(working_state);
          end
          result.state = working_state;
        end
      endcase

      return result;
    end
  endfunction

  function automatic pcie_lfsr_action_t expected_pair_action(
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

  function automatic pcie_lfsr_action_t resolve_tx_character_action(
    input logic [7:0]        data,
    input logic              is_k,
    input logic [3:0]        character_class,
    input pcie_lfsr_action_t pair_action
  );
    if (is_k && (data == K_COM)) begin
      return LFSR_ACTION_RESET;
    end
    if (character_class == CHAR_CLASS_SKP) begin
      return LFSR_ACTION_HOLD;
    end
    return pair_action;
  endfunction

  function automatic logic rx_action_is_legal(
    input logic [7:0]        data,
    input logic              is_k,
    input logic [3:0]        character_class,
    input pcie_lfsr_action_t action
  );
    if (is_k && (data == K_COM)) begin
      return action == LFSR_ACTION_RESET;
    end
    if (is_k && (data == K_SKP)) begin
      return action == LFSR_ACTION_HOLD;
    end
    if (character_class == CHAR_CLASS_SKP) begin
      return 1'b0;
    end
    return (action != LFSR_ACTION_RESET) &&
           (action != LFSR_ACTION_HOLD);
  endfunction

  always_comb begin
    tx_pair_action = pcie_lfsr_action_t'(tx_scr_lfsr_action_i);
    tx_char0_action = resolve_tx_character_action(
      tx_scr_data_i[7:0], tx_scr_is_k_i[0], tx_scr_class_i, tx_pair_action
    );
    tx_char1_action = resolve_tx_character_action(
      tx_scr_data_i[15:8], tx_scr_is_k_i[1], tx_scr_class_i, tx_pair_action
    );
    rx_char0_action = pcie_lfsr_action_t'(rx_descr_lfsr_action_i[1:0]);
    rx_char1_action = pcie_lfsr_action_t'(rx_descr_lfsr_action_i[3:2]);

    tx_char0_result = process_character(
      tx_scr_data_i[7:0], tx_scr_is_k_i[0], tx_char0_action, tx_lfsr_q
    );
    tx_char1_result = process_character(
      tx_scr_data_i[15:8], tx_scr_is_k_i[1], tx_char1_action,
      tx_char0_result.state
    );

    rx_char0_result = process_character(
      rx_descr_data_i[7:0], rx_descr_is_k_i[0], rx_char0_action, rx_lfsr_q
    );
    rx_char1_result = process_character(
      rx_descr_data_i[15:8], rx_descr_is_k_i[1], rx_char1_action,
      rx_char0_result.state
    );

    tx_lfsr_next = tx_char1_result.state;
    rx_lfsr_next = rx_char1_result.state;

    tx_rule_error =
      (tx_pair_action != expected_pair_action(tx_scr_class_i)) ||
      ((tx_scr_class_i == CHAR_CLASS_SKP) &&
       ((!tx_scr_is_k_i[0] ||
         ((tx_scr_data_i[7:0] != K_COM) &&
          (tx_scr_data_i[7:0] != K_SKP))) ||
        (!tx_scr_is_k_i[1] ||
         ((tx_scr_data_i[15:8] != K_COM) &&
          (tx_scr_data_i[15:8] != K_SKP))))) ||
      (tx_scr_class_i == CHAR_CLASS_UNKNOWN);

    rx_rule_error =
      !rx_action_is_legal(
        rx_descr_data_i[7:0], rx_descr_is_k_i[0], rx_descr_class_i,
        rx_char0_action
      ) ||
      !rx_action_is_legal(
        rx_descr_data_i[15:8], rx_descr_is_k_i[1], rx_descr_class_i,
        rx_char1_action
      ) ||
      ((rx_descr_class_i == CHAR_CLASS_UNKNOWN) &&
       ((rx_char0_action != LFSR_ACTION_HOLD) ||
        (rx_char1_action != LFSR_ACTION_HOLD)));

    if (!sym_rst_ni) begin
      tx_scr_data_o    = {D_LOGICAL_IDLE, D_LOGICAL_IDLE};
      tx_scr_is_k_o    = 2'b00;
      rx_descr_data_o  = '0;
      rx_descr_valid_o = 1'b0;
    end else begin
      tx_scr_data_o    = {tx_char1_result.data, tx_char0_result.data};
      tx_scr_is_k_o    = tx_scr_is_k_i;
      rx_descr_data_o  = {rx_char1_result.data, rx_char0_result.data};
      rx_descr_valid_o = rx_descr_valid_i;
    end
  end

  always_ff @(posedge sym_clk_i or negedge sym_rst_ni) begin
    if (!sym_rst_ni) begin
      tx_lfsr_q               <= PCIE_SCRAMBLER_SEED;
      rx_lfsr_q               <= PCIE_SCRAMBLER_SEED;
      scrambler_sync_error_o  <= 1'b0;
    end else begin
      tx_lfsr_q <= tx_lfsr_next;
      if (rx_descr_valid_i) begin
        rx_lfsr_q <= rx_lfsr_next;
      end
      scrambler_sync_error_o <=
        tx_rule_error || (rx_descr_valid_i && rx_rule_error);
    end
  end

  assign tx_scrambler_state_o   = tx_lfsr_q;
  assign rx_descrambler_state_o = rx_lfsr_q;

endmodule
