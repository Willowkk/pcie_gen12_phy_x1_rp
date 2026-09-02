`timescale 1ns/1ps
module phy_clocking #(
  parameter time CTRL_HALF_PERIOD = 5ns,
  parameter time LINK_HALF_PERIOD = 2ns,
  parameter time SYM_HALF_PERIOD  = 4ns,
  parameter time REF_HALF_PERIOD  = 5ns
) (
  output logic ctrl_clk_o,
  output logic link_clk_o,
  output logic unit_sym_clk_o,
  output logic refclk_p_o,
  output logic refclk_n_o,
  output logic ctrl_rst_no,
  output logic link_rst_no,
  output logic port_reset_no,
  output logic unit_sym_rst_no
);
  initial begin ctrl_clk_o = 1'b0; forever #CTRL_HALF_PERIOD ctrl_clk_o = ~ctrl_clk_o; end
  initial begin link_clk_o = 1'b0; forever #LINK_HALF_PERIOD link_clk_o = ~link_clk_o; end
  initial begin unit_sym_clk_o = 1'b0; forever #SYM_HALF_PERIOD unit_sym_clk_o = ~unit_sym_clk_o; end
  initial begin
    refclk_p_o = 1'b0;
    refclk_n_o = 1'b1;
    forever #REF_HALF_PERIOD begin
      refclk_p_o = ~refclk_p_o;
      refclk_n_o = ~refclk_n_o;
    end
  end

  initial begin
    ctrl_rst_no = 1'b0;
    link_rst_no = 1'b0;
    port_reset_no = 1'b0;
    unit_sym_rst_no = 1'b0;
  end

  task automatic release_all_resets(input time phase_delay);
    begin
      #phase_delay;
      ctrl_rst_no = 1'b1;
      link_rst_no = 1'b1;
      port_reset_no = 1'b1;
      unit_sym_rst_no = 1'b1;
    end
  endtask

  task automatic pulse_ctrl_reset(input int unsigned cycles, input time phase_delay);
    begin
      #phase_delay; ctrl_rst_no = 1'b0;
      repeat (cycles) @(posedge ctrl_clk_o);
      #1ps ctrl_rst_no = 1'b1;
    end
  endtask

  task automatic pulse_link_reset(input int unsigned cycles, input time phase_delay);
    begin
      #phase_delay; link_rst_no = 1'b0;
      repeat (cycles) @(posedge link_clk_o);
      #1ps link_rst_no = 1'b1;
    end
  endtask

  task automatic pulse_port_reset(input int unsigned cycles, input time phase_delay);
    begin
      #phase_delay; port_reset_no = 1'b0;
      repeat (cycles) @(posedge ctrl_clk_o);
      #1ps port_reset_no = 1'b1;
    end
  endtask
endmodule
