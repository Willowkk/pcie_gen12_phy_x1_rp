`timescale 1ns/1ps

// Single-lane GT boundary. GTYE4-private signals terminate here; the rest of
// the PHY sees only the normalized two-character and bounded control contract.
module pcie_gty_adapter_x1 #(
  parameter int unsigned SIM_TIME_SCALE = 1,
  parameter logic [2:0] BEHAV_DETECT_STATUS = 3'b011,
  parameter bit BEHAV_DETECT_TIMEOUT = 1'b0,
  parameter bit BEHAV_RATE_FAIL = 1'b0,
  parameter bit BEHAV_POWER_FAIL = 1'b0,
  parameter bit BEHAV_LINK_POLARITY_INVERTED = 1'b0,
  parameter int unsigned BEHAV_ELASTIC_DEPTH_PAIRS = 16,
  parameter int unsigned BEHAV_ELASTIC_CORRECTION_MODE = 0,
  parameter bit BEHAV_INJECT_CODE_ERROR = 1'b0,
  parameter bit BEHAV_INJECT_DISPARITY_ERROR = 1'b0,
  parameter bit BEHAV_INJECT_RXBUF_UNDERFLOW = 1'b0,
  parameter bit BEHAV_INJECT_RXBUF_OVERFLOW = 1'b0,
  parameter bit BEHAV_INJECT_TXBUF_FAULT = 1'b0,
  // TODO(Wizard): Replace these placeholder native TXRATE/RXRATE encodings
  // with the values from the final GT Wizard wrapper.
  parameter logic [2:0] WIZARD_RATE_CODE_GEN1 = 3'b000,
  parameter logic [2:0] WIZARD_RATE_CODE_GEN2 = 3'b000,
  // TODO(Wizard): Replace these placeholder rate-mode values with the values
  // from the final GT Wizard wrapper.
  parameter logic WIZARD_TX_RATE_MODE = 1'b0,
  parameter logic WIZARD_RX_RATE_MODE = 1'b0,
  // TODO(Wizard): Replace this placeholder RXELECIDLEMODE value with the value
  // from the final GT Wizard wrapper.
  parameter logic [1:0] WIZARD_RX_EI_MODE = 2'b00,
  // TODO(Wizard): Freeze RX LPM-versus-DFE selection and any static board-only
  // TX polarity setting from the final Wizard/electrical configuration.
  parameter logic WIZARD_RX_LPM_ENABLE = 1'b0,
  parameter logic WIZARD_TX_POLARITY   = 1'b0,
  // TODO(Wizard): Freeze the TXCTRL0/TXCTRL1 low-bit values which make the
  // first Compliance K28.5 use negative-current-disparity semantics.
  parameter logic [1:0] WIZARD_COMPLIANCE_TXCTRL0_LOW = 2'b00,
  parameter logic [1:0] WIZARD_COMPLIANCE_TXCTRL1_LOW = 2'b00
) (
  input  logic        ctrl_clk_i,
  input  logic        ctrl_rst_ni,
  input  logic        pcie_refclk_p_i,
  input  logic        pcie_refclk_n_i,
  input  logic        pcie_rx_p_i,
  input  logic        pcie_rx_n_i,
  output logic        pcie_tx_p_o,
  output logic        pcie_tx_n_o,
  output logic        gt_sym_clk_o,
  output logic        gt_sym_rst_no,
  output logic        gt_sym_clk_stable_o,
  output logic        gt_buffer_reinit_done_o,

  input  logic [15:0] tx_symbol_data_i,
  input  logic [1:0]  tx_symbol_is_k_i,
  output logic [15:0] rx_symbol_data_o,
  output logic [1:0]  rx_symbol_is_k_o,
  output logic [1:0]  rx_symbol_disparity_error_o,
  output logic [1:0]  rx_symbol_code_error_o,
  output logic [1:0]  rx_symbol_is_comma_o,
  output logic        rx_symbol_valid_o,
  output logic        rx_byte_aligned_o,
  output logic        rx_realign_event_o,
  output logic [1:0]  gt_rx_clkcor_count_o,
  output logic [2:0]  gt_rx_buffer_status_o,
  output logic        gt_tx_buffer_fault_o,

  input  logic        gt_detect_req_i,
  output logic        gt_detect_busy_o,
  output logic        gt_detect_done_o,
  output logic        gt_receiver_present_o,
  input  logic        gt_rate_req_i,
  input  logic        gt_rate_target_gen2_i,
  output logic        gt_rate_busy_o,
  output logic        gt_rate_done_o,
  output logic        gt_rate_fail_o,
  input  logic        gt_tx_electrical_idle_i,
  output logic        gt_tx_electrical_idle_active_o,
  output logic        gt_rx_electrical_idle_o,
  input  logic        gt_power_req_i,
  input  logic [1:0]  gt_power_state_i,
  output logic        gt_power_busy_o,
  output logic        gt_power_done_o,
  output logic        gt_power_fail_o,
  input  logic        gt_rx_polarity_invert_i,
  input  logic        gt_tx_deemphasis_i,
  input  logic        gt_tx_swing_i,
  input  logic [2:0]  gt_tx_margin_i,
  input  logic        gt_compliance_enable_i,
  input  logic [2:0]  gt_loopback_mode_i,
  output logic        gt_ready_o,
  output logic        gt_fault_o,
  output logic [7:0]  gt_fault_code_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

`ifdef GT_BEHAV_MODEL

  gty_behavioral_model #(
    .EI_ASSERT_STABLE_CYCLES(RX_EI_ASSERT_STABLE_CYCLES),
    .EI_DEASSERT_STABLE_CYCLES(RX_EI_DEASSERT_STABLE_CYCLES),
    .DETECT_LATENCY_CYCLES(
      sim_scaled_cycles(GT_BUFFER_REINIT_CYCLES,SIM_TIME_SCALE)),
    .RATE_LATENCY_CYCLES(
      sim_scaled_cycles(GT_CLOCK_STABLE_CYCLES,SIM_TIME_SCALE)),
    .POWER_LATENCY_CYCLES(
      sim_scaled_cycles(GT_BUFFER_REINIT_CYCLES,SIM_TIME_SCALE)),
    .READY_LATENCY_CYCLES(
      sim_scaled_cycles(GT_CLOCK_STABLE_CYCLES,SIM_TIME_SCALE)),
    .DETECT_TIMEOUT_CYCLES(
      timer_default_cycles(TIMER_GT_DETECT,SIM_TIME_SCALE)),
    .RATE_TIMEOUT_CYCLES(
      timer_default_cycles(TIMER_GT_RATE,SIM_TIME_SCALE)),
    .POWER_TIMEOUT_CYCLES(
      timer_default_cycles(TIMER_GT_POWER,SIM_TIME_SCALE)),
    .ELASTIC_DEPTH_PAIRS(BEHAV_ELASTIC_DEPTH_PAIRS),
    .CLOCK_COR_INTERVAL(SKP_SCHEDULE_INTERVAL_SYMBOLS/2),
    .DETECT_STATUS(BEHAV_DETECT_STATUS),
    .DETECT_TIMEOUT(BEHAV_DETECT_TIMEOUT),
    .RATE_FAIL(BEHAV_RATE_FAIL),
    .POWER_FAIL(BEHAV_POWER_FAIL),
    .LINK_POLARITY_INVERTED(BEHAV_LINK_POLARITY_INVERTED),
    .INJECT_CODE_ERROR(BEHAV_INJECT_CODE_ERROR),
    .INJECT_DISPARITY_ERROR(BEHAV_INJECT_DISPARITY_ERROR),
    .INJECT_RXBUF_UNDERFLOW(BEHAV_INJECT_RXBUF_UNDERFLOW),
    .INJECT_RXBUF_OVERFLOW(BEHAV_INJECT_RXBUF_OVERFLOW),
    .INJECT_TXBUF_FAULT(BEHAV_INJECT_TXBUF_FAULT),
    .ELASTIC_CORRECTION_MODE(BEHAV_ELASTIC_CORRECTION_MODE)
  ) u_gty_behavioral_model (
    .ctrl_clk_i(ctrl_clk_i),
    .ctrl_rst_ni(ctrl_rst_ni),
    .sym_clk_o(gt_sym_clk_o),
    .sym_rst_no(gt_sym_rst_no),
    .tx_symbol_data_i(tx_symbol_data_i),
    .tx_symbol_is_k_i(tx_symbol_is_k_i),
    .rx_symbol_data_o(rx_symbol_data_o),
    .rx_symbol_is_k_o(rx_symbol_is_k_o),
    .rx_symbol_disparity_error_o(rx_symbol_disparity_error_o),
    .rx_symbol_code_error_o(rx_symbol_code_error_o),
    .rx_symbol_is_comma_o(rx_symbol_is_comma_o),
    .rx_symbol_valid_o(rx_symbol_valid_o),
    .rx_byte_aligned_o(rx_byte_aligned_o),
    .rx_realign_event_o(rx_realign_event_o),
    .gt_rx_clkcor_count_o(gt_rx_clkcor_count_o),
    .gt_rx_buffer_status_o(gt_rx_buffer_status_o),
    .gt_tx_buffer_fault_o(gt_tx_buffer_fault_o),
    .gt_detect_req_i(gt_detect_req_i),
    .gt_detect_busy_o(gt_detect_busy_o),
    .gt_detect_done_o(gt_detect_done_o),
    .gt_receiver_present_o(gt_receiver_present_o),
    .gt_rate_req_i(gt_rate_req_i),
    .gt_rate_target_gen2_i(gt_rate_target_gen2_i),
    .gt_rate_busy_o(gt_rate_busy_o),
    .gt_rate_done_o(gt_rate_done_o),
    .gt_rate_fail_o(gt_rate_fail_o),
    .gt_tx_electrical_idle_i(gt_tx_electrical_idle_i),
    .gt_tx_electrical_idle_active_o(gt_tx_electrical_idle_active_o),
    .gt_rx_electrical_idle_o(gt_rx_electrical_idle_o),
    .gt_power_req_i(gt_power_req_i),
    .gt_power_state_i(gt_power_state_i),
    .gt_power_busy_o(gt_power_busy_o),
    .gt_power_done_o(gt_power_done_o),
    .gt_power_fail_o(gt_power_fail_o),
    .gt_rx_polarity_invert_i(gt_rx_polarity_invert_i),
    .gt_tx_deemphasis_i(gt_tx_deemphasis_i),
    .gt_tx_swing_i(gt_tx_swing_i),
    .gt_tx_margin_i(gt_tx_margin_i),
    .gt_compliance_enable_i(gt_compliance_enable_i),
    .gt_loopback_mode_i(gt_loopback_mode_i),
    .gt_ready_o(gt_ready_o),
    .gt_fault_o(gt_fault_o),
    .gt_fault_code_o(gt_fault_code_o),
    .pcie_rx_p_i(pcie_rx_p_i),
    .pcie_rx_n_i(pcie_rx_n_i),
    .pcie_tx_p_o(pcie_tx_p_o),
    .pcie_tx_n_o(pcie_tx_n_o)
  );

  (* ASYNC_REG = "TRUE" *) logic [1:0] behav_sym_rst_ctrl_sync_q;
  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) behav_sym_rst_ctrl_sync_q <= 2'b00;
    else behav_sym_rst_ctrl_sync_q <= {behav_sym_rst_ctrl_sync_q[0],
                                       gt_sym_rst_no};
  end
  assign gt_sym_clk_stable_o = gt_ready_o &&
                               behav_sym_rst_ctrl_sync_q[1];
  assign gt_buffer_reinit_done_o = gt_ready_o &&
                                   behav_sym_rst_ctrl_sync_q[1];

`else

  localparam int unsigned RESET_TIMEOUT_CYCLES =
    timer_default_cycles(TIMER_GT_RESET,SIM_TIME_SCALE);
  localparam int unsigned DETECT_TIMEOUT_CYCLES =
    timer_default_cycles(TIMER_GT_DETECT,SIM_TIME_SCALE);
  localparam int unsigned RATE_TIMEOUT_CYCLES =
    timer_default_cycles(TIMER_GT_RATE,SIM_TIME_SCALE);
  localparam int unsigned POWER_TIMEOUT_CYCLES =
    timer_default_cycles(TIMER_GT_POWER,SIM_TIME_SCALE);

  typedef enum logic [4:0] {
    GT_ST_RESET_HOLD,
    GT_ST_RESET_WAIT,
    GT_ST_IDLE,
    GT_ST_DETECT_ENTER_P1,
    GT_ST_DETECT_WAIT,
    GT_ST_DETECT_DISARM,
    GT_ST_DETECT_RESTORE,
    GT_ST_DETECT_RESET_HOLD,
    GT_ST_DETECT_RESET_WAIT,
    GT_ST_RATE_WAIT_EI,
    GT_ST_RATE_WAIT_DONE,
    GT_ST_RATE_RESET_HOLD,
    GT_ST_RATE_RESET_WAIT,
    GT_ST_POWER_WAIT,
    GT_ST_POWER_RESET_HOLD,
    GT_ST_POWER_RESET_WAIT,
    GT_ST_SAFE_FAULT
  } gt_ctrl_state_t;

  typedef struct packed {
    logic [2:0] rate;
    logic       txdetectrx;
    logic       txelecidle;
    logic       rxpolarity;
    logic       txdeemphasis;
    logic       txswing;
    logic [2:0] txmargin;
    logic [2:0] loopback;
    logic       compliance;
  } native_ctrl_bundle_t;

  gt_ctrl_state_t ctrl_state_q;
  logic [31:0] op_count_q;
  logic [31:0] stable_count_q;
  logic detect_consumed_q, rate_consumed_q, power_consumed_q;
  logic detect_fault_pending_q, detect_result_q;
  logic rate_target_q, current_rate_q;
  logic [1:0] power_target_q, current_power_q, detect_saved_power_q;

  // TODO(Wizard): Recheck the primitive DATA/CTRL port widths and unused high
  // bit tie-offs against the exact Vivado-version-generated GTYE4 instance.
  logic gt_refclk, gt_refclk_div2;
  logic native_txoutclk, native_rxoutclk;
  logic [127:0] native_txdata, native_rxdata;
  logic [15:0] native_txctrl0, native_txctrl1;
  logic [7:0] native_txctrl2;
  logic [15:0] native_rxctrl0, native_rxctrl1;
  logic [7:0] native_rxctrl2, native_rxctrl3;
  logic [1:0] native_rxdatavalid;
  logic native_rxbyteisaligned, native_rxbyterealign, native_rxcommadet;
  logic [1:0] native_rxclkcorcnt;
  logic [2:0] native_rxbufstatus;
  logic [1:0] native_txbufstatus;
  logic native_rxelecidle, native_phystatus;
  logic native_rxcdrlock;
  logic native_txbuf_fault_prev_q, native_txbuf_fault_event_q;
  logic native_txbuf_fault_toggle_sym_q;
  logic [2:0] native_rxstatus;
  logic native_txratedone, native_rxratedone;
  logic native_txresetdone, native_rxresetdone;
  logic native_cplllock, native_gtpowergood;

  logic [1:0] native_txpd_q, native_rxpd_q;
  logic [2:0] native_rate_q;
  logic [1:0] native_txdeemph;
  logic native_txdetectrx_q, native_txelecidle_q;
  logic native_gttxreset_q, native_gtrxreset_q, native_rxbufreset_q;
  logic native_txuserrdy_q, native_rxuserrdy_q;
  logic sym_release_ctrl_q, data_enable_ctrl_q;
  native_ctrl_bundle_t native_ctrl_desired;
  native_ctrl_bundle_t native_ctrl_source_q;
  native_ctrl_bundle_t native_ctrl_applied_q;
  logic native_ctrl_req_toggle_q, native_ctrl_ack_toggle_sym_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] native_ctrl_req_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] native_ctrl_ack_sync_q;
  logic compliance_pending_sym_q, compliance_force_now;

  logic phystatus_toggle_sym_q, txratedone_toggle_sym_q;
  logic rxratedone_toggle_sym_q;
  logic [2:0] phystatus_value_sym_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] phystatus_toggle_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] txratedone_toggle_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rxratedone_toggle_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] txbuf_fault_toggle_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [2:0] phystatus_value_meta_q;
  (* ASYNC_REG = "TRUE" *) logic [2:0] phystatus_value_sync_q;
  logic phystatus_snapshot_q, txratedone_snapshot_q, rxratedone_snapshot_q;
  logic txbuf_fault_snapshot_q;
  logic txrate_seen_q, rxrate_seen_q;

  (* ASYNC_REG = "TRUE" *) logic [1:0] txresetdone_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rxresetdone_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] cplllock_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] gtpowergood_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] txei_feedback_sync_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rxelecidle_sync_q;
  logic [31:0] rx_ei_assert_count_q, rx_ei_deassert_count_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] sym_reset_release_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] data_enable_sym_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] txei_feedback_sym_q;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rxei_gate_sym_q;
  (* ASYNC_REG = "TRUE" *) logic gt_sym_rst_ctrl_meta_q;
  (* ASYNC_REG = "TRUE" *) logic gt_sym_rst_ctrl_q;
  logic sym_async_reset_ni;

  // TODO(Wizard): Replace the unused DATA/CTRL high-bit zero placeholders with
  // the static tie-offs emitted by the final Wizard wrapper.
  assign native_txdata = {112'h0,tx_symbol_data_i};
  assign compliance_force_now = compliance_pending_sym_q &&
                                native_ctrl_applied_q.compliance &&
                                tx_symbol_is_k_i[0] &&
                                (tx_symbol_data_i[7:0] == K_COM);
  assign native_txctrl0 = {14'h0000,
    compliance_force_now ? WIZARD_COMPLIANCE_TXCTRL0_LOW : 2'b00};
  assign native_txctrl1 = {14'h0000,
    compliance_force_now ? WIZARD_COMPLIANCE_TXCTRL1_LOW : 2'b00};
  assign native_txctrl2 = {6'h00,tx_symbol_is_k_i};
  // TODO(Wizard): Freeze the normalized one-bit deemphasis to GTYE4's
  // two-bit TXDEEMPH mapping from the final Wizard electrical configuration.
  assign native_txdeemph = {1'b0,native_ctrl_applied_q.txdeemphasis};
  always_comb begin
    native_ctrl_desired.rate = native_rate_q;
    native_ctrl_desired.txdetectrx = native_txdetectrx_q;
    native_ctrl_desired.txelecidle = native_txelecidle_q;
    native_ctrl_desired.rxpolarity = gt_rx_polarity_invert_i;
    native_ctrl_desired.txdeemphasis = gt_tx_deemphasis_i;
    native_ctrl_desired.txswing = gt_tx_swing_i;
    native_ctrl_desired.txmargin = gt_tx_margin_i;
    native_ctrl_desired.loopback = gt_loopback_mode_i;
    native_ctrl_desired.compliance = gt_compliance_enable_i;
  end

  assign rx_symbol_data_o = native_rxdata[15:0];
  assign rx_symbol_code_error_o = native_rxctrl3[1:0];
  assign rx_symbol_is_k_o = native_rxctrl0[1:0] & ~native_rxctrl3[1:0];
  assign rx_symbol_disparity_error_o = native_rxctrl1[1:0] &
                                       ~native_rxctrl3[1:0];
  assign rx_symbol_is_comma_o = native_rxctrl2[1:0] &
                                ~native_rxctrl3[1:0];
  assign rx_byte_aligned_o = native_rxbyteisaligned;
  assign rx_realign_event_o = native_rxbyterealign;
  assign gt_rx_clkcor_count_o = native_rxclkcorcnt;
  assign gt_tx_buffer_fault_o = native_txbuf_fault_event_q;
  assign rx_symbol_valid_o = (&native_rxdatavalid) &&
                             data_enable_sym_q[1] && gt_sym_rst_no &&
                             native_rxcdrlock &&
                             !rxei_gate_sym_q[1] &&
                             ((native_rxbufstatus == 3'b000) ||
                              (native_rxbufstatus == 3'b001) ||
                              (native_rxbufstatus == 3'b010));
  assign gt_tx_electrical_idle_active_o = txei_feedback_sync_q[1];
  assign gt_sym_clk_stable_o = gt_ready_o && gt_sym_rst_ctrl_q;
  assign gt_buffer_reinit_done_o = gt_ready_o && gt_sym_rst_ctrl_q;

  always_comb begin
    case (native_rxbufstatus)
      3'b000: gt_rx_buffer_status_o = 3'b000;
      3'b001: gt_rx_buffer_status_o = 3'b001;
      3'b010: gt_rx_buffer_status_o = 3'b010;
      3'b101: gt_rx_buffer_status_o = 3'b101;
      3'b110: gt_rx_buffer_status_o = 3'b110;
      // Preserve a reserved native encoding so the downstream status checker
      // can raise its invalid-status event; never disguise it as nominal.
      default: gt_rx_buffer_status_o = native_rxbufstatus;
    endcase
  end

  assign gt_detect_busy_o = (ctrl_state_q == GT_ST_DETECT_ENTER_P1) ||
                            (ctrl_state_q == GT_ST_DETECT_WAIT) ||
                            (ctrl_state_q == GT_ST_DETECT_DISARM) ||
                            (ctrl_state_q == GT_ST_DETECT_RESTORE) ||
                            (ctrl_state_q == GT_ST_DETECT_RESET_HOLD) ||
                            (ctrl_state_q == GT_ST_DETECT_RESET_WAIT);
  assign gt_rate_busy_o = (ctrl_state_q == GT_ST_RATE_WAIT_EI) ||
                          (ctrl_state_q == GT_ST_RATE_WAIT_DONE) ||
                          (ctrl_state_q == GT_ST_RATE_RESET_HOLD) ||
                          (ctrl_state_q == GT_ST_RATE_RESET_WAIT);
  assign gt_power_busy_o = (ctrl_state_q == GT_ST_POWER_WAIT) ||
                           (ctrl_state_q == GT_ST_POWER_RESET_HOLD) ||
                           (ctrl_state_q == GT_ST_POWER_RESET_WAIT);

  always_ff @(posedge gt_sym_clk_o or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) begin
      native_txbuf_fault_prev_q <= 1'b0;
      native_txbuf_fault_event_q <= 1'b0;
      native_txbuf_fault_toggle_sym_q <= 1'b0;
    end else begin
      native_txbuf_fault_event_q <= (native_txbufstatus != 2'b00) &&
                                    !native_txbuf_fault_prev_q;
      if ((native_txbufstatus != 2'b00) && !native_txbuf_fault_prev_q)
        native_txbuf_fault_toggle_sym_q <=
          ~native_txbuf_fault_toggle_sym_q;
      // Every non-nominal native encoding is unsafe here: this covers the
      // documented underflow/overflow indications and any reserved value.
      native_txbuf_fault_prev_q <= (native_txbufstatus != 2'b00);
    end
  end

  // Rate plus the symbol-domain mode controls cross as one held bundle.  The
  // source cannot be overwritten until the destination acknowledges the
  // current toggle.  TXPD/RXPD and reset-helper controls are separate held,
  // glitch-free control-domain registers because the GT user clock may stop in
  // P2 or while reset is asserted.
  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) begin
      native_ctrl_source_q.rate <= WIZARD_RATE_CODE_GEN1;
      native_ctrl_source_q.txdetectrx <= 1'b0;
      native_ctrl_source_q.txelecidle <= 1'b1;
      native_ctrl_source_q.rxpolarity <= 1'b0;
      native_ctrl_source_q.txdeemphasis <= 1'b0;
      native_ctrl_source_q.txswing <= 1'b0;
      native_ctrl_source_q.txmargin <= 3'b000;
      native_ctrl_source_q.loopback <= 3'b000;
      native_ctrl_source_q.compliance <= 1'b0;
      native_ctrl_req_toggle_q <= 1'b0;
      native_ctrl_ack_sync_q <= 2'b00;
    end else begin
      native_ctrl_ack_sync_q <= {native_ctrl_ack_sync_q[0],
                                  native_ctrl_ack_toggle_sym_q};
      if ((native_ctrl_ack_sync_q[1] == native_ctrl_req_toggle_q) &&
          (native_ctrl_source_q != native_ctrl_desired)) begin
        native_ctrl_source_q <= native_ctrl_desired;
        native_ctrl_req_toggle_q <= ~native_ctrl_req_toggle_q;
      end
    end
  end

  always_ff @(posedge gt_sym_clk_o or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) begin
      native_ctrl_req_sync_q <= 2'b00;
      native_ctrl_ack_toggle_sym_q <= 1'b0;
      native_ctrl_applied_q.rate <= WIZARD_RATE_CODE_GEN1;
      native_ctrl_applied_q.txdetectrx <= 1'b0;
      native_ctrl_applied_q.txelecidle <= 1'b1;
      native_ctrl_applied_q.rxpolarity <= 1'b0;
      native_ctrl_applied_q.txdeemphasis <= 1'b0;
      native_ctrl_applied_q.txswing <= 1'b0;
      native_ctrl_applied_q.txmargin <= 3'b000;
      native_ctrl_applied_q.loopback <= 3'b000;
      native_ctrl_applied_q.compliance <= 1'b0;
      compliance_pending_sym_q <= 1'b0;
    end else begin
      if (compliance_force_now)
        compliance_pending_sym_q <= 1'b0;
      native_ctrl_req_sync_q <= {native_ctrl_req_sync_q[0],
                                  native_ctrl_req_toggle_q};
      if (native_ctrl_req_sync_q[1] != native_ctrl_ack_toggle_sym_q) begin
        if (native_ctrl_source_q.compliance &&
            !native_ctrl_applied_q.compliance)
          compliance_pending_sym_q <= 1'b1;
        else if (!native_ctrl_source_q.compliance)
          compliance_pending_sym_q <= 1'b0;
        native_ctrl_applied_q <= native_ctrl_source_q;
        native_ctrl_ack_toggle_sym_q <= native_ctrl_req_sync_q[1];
      end
    end
  end

  // Source-domain event capture. RXSTATUS and its event toggle form one
  // bundled-data transfer, so Detect cannot sample a later native transaction.
  // These capture flops intentionally remain live while the PL symbol-path
  // reset is asserted during rate/power operations.
  assign sym_async_reset_ni = ctrl_rst_ni && sym_release_ctrl_q;
  always_ff @(posedge gt_sym_clk_o or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) begin
      phystatus_toggle_sym_q <= 1'b0;
      txratedone_toggle_sym_q <= 1'b0;
      rxratedone_toggle_sym_q <= 1'b0;
      phystatus_value_sym_q <= 3'b000;
    end else begin
      if (native_phystatus) begin
        phystatus_value_sym_q <= native_rxstatus;
        phystatus_toggle_sym_q <= ~phystatus_toggle_sym_q;
      end
      if (native_txratedone)
        txratedone_toggle_sym_q <= ~txratedone_toggle_sym_q;
      if (native_rxratedone)
        rxratedone_toggle_sym_q <= ~rxratedone_toggle_sym_q;
    end
  end

  always_ff @(posedge gt_sym_clk_o or negedge sym_async_reset_ni) begin
    if (!sym_async_reset_ni) begin
      sym_reset_release_q <= 2'b00;
      data_enable_sym_q <= 2'b00;
      txei_feedback_sym_q <= 2'b11;
      rxei_gate_sym_q <= 2'b11;
    end else begin
      if (!sym_release_ctrl_q)
        sym_reset_release_q <= 2'b00;
      else
        sym_reset_release_q <= {sym_reset_release_q[0],1'b1};
      data_enable_sym_q <= {data_enable_sym_q[0],data_enable_ctrl_q};
      txei_feedback_sym_q <= {txei_feedback_sym_q[0],
                              native_ctrl_applied_q.txelecidle};
      rxei_gate_sym_q <= {rxei_gate_sym_q[0],gt_rx_electrical_idle_o};
    end
  end
  assign gt_sym_rst_no = sym_reset_release_q[1];

  // Synchronizers and the asymmetric RX electrical-idle debounce live in the
  // control domain. All single-cycle native events were captured as toggles.
  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni) begin
      phystatus_toggle_sync_q <= 2'b00;
      txratedone_toggle_sync_q <= 2'b00;
      rxratedone_toggle_sync_q <= 2'b00;
      txbuf_fault_toggle_sync_q <= 2'b00;
      phystatus_value_meta_q <= 3'b000;
      phystatus_value_sync_q <= 3'b000;
      txresetdone_sync_q <= 2'b00;
      rxresetdone_sync_q <= 2'b00;
      cplllock_sync_q <= 2'b00;
      gtpowergood_sync_q <= 2'b00;
      txei_feedback_sync_q <= 2'b11;
      rxelecidle_sync_q <= 2'b11;
      gt_sym_rst_ctrl_meta_q <= 1'b0;
      gt_sym_rst_ctrl_q <= 1'b0;
      rx_ei_assert_count_q <= '0;
      rx_ei_deassert_count_q <= '0;
      gt_rx_electrical_idle_o <= 1'b1;
    end else begin
      phystatus_toggle_sync_q <= {phystatus_toggle_sync_q[0],
                                  phystatus_toggle_sym_q};
      txratedone_toggle_sync_q <= {txratedone_toggle_sync_q[0],
                                   txratedone_toggle_sym_q};
      rxratedone_toggle_sync_q <= {rxratedone_toggle_sync_q[0],
                                   rxratedone_toggle_sym_q};
      txbuf_fault_toggle_sync_q <= {txbuf_fault_toggle_sync_q[0],
                                    native_txbuf_fault_toggle_sym_q};
      phystatus_value_meta_q <= phystatus_value_sym_q;
      phystatus_value_sync_q <= phystatus_value_meta_q;
      txresetdone_sync_q <= {txresetdone_sync_q[0],native_txresetdone};
      rxresetdone_sync_q <= {rxresetdone_sync_q[0],native_rxresetdone};
      cplllock_sync_q <= {cplllock_sync_q[0],native_cplllock};
      gtpowergood_sync_q <= {gtpowergood_sync_q[0],native_gtpowergood};
      txei_feedback_sync_q <= {txei_feedback_sync_q[0],
                               txei_feedback_sym_q[1]};
      rxelecidle_sync_q <= {rxelecidle_sync_q[0],native_rxelecidle};
      gt_sym_rst_ctrl_meta_q <= gt_sym_rst_no;
      gt_sym_rst_ctrl_q <= gt_sym_rst_ctrl_meta_q;

      if (rxelecidle_sync_q[1]) begin
        rx_ei_deassert_count_q <= '0;
        if (rx_ei_assert_count_q < RX_EI_ASSERT_STABLE_CYCLES)
          rx_ei_assert_count_q <= rx_ei_assert_count_q + 1'b1;
        if (rx_ei_assert_count_q + 1 >= RX_EI_ASSERT_STABLE_CYCLES)
          gt_rx_electrical_idle_o <= 1'b1;
      end else begin
        rx_ei_assert_count_q <= '0;
        if (rx_ei_deassert_count_q < RX_EI_DEASSERT_STABLE_CYCLES)
          rx_ei_deassert_count_q <= rx_ei_deassert_count_q + 1'b1;
        if (rx_ei_deassert_count_q + 1 >= RX_EI_DEASSERT_STABLE_CYCLES)
          gt_rx_electrical_idle_o <= 1'b0;
      end
    end
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin : native_control
    logic phystatus_changed, txrate_changed, rxrate_changed;
    logic txbuf_fault_changed;
    if (!ctrl_rst_ni) begin
      ctrl_state_q <= GT_ST_RESET_HOLD;
      op_count_q <= '0;
      stable_count_q <= '0;
      detect_consumed_q <= 1'b0;
      rate_consumed_q <= 1'b0;
      power_consumed_q <= 1'b0;
      detect_fault_pending_q <= 1'b0;
      detect_result_q <= 1'b0;
      rate_target_q <= 1'b0;
      current_rate_q <= 1'b0;
      power_target_q <= PHY_POWER_P0;
      current_power_q <= PHY_POWER_P0;
      detect_saved_power_q <= PHY_POWER_P0;
      phystatus_snapshot_q <= 1'b0;
      txratedone_snapshot_q <= 1'b0;
      rxratedone_snapshot_q <= 1'b0;
      txbuf_fault_snapshot_q <= 1'b0;
      txrate_seen_q <= 1'b0;
      rxrate_seen_q <= 1'b0;
      native_txpd_q <= PHY_POWER_P0;
      native_rxpd_q <= PHY_POWER_P0;
      native_rate_q <= WIZARD_RATE_CODE_GEN1;
      native_txdetectrx_q <= 1'b0;
      native_txelecidle_q <= 1'b1;
      native_gttxreset_q <= 1'b1;
      native_gtrxreset_q <= 1'b1;
      native_rxbufreset_q <= 1'b1;
      native_txuserrdy_q <= 1'b0;
      native_rxuserrdy_q <= 1'b0;
      sym_release_ctrl_q <= 1'b0;
      data_enable_ctrl_q <= 1'b0;
      gt_detect_done_o <= 1'b0;
      gt_receiver_present_o <= 1'b0;
      gt_rate_done_o <= 1'b0;
      gt_rate_fail_o <= 1'b0;
      gt_power_done_o <= 1'b0;
      gt_power_fail_o <= 1'b0;
      gt_ready_o <= 1'b0;
      gt_fault_o <= 1'b0;
      gt_fault_code_o <= ERR_NONE;
    end else begin
      phystatus_changed = phystatus_toggle_sync_q[1] ^ phystatus_snapshot_q;
      txrate_changed = txratedone_toggle_sync_q[1] ^ txratedone_snapshot_q;
      rxrate_changed = rxratedone_toggle_sync_q[1] ^ rxratedone_snapshot_q;
      txbuf_fault_changed = txbuf_fault_toggle_sync_q[1] ^
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
        txbuf_fault_snapshot_q <= txbuf_fault_toggle_sync_q[1];
      if (!gt_detect_req_i) detect_consumed_q <= 1'b0;
      if (!gt_rate_req_i) rate_consumed_q <= 1'b0;
      if (!gt_power_req_i) power_consumed_q <= 1'b0;

      // PLL loss is the native fatal condition with priority over transactions.
      if ((ctrl_state_q == GT_ST_IDLE) && gt_ready_o &&
          (current_power_q == PHY_POWER_P0) &&
          (!cplllock_sync_q[1] || !gtpowergood_sync_q[1])) begin
        gt_ready_o <= 1'b0;
        data_enable_ctrl_q <= 1'b0;
        native_txelecidle_q <= 1'b1;
        gt_fault_o <= 1'b1;
        gt_fault_code_o <= !cplllock_sync_q[1] ? ERR_GT_PLL_UNLOCK :
                                                ERR_GT_RESET_TIMEOUT;
        ctrl_state_q <= GT_ST_SAFE_FAULT;
      end else if (txbuf_fault_changed) begin
        // The frozen error enumeration has no TX-buffer-specific code.  Treat
        // this native GT-buffer corruption as the existing fatal GT-reset
        // class: data is quiesced immediately and a full GT reset follows.
        gt_ready_o <= 1'b0;
        data_enable_ctrl_q <= 1'b0;
        native_txelecidle_q <= 1'b1;
        gt_fault_o <= 1'b1;
        gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
        ctrl_state_q <= GT_ST_SAFE_FAULT;
      end else begin
        case (ctrl_state_q)
          GT_ST_RESET_HOLD: begin
            gt_ready_o <= 1'b0;
            data_enable_ctrl_q <= 1'b0;
            native_txelecidle_q <= 1'b1;
            native_gttxreset_q <= 1'b1;
            native_gtrxreset_q <= 1'b1;
            native_rxbufreset_q <= 1'b1;
            native_txuserrdy_q <= 1'b0;
            native_rxuserrdy_q <= 1'b0;
            sym_release_ctrl_q <= 1'b0;
            if (op_count_q + 1 >= GT_BUFFER_REINIT_CYCLES) begin
              op_count_q <= '0;
              stable_count_q <= '0;
              native_gttxreset_q <= 1'b0;
              native_gtrxreset_q <= 1'b0;
              native_rxbufreset_q <= 1'b0;
              native_txuserrdy_q <= 1'b1;
              native_rxuserrdy_q <= 1'b1;
              ctrl_state_q <= GT_ST_RESET_WAIT;
            end else if (op_count_q + 1 >= RESET_TIMEOUT_CYCLES) begin
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end else op_count_q <= op_count_q + 1'b1;
          end

          GT_ST_RESET_WAIT: begin
            op_count_q <= op_count_q + 1'b1;
            if (!native_gttxreset_q && !native_gtrxreset_q &&
                !native_rxbufreset_q && native_txuserrdy_q &&
                native_rxuserrdy_q)
              sym_release_ctrl_q <= 1'b1;
            if (txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                gt_sym_rst_ctrl_q) begin
              if (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES) begin
                gt_ready_o <= 1'b1;
                native_txelecidle_q <= gt_tx_electrical_idle_i;
                data_enable_ctrl_q <= (current_power_q == PHY_POWER_P0);
                ctrl_state_q <= GT_ST_IDLE;
                op_count_q <= '0;
              end else stable_count_q <= stable_count_q + 1'b1;
            end else stable_count_q <= '0;
            if ((op_count_q + 1 >= RESET_TIMEOUT_CYCLES) &&
                !(txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                  cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                  gt_sym_rst_ctrl_q &&
                  (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES))) begin
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end
          end

          GT_ST_IDLE: begin
            op_count_q <= '0;
            stable_count_q <= '0;
            native_txdetectrx_q <= 1'b0;
            data_enable_ctrl_q <= (current_power_q == PHY_POWER_P0);
            native_txelecidle_q <= (current_power_q == PHY_POWER_P0) ?
                                   gt_tx_electrical_idle_i : 1'b1;
            // One global native transaction, with frozen rate/detect/power priority.
            if (gt_rate_req_i && !rate_consumed_q) begin
              rate_consumed_q <= 1'b1;
              if (!gt_ready_o || (current_power_q != PHY_POWER_P0)) begin
                gt_rate_fail_o <= 1'b1;
                gt_fault_o <= 1'b1;
                gt_fault_code_o <= ERR_RATE_NOT_QUIESCED;
              end else begin
                rate_target_q <= gt_rate_target_gen2_i;
                txrate_seen_q <= 1'b0;
                rxrate_seen_q <= 1'b0;
                data_enable_ctrl_q <= 1'b0;
                native_txelecidle_q <= 1'b1;
                ctrl_state_q <= GT_ST_RATE_WAIT_EI;
              end
            end else if (gt_detect_req_i && !detect_consumed_q) begin
              detect_consumed_q <= 1'b1;
              if (!gt_ready_o || (current_power_q != PHY_POWER_P0)) begin
                gt_detect_done_o <= 1'b1;
                gt_receiver_present_o <= 1'b0;
                gt_fault_o <= 1'b1;
                gt_fault_code_o <= ERR_DETECT_TIMEOUT;
              end else begin
                detect_saved_power_q <= current_power_q;
                detect_fault_pending_q <= 1'b0;
                detect_result_q <= 1'b0;
                phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
                native_txpd_q <= PHY_POWER_P1;
                native_rxpd_q <= PHY_POWER_P1;
                data_enable_ctrl_q <= 1'b0;
                native_txelecidle_q <= 1'b1;
                gt_ready_o <= 1'b0;
                sym_release_ctrl_q <= 1'b0;
                ctrl_state_q <= GT_ST_DETECT_ENTER_P1;
              end
            end else if (gt_power_req_i && !power_consumed_q) begin
              power_consumed_q <= 1'b1;
              power_target_q <= gt_power_state_i;
              native_txpd_q <= gt_power_state_i;
              native_rxpd_q <= gt_power_state_i;
              phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
              data_enable_ctrl_q <= 1'b0;
              native_txelecidle_q <= 1'b1;
              gt_ready_o <= 1'b0;
              sym_release_ctrl_q <= 1'b0;
              ctrl_state_q <= GT_ST_POWER_WAIT;
            end
          end

          GT_ST_DETECT_ENTER_P1: begin
            data_enable_ctrl_q <= 1'b0;
            native_txelecidle_q <= 1'b1;
            op_count_q <= op_count_q + 1'b1;
            if (phystatus_changed ||
                ((detect_saved_power_q == PHY_POWER_P1) &&
                 (op_count_q + 1 >= GT_BUFFER_REINIT_CYCLES))) begin
              op_count_q <= '0;
              phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
              native_txdetectrx_q <= 1'b1;
              ctrl_state_q <= GT_ST_DETECT_WAIT;
            end else if (op_count_q + 1 >= DETECT_TIMEOUT_CYCLES) begin
              native_txpd_q <= detect_saved_power_q;
              native_rxpd_q <= detect_saved_power_q;
              detect_fault_pending_q <= 1'b1;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_DETECT_RESTORE;
            end
          end

          GT_ST_DETECT_WAIT: begin
            op_count_q <= op_count_q + 1'b1;
            if (phystatus_changed) begin
              phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
              native_txdetectrx_q <= 1'b0;
              detect_result_q <= (phystatus_value_sync_q == 3'b011);
              detect_fault_pending_q <= (phystatus_value_sync_q != 3'b000) &&
                                        (phystatus_value_sync_q != 3'b011);
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_DETECT_DISARM;
            end else if (op_count_q + 1 >= DETECT_TIMEOUT_CYCLES) begin
              native_txdetectrx_q <= 1'b0;
              detect_result_q <= 1'b0;
              detect_fault_pending_q <= 1'b1;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_DETECT_DISARM;
            end
          end

          GT_ST_DETECT_DISARM: begin
            op_count_q <= op_count_q + 1'b1;
            native_txelecidle_q <= 1'b1;
            data_enable_ctrl_q <= 1'b0;
            if (!native_ctrl_applied_q.txdetectrx) begin
              native_txpd_q <= detect_saved_power_q;
              native_rxpd_q <= detect_saved_power_q;
              phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_DETECT_RESTORE;
            end else if (op_count_q + 1 >= DETECT_TIMEOUT_CYCLES) begin
              native_txpd_q <= detect_saved_power_q;
              native_rxpd_q <= detect_saved_power_q;
              detect_fault_pending_q <= 1'b1;
              phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_DETECT_RESTORE;
            end
          end

          GT_ST_DETECT_RESTORE: begin
            op_count_q <= op_count_q + 1'b1;
            if (phystatus_changed ||
                ((detect_saved_power_q == PHY_POWER_P1) &&
                 (op_count_q + 1 >= GT_BUFFER_REINIT_CYCLES))) begin
              phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
              current_power_q <= detect_saved_power_q;
              native_gttxreset_q <= 1'b1;
              native_gtrxreset_q <= 1'b1;
              native_rxbufreset_q <= 1'b1;
              native_txuserrdy_q <= 1'b0;
              native_rxuserrdy_q <= 1'b0;
              gt_ready_o <= 1'b0;
              data_enable_ctrl_q <= 1'b0;
              native_txelecidle_q <= 1'b1;
              sym_release_ctrl_q <= 1'b0;
              stable_count_q <= '0;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_DETECT_RESET_HOLD;
            end else if (op_count_q + 1 >= DETECT_TIMEOUT_CYCLES) begin
              current_power_q <= detect_saved_power_q;
              data_enable_ctrl_q <= 1'b0;
              native_txelecidle_q <= 1'b1;
              gt_detect_done_o <= 1'b1;
              gt_receiver_present_o <= 1'b0;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_DETECT_TIMEOUT;
              gt_ready_o <= 1'b0;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
              op_count_q <= '0;
            end
          end

          GT_ST_DETECT_RESET_HOLD: begin
            if (op_count_q + 1 >= GT_BUFFER_REINIT_CYCLES) begin
              native_gttxreset_q <= 1'b0;
              native_gtrxreset_q <= 1'b0;
              native_rxbufreset_q <= 1'b0;
              native_txuserrdy_q <= 1'b1;
              native_rxuserrdy_q <= 1'b1;
              stable_count_q <= '0;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_DETECT_RESET_WAIT;
            end else if (op_count_q + 1 >= DETECT_TIMEOUT_CYCLES) begin
              gt_detect_done_o <= 1'b1;
              gt_receiver_present_o <= 1'b0;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_DETECT_TIMEOUT;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end else op_count_q <= op_count_q + 1'b1;
          end

          GT_ST_DETECT_RESET_WAIT: begin
            op_count_q <= op_count_q + 1'b1;
            if (!native_gttxreset_q && !native_gtrxreset_q &&
                !native_rxbufreset_q && native_txuserrdy_q &&
                native_rxuserrdy_q)
              sym_release_ctrl_q <= 1'b1;
            if (txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                gt_sym_rst_ctrl_q) begin
              if (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES) begin
                gt_detect_done_o <= 1'b1;
                gt_receiver_present_o <= detect_result_q &&
                                         !detect_fault_pending_q;
                if (detect_fault_pending_q) begin
                  gt_ready_o <= 1'b0;
                  data_enable_ctrl_q <= 1'b0;
                  native_txelecidle_q <= 1'b1;
                  gt_fault_o <= 1'b1;
                  gt_fault_code_o <= ERR_DETECT_TIMEOUT;
                  ctrl_state_q <= GT_ST_SAFE_FAULT;
                end else begin
                  gt_ready_o <= 1'b1;
                  data_enable_ctrl_q <= 1'b1;
                  native_txelecidle_q <= gt_tx_electrical_idle_i;
                  ctrl_state_q <= GT_ST_IDLE;
                end
              end else stable_count_q <= stable_count_q + 1'b1;
            end else stable_count_q <= '0;
            if ((op_count_q + 1 >= DETECT_TIMEOUT_CYCLES) &&
                !(txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                  cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                  gt_sym_rst_ctrl_q &&
                  (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES))) begin
              gt_detect_done_o <= 1'b1;
              gt_receiver_present_o <= 1'b0;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_DETECT_TIMEOUT;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end
          end

          GT_ST_RATE_WAIT_EI: begin
            op_count_q <= op_count_q + 1'b1;
            data_enable_ctrl_q <= 1'b0;
            native_txelecidle_q <= 1'b1;
            if (txei_feedback_sync_q[1]) begin
              gt_ready_o <= 1'b0;
              sym_release_ctrl_q <= 1'b0;
              native_rate_q <= rate_target_q ? WIZARD_RATE_CODE_GEN2 :
                                                WIZARD_RATE_CODE_GEN1;
              txratedone_snapshot_q <= txratedone_toggle_sync_q[1];
              rxratedone_snapshot_q <= rxratedone_toggle_sync_q[1];
              txrate_seen_q <= 1'b0;
              rxrate_seen_q <= 1'b0;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_RATE_WAIT_DONE;
            end else if (op_count_q + 1 >= RATE_TIMEOUT_CYCLES) begin
              native_rate_q <= current_rate_q ? WIZARD_RATE_CODE_GEN2 :
                                                WIZARD_RATE_CODE_GEN1;
              gt_rate_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_RATE_NOT_QUIESCED;
              gt_ready_o <= 1'b0;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end
          end

          GT_ST_RATE_WAIT_DONE: begin
            op_count_q <= op_count_q + 1'b1;
            if (txrate_changed) txrate_seen_q <= 1'b1;
            if (rxrate_changed) rxrate_seen_q <= 1'b1;
            if ((txrate_seen_q || txrate_changed) &&
                (rxrate_seen_q || rxrate_changed)) begin
              native_gttxreset_q <= 1'b1;
              native_gtrxreset_q <= 1'b1;
              native_rxbufreset_q <= 1'b1;
              native_txuserrdy_q <= 1'b0;
              native_rxuserrdy_q <= 1'b0;
              sym_release_ctrl_q <= 1'b0;
              gt_ready_o <= 1'b0;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_RATE_RESET_HOLD;
            end else if (op_count_q + 1 >= RATE_TIMEOUT_CYCLES) begin
              native_rate_q <= current_rate_q ? WIZARD_RATE_CODE_GEN2 :
                                                WIZARD_RATE_CODE_GEN1;
              gt_rate_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_RATE_CHANGE;
              gt_ready_o <= 1'b0;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end
          end

          GT_ST_RATE_RESET_HOLD: begin
            if (op_count_q + 1 >= GT_BUFFER_REINIT_CYCLES) begin
              native_gttxreset_q <= 1'b0;
              native_gtrxreset_q <= 1'b0;
              native_rxbufreset_q <= 1'b0;
              native_txuserrdy_q <= 1'b1;
              native_rxuserrdy_q <= 1'b1;
              stable_count_q <= '0;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_RATE_RESET_WAIT;
            end else if (op_count_q + 1 >= RATE_TIMEOUT_CYCLES) begin
              native_rate_q <= current_rate_q ? WIZARD_RATE_CODE_GEN2 :
                                                WIZARD_RATE_CODE_GEN1;
              gt_rate_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_RATE_CHANGE;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end else op_count_q <= op_count_q + 1'b1;
          end

          GT_ST_RATE_RESET_WAIT: begin
            op_count_q <= op_count_q + 1'b1;
            if (!native_gttxreset_q && !native_gtrxreset_q &&
                !native_rxbufreset_q && native_txuserrdy_q &&
                native_rxuserrdy_q)
              sym_release_ctrl_q <= 1'b1;
            if (txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                gt_sym_rst_ctrl_q) begin
              if (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES) begin
                current_rate_q <= rate_target_q;
                gt_ready_o <= 1'b1;
                data_enable_ctrl_q <= (current_power_q == PHY_POWER_P0);
                native_txelecidle_q <= gt_tx_electrical_idle_i;
                gt_rate_done_o <= 1'b1;
                ctrl_state_q <= GT_ST_IDLE;
              end else stable_count_q <= stable_count_q + 1'b1;
            end else stable_count_q <= '0;
            if ((op_count_q + 1 >= RATE_TIMEOUT_CYCLES) &&
                !(txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                  cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                  gt_sym_rst_ctrl_q &&
                  (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES))) begin
              native_rate_q <= current_rate_q ? WIZARD_RATE_CODE_GEN2 :
                                                WIZARD_RATE_CODE_GEN1;
              gt_rate_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_RATE_CHANGE;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end
          end

          GT_ST_POWER_WAIT: begin
            op_count_q <= op_count_q + 1'b1;
            if (phystatus_changed) begin
              phystatus_snapshot_q <= phystatus_toggle_sync_q[1];
              current_power_q <= power_target_q;
              op_count_q <= '0;
              if (power_target_q == PHY_POWER_P0) begin
                native_gttxreset_q <= 1'b1;
                native_gtrxreset_q <= 1'b1;
                native_rxbufreset_q <= 1'b1;
                native_txuserrdy_q <= 1'b0;
                native_rxuserrdy_q <= 1'b0;
                sym_release_ctrl_q <= 1'b0;
                gt_ready_o <= 1'b0;
                ctrl_state_q <= GT_ST_POWER_RESET_HOLD;
              end else begin
                gt_power_done_o <= 1'b1;
                ctrl_state_q <= GT_ST_IDLE;
              end
            end else if (op_count_q + 1 >= POWER_TIMEOUT_CYCLES) begin
              native_txpd_q <= current_power_q;
              native_rxpd_q <= current_power_q;
              gt_power_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
              gt_ready_o <= 1'b0;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end
          end

          GT_ST_POWER_RESET_HOLD: begin
            if (op_count_q + 1 >= GT_BUFFER_REINIT_CYCLES) begin
              native_gttxreset_q <= 1'b0;
              native_gtrxreset_q <= 1'b0;
              native_rxbufreset_q <= 1'b0;
              native_txuserrdy_q <= 1'b1;
              native_rxuserrdy_q <= 1'b1;
              stable_count_q <= '0;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_POWER_RESET_WAIT;
            end else if (op_count_q + 1 >= POWER_TIMEOUT_CYCLES) begin
              native_txpd_q <= current_power_q;
              native_rxpd_q <= current_power_q;
              gt_power_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end else op_count_q <= op_count_q + 1'b1;
          end

          GT_ST_POWER_RESET_WAIT: begin
            op_count_q <= op_count_q + 1'b1;
            if (!native_gttxreset_q && !native_gtrxreset_q &&
                !native_rxbufreset_q && native_txuserrdy_q &&
                native_rxuserrdy_q)
              sym_release_ctrl_q <= 1'b1;
            if (txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                gt_sym_rst_ctrl_q) begin
              if (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES) begin
                gt_ready_o <= 1'b1;
                data_enable_ctrl_q <= 1'b1;
                native_txelecidle_q <= gt_tx_electrical_idle_i;
                gt_power_done_o <= 1'b1;
                ctrl_state_q <= GT_ST_IDLE;
              end else stable_count_q <= stable_count_q + 1'b1;
            end else stable_count_q <= '0;
            if ((op_count_q + 1 >= POWER_TIMEOUT_CYCLES) &&
                !(txresetdone_sync_q[1] && rxresetdone_sync_q[1] &&
                  cplllock_sync_q[1] && gtpowergood_sync_q[1] &&
                  gt_sym_rst_ctrl_q &&
                  (stable_count_q + 1 >= GT_CLOCK_STABLE_CYCLES))) begin
              native_txpd_q <= current_power_q;
              native_rxpd_q <= current_power_q;
              gt_power_fail_o <= 1'b1;
              gt_fault_o <= 1'b1;
              gt_fault_code_o <= ERR_GT_RESET_TIMEOUT;
              ctrl_state_q <= GT_ST_SAFE_FAULT;
            end
          end

          GT_ST_SAFE_FAULT: begin
            gt_ready_o <= 1'b0;
            data_enable_ctrl_q <= 1'b0;
            native_txelecidle_q <= 1'b1;
            native_txdetectrx_q <= 1'b0;
            native_gttxreset_q <= 1'b1;
            native_gtrxreset_q <= 1'b1;
            native_rxbufreset_q <= 1'b1;
            native_txuserrdy_q <= 1'b0;
            native_rxuserrdy_q <= 1'b0;
            sym_release_ctrl_q <= 1'b0;
            if (!gt_detect_req_i && !gt_rate_req_i && !gt_power_req_i) begin
              // Fatal recovery restarts the hard PCS from the mandatory Gen1
              // base rate, matching CRR's RESET_WAIT current-rate contract.
              native_rate_q <= WIZARD_RATE_CODE_GEN1;
              current_rate_q <= 1'b0;
              rate_target_q <= 1'b0;
              native_txpd_q <= PHY_POWER_P0;
              native_rxpd_q <= PHY_POWER_P0;
              current_power_q <= PHY_POWER_P0;
              op_count_q <= '0;
              ctrl_state_q <= GT_ST_RESET_HOLD;
            end
          end

          default: ctrl_state_q <= GT_ST_SAFE_FAULT;
        endcase
      end
    end
  end

  // TODO(Wizard): Copy IBUFDS_GTE4 attributes and reference-clock selection
  // from the final GT Wizard generated wrapper.
  IBUFDS_GTE4 u_pcie_refclk_ibuf (
    .I(pcie_refclk_p_i),
    .IB(pcie_refclk_n_i),
    .CEB(1'b0),
    .O(gt_refclk),
    .ODIV2(gt_refclk_div2)
  );

  // TODO(Wizard): Replace this provisional BUFG_GT topology, including its
  // DIV/CE/CLR values, with the final Wizard user-clock helper.
  BUFG_GT u_gt_sym_clk_buf (
    .I(native_txoutclk),
    .CE(1'b1),
    .CEMASK(1'b0),
    .CLR(1'b0),
    .CLRMASK(1'b0),
    .DIV(3'b000),
    .O(gt_sym_clk_o)
  );

  // TODO(Wizard): Copy the complete GTYE4_CHANNEL attribute set verbatim from
  // the final PCIe Gen1/Gen2, 20-bit internal, hard-8b10b Wizard generation.
  // TODO(Wizard): Freeze CPLL/QPLL selection, refclk/system-clock selectors,
  // OUTCLK selectors, PROGDIV/reset helpers, and unused-port tie-offs from the
  // same generation; no values are inferred here.
  // TODO(Wizard): Freeze CLK_COR_SEQ, comma/alignment, and RX elastic-buffer
  // attributes from the final Wizard generation.
  GTYE4_CHANNEL u_gtye4_channel (
    .GTREFCLK0(gt_refclk),
    .GTYRXP(pcie_rx_p_i),
    .GTYRXN(pcie_rx_n_i),
    .GTYTXP(pcie_tx_p_o),
    .GTYTXN(pcie_tx_n_o),
    .TXDATA(native_txdata),
    .TXCTRL0(native_txctrl0),
    .TXCTRL1(native_txctrl1),
    .TXCTRL2(native_txctrl2),
    .RXDATA(native_rxdata),
    .RXCTRL0(native_rxctrl0),
    .RXCTRL1(native_rxctrl1),
    .RXCTRL2(native_rxctrl2),
    .RXCTRL3(native_rxctrl3),
    .RXDATAVALID(native_rxdatavalid),
    .TX8B10BEN(1'b1),
    .RX8B10BEN(1'b1),
    // TODO(Wizard): Preserve low bits [1:0]=0 and replace unused high bits with
    // the final Wizard-generated TX8B10BBYPASS tie-off.
    .TX8B10BBYPASS(8'h00),
    .RXCOMMADETEN(1'b1),
    .RXPCOMMAALIGNEN(1'b1),
    .RXMCOMMAALIGNEN(1'b1),
    .RXBYTEISALIGNED(native_rxbyteisaligned),
    .RXBYTEREALIGN(native_rxbyterealign),
    .RXCOMMADET(native_rxcommadet),
    .RXCLKCORCNT(native_rxclkcorcnt),
    .RXBUFSTATUS(native_rxbufstatus),
    .TXBUFSTATUS(native_txbufstatus),
    .RXBUFRESET(native_rxbufreset_q),
    .TXELECIDLE(native_ctrl_applied_q.txelecidle),
    .RXELECIDLE(native_rxelecidle),
    .RXCDRLOCK(native_rxcdrlock),
    .RXELECIDLEMODE(WIZARD_RX_EI_MODE),
    .RXLPMEN(WIZARD_RX_LPM_ENABLE),
    .TXDETECTRX(native_ctrl_applied_q.txdetectrx),
    .PHYSTATUS(native_phystatus),
    .RXSTATUS(native_rxstatus),
    .TXPD(native_txpd_q),
    .RXPD(native_rxpd_q),
    .TXRATE(native_ctrl_applied_q.rate),
    .RXRATE(native_ctrl_applied_q.rate),
    .TXRATEMODE(WIZARD_TX_RATE_MODE),
    .RXRATEMODE(WIZARD_RX_RATE_MODE),
    .TXRATEDONE(native_txratedone),
    .RXRATEDONE(native_rxratedone),
    .RXPOLARITY(native_ctrl_applied_q.rxpolarity),
    .TXPOLARITY(WIZARD_TX_POLARITY),
    .TXDEEMPH(native_txdeemph),
    .TXSWING(native_ctrl_applied_q.txswing),
    .TXMARGIN(native_ctrl_applied_q.txmargin),
    .LOOPBACK(native_ctrl_applied_q.loopback),
    .GTTXRESET(native_gttxreset_q),
    .GTRXRESET(native_gtrxreset_q),
    .TXUSERRDY(native_txuserrdy_q),
    .RXUSERRDY(native_rxuserrdy_q),
    .TXRESETDONE(native_txresetdone),
    .RXRESETDONE(native_rxresetdone),
    .GTPOWERGOOD(native_gtpowergood),
    .CPLLLOCK(native_cplllock),
    .TXOUTCLK(native_txoutclk),
    .RXOUTCLK(native_rxoutclk),
    .TXUSRCLK(gt_sym_clk_o),
    .TXUSRCLK2(gt_sym_clk_o),
    .RXUSRCLK(gt_sym_clk_o),
    .RXUSRCLK2(gt_sym_clk_o)
  );

  // gt_compliance_enable_i intentionally has no native GT control mapping:
  // Compliance characters are supplied on TXDATA/TXCTRL2 by the PL scheduler.

`endif

endmodule
