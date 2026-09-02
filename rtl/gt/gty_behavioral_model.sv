`timescale 1ns/1ps

// Simulation-only functional model of the normalized Gen1/Gen2 GT contract.
// The TX code groups are echoed through an explicit encoded internal peer path;
// the serial pins are activity/carrier indicators, with RX pin activity used
// only for Electrical-Idle qualification.  Protocol checking is performed on
// 10-bit code groups and therefore makes no analog/CDR claim.
module gty_behavioral_model #(
  parameter int unsigned EI_ASSERT_STABLE_CYCLES = 8,
  parameter int unsigned EI_DEASSERT_STABLE_CYCLES = 16,
  parameter int unsigned DETECT_LATENCY_CYCLES   = 16,
  parameter int unsigned RATE_LATENCY_CYCLES     = 64,
  parameter int unsigned POWER_LATENCY_CYCLES    = 32,
  parameter int unsigned READY_LATENCY_CYCLES    = 32,
  parameter int unsigned DETECT_TIMEOUT_CYCLES = 1024,
  parameter int unsigned RATE_TIMEOUT_CYCLES   = 1024,
  parameter int unsigned POWER_TIMEOUT_CYCLES  = 1024,
  parameter int unsigned ELASTIC_DEPTH_PAIRS     = 16,
  parameter int unsigned CLOCK_COR_INTERVAL      = 64,
  parameter logic [2:0] DETECT_STATUS             = 3'b011,
  parameter bit DETECT_TIMEOUT                    = 1'b0,
  parameter bit RATE_FAIL                         = 1'b0,
  parameter bit POWER_FAIL                        = 1'b0,
  parameter bit LINK_POLARITY_INVERTED            = 1'b0,
  parameter bit INJECT_CODE_ERROR                 = 1'b0,
  parameter bit INJECT_DISPARITY_ERROR            = 1'b0,
  parameter bit INJECT_RXBUF_UNDERFLOW            = 1'b0,
  parameter bit INJECT_RXBUF_OVERFLOW             = 1'b0,
  parameter bit INJECT_TXBUF_FAULT                = 1'b0,
  // 0=no correction, 1=skip one SKP OS, 2=skip two SKP OS, 3=add one SKP OS.
  parameter int unsigned ELASTIC_CORRECTION_MODE = 0
) (
  input  logic         ctrl_clk_i,
  input  logic         ctrl_rst_ni,
  output logic         sym_clk_o,
  output logic         sym_rst_no,
  input  logic [15:0]  tx_symbol_data_i,
  input  logic [1:0]   tx_symbol_is_k_i,
  output logic [15:0]  rx_symbol_data_o,
  output logic [1:0]   rx_symbol_is_k_o,
  output logic [1:0]   rx_symbol_disparity_error_o,
  output logic [1:0]   rx_symbol_code_error_o,
  output logic [1:0]   rx_symbol_is_comma_o,
  output logic         rx_symbol_valid_o,
  output logic         rx_byte_aligned_o,
  output logic         rx_realign_event_o,
  output logic [1:0]   gt_rx_clkcor_count_o,
  output logic [2:0]   gt_rx_buffer_status_o,
  output logic         gt_tx_buffer_fault_o,
  input  logic         gt_detect_req_i,
  output logic         gt_detect_busy_o,
  output logic         gt_detect_done_o,
  output logic         gt_receiver_present_o,
  input  logic         gt_rate_req_i,
  input  logic         gt_rate_target_gen2_i,
  output logic         gt_rate_busy_o,
  output logic         gt_rate_done_o,
  output logic         gt_rate_fail_o,
  input  logic         gt_tx_electrical_idle_i,
  output logic         gt_tx_electrical_idle_active_o,
  output logic         gt_rx_electrical_idle_o,
  input  logic         gt_power_req_i,
  input  logic [1:0]   gt_power_state_i,
  output logic         gt_power_busy_o,
  output logic         gt_power_done_o,
  output logic         gt_power_fail_o,
  input  logic         gt_rx_polarity_invert_i,
  input  logic         gt_tx_deemphasis_i,
  input  logic         gt_tx_swing_i,
  input  logic [2:0]   gt_tx_margin_i,
  input  logic         gt_compliance_enable_i,
  input  logic [2:0]   gt_loopback_mode_i,
  output logic         gt_ready_o,
  output logic         gt_fault_o,
  output logic [7:0]   gt_fault_code_o,
  input  logic         pcie_rx_p_i,
  input  logic         pcie_rx_n_i,
  output logic         pcie_tx_p_o,
  output logic         pcie_tx_n_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;

  typedef struct packed {
    logic       error;
    logic       rd_out;
    logic [9:0] code;
  } enc_result_t;

  typedef struct packed {
    logic       code_error;
    logic       disparity_error;
    logic       is_k;
    logic       rd_out;
    logic [7:0] data;
  } dec_result_t;

  typedef struct packed {
    logic [15:0] data;
    logic [1:0]  is_k;
    logic [1:0]  disparity_error;
    logic [1:0]  code_error;
    logic [1:0]  comma;
    logic [1:0]  align_comma;
  } rx_pair_t;

  typedef enum logic [3:0] {
    OP_IDLE,
    OP_DETECT_ENTER_P1,
    OP_DETECT_SAMPLE,
    OP_DETECT_RESTORE,
    OP_DETECT_REINIT,
    OP_RATE_APPLY,
    OP_RATE_REINIT,
    OP_POWER_APPLY,
    OP_POWER_REINIT,
    OP_SAFE_FAULT
  } op_state_t;

  op_state_t op_state_q;
  logic [31:0] op_count_q;
  logic [31:0] ready_count_q;
  logic [31:0] rx_ei_assert_count_q, rx_ei_deassert_count_q;
  logic [1:0] power_state_q, saved_power_state_q;
  logic current_rate_q, rate_target_q;
  logic detect_consumed_q, rate_consumed_q, power_consumed_q;
  logic detect_fault_pending_q;
  logic internal_electrical_idle_q, txei_sync_q;
  logic tx_rd_q, rx_rd_q;
  logic [19:0] encoded_pipe_q [0:3];
  logic [3:0] encoded_valid_q;
  rx_pair_t elastic_q [0:ELASTIC_DEPTH_PAIRS-1];
  integer elastic_wr_q, elastic_rd_q, elastic_count_q;
  logic elastic_started_q;
  logic rxbuf_fault_q, rxbuf_overflow_fault_q;
  logic [31:0] correction_count_q;
  logic [1:0] replay_count_q;
  rx_pair_t replay_q [0:2];
  logic comma_phase_q;
  logic [4:0] serial_observe_index_q;
  logic [1:0] sym_reset_sync_q;
  logic [1:0] sym_reset_ctrl_sync_q;
  logic [1:0] rx_ei_sym_q, rx_polarity_sym_q;
  logic sym_reset_async_ni;
  logic compliance_active_q, compliance_start_pending_q;
  logic txbuf_inject_seen_q;
  logic txbuf_fault_toggle_sym_q;
  logic [1:0] txbuf_fault_toggle_ctrl_sync_q;
  logic txbuf_fault_snapshot_q;

  initial begin : validate_model_parameters
    if (ELASTIC_DEPTH_PAIRS < 4)
      $fatal(1,"ELASTIC_DEPTH_PAIRS must hold at least one two-pair SKP OS");
    if ((EI_ASSERT_STABLE_CYCLES == 0) ||
        (EI_DEASSERT_STABLE_CYCLES == 0) ||
        (DETECT_LATENCY_CYCLES == 0) ||
        (RATE_LATENCY_CYCLES == 0) || (POWER_LATENCY_CYCLES == 0) ||
        (READY_LATENCY_CYCLES == 0) || (DETECT_TIMEOUT_CYCLES == 0) ||
        (RATE_TIMEOUT_CYCLES == 0) || (POWER_TIMEOUT_CYCLES == 0) ||
        (CLOCK_COR_INTERVAL == 0))
      $fatal(1,"GT behavioral-model timing parameters must be nonzero");
    if (ELASTIC_CORRECTION_MODE > 3)
      $fatal(1,"ELASTIC_CORRECTION_MODE must be 0..3");
  end

  initial begin
    sym_clk_o = 1'b0;
    forever begin
      #((current_rate_q === 1'b1) ? 2ns : 4ns);
      sym_clk_o = ~sym_clk_o;
    end
  end

  assign sym_reset_async_ni = ctrl_rst_ni && gt_ready_o &&
                              ((op_state_q == OP_IDLE) ||
                               (op_state_q == OP_DETECT_REINIT) ||
                               (op_state_q == OP_RATE_REINIT) ||
                               (op_state_q == OP_POWER_REINIT));
  always_ff @(posedge sym_clk_o or negedge sym_reset_async_ni) begin
    if (!sym_reset_async_ni)
      sym_reset_sync_q <= 2'b00;
    else
      sym_reset_sync_q <= {sym_reset_sync_q[0],1'b1};
  end
  assign sym_rst_no = sym_reset_sync_q[1];

  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) begin
      sym_reset_ctrl_sync_q <= 2'b00;
      txbuf_fault_toggle_ctrl_sync_q <= 2'b00;
    end else begin
      sym_reset_ctrl_sync_q <= {sym_reset_ctrl_sync_q[0],sym_rst_no};
      txbuf_fault_toggle_ctrl_sync_q <= {
        txbuf_fault_toggle_ctrl_sync_q[0],txbuf_fault_toggle_sym_q};
    end
  end

  // A TX-buffer fault is a symbol-domain event.  Keep its event toggle alive
  // across symbol resets so the control domain cannot lose the fatal report.
  always_ff @(posedge sym_clk_o or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) begin
      gt_tx_buffer_fault_o <= 1'b0;
      txbuf_inject_seen_q <= 1'b0;
      txbuf_fault_toggle_sym_q <= 1'b0;
    end else begin
      gt_tx_buffer_fault_o <= 1'b0;
      if (sym_rst_no && INJECT_TXBUF_FAULT && !txbuf_inject_seen_q) begin
        gt_tx_buffer_fault_o <= 1'b1;
        txbuf_fault_toggle_sym_q <= ~txbuf_fault_toggle_sym_q;
        txbuf_inject_seen_q <= 1'b1;
      end else if (!INJECT_TXBUF_FAULT) begin
        txbuf_inject_seen_q <= 1'b0;
      end
    end
  end

  // Table entry: {toggle-RD, complement-for-RD+, RD-minus code}.
  function automatic logic [7:0] table_5b6b(input logic [5:0] index_i);
    case (index_i)
      6'd0:return 8'o371;  6'd1:return 8'o356;
      6'd2:return 8'o355;  6'd3:return 8'o043;
      6'd4:return 8'o353;  6'd5:return 8'o045;
      6'd6:return 8'o046;  6'd7:return 8'o107;
      6'd8:return 8'o347;  6'd9:return 8'o051;
      6'd10:return 8'o052; 6'd11:return 8'o013;
      6'd12:return 8'o054; 6'd13:return 8'o015;
      6'd14:return 8'o016; 6'd15:return 8'o372;
      6'd16:return 8'o366; 6'd17:return 8'o061;
      6'd18:return 8'o062; 6'd19:return 8'o023;
      6'd20:return 8'o064; 6'd21:return 8'o025;
      6'd22:return 8'o026; 6'd23:return 8'o327;
      6'd24:return 8'o363; 6'd25:return 8'o031;
      6'd26:return 8'o032; 6'd27:return 8'o333;
      6'd28:return 8'o034; 6'd29:return 8'o335;
      6'd30:return 8'o336; 6'd31:return 8'o365;
      6'd32:return 8'o374; // K28.y special 001111/110000.
      default:return 8'o000;
    endcase
  endfunction

  function automatic logic [7:0] table_data_3b4b(input logic [3:0] index_i);
    case (index_i)
      4'd0:return 8'o315; 4'd1:return 8'o011;
      4'd2:return 8'o012; 4'd3:return 8'o103;
      4'd4:return 8'o313; 4'd5:return 8'o005;
      4'd6:return 8'o006; 4'd7:return 8'o307;
      4'd8:return 8'o316;
      default:return 8'o000;
    endcase
  endfunction

  function automatic logic [7:0] table_ctrl_3b4b(input logic [2:0] index_i);
    case (index_i)
      3'd0:return 8'o315; 3'd1:return 8'o106;
      3'd2:return 8'o105; 3'd3:return 8'o103;
      3'd4:return 8'o313; 3'd5:return 8'o112;
      3'd6:return 8'o111; 3'd7:return 8'o316;
      default:return 8'o000;
    endcase
  endfunction

  function automatic logic legal_k(input logic [7:0] data_i);
    logic [4:0] x;
    logic [2:0] y;
    begin
      x = data_i[4:0];
      y = data_i[7:5];
      return (x == 5'd28) || ((y == 3'd7) &&
             ((x == 5'd23) || (x == 5'd27) ||
              (x == 5'd29) || (x == 5'd30)));
    end
  endfunction

  function automatic enc_result_t encode_8b10b(
    input logic [7:0] data_i, input logic is_k_i, input logic rd_i
  );
    enc_result_t result;
    logic [4:0] x;
    logic [2:0] y;
    logic [7:0] lut6, lut4;
    logic [5:0] code6;
    logic [3:0] code4;
    logic rd_mid, use_alt7;
    begin
      x = data_i[4:0];
      y = data_i[7:5];
      result.error = is_k_i && !legal_k(data_i);
      lut6 = (is_k_i && (x == 5'd28)) ? table_5b6b(6'd32)
                                             : table_5b6b({1'b0,x});
      code6 = (rd_i && lut6[6]) ? ~lut6[5:0] : lut6[5:0];
      rd_mid = lut6[7] ^ rd_i;
      use_alt7 = (y == 3'd7) &&
                 ((rd_mid && ((x == 5'd11)||(x == 5'd13)||(x == 5'd14))) ||
                  (!rd_mid && ((x == 5'd17)||(x == 5'd18)||(x == 5'd20))));
      lut4 = is_k_i ? table_ctrl_3b4b(y)
                    : table_data_3b4b(use_alt7 ? 4'd8 : {1'b0,y});
      code4 = (rd_mid && lut4[6]) ? ~lut4[3:0] : lut4[3:0];
      result.rd_out = lut4[7] ^ rd_mid;
      result.code = {code4,code6};
      if (result.error) begin
        result.code = 10'b0000000000;
        result.rd_out = rd_i;
      end
      return result;
    end
  endfunction

  // Decode tables: {valid,K,RD-out,byte}.
  logic [10:0] decode_rd_minus [0:1023];
  logic [10:0] decode_rd_plus  [0:1023];
  integer init_i, init_k;
  enc_result_t init_enc;
  initial begin
    for (init_i=0; init_i<1024; init_i=init_i+1) begin
      decode_rd_minus[init_i] = '0;
      decode_rd_plus[init_i]  = '0;
    end
    for (init_i=0; init_i<256; init_i=init_i+1) begin
      for (init_k=0; init_k<2; init_k=init_k+1) begin
        init_enc = encode_8b10b(init_i[7:0],init_k[0],1'b0);
        if (!init_enc.error)
          decode_rd_minus[init_enc.code] = {1'b1,init_k[0],init_enc.rd_out,init_i[7:0]};
        init_enc = encode_8b10b(init_i[7:0],init_k[0],1'b1);
        if (!init_enc.error)
          decode_rd_plus[init_enc.code] = {1'b1,init_k[0],init_enc.rd_out,init_i[7:0]};
      end
    end
  end

  function automatic dec_result_t decode_8b10b(
    input logic [9:0] code_i, input logic rd_i
  );
    dec_result_t result;
    logic [10:0] current_entry, opposite_entry;
    begin
      current_entry = rd_i ? decode_rd_plus[code_i] : decode_rd_minus[code_i];
      opposite_entry = rd_i ? decode_rd_minus[code_i] : decode_rd_plus[code_i];
      result = '0;
      result.rd_out = rd_i;
      if (current_entry[10]) begin
        result.is_k = current_entry[9];
        result.rd_out = current_entry[8];
        result.data = current_entry[7:0];
      end else if (opposite_entry[10]) begin
        result.disparity_error = 1'b1;
        result.is_k = opposite_entry[9];
        result.rd_out = opposite_entry[8];
        result.data = opposite_entry[7:0];
      end else begin
        result.code_error = 1'b1;
      end
      return result;
    end
  endfunction

  assign gt_detect_busy_o = (op_state_q == OP_DETECT_ENTER_P1) ||
                            (op_state_q == OP_DETECT_SAMPLE) ||
                            (op_state_q == OP_DETECT_RESTORE) ||
                            (op_state_q == OP_DETECT_REINIT);
  assign gt_rate_busy_o = (op_state_q == OP_RATE_APPLY) ||
                          (op_state_q == OP_RATE_REINIT);
  assign gt_power_busy_o = (op_state_q == OP_POWER_APPLY) ||
                           (op_state_q == OP_POWER_REINIT);

  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin : control_model
    logic txbuf_fault_changed;
    if (!ctrl_rst_ni) begin
      op_state_q <= OP_IDLE;
      op_count_q <= '0;
      ready_count_q <= '0;
      power_state_q <= PHY_POWER_P0;
      saved_power_state_q <= PHY_POWER_P0;
      current_rate_q <= 1'b0;
      rate_target_q <= 1'b0;
      detect_consumed_q <= 1'b0;
      rate_consumed_q <= 1'b0;
      power_consumed_q <= 1'b0;
      detect_fault_pending_q <= 1'b0;
      internal_electrical_idle_q <= 1'b1;
      txei_sync_q <= 1'b1;
      rx_ei_assert_count_q <= '0;
      rx_ei_deassert_count_q <= '0;
      gt_detect_done_o <= 1'b0;
      gt_receiver_present_o <= 1'b0;
      gt_rate_done_o <= 1'b0;
      gt_rate_fail_o <= 1'b0;
      gt_power_done_o <= 1'b0;
      gt_power_fail_o <= 1'b0;
      gt_tx_electrical_idle_active_o <= 1'b1;
      gt_rx_electrical_idle_o <= 1'b1;
      gt_ready_o <= 1'b0;
      gt_fault_o <= 1'b0;
      gt_fault_code_o <= ERR_NONE;
      txbuf_fault_snapshot_q <= 1'b0;
    end else begin
      txbuf_fault_changed = txbuf_fault_toggle_ctrl_sync_q[1] ^
                            txbuf_fault_snapshot_q;
      gt_detect_done_o <= 1'b0;
      gt_receiver_present_o <= 1'b0;
      gt_rate_done_o <= 1'b0;
      gt_rate_fail_o <= 1'b0;
      gt_power_done_o <= 1'b0;
      gt_power_fail_o <= 1'b0;
      gt_fault_o <= 1'b0;
      gt_fault_code_o <= ERR_NONE;
      if (txbuf_fault_changed)
        txbuf_fault_snapshot_q <= txbuf_fault_toggle_ctrl_sync_q[1];
      txei_sync_q <= gt_tx_electrical_idle_i | internal_electrical_idle_q;
      gt_tx_electrical_idle_active_o <= txei_sync_q;
      if (!gt_detect_req_i) detect_consumed_q <= 1'b0;
      if (!gt_rate_req_i) rate_consumed_q <= 1'b0;
      if (!gt_power_req_i) power_consumed_q <= 1'b0;

      if (!gt_ready_o && (power_state_q == PHY_POWER_P0) &&
          ((op_state_q == OP_IDLE) || (op_state_q == OP_DETECT_REINIT) ||
           (op_state_q == OP_RATE_REINIT) ||
           (op_state_q == OP_POWER_REINIT))) begin
        if (ready_count_q + 1 >= READY_LATENCY_CYCLES) begin
          gt_ready_o <= 1'b1;
          internal_electrical_idle_q <= gt_tx_electrical_idle_i;
        end else ready_count_q <= ready_count_q + 1'b1;
      end

      if ((pcie_rx_p_i === pcie_rx_n_i) || (power_state_q != PHY_POWER_P0)) begin
        rx_ei_deassert_count_q <= '0;
        if (rx_ei_assert_count_q < EI_ASSERT_STABLE_CYCLES)
          rx_ei_assert_count_q <= rx_ei_assert_count_q + 1'b1;
        if (rx_ei_assert_count_q + 1 >= EI_ASSERT_STABLE_CYCLES)
          gt_rx_electrical_idle_o <= 1'b1;
      end else begin
        rx_ei_assert_count_q <= '0;
        if (rx_ei_deassert_count_q < EI_DEASSERT_STABLE_CYCLES)
          rx_ei_deassert_count_q <= rx_ei_deassert_count_q + 1'b1;
        if (rx_ei_deassert_count_q + 1 >= EI_DEASSERT_STABLE_CYCLES)
          gt_rx_electrical_idle_o <= 1'b0;
      end

      if (txbuf_fault_changed) begin
        // No TX-buffer-specific value exists in the frozen error-code set.
        // Use its fatal GT-reset class so corrupted PCS data is never exposed.
        internal_electrical_idle_q <= 1'b1;
        gt_ready_o <= 1'b0;
        ready_count_q <= '0;
        gt_fault_o <= 1'b1;
        gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
        op_state_q <= OP_SAFE_FAULT;
      end else case (op_state_q)
        OP_IDLE: begin
          op_count_q <= '0;
          internal_electrical_idle_q <= gt_tx_electrical_idle_i;
          // Frozen reset/rate/detect/power priority after reset/fatal handling.
          if (gt_rate_req_i && !rate_consumed_q) begin
            rate_consumed_q <= 1'b1;
            if (!gt_ready_o || (power_state_q != PHY_POWER_P0)) begin
              gt_rate_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_RATE_NOT_QUIESCED;
            end else begin
              rate_target_q <= gt_rate_target_gen2_i;
              internal_electrical_idle_q <= 1'b1;
              gt_ready_o <= 1'b0;
              ready_count_q <= '0;
              op_state_q <= OP_RATE_APPLY;
            end
          end else if (gt_detect_req_i && !detect_consumed_q) begin
            detect_consumed_q <= 1'b1;
            if (!gt_ready_o || (power_state_q != PHY_POWER_P0)) begin
              gt_detect_done_o <= 1'b1;
              gt_receiver_present_o <= 1'b0;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_DETECT_TIMEOUT;
            end else begin
              detect_fault_pending_q <= 1'b0;
              saved_power_state_q <= power_state_q;
              internal_electrical_idle_q <= 1'b1;
              gt_ready_o <= 1'b0;
              ready_count_q <= '0;
              op_state_q <= OP_DETECT_ENTER_P1;
            end
          end else if (gt_power_req_i && !power_consumed_q) begin
            power_consumed_q <= 1'b1;
            saved_power_state_q <= gt_power_state_i;
            internal_electrical_idle_q <= 1'b1;
            gt_ready_o <= 1'b0;
            ready_count_q <= '0;
            op_state_q <= OP_POWER_APPLY;
          end
        end
        OP_DETECT_ENTER_P1: begin
          op_count_q <= op_count_q + 1'b1;
          if (op_count_q + 1 >= POWER_LATENCY_CYCLES) begin
            power_state_q <= PHY_POWER_P1;
            op_count_q <= '0;
            op_state_q <= OP_DETECT_SAMPLE;
          end
        end
        OP_DETECT_SAMPLE: begin
          op_count_q <= op_count_q + 1'b1;
          if (!DETECT_TIMEOUT && (op_count_q + 1 >= DETECT_LATENCY_CYCLES)) begin
            op_count_q <= '0;
            if ((DETECT_STATUS != 3'b000) && (DETECT_STATUS != 3'b011)) begin
              detect_fault_pending_q <= 1'b1;
            end
            op_state_q <= OP_DETECT_RESTORE;
          end else if (DETECT_TIMEOUT &&
                       (op_count_q + 1 >= DETECT_TIMEOUT_CYCLES)) begin
            detect_fault_pending_q <= 1'b1;
            op_count_q <= '0;
            op_state_q <= OP_DETECT_RESTORE;
          end
        end
        OP_DETECT_RESTORE: begin
          op_count_q <= op_count_q + 1'b1;
          if (op_count_q + 1 >= POWER_LATENCY_CYCLES) begin
            power_state_q <= saved_power_state_q;
            gt_ready_o <= 1'b0;
            ready_count_q <= '0;
            op_count_q <= '0;
            op_state_q <= OP_DETECT_REINIT;
          end
        end
        OP_DETECT_REINIT: begin
          op_count_q <= op_count_q + 1'b1;
          if (gt_ready_o && sym_reset_ctrl_sync_q[1]) begin
            gt_detect_done_o <= 1'b1;
            gt_receiver_present_o <= (DETECT_STATUS == 3'b011) &&
                                     !detect_fault_pending_q;
            op_count_q <= '0;
            if (detect_fault_pending_q) begin
              internal_electrical_idle_q <= 1'b1;
              gt_ready_o <= 1'b0;
              ready_count_q <= '0;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_DETECT_TIMEOUT;
              op_state_q <= OP_SAFE_FAULT;
            end else begin
              internal_electrical_idle_q <= gt_tx_electrical_idle_i;
              op_state_q <= OP_IDLE;
            end
          end else if (op_count_q + 1 >= DETECT_TIMEOUT_CYCLES) begin
            gt_detect_done_o <= 1'b1;
            gt_receiver_present_o <= 1'b0;
            gt_fault_o <= 1'b1;
            gt_fault_code_o <= ERR_DETECT_TIMEOUT;
            internal_electrical_idle_q <= 1'b1;
            op_state_q <= OP_SAFE_FAULT;
          end
        end
        OP_RATE_APPLY: begin
          op_count_q <= op_count_q + 1'b1;
          if (op_count_q + 1 >= RATE_LATENCY_CYCLES) begin
            op_count_q <= '0;
            if (RATE_FAIL) begin
              gt_rate_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_RATE_CHANGE;
              gt_ready_o <= 1'b0;
              ready_count_q <= '0;
              op_state_q <= OP_SAFE_FAULT;
            end else begin
              current_rate_q <= rate_target_q;
              gt_ready_o <= 1'b0;
              ready_count_q <= '0;
              op_state_q <= OP_RATE_REINIT;
            end
          end
        end
        OP_RATE_REINIT: begin
          op_count_q <= op_count_q + 1'b1;
          if (gt_ready_o && sym_reset_ctrl_sync_q[1]) begin
            internal_electrical_idle_q <= gt_tx_electrical_idle_i;
            gt_rate_done_o <= 1'b1;
            op_count_q <= '0;
            op_state_q <= OP_IDLE;
          end else if (op_count_q + 1 >= RATE_TIMEOUT_CYCLES) begin
            gt_rate_fail_o <= 1'b1;
            gt_fault_o <= 1'b1;
            gt_fault_code_o <= ERR_RATE_CHANGE;
            internal_electrical_idle_q <= 1'b1;
            op_state_q <= OP_SAFE_FAULT;
          end
        end
        OP_POWER_APPLY: begin
          op_count_q <= op_count_q + 1'b1;
          if (op_count_q + 1 >= POWER_LATENCY_CYCLES) begin
            op_count_q <= '0;
            if (POWER_FAIL) begin
              gt_power_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
              gt_ready_o <= 1'b0;
              ready_count_q <= '0;
              op_state_q <= OP_SAFE_FAULT;
            end else begin
              power_state_q <= saved_power_state_q;
              if (saved_power_state_q == PHY_POWER_P0) begin
                gt_ready_o <= 1'b0;
                ready_count_q <= '0;
                op_state_q <= OP_POWER_REINIT;
              end else begin
                gt_power_done_o <= 1'b1;
                op_state_q <= OP_IDLE;
              end
            end
          end
        end
        OP_POWER_REINIT: begin
          op_count_q <= op_count_q + 1'b1;
          if (gt_ready_o && sym_reset_ctrl_sync_q[1]) begin
            internal_electrical_idle_q <= gt_tx_electrical_idle_i;
            gt_power_done_o <= 1'b1;
            op_count_q <= '0;
            op_state_q <= OP_IDLE;
          end else if (op_count_q + 1 >= POWER_TIMEOUT_CYCLES) begin
            gt_power_fail_o <= 1'b1;
            gt_fault_o <= 1'b1;
            gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
            internal_electrical_idle_q <= 1'b1;
            op_state_q <= OP_SAFE_FAULT;
          end
        end
        OP_SAFE_FAULT: begin
          internal_electrical_idle_q <= 1'b1;
          if (!gt_detect_req_i && !gt_rate_req_i && !gt_power_req_i) begin
            // Fatal recovery is a fresh PHY initialization.  Return the
            // behavioral PCS clock/rate context to the mandatory Gen1 base
            // rate before ready can be re-established.
            current_rate_q <= 1'b0;
            rate_target_q <= 1'b0;
            power_state_q <= PHY_POWER_P0;
            saved_power_state_q <= PHY_POWER_P0;
            ready_count_q <= '0;
            op_state_q <= OP_IDLE;
          end
        end
        default: op_state_q <= OP_SAFE_FAULT;
      endcase
    end
  end

  always @(posedge sym_clk_o or negedge sym_rst_no) begin : pcs_and_elastic_model
    integer idx, next_wr, next_rd, next_count;
    enc_result_t enc0, enc1;
    dec_result_t dec0, dec1;
    logic [19:0] received_codes;
    rx_pair_t decoded_pair, head_pair;
    logic head_valid, head_is_skp_start, second_is_skp_tail;
    logic third_is_skp_start, fourth_is_skp_tail;
    logic overflow_event, underflow_event;
    logic fault_active;
    logic compliance_start;
    logic tx_rd_start;
    if (!sym_rst_no) begin
      tx_rd_q <= 1'b0;
      rx_rd_q <= 1'b0;
      encoded_valid_q <= '0;
      for (idx=0; idx<4; idx=idx+1) encoded_pipe_q[idx] <= '0;
      elastic_wr_q <= 0;
      elastic_rd_q <= 0;
      elastic_count_q <= 0;
      elastic_started_q <= 1'b0;
      rxbuf_fault_q <= 1'b0;
      rxbuf_overflow_fault_q <= 1'b0;
      correction_count_q <= '0;
      replay_count_q <= 2'd0;
      for (idx=0; idx<3; idx=idx+1) replay_q[idx] <= '0;
      rx_symbol_data_o <= '0;
      rx_symbol_is_k_o <= '0;
      rx_symbol_disparity_error_o <= '0;
      rx_symbol_code_error_o <= '0;
      rx_symbol_is_comma_o <= '0;
      rx_symbol_valid_o <= 1'b0;
      rx_byte_aligned_o <= 1'b0;
      rx_realign_event_o <= 1'b0;
      gt_rx_clkcor_count_o <= 2'b00;
      gt_rx_buffer_status_o <= 3'b000;
      comma_phase_q <= 1'b0;
      serial_observe_index_q <= '0;
      rx_ei_sym_q <= 2'b11;
      rx_polarity_sym_q <= 2'b00;
      compliance_active_q <= 1'b0;
      compliance_start_pending_q <= 1'b0;
      pcie_tx_p_o <= 1'b0;
      pcie_tx_n_o <= 1'b0;
    end else begin
      rx_symbol_valid_o <= 1'b0;
      rx_realign_event_o <= 1'b0;
      gt_rx_clkcor_count_o <= 2'b00;
      correction_count_q <= correction_count_q + 1'b1;
      head_pair = '0;
      head_valid = 1'b0;
      overflow_event = 1'b0;
      underflow_event = 1'b0;
      fault_active = rxbuf_fault_q || INJECT_RXBUF_UNDERFLOW ||
                     INJECT_RXBUF_OVERFLOW;
      rx_ei_sym_q <= {rx_ei_sym_q[0],gt_rx_electrical_idle_o};
      rx_polarity_sym_q <= {rx_polarity_sym_q[0],
                            gt_rx_polarity_invert_i};
      if (!gt_compliance_enable_i) begin
        compliance_active_q <= 1'b0;
        compliance_start_pending_q <= 1'b0;
      end else if (!compliance_active_q) begin
        compliance_active_q <= 1'b1;
        compliance_start_pending_q <= 1'b1;
      end

      for (idx=3; idx>0; idx=idx-1) begin
        encoded_pipe_q[idx] <= encoded_pipe_q[idx-1];
        encoded_valid_q[idx] <= encoded_valid_q[idx-1];
      end
      if (gt_ready_o && !gt_tx_electrical_idle_active_o &&
          (power_state_q == PHY_POWER_P0)) begin
        compliance_start = gt_compliance_enable_i &&
                           (!compliance_active_q ||
                            compliance_start_pending_q) &&
                           tx_symbol_is_k_i[0] &&
                           (tx_symbol_data_i[7:0] == K_COM);
        tx_rd_start = compliance_start ? 1'b0 : tx_rd_q;
        enc0 = encode_8b10b(tx_symbol_data_i[7:0],tx_symbol_is_k_i[0],
                            tx_rd_start);
        enc1 = encode_8b10b(tx_symbol_data_i[15:8],tx_symbol_is_k_i[1],enc0.rd_out);
        encoded_pipe_q[0] <= {enc1.code,enc0.code};
        encoded_valid_q[0] <= 1'b1;
        tx_rd_q <= enc1.rd_out;
        if (compliance_start) compliance_start_pending_q <= 1'b0;
      end else begin
        encoded_pipe_q[0] <= '0;
        encoded_valid_q[0] <= 1'b0;
        tx_rd_q <= 1'b0;
      end

      next_wr = elastic_wr_q;
      next_rd = elastic_rd_q;
      next_count = elastic_count_q;
      if (encoded_valid_q[3] && !rx_ei_sym_q[1] && !fault_active) begin
        received_codes = LINK_POLARITY_INVERTED ? ~encoded_pipe_q[3]
                                                : encoded_pipe_q[3];
        if (rx_polarity_sym_q[1]) received_codes = ~received_codes;
        dec0 = decode_8b10b(received_codes[9:0],rx_rd_q);
        dec1 = decode_8b10b(received_codes[19:10],dec0.rd_out);
        rx_rd_q <= dec1.rd_out;
        decoded_pair.data = {dec1.data,dec0.data};
        decoded_pair.code_error = {dec1.code_error,dec0.code_error};
        decoded_pair.align_comma[0] = dec0.is_k && !dec0.code_error &&
                                      (dec0.data == K_COM);
        decoded_pair.align_comma[1] = dec1.is_k && !dec1.code_error &&
                                      (dec1.data == K_COM);
        if (INJECT_CODE_ERROR) decoded_pair.code_error[0] = 1'b1;
        decoded_pair.is_k[0] = dec0.is_k && !decoded_pair.code_error[0];
        decoded_pair.is_k[1] = dec1.is_k && !decoded_pair.code_error[1];
        decoded_pair.disparity_error[0] =
          (dec0.disparity_error || INJECT_DISPARITY_ERROR) &&
          !decoded_pair.code_error[0];
        decoded_pair.disparity_error[1] =
          (dec1.disparity_error || INJECT_DISPARITY_ERROR) &&
          !decoded_pair.code_error[1];
        decoded_pair.comma[0] = decoded_pair.is_k[0] && (dec0.data == K_COM);
        decoded_pair.comma[1] = decoded_pair.is_k[1] && (dec1.data == K_COM);
        if (next_count < ELASTIC_DEPTH_PAIRS) begin
          elastic_q[next_wr] = decoded_pair;
          next_wr = (next_wr+1) % ELASTIC_DEPTH_PAIRS;
          next_count = next_count+1;
        end else begin
          overflow_event = 1'b1;
          rxbuf_fault_q <= 1'b1;
          rxbuf_overflow_fault_q <= 1'b1;
          rx_byte_aligned_o <= 1'b0;
        end
      end else if (rx_ei_sym_q[1]) begin
        rx_rd_q <= 1'b0;
        rx_byte_aligned_o <= 1'b0;
        next_wr = 0;
        next_rd = 0;
        next_count = 0;
        elastic_started_q <= 1'b0;
        replay_count_q <= 2'd0;
      end

      if (!fault_active) begin
      if (replay_count_q != 0) begin
        head_pair = replay_q[0];
        head_valid = 1'b1;
        replay_q[0] <= replay_q[1];
        replay_q[1] <= replay_q[2];
        replay_q[2] <= '0;
        replay_count_q <= replay_count_q - 1'b1;
      end else if ((next_count > 0) &&
                   (elastic_started_q ||
                    (next_count >= ((ELASTIC_CORRECTION_MODE == 2) ? 4 : 2)))) begin
        elastic_started_q <= 1'b1;
        head_pair = elastic_q[next_rd];
        head_is_skp_start = (head_pair.is_k == 2'b11) &&
                            (head_pair.data == {K_SKP,K_COM}) &&
                            (head_pair.code_error == 2'b00);
        second_is_skp_tail = 1'b0;
        third_is_skp_start = 1'b0;
        fourth_is_skp_tail = 1'b0;
        if (next_count > 1)
          second_is_skp_tail =
            (elastic_q[(next_rd+1)%ELASTIC_DEPTH_PAIRS].is_k == 2'b11) &&
            (elastic_q[(next_rd+1)%ELASTIC_DEPTH_PAIRS].data == {K_SKP,K_SKP}) &&
            (elastic_q[(next_rd+1)%ELASTIC_DEPTH_PAIRS].code_error == 2'b00);
        if (next_count > 2)
          third_is_skp_start =
            (elastic_q[(next_rd+2)%ELASTIC_DEPTH_PAIRS].is_k == 2'b11) &&
            (elastic_q[(next_rd+2)%ELASTIC_DEPTH_PAIRS].data == {K_SKP,K_COM}) &&
            (elastic_q[(next_rd+2)%ELASTIC_DEPTH_PAIRS].code_error == 2'b00);
        if (next_count > 3)
          fourth_is_skp_tail =
            (elastic_q[(next_rd+3)%ELASTIC_DEPTH_PAIRS].is_k == 2'b11) &&
            (elastic_q[(next_rd+3)%ELASTIC_DEPTH_PAIRS].data == {K_SKP,K_SKP}) &&
            (elastic_q[(next_rd+3)%ELASTIC_DEPTH_PAIRS].code_error == 2'b00);
        if ((ELASTIC_CORRECTION_MODE == 2) && head_is_skp_start &&
            (next_count < 4)) begin
          // Hold the first OS until the second complete OS is visible.  This
          // deterministic high-water pause models the worst-drift case and
          // lets skip-two remain atomic without dropping non-SKP characters.
          head_valid = 1'b0;
        end else if (head_is_skp_start && second_is_skp_tail &&
            (correction_count_q >= CLOCK_COR_INTERVAL) &&
            (ELASTIC_CORRECTION_MODE == 1)) begin
          next_rd = (next_rd+2) % ELASTIC_DEPTH_PAIRS;
          next_count = next_count-2;
          gt_rx_clkcor_count_o <= 2'b01;
          correction_count_q <= '0;
        end else if (head_is_skp_start && second_is_skp_tail &&
                     third_is_skp_start && fourth_is_skp_tail &&
                     (correction_count_q >= CLOCK_COR_INTERVAL) &&
                     (ELASTIC_CORRECTION_MODE == 2)) begin
          next_rd = (next_rd+4) % ELASTIC_DEPTH_PAIRS;
          next_count = next_count-4;
          gt_rx_clkcor_count_o <= 2'b10;
          correction_count_q <= '0;
        end else if (head_is_skp_start && second_is_skp_tail &&
                     (correction_count_q >= CLOCK_COR_INTERVAL) &&
                     (ELASTIC_CORRECTION_MODE == 3)) begin
          head_valid = 1'b1;
          next_rd = (next_rd+2) % ELASTIC_DEPTH_PAIRS;
          next_count = next_count-2;
          replay_q[0] <= elastic_q[(elastic_rd_q+1)%ELASTIC_DEPTH_PAIRS];
          replay_q[1] <= head_pair;
          replay_q[2] <= elastic_q[(elastic_rd_q+1)%ELASTIC_DEPTH_PAIRS];
          replay_count_q <= 2'd3;
          gt_rx_clkcor_count_o <= 2'b11;
          correction_count_q <= '0;
        end else begin
          head_valid = 1'b1;
          next_rd = (next_rd+1) % ELASTIC_DEPTH_PAIRS;
          next_count = next_count-1;
        end
      end else if (elastic_started_q && rx_byte_aligned_o &&
                   !rx_ei_sym_q[1]) begin
        underflow_event = 1'b1;
        elastic_started_q <= 1'b0;
        rxbuf_fault_q <= 1'b1;
        rxbuf_overflow_fault_q <= 1'b0;
        rx_byte_aligned_o <= 1'b0;
      end
      end

      if (head_valid) begin
        rx_symbol_data_o <= head_pair.data;
        rx_symbol_is_k_o <= head_pair.is_k;
        rx_symbol_disparity_error_o <= head_pair.disparity_error;
        rx_symbol_code_error_o <= head_pair.code_error;
        rx_symbol_is_comma_o <= head_pair.comma;
        rx_symbol_valid_o <= gt_ready_o &&
                             !rx_ei_sym_q[1] &&
                             !INJECT_RXBUF_UNDERFLOW &&
                             !INJECT_RXBUF_OVERFLOW && !rxbuf_fault_q &&
                             !overflow_event;
        if (head_pair.align_comma != 2'b00) begin
          if (!rx_byte_aligned_o) rx_byte_aligned_o <= 1'b1;
          else if (comma_phase_q != head_pair.align_comma[1])
            rx_realign_event_o <= 1'b1;
          comma_phase_q <= head_pair.align_comma[1];
        end
      end

      elastic_wr_q <= next_wr;
      elastic_rd_q <= next_rd;
      elastic_count_q <= next_count;
      if (INJECT_RXBUF_OVERFLOW || overflow_event ||
          (rxbuf_fault_q && rxbuf_overflow_fault_q))
        gt_rx_buffer_status_o <= 3'b110;
      else if (INJECT_RXBUF_UNDERFLOW || underflow_event || rxbuf_fault_q)
        gt_rx_buffer_status_o <= 3'b101;
      else if (next_count == 0) gt_rx_buffer_status_o <= 3'b001;
      else if (next_count >= ELASTIC_DEPTH_PAIRS-2) gt_rx_buffer_status_o <= 3'b010;
      else gt_rx_buffer_status_o <= 3'b000;

      if (gt_tx_electrical_idle_active_o || (power_state_q != PHY_POWER_P0)) begin
        pcie_tx_p_o <= 1'b0;
        pcie_tx_n_o <= 1'b0;
      end else begin
        pcie_tx_p_o <= encoded_pipe_q[0][serial_observe_index_q];
        pcie_tx_n_o <= ~encoded_pipe_q[0][serial_observe_index_q];
        serial_observe_index_q <= (serial_observe_index_q == 5'd19) ? 5'd0
                                                                    : serial_observe_index_q+1'b1;
      end
    end
  end

  // TX deemphasis/swing/margin are analog-only in this digital model.  The
  // encoded-code-group echo is the model's explicit loopback/peer semantics;
  // gt_loopback_mode_i therefore does not alter the already-internal path.

endmodule
