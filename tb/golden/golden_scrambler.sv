package golden_scrambler_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  typedef struct packed {
    logic [7:0]  data;
    logic [15:0] state;
  } golden_scr_byte_result_t;

  typedef struct packed {
    logic [15:0] data;
    logic [15:0] state;
  } golden_scr_pair_result_t;

  // Deliberately bit-serial reference for x^16+x^5+x^4+x^3+1. The DUT is
  // expected to use a two-character parallel transform, keeping this model
  // structurally independent of the implementation being checked.
  function automatic logic [15:0] golden_lfsr_step(input logic [15:0] state_i);
    logic feedback;
    begin
      feedback = state_i[15] ^ state_i[4] ^ state_i[3] ^ state_i[2];
      return {state_i[14:0], feedback};
    end
  endfunction

  function automatic golden_scr_byte_result_t golden_scramble_byte(
    input logic [7:0] data_i,
    input logic [15:0] state_i,
    input logic is_k_i,
    input pcie_character_class_t class_i,
    input pcie_lfsr_action_t action_i
  );
    golden_scr_byte_result_t result;
    logic [15:0] state_v;
    integer bit_index;
    begin
      result.data = data_i;
      state_v = state_i;
      if (action_i == LFSR_ACTION_RESET) begin
        result.state = 16'hffff;
        return result;
      end
      if (action_i == LFSR_ACTION_HOLD) begin
        result.state = state_v;
        return result;
      end
      for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
        // The action is the contract.  TS/compliance use BYPASS, while an
        // erroneous ADV8 request must not be hidden by class-side heuristics.
        if (!is_k_i && (action_i == LFSR_ACTION_ADV8)) begin
          result.data[bit_index] = data_i[bit_index] ^ state_v[15];
        end
        state_v = golden_lfsr_step(state_v);
      end
      result.state = state_v;
      return result;
    end
  endfunction

  function automatic golden_scr_pair_result_t golden_scramble_pair(
    input logic [15:0] data_i,
    input logic [1:0] is_k_i,
    input pcie_character_class_t class_i,
    input logic [3:0] actions_i,
    input logic [15:0] state_i
  );
    golden_scr_pair_result_t result;
    golden_scr_byte_result_t lo_result;
    golden_scr_byte_result_t hi_result;
    begin
      lo_result = golden_scramble_byte(data_i[7:0], state_i, is_k_i[0],
                                       class_i, pcie_lfsr_action_t'(actions_i[1:0]));
      hi_result = golden_scramble_byte(data_i[15:8], lo_result.state, is_k_i[1],
                                       class_i, pcie_lfsr_action_t'(actions_i[3:2]));
      result.data = {hi_result.data, lo_result.data};
      result.state = hi_result.state;
      return result;
    end
  endfunction

  function automatic logic [15:0] golden_advance_bytes(
    input logic [15:0] state_i,
    input int unsigned byte_count_i
  );
    logic [15:0] state_v;
    integer i;
    begin
      state_v = state_i;
      for (i = 0; i < (byte_count_i * 8); i = i + 1)
        state_v = golden_lfsr_step(state_v);
      return state_v;
    end
  endfunction
endpackage
