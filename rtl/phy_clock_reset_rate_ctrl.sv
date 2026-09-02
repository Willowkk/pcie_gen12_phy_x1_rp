module phy_clock_reset_rate_ctrl #(
  parameter int unsigned SIM_TIME_SCALE =
      pcie_gen12_phy_timing_pkg::SIM_TIME_SCALE
) (
  input  logic        ctrl_clk_i,
  input  logic        ctrl_rst_ni,
  input  logic        port_reset_ni,
  input  logic        pcie_refclk_p_i,
  input  logic        pcie_refclk_n_i,
  input  logic        gt_sym_clk_i,
  input  logic        gt_sym_rst_ni,
  input  logic        gt_sym_clk_stable_i,
  input  logic        gt_buffer_reinit_done_i,
  output logic        phy_sym_clk_o,
  output logic        phy_sym_rst_no,
  output logic        crr_ready_o,
  output logic        crr_current_rate_o,
  input  logic        lt_gt_detect_req_i,
  input  logic        lt_gt_rate_req_i,
  input  logic        lt_gt_rate_target_gen2_i,
  input  logic        lt_gt_power_req_i,
  input  logic [1:0]  lt_gt_power_state_i,
  input  logic        lt_gt_tx_electrical_idle_i,
  input  logic        lt_gt_rx_polarity_invert_i,
  input  logic        lt_gt_tx_deemphasis_i,
  input  logic        lt_gt_tx_swing_i,
  input  logic [2:0]  lt_gt_tx_margin_i,
  input  logic        lt_gt_compliance_enable_i,
  input  logic [2:0]  lt_gt_loopback_mode_i,
  output logic        crr_detect_done_o,
  output logic        crr_receiver_present_o,
  output logic        crr_rate_done_o,
  output logic        crr_rate_fail_o,
  output logic        crr_power_done_o,
  output logic        crr_power_fail_o,
  output logic        crr_tx_electrical_idle_active_o,
  output logic        crr_rx_electrical_idle_o,
  output logic        crr_rx_aligned_o,
  output logic        crr_fault_o,
  output logic [7:0]  crr_fault_code_o,
  input  logic        gt_detect_busy_i,
  input  logic        gt_detect_done_i,
  input  logic        gt_receiver_present_i,
  input  logic        gt_rate_busy_i,
  input  logic        gt_rate_done_i,
  input  logic        gt_rate_fail_i,
  input  logic        gt_tx_electrical_idle_active_i,
  input  logic        gt_rx_electrical_idle_i,
  input  logic        gt_power_busy_i,
  input  logic        gt_power_done_i,
  input  logic        gt_power_fail_i,
  input  logic        gt_ready_i,
  input  logic        gt_fault_i,
  input  logic [7:0]  gt_fault_code_i,
  input  logic        rx_byte_aligned_i,
  input  logic        tx_quiesced_i,
  input  logic        rx_packet_active_i,
  output logic        gt_detect_req_o,
  output logic        gt_rate_req_o,
  output logic        gt_rate_target_gen2_o,
  output logic        gt_tx_electrical_idle_o,
  output logic        gt_power_req_o,
  output logic [1:0]  gt_power_state_o,
  output logic        gt_rx_polarity_invert_o,
  output logic        gt_tx_deemphasis_o,
  output logic        gt_tx_swing_o,
  output logic [2:0]  gt_tx_margin_o,
  output logic        gt_compliance_enable_o,
  output logic [2:0]  gt_loopback_mode_o,
  output logic        sym_path_reset_o,
  output logic        packet_admission_enable_o,
  output logic        packet_buffer_flush_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

  typedef enum logic [4:0] {
    CRR_RESET_WAIT,
    CRR_RESET_RELEASE,
    CRR_IDLE,
    CRR_DETECT_ISSUE,
    CRR_DETECT_WAIT,
    CRR_RATE_QUIESCE,
    CRR_RATE_EIDLE,
    CRR_RATE_ISSUE,
    CRR_RATE_WAIT,
    CRR_RATE_STABILIZE,
    CRR_RATE_RELEASE,
    CRR_POWER_QUIESCE,
    CRR_POWER_EIDLE,
    CRR_POWER_ISSUE,
    CRR_POWER_WAIT,
    CRR_POWER_STABILIZE,
    CRR_POWER_RELEASE
  } crr_state_t;

  localparam logic [31:0] RESET_TIMEOUT_CYCLES  = timer_default_cycles(TIMER_GT_RESET,  SIM_TIME_SCALE);
  localparam logic [31:0] DETECT_TIMEOUT_CYCLES = timer_default_cycles(TIMER_GT_DETECT, SIM_TIME_SCALE);
  localparam logic [31:0] RATE_TIMEOUT_CYCLES   = timer_default_cycles(TIMER_GT_RATE,   SIM_TIME_SCALE);
  localparam logic [31:0] POWER_TIMEOUT_CYCLES  = timer_default_cycles(TIMER_GT_POWER,  SIM_TIME_SCALE);

  wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;
  wire sym_release_ani      = ctrl_rst_ni & port_reset_ni & gt_sym_rst_ni & ~sym_path_reset_o;

  crr_state_t crr_state_q;
  logic [31:0] operation_timer_q;
  logic [31:0] clock_stable_count_q;
  logic [31:0] rx_ei_filter_count_q;
  logic [31:0] rx_align_filter_count_q;
  logic [2:0]  sym_reset_release_q;
  logic [1:0]  phy_sym_rst_ctrl_sync_q;
  logic         reset_timeout_reported_q;
  logic         gt_fault_reported_q;
  logic         detect_armed_q;
  logic         rate_armed_q;
  logic         power_armed_q;
  logic         rate_target_q;
  logic [1:0]   power_target_q;
  logic [1:0]   current_power_q;
  logic         mode_tx_electrical_idle_q;
  logic         mode_rx_polarity_q;
  logic         mode_tx_deemphasis_q;
  logic         mode_tx_swing_q;
  logic [2:0]   mode_tx_margin_q;
  logic         mode_compliance_q;
  logic [2:0]   mode_loopback_q;
  logic         refclk_observation_q;

  assign phy_sym_clk_o = gt_sym_clk_i;
  assign gt_detect_req_o = (crr_state_q == CRR_DETECT_ISSUE);
  assign gt_rate_req_o   = (crr_state_q == CRR_RATE_ISSUE);
  assign gt_power_req_o  = (crr_state_q == CRR_POWER_ISSUE);
  assign gt_rate_target_gen2_o   = rate_target_q;
  assign gt_power_state_o        = power_target_q;
  assign gt_rx_polarity_invert_o = mode_rx_polarity_q;
  assign gt_tx_deemphasis_o      = mode_tx_deemphasis_q;
  assign gt_tx_swing_o           = mode_tx_swing_q;
  assign gt_tx_margin_o          = mode_tx_margin_q;
  assign gt_compliance_enable_o  = mode_compliance_q;
  assign gt_loopback_mode_o      = mode_loopback_q;

  always_comb begin
    gt_tx_electrical_idle_o = mode_tx_electrical_idle_q;
    unique case (crr_state_q)
      CRR_RESET_WAIT, CRR_RESET_RELEASE,
      CRR_DETECT_ISSUE, CRR_DETECT_WAIT,
      CRR_RATE_QUIESCE, CRR_RATE_EIDLE, CRR_RATE_ISSUE,
      CRR_RATE_WAIT, CRR_RATE_STABILIZE, CRR_RATE_RELEASE,
      CRR_POWER_EIDLE, CRR_POWER_ISSUE, CRR_POWER_WAIT,
      CRR_POWER_STABILIZE, CRR_POWER_RELEASE:
        gt_tx_electrical_idle_o = 1'b1;
      default: ;
    endcase
  end

  // Asynchronous assertion, synchronous release in the adapter-owned clock.
  always_ff @(posedge gt_sym_clk_i or negedge sym_release_ani) begin
    if (!sym_release_ani) begin
      sym_reset_release_q <= '0;
      phy_sym_rst_no      <= 1'b0;
    end else begin
      sym_reset_release_q <= {sym_reset_release_q[1:0], 1'b1};
      phy_sym_rst_no      <= &sym_reset_release_q;
    end
  end

  // Acknowledges in ctrl_clk that the variable-rate clock is running and its
  // local reset has actually completed synchronous release.
  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani) begin
    if (!ctrl_local_reset_ani) begin
      phy_sym_rst_ctrl_sync_q <= '0;
    end else begin
      phy_sym_rst_ctrl_sync_q <= {phy_sym_rst_ctrl_sync_q[0], phy_sym_rst_no};
    end
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani) begin
    if (!ctrl_local_reset_ani) begin
      crr_state_q                     <= CRR_RESET_WAIT;
      operation_timer_q               <= RESET_TIMEOUT_CYCLES;
      clock_stable_count_q            <= '0;
      rx_ei_filter_count_q            <= '0;
      rx_align_filter_count_q         <= '0;
      reset_timeout_reported_q        <= 1'b0;
      gt_fault_reported_q             <= 1'b0;
      detect_armed_q                  <= 1'b1;
      rate_armed_q                    <= 1'b1;
      power_armed_q                   <= 1'b1;
      rate_target_q                   <= 1'b0;
      power_target_q                  <= PHY_POWER_P0;
      current_power_q                 <= PHY_POWER_P0;
      crr_current_rate_o              <= 1'b0;
      mode_tx_electrical_idle_q       <= 1'b1;
      mode_rx_polarity_q              <= 1'b0;
      mode_tx_deemphasis_q            <= 1'b0;
      mode_tx_swing_q                 <= 1'b0;
      mode_tx_margin_q                <= '0;
      mode_compliance_q               <= 1'b0;
      mode_loopback_q                 <= '0;
      refclk_observation_q            <= 1'b0;
      sym_path_reset_o                <= 1'b1;
      packet_buffer_flush_o           <= 1'b1;
      packet_admission_enable_o       <= 1'b0;
      crr_ready_o                     <= 1'b0;
      crr_detect_done_o               <= 1'b0;
      crr_receiver_present_o          <= 1'b0;
      crr_rate_done_o                 <= 1'b0;
      crr_rate_fail_o                 <= 1'b0;
      crr_power_done_o                <= 1'b0;
      crr_power_fail_o                <= 1'b0;
      crr_tx_electrical_idle_active_o <= 1'b1;
      crr_rx_electrical_idle_o        <= 1'b1;
      crr_rx_aligned_o                <= 1'b0;
      crr_fault_o                     <= 1'b0;
      crr_fault_code_o                <= ERR_NONE;
    end else begin
      crr_detect_done_o     <= 1'b0;
      crr_rate_done_o       <= 1'b0;
      crr_rate_fail_o       <= 1'b0;
      crr_power_done_o      <= 1'b0;
      crr_power_fail_o      <= 1'b0;
      crr_fault_o           <= 1'b0;
      packet_buffer_flush_o <= 1'b0;
      refclk_observation_q  <= pcie_refclk_p_i ^ pcie_refclk_n_i;
      crr_tx_electrical_idle_active_o <= gt_tx_electrical_idle_active_i;

      if (!lt_gt_detect_req_i) detect_armed_q <= 1'b1;
      if (!lt_gt_rate_req_i)   rate_armed_q   <= 1'b1;
      if (!lt_gt_power_req_i)  power_armed_q  <= 1'b1;
      if (operation_timer_q != 0) operation_timer_q <= operation_timer_q - 1'b1;

      if (gt_rx_electrical_idle_i == crr_rx_electrical_idle_o) begin
        rx_ei_filter_count_q <= '0;
      end else if (rx_ei_filter_count_q != 32'hffff_ffff) begin
        rx_ei_filter_count_q <= rx_ei_filter_count_q + 1'b1;
        if (gt_rx_electrical_idle_i &&
            (rx_ei_filter_count_q + 1'b1 >= RX_EI_ASSERT_STABLE_CYCLES)) begin
          crr_rx_electrical_idle_o <= 1'b1;
          crr_rx_aligned_o         <= 1'b0;
          rx_ei_filter_count_q     <= '0;
        end else if (!gt_rx_electrical_idle_i &&
                     (rx_ei_filter_count_q + 1'b1 >= RX_EI_DEASSERT_STABLE_CYCLES)) begin
          crr_rx_electrical_idle_o <= 1'b0;
          rx_ei_filter_count_q     <= '0;
        end
      end

      if (crr_rx_electrical_idle_o || !rx_byte_aligned_i || sym_path_reset_o) begin
        rx_align_filter_count_q <= '0;
        crr_rx_aligned_o        <= 1'b0;
      end else if (!crr_rx_aligned_o) begin
        if (rx_align_filter_count_q != 32'hffff_ffff)
          rx_align_filter_count_q <= rx_align_filter_count_q + 1'b1;
        if (rx_align_filter_count_q + 1'b1 >= RX_ALIGNMENT_STABLE_CYCLES) begin
          crr_rx_aligned_o        <= 1'b1;
          rx_align_filter_count_q <= '0;
        end
      end

      // Fatal GT/clock recovery preempts Rate, Detect and Power.
      if (gt_fault_i) begin
        if (!gt_fault_reported_q) begin
          crr_fault_o         <= 1'b1;
          crr_fault_code_o    <= (gt_fault_code_i == ERR_NONE) ? ERR_GT_PLL_UNLOCK : gt_fault_code_i;
          gt_fault_reported_q <= 1'b1;
        end
        if (crr_state_q inside {CRR_RATE_QUIESCE, CRR_RATE_EIDLE, CRR_RATE_ISSUE,
                                CRR_RATE_WAIT, CRR_RATE_STABILIZE, CRR_RATE_RELEASE})
          crr_rate_fail_o <= 1'b1;
        if (crr_state_q inside {CRR_POWER_QUIESCE, CRR_POWER_EIDLE, CRR_POWER_ISSUE,
                                CRR_POWER_WAIT, CRR_POWER_STABILIZE, CRR_POWER_RELEASE})
          crr_power_fail_o <= 1'b1;
        if (crr_state_q inside {CRR_DETECT_ISSUE, CRR_DETECT_WAIT}) begin
          crr_detect_done_o       <= 1'b1;
          crr_receiver_present_o  <= 1'b0;
        end
        crr_state_q                  <= CRR_RESET_WAIT;
        operation_timer_q            <= RESET_TIMEOUT_CYCLES;
        clock_stable_count_q         <= '0;
        reset_timeout_reported_q     <= 1'b0;
        crr_ready_o                  <= 1'b0;
        sym_path_reset_o             <= 1'b1;
        packet_admission_enable_o    <= 1'b0;
        packet_buffer_flush_o        <= 1'b1;
      end else begin
        gt_fault_reported_q <= 1'b0;
        unique case (crr_state_q)
          CRR_RESET_WAIT: begin
            crr_ready_o               <= 1'b0;
            sym_path_reset_o          <= 1'b1;
            packet_admission_enable_o <= 1'b0;
            mode_tx_electrical_idle_q <= 1'b1;
            current_power_q           <= PHY_POWER_P0;
            crr_current_rate_o        <= 1'b0;
            if (gt_ready_i && gt_sym_clk_stable_i && gt_sym_rst_ni &&
                gt_buffer_reinit_done_i) begin
              if (clock_stable_count_q + 1'b1 >= GT_CLOCK_STABLE_CYCLES) begin
                clock_stable_count_q <= '0;
                sym_path_reset_o     <= 1'b0;
                crr_state_q          <= CRR_RESET_RELEASE;
              end else begin
                clock_stable_count_q <= clock_stable_count_q + 1'b1;
              end
            end else begin
              clock_stable_count_q <= '0;
            end
            if ((operation_timer_q == 0) && !reset_timeout_reported_q) begin
              crr_fault_o              <= 1'b1;
              crr_fault_code_o         <= ERR_GT_RESET_TIMEOUT;
              reset_timeout_reported_q <= 1'b1;
            end
          end

          CRR_RESET_RELEASE: begin
            crr_ready_o               <= 1'b0;
            packet_admission_enable_o <= 1'b0;
            if (!gt_ready_i || !gt_sym_clk_stable_i || !gt_sym_rst_ni) begin
              crr_state_q          <= CRR_RESET_WAIT;
              operation_timer_q    <= RESET_TIMEOUT_CYCLES;
              sym_path_reset_o     <= 1'b1;
              clock_stable_count_q <= '0;
            end else if (phy_sym_rst_ctrl_sync_q[1]) begin
              crr_ready_o               <= 1'b1;
              packet_admission_enable_o <= 1'b1;
              reset_timeout_reported_q  <= 1'b0;
              crr_state_q               <= CRR_IDLE;
            end
          end

          CRR_IDLE: begin
            crr_ready_o <= gt_ready_i && gt_sym_clk_stable_i && gt_sym_rst_ni &&
                           phy_sym_rst_ctrl_sync_q[1] && !sym_path_reset_o;
            packet_admission_enable_o <= crr_ready_o && (current_power_q == PHY_POWER_P0);
            mode_tx_electrical_idle_q <= lt_gt_tx_electrical_idle_i;
            mode_rx_polarity_q        <= lt_gt_rx_polarity_invert_i;
            mode_tx_deemphasis_q      <= lt_gt_tx_deemphasis_i;
            mode_tx_swing_q           <= lt_gt_tx_swing_i;
            mode_tx_margin_q          <= lt_gt_tx_margin_i;
            mode_compliance_q         <= lt_gt_compliance_enable_i;
            mode_loopback_q           <= lt_gt_loopback_mode_i;
            // Native operation priority: Rate > Detect > Power.
            if (lt_gt_rate_req_i && rate_armed_q && (current_power_q == PHY_POWER_P0)) begin
              rate_armed_q              <= 1'b0;
              rate_target_q             <= lt_gt_rate_target_gen2_i;
              packet_admission_enable_o <= 1'b0;
              operation_timer_q         <= RATE_TIMEOUT_CYCLES;
              crr_state_q               <= CRR_RATE_QUIESCE;
            end else if (lt_gt_detect_req_i && detect_armed_q && crr_ready_o &&
                         (current_power_q == PHY_POWER_P0)) begin
              detect_armed_q            <= 1'b0;
              packet_admission_enable_o <= 1'b0;
              mode_tx_electrical_idle_q <= 1'b1;
              operation_timer_q         <= DETECT_TIMEOUT_CYCLES;
              crr_state_q               <= CRR_DETECT_ISSUE;
            end else if (lt_gt_power_req_i && power_armed_q) begin
              power_armed_q      <= 1'b0;
              power_target_q     <= lt_gt_power_state_i;
              operation_timer_q  <= POWER_TIMEOUT_CYCLES;
              packet_admission_enable_o <= 1'b0;
              if (lt_gt_power_state_i == PHY_POWER_P0) begin
                sym_path_reset_o <= 1'b1;
                crr_ready_o      <= 1'b0;
                crr_state_q      <= CRR_POWER_ISSUE;
              end else begin
                crr_state_q <= CRR_POWER_QUIESCE;
              end
            end else if ((current_power_q == PHY_POWER_P0) &&
                         (!gt_ready_i || !gt_sym_clk_stable_i || !gt_sym_rst_ni)) begin
              crr_fault_o               <= 1'b1;
              crr_fault_code_o          <= ERR_GT_PLL_UNLOCK;
              crr_state_q               <= CRR_RESET_WAIT;
              operation_timer_q         <= RESET_TIMEOUT_CYCLES;
              reset_timeout_reported_q  <= 1'b0;
              sym_path_reset_o          <= 1'b1;
              packet_buffer_flush_o     <= 1'b1;
              packet_admission_enable_o <= 1'b0;
              crr_ready_o               <= 1'b0;
            end
          end

          CRR_DETECT_ISSUE: begin
            // Receiver Detect temporarily resets/stops the GT user path; the
            // public ready contract must therefore fall for the whole bounded
            // native transaction, even though the control clock keeps running.
            crr_ready_o               <= 1'b0;
            packet_admission_enable_o <= 1'b0;
            if (gt_detect_done_i) begin
              crr_detect_done_o      <= 1'b1;
              crr_receiver_present_o <= gt_receiver_present_i;
              crr_state_q            <= CRR_IDLE;
            end else if (gt_detect_busy_i) begin
              crr_state_q <= CRR_DETECT_WAIT;
            end else if (operation_timer_q == 0) begin
              crr_detect_done_o      <= 1'b1;
              crr_receiver_present_o <= 1'b0;
              crr_fault_o            <= 1'b1;
              crr_fault_code_o       <= ERR_DETECT_TIMEOUT;
              crr_state_q            <= CRR_IDLE;
            end
          end

          CRR_DETECT_WAIT: begin
            crr_ready_o               <= 1'b0;
            packet_admission_enable_o <= 1'b0;
            if (gt_detect_done_i) begin
              crr_detect_done_o      <= 1'b1;
              crr_receiver_present_o <= gt_receiver_present_i;
              crr_state_q            <= CRR_IDLE;
            end else if (operation_timer_q == 0) begin
              crr_detect_done_o      <= 1'b1;
              crr_receiver_present_o <= 1'b0;
              crr_fault_o            <= 1'b1;
              crr_fault_code_o       <= ERR_DETECT_TIMEOUT;
              crr_state_q            <= CRR_IDLE;
            end
          end

          CRR_RATE_QUIESCE: begin
            crr_ready_o               <= 1'b0;
            packet_admission_enable_o <= 1'b0;
            if (tx_quiesced_i && !rx_packet_active_i) begin
              packet_buffer_flush_o     <= 1'b1;
              mode_tx_electrical_idle_q <= 1'b1;
              crr_state_q               <= CRR_RATE_EIDLE;
            end else if (operation_timer_q == 0) begin
              crr_rate_fail_o  <= 1'b1;
              crr_fault_o      <= 1'b1;
              crr_fault_code_o <= ERR_RATE_NOT_QUIESCED;
              crr_state_q      <= CRR_IDLE;
            end
          end

          CRR_RATE_EIDLE: begin
            crr_ready_o               <= 1'b0;
            packet_admission_enable_o <= 1'b0;
            if (gt_tx_electrical_idle_active_i) begin
              sym_path_reset_o <= 1'b1;
              crr_state_q      <= CRR_RATE_ISSUE;
            end else if (operation_timer_q == 0) begin
              crr_rate_fail_o  <= 1'b1;
              crr_fault_o      <= 1'b1;
              crr_fault_code_o <= ERR_RATE_CHANGE;
              crr_state_q      <= CRR_IDLE;
            end
          end

          CRR_RATE_ISSUE: begin
            if (gt_rate_done_i) begin
              clock_stable_count_q <= '0;
              crr_state_q          <= CRR_RATE_STABILIZE;
            end else if (gt_rate_fail_i || (operation_timer_q == 0)) begin
              crr_rate_fail_o   <= 1'b1;
              crr_fault_o       <= 1'b1;
              crr_fault_code_o  <= ERR_RATE_CHANGE;
              crr_state_q       <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end else if (gt_rate_busy_i) begin
              crr_state_q <= CRR_RATE_WAIT;
            end
          end

          CRR_RATE_WAIT: begin
            if (gt_rate_done_i) begin
              clock_stable_count_q <= '0;
              crr_state_q          <= CRR_RATE_STABILIZE;
            end else if (gt_rate_fail_i || (operation_timer_q == 0)) begin
              crr_rate_fail_o   <= 1'b1;
              crr_fault_o       <= 1'b1;
              crr_fault_code_o  <= ERR_RATE_CHANGE;
              crr_state_q       <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end
          end

          CRR_RATE_STABILIZE: begin
            if (gt_ready_i && gt_sym_clk_stable_i && gt_sym_rst_ni && gt_buffer_reinit_done_i) begin
              if (clock_stable_count_q + 1'b1 >= GT_CLOCK_STABLE_CYCLES) begin
                clock_stable_count_q <= '0;
                sym_path_reset_o     <= 1'b0;
                crr_state_q          <= CRR_RATE_RELEASE;
              end else begin
                clock_stable_count_q <= clock_stable_count_q + 1'b1;
              end
            end else begin
              clock_stable_count_q <= '0;
            end
            if (operation_timer_q == 0) begin
              crr_rate_fail_o   <= 1'b1;
              crr_fault_o       <= 1'b1;
              crr_fault_code_o  <= ERR_RATE_CHANGE;
              crr_state_q       <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end
          end

          CRR_RATE_RELEASE: begin
            if (phy_sym_rst_ctrl_sync_q[1] && gt_ready_i && gt_buffer_reinit_done_i) begin
              crr_current_rate_o         <= rate_target_q;
              crr_rate_done_o            <= 1'b1;
              crr_ready_o                <= 1'b1;
              packet_admission_enable_o  <= 1'b1;
              crr_state_q                <= CRR_IDLE;
            end else if (operation_timer_q == 0) begin
              crr_rate_fail_o   <= 1'b1;
              crr_fault_o       <= 1'b1;
              crr_fault_code_o  <= ERR_RATE_CHANGE;
              crr_state_q       <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end
          end

          CRR_POWER_QUIESCE: begin
            crr_ready_o               <= 1'b0;
            packet_admission_enable_o <= 1'b0;
            if (tx_quiesced_i && !rx_packet_active_i) begin
              packet_buffer_flush_o     <= 1'b1;
              mode_tx_electrical_idle_q <= 1'b1;
              crr_state_q <= (power_target_q == PHY_POWER_P0S) ? CRR_POWER_ISSUE : CRR_POWER_EIDLE;
            end else if (operation_timer_q == 0) begin
              crr_power_fail_o <= 1'b1;
              crr_fault_o      <= 1'b1;
              crr_fault_code_o <= ERR_LTSSM_TIMEOUT;
              crr_state_q      <= CRR_IDLE;
            end
          end

          CRR_POWER_EIDLE: begin
            if (gt_tx_electrical_idle_active_i) begin
              sym_path_reset_o <= 1'b1;
              crr_state_q      <= CRR_POWER_ISSUE;
            end else if (operation_timer_q == 0) begin
              crr_power_fail_o <= 1'b1;
              crr_fault_o      <= 1'b1;
              crr_fault_code_o <= ERR_LTSSM_TIMEOUT;
              crr_state_q      <= CRR_IDLE;
            end
          end

          CRR_POWER_ISSUE: begin
            if (gt_power_done_i) begin
              current_power_q <= power_target_q;
              if (power_target_q == PHY_POWER_P0) begin
                clock_stable_count_q <= '0;
                crr_state_q          <= CRR_POWER_STABILIZE;
              end else begin
                crr_power_done_o <= 1'b1;
                crr_state_q      <= CRR_IDLE;
              end
            end else if (gt_power_fail_i || (operation_timer_q == 0)) begin
              crr_power_fail_o <= 1'b1;
              crr_fault_o      <= 1'b1;
              crr_fault_code_o <= ERR_GT_RESET_TIMEOUT;
              crr_state_q      <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end else if (gt_power_busy_i) begin
              crr_state_q <= CRR_POWER_WAIT;
            end
          end

          CRR_POWER_WAIT: begin
            if (gt_power_done_i) begin
              current_power_q <= power_target_q;
              if (power_target_q == PHY_POWER_P0) begin
                clock_stable_count_q <= '0;
                crr_state_q          <= CRR_POWER_STABILIZE;
              end else begin
                crr_power_done_o <= 1'b1;
                crr_state_q      <= CRR_IDLE;
              end
            end else if (gt_power_fail_i || (operation_timer_q == 0)) begin
              crr_power_fail_o  <= 1'b1;
              crr_fault_o       <= 1'b1;
              crr_fault_code_o  <= ERR_GT_RESET_TIMEOUT;
              crr_state_q       <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end
          end

          CRR_POWER_STABILIZE: begin
            if (gt_ready_i && gt_sym_clk_stable_i && gt_sym_rst_ni && gt_buffer_reinit_done_i) begin
              if (clock_stable_count_q + 1'b1 >= GT_CLOCK_STABLE_CYCLES) begin
                clock_stable_count_q <= '0;
                sym_path_reset_o     <= 1'b0;
                crr_state_q          <= CRR_POWER_RELEASE;
              end else begin
                clock_stable_count_q <= clock_stable_count_q + 1'b1;
              end
            end else begin
              clock_stable_count_q <= '0;
            end
            if (operation_timer_q == 0) begin
              crr_power_fail_o  <= 1'b1;
              crr_fault_o       <= 1'b1;
              crr_fault_code_o  <= ERR_GT_RESET_TIMEOUT;
              crr_state_q       <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end
          end

          CRR_POWER_RELEASE: begin
            if (phy_sym_rst_ctrl_sync_q[1] && gt_ready_i && gt_buffer_reinit_done_i) begin
              crr_power_done_o              <= 1'b1;
              crr_ready_o                   <= 1'b1;
              packet_admission_enable_o     <= 1'b1;
              crr_state_q                   <= CRR_IDLE;
            end else if (operation_timer_q == 0) begin
              crr_power_fail_o  <= 1'b1;
              crr_fault_o       <= 1'b1;
              crr_fault_code_o  <= ERR_GT_RESET_TIMEOUT;
              crr_state_q       <= CRR_RESET_WAIT;
              operation_timer_q <= RESET_TIMEOUT_CYCLES;
            end
          end

          default: begin
            crr_state_q                  <= CRR_RESET_WAIT;
            operation_timer_q            <= RESET_TIMEOUT_CYCLES;
            sym_path_reset_o             <= 1'b1;
            packet_admission_enable_o    <= 1'b0;
            packet_buffer_flush_o        <= 1'b1;
            crr_ready_o                  <= 1'b0;
          end
        endcase
      end
    end
  end

endmodule
