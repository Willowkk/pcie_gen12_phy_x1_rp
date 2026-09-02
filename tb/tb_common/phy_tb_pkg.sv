package phy_tb_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  int unsigned tb_checks;
  int unsigned tb_failures;
  logic [63:0] tb_required_scenarios;
  logic [63:0] tb_hit_scenarios;
  string tb_active_id;

  typedef struct packed {
    logic [15:0] data;
    logic [1:0]  keep;
    logic        sop;
    logic        eop;
    logic        kind;
    logic        abort;
  } phy_packet_beat_t;

  typedef struct packed {
    logic [15:0] data;
    logic [1:0]  is_k;
    logic [3:0]  char_class;
  } phy_symbol_pair_t;

  task automatic tb_start(input string test_id,
                          input logic [63:0] required_scenarios);
    begin
      tb_active_id = test_id;
      tb_checks = 0;
      tb_failures = 0;
      tb_required_scenarios = required_scenarios;
      tb_hit_scenarios = '0;
      $display("[TB_BEGIN] %s", test_id);
    end
  endtask

  task automatic tb_check(input logic condition, input string message);
    begin
      tb_checks = tb_checks + 1;
      if (condition !== 1'b1) begin
        tb_failures = tb_failures + 1;
        $error("[TB_CHECK_FAIL] %s: %s", tb_active_id, message);
      end
    end
  endtask

  task automatic tb_check_eq1(input logic actual, input logic expected,
                              input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%b expected=%b", message, actual, expected));
  endtask

  task automatic tb_check_eq2(input logic [1:0] actual,
                              input logic [1:0] expected,
                              input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%b expected=%b", message, actual, expected));
  endtask

  task automatic tb_check_eq4(input logic [3:0] actual,
                              input logic [3:0] expected,
                              input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%h expected=%h", message, actual, expected));
  endtask

  task automatic tb_check_eq6(input logic [5:0] actual,
                              input logic [5:0] expected,
                              input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%h expected=%h", message, actual, expected));
  endtask

  task automatic tb_check_eq8(input logic [7:0] actual,
                              input logic [7:0] expected,
                              input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%h expected=%h", message, actual, expected));
  endtask

  task automatic tb_check_eq10(input logic [9:0] actual,
                               input logic [9:0] expected,
                               input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%h expected=%h", message, actual, expected));
  endtask

  task automatic tb_check_eq16(input logic [15:0] actual,
                               input logic [15:0] expected,
                               input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%h expected=%h", message, actual, expected));
  endtask

  task automatic tb_check_eq32(input logic [31:0] actual,
                               input logic [31:0] expected,
                               input string message);
    tb_check(actual === expected,
             $sformatf("%s actual=%h expected=%h", message, actual, expected));
  endtask

  task automatic tb_hit(input int unsigned scenario_index);
    begin
      if (scenario_index < 64)
        tb_hit_scenarios[scenario_index] = 1'b1;
      else begin
        tb_failures = tb_failures + 1;
        $error("[TB_SCENARIO_RANGE] %s index=%0d", tb_active_id, scenario_index);
      end
    end
  endtask

  task automatic tb_finish(input string test_id);
    logic [63:0] missing;
    begin
      missing = tb_required_scenarios & ~tb_hit_scenarios;
      if (missing != 0) begin
        tb_failures = tb_failures + 1;
        $error("[TB_COVERAGE_MISSING] %s bitmap=%016h", test_id, missing);
      end
      if (tb_checks == 0) begin
        tb_failures = tb_failures + 1;
        $error("[TB_NO_CHECKS] %s", test_id);
      end
      if (tb_failures == 0) begin
        $display("[TB_RESULT] %s PASS checks=%0d scenarios=%016h",
                 test_id, tb_checks, tb_hit_scenarios);
        $finish;
      end else begin
        $fatal(1, "[TB_RESULT] %s FAIL checks=%0d failures=%0d missing=%016h",
               test_id, tb_checks, tb_failures, missing);
      end
    end
  endtask

  function automatic logic [31:0] tb_prng_next(input logic [31:0] value_i);
    logic feedback;
    begin
      feedback = value_i[31] ^ value_i[21] ^ value_i[1] ^ value_i[0];
      return {value_i[30:0], feedback};
    end
  endfunction

  function automatic logic legal_main_transition(input logic [5:0] from_i,
                                                   input logic [5:0] to_i);
    begin
      if (from_i == to_i) return 1'b1;
      case (from_i)
        LTSSM_RESET: return (to_i == LTSSM_DETECT) || (to_i == LTSSM_DISABLED);
        LTSSM_DETECT: return (to_i == LTSSM_POLLING) || (to_i == LTSSM_RESET) ||
                             (to_i == LTSSM_DISABLED);
        LTSSM_POLLING: return (to_i == LTSSM_CONFIGURATION) ||
                              (to_i == LTSSM_DETECT) || (to_i == LTSSM_DISABLED);
        LTSSM_CONFIGURATION: return (to_i == LTSSM_L0) ||
                                    (to_i == LTSSM_DETECT) ||
                                    (to_i == LTSSM_POLLING);
        LTSSM_L0: return (to_i == LTSSM_RECOVERY) || (to_i == LTSSM_L0S) ||
                          (to_i == LTSSM_L1) || (to_i == LTSSM_L2_L3_READY) ||
                          (to_i == LTSSM_DISABLED) || (to_i == LTSSM_LOOPBACK) ||
                          (to_i == LTSSM_HOT_RESET);
        LTSSM_RECOVERY: return (to_i == LTSSM_L0) || (to_i == LTSSM_DETECT) ||
                                (to_i == LTSSM_DISABLED);
        LTSSM_L0S: return (to_i == LTSSM_L0) || (to_i == LTSSM_RECOVERY);
        LTSSM_L1: return (to_i == LTSSM_L0) || (to_i == LTSSM_RECOVERY) ||
                          (to_i == LTSSM_DETECT);
        LTSSM_L2_L3_READY: return (to_i == LTSSM_DETECT) ||
                                   (to_i == LTSSM_RECOVERY);
        LTSSM_DISABLED: return (to_i == LTSSM_DETECT) || (to_i == LTSSM_RESET);
        LTSSM_LOOPBACK: return (to_i == LTSSM_RECOVERY) || (to_i == LTSSM_DETECT);
        LTSSM_HOT_RESET: return (to_i == LTSSM_DETECT) || (to_i == LTSSM_POLLING);
        default: return 1'b0;
      endcase
    end
  endfunction

  function automatic logic [2:0] golden_error_priority(input logic [7:0] code_i);
    case (code_i)
      8'h0c, 8'h0d: return 3'd0;
      8'h07, 8'h08, 8'h10, 8'h12: return 3'd1;
      8'h03, 8'h11: return 3'd2;
      8'h04, 8'h0e, 8'h0f, 8'h13: return 3'd3;
      8'h01, 8'h02, 8'h05, 8'h06, 8'h09, 8'h0a, 8'h0b: return 3'd4;
      default: return 3'd7;
    endcase
  endfunction
endpackage
