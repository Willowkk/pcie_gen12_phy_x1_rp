module phy_watchdog #(
  parameter int unsigned MAX_CTRL_CYCLES = 100000,
  parameter string TEST_ID = "UNNAMED"
) (
  input logic ctrl_clk_i,
  input logic ctrl_rst_ni,
  input logic done_i
);
  timeunit 1ns;
  timeprecision 1ps;

  int unsigned cycles_q;
  always_ff @(posedge ctrl_clk_i or negedge ctrl_rst_ni) begin
    if (!ctrl_rst_ni || done_i)
      cycles_q <= 0;
    else if (cycles_q + 1 >= MAX_CTRL_CYCLES)
      $fatal(1, "[TB_WATCHDOG] %s exceeded %0d ctrl cycles", TEST_ID,
             MAX_CTRL_CYCLES);
    else
      cycles_q <= cycles_q + 1;
  end
endmodule
