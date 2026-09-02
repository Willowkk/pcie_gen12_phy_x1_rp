module phy_timer_bank (
  input  logic        ctrl_clk_i,
  input  logic        ctrl_rst_ni,
  input  logic        port_reset_ni,
  input  logic        timer_start_i,
  input  logic        timer_stop_i,
  input  logic [5:0]  timer_id_i,
  input  logic [31:0] timer_limit_i,
  input  logic        retry_update_i,
  input  logic        retry_clear_i,
  output logic        timer_expired_o,
  output logic [5:0]  timer_id_o,
  output logic [7:0]  retry_count_o,
  output logic        timer_active_o,
  output logic [31:0] timer_count_o
);

  timeunit 1ns;
  timeprecision 1ps;

  import pcie_gen12_phy_pkg::*;
  import pcie_gen12_phy_timing_pkg::*;

  wire ctrl_local_reset_ani = ctrl_rst_ni & port_reset_ni;

  logic [31:0] selected_limit;
  pcie_retry_action_t retry_action;

  always_comb begin
    if (timer_limit_i != 0) begin
      selected_limit = timer_limit_i;
    end else begin
      selected_limit = timer_default_cycles(pcie_timer_id_t'(timer_id_i), SIM_TIME_SCALE);
    end
    if (selected_limit == 0) selected_limit = 1;

    retry_action = RETRY_HOLD;
    if (retry_clear_i) begin
      retry_action = RETRY_CLEAR;
    end else if (retry_update_i) begin
      retry_action = RETRY_INCREMENT;
    end
  end

  always_ff @(posedge ctrl_clk_i or negedge ctrl_local_reset_ani) begin
    if (!ctrl_local_reset_ani) begin
      timer_active_o  <= 1'b0;
      timer_count_o   <= '0;
      timer_expired_o <= 1'b0;
      timer_id_o      <= TIMER_NONE;
      retry_count_o   <= '0;
    end else begin
      timer_expired_o <= 1'b0;

      // Starting a replacement timer has priority over stopping the old one.
      // The counter expires after exactly selected_limit active ctrl clocks.
      if (timer_start_i) begin
        timer_active_o <= 1'b1;
        timer_count_o  <= selected_limit;
        timer_id_o     <= timer_id_i;
      end else if (timer_stop_i) begin
        timer_active_o <= 1'b0;
        timer_count_o  <= '0;
        timer_id_o     <= TIMER_NONE;
      end else if (timer_active_o) begin
        if (timer_count_o <= 1) begin
          timer_active_o  <= 1'b0;
          timer_count_o   <= '0;
          timer_expired_o <= 1'b1;
        end else begin
          timer_count_o <= timer_count_o - 1'b1;
        end
      end

      unique case (retry_action)
        RETRY_CLEAR: retry_count_o <= '0;
        RETRY_INCREMENT: begin
          if (retry_count_o != 8'hff) retry_count_o <= retry_count_o + 1'b1;
        end
        default: ;
      endcase
    end
  end

endmodule
