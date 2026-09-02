module phy_symbol_scoreboard (
  input logic clk_i,
  input logic rst_ni,
  input logic expected_valid_i,
  input logic [15:0] expected_data_i,
  input logic [1:0] expected_is_k_i,
  input logic actual_valid_i,
  input logic [15:0] actual_data_i,
  input logic [1:0] actual_is_k_i,
  output logic [31:0] compare_count_o,
  output logic [31:0] mismatch_count_o
);
  timeunit 1ns;
  timeprecision 1ps;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      compare_count_o <= '0;
      mismatch_count_o <= '0;
    end else if (expected_valid_i || actual_valid_i) begin
      compare_count_o <= compare_count_o + 1'b1;
      if ((expected_valid_i !== actual_valid_i) ||
          (expected_data_i !== actual_data_i) ||
          (expected_is_k_i !== actual_is_k_i))
        mismatch_count_o <= mismatch_count_o + 1'b1;
    end
  end
endmodule

module phy_packet_scoreboard (
  input logic clk_i,
  input logic rst_ni,
  input logic expected_valid_i,
  input logic [15:0] expected_data_i,
  input logic [1:0] expected_keep_i,
  input logic expected_sop_i,
  input logic expected_eop_i,
  input logic expected_kind_i,
  input logic expected_abort_i,
  input logic actual_valid_i,
  input logic actual_ready_i,
  input logic [15:0] actual_data_i,
  input logic [1:0] actual_keep_i,
  input logic actual_sop_i,
  input logic actual_eop_i,
  input logic actual_kind_i,
  input logic actual_abort_i,
  output logic [31:0] compare_count_o,
  output logic [31:0] mismatch_count_o
);
  timeunit 1ns;
  timeprecision 1ps;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      compare_count_o <= '0;
      mismatch_count_o <= '0;
    end else if (actual_valid_i && actual_ready_i) begin
      compare_count_o <= compare_count_o + 1'b1;
      if (!expected_valid_i || (expected_data_i !== actual_data_i) ||
          (expected_keep_i !== actual_keep_i) ||
          (expected_sop_i !== actual_sop_i) ||
          (expected_eop_i !== actual_eop_i) ||
          (expected_kind_i !== actual_kind_i) ||
          (expected_abort_i !== actual_abort_i))
        mismatch_count_o <= mismatch_count_o + 1'b1;
    end
  end
endmodule

module phy_elastic_scoreboard #(
  parameter int unsigned DEPTH = 4096
) (
  input logic clk_i,
  input logic rst_ni,
  input logic input_valid_i,
  input logic [7:0] input_data_i,
  input logic input_is_skp_i,
  input logic output_valid_i,
  input logic [7:0] output_data_i,
  input logic output_is_skp_i,
  output logic [31:0] compared_o,
  output logic [31:0] errors_o
);
  timeunit 1ns;
  timeprecision 1ps;

  logic [7:0] expected_q [0:DEPTH-1];
  integer wr_ptr_q, rd_ptr_q, count_q;
  integer error_increment;
  logic push_request, pop_request, push_success, pop_success;
  always_comb begin
    push_request = input_valid_i && !input_is_skp_i;
    pop_request = output_valid_i && !output_is_skp_i;
    push_success = push_request && (count_q < DEPTH);
    pop_success = pop_request && (count_q > 0);
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      wr_ptr_q <= 0; rd_ptr_q <= 0; count_q <= 0;
      compared_o <= 0; errors_o <= 0;
    end else begin
      error_increment = 0;
      if (push_request) begin
        if (push_success) begin
          expected_q[wr_ptr_q] <= input_data_i;
          wr_ptr_q <= (wr_ptr_q + 1) % DEPTH;
        end else error_increment = error_increment + 1;
      end
      if (pop_request) begin
        compared_o <= compared_o + 1'b1;
        if (!pop_success || (expected_q[rd_ptr_q] !== output_data_i))
          error_increment = error_increment + 1;
        if (pop_success) begin
          rd_ptr_q <= (rd_ptr_q + 1) % DEPTH;
        end
      end
      unique case ({push_success, pop_success})
        2'b10: count_q <= count_q + 1;
        2'b01: count_q <= count_q - 1;
        default: count_q <= count_q;
      endcase
      if (error_increment != 0)
        errors_o <= errors_o + error_increment;
    end
  end
endmodule
