`timescale 1ns/1ps
module phy_top_harness;
  import pcie_gen12_phy_pkg::*;

  logic ctrl_clk, link_clk, unit_sym_clk, refclk_p, refclk_n;
  logic ctrl_rst_n, link_rst_n, port_reset_n, unit_sym_rst_n;
  logic pcie_rx_p, pcie_rx_n, pcie_tx_p, pcie_tx_n;
  logic phy_sym_clk, phy_sym_rst_n;
  logic phy_dll_link_up, phy_dll_data_active, phy_dll_current_rate;
  logic phy_dll_link_down_evt;
  logic dll_tx_valid, dll_tx_ready;
  logic [15:0] dll_tx_data;
  logic [1:0] dll_tx_keep;
  logic dll_tx_sop, dll_tx_eop, dll_tx_kind, dll_tx_abort;
  logic dll_rx_valid, dll_rx_ready;
  logic [15:0] dll_rx_data;
  logic [1:0] dll_rx_keep;
  logic dll_rx_sop, dll_rx_eop, dll_rx_kind, dll_rx_abort;
  logic mgmt_cmd_valid, mgmt_cmd_ready;
  logic [3:0] mgmt_cmd_opcode;
  logic [7:0] mgmt_cmd_arg;
  logic mgmt_rsp_valid, mgmt_rsp_ready;
  logic [3:0] mgmt_rsp_status;
  logic pm_req_valid, pm_req_ready, pm_req_exit, pm_done, pm_fail, pm_rsp_ready;
  logic [1:0] pm_req_state;
  logic phy_ready, phy_link_up, phy_data_active, phy_current_rate, phy_rx_locked;
  logic [5:0] phy_state, phy_substate;
  logic [7:0] phy_reason;
  logic phy_err_valid, phy_err_ready;
  logic [7:0] phy_err_code;
  logic [31:0] phy_err_info;
  logic csr_req_valid, csr_req_ready, csr_req_write;
  logic [11:0] csr_req_addr;
  logic [31:0] csr_req_wdata, csr_rsp_rdata;
  logic [3:0] csr_req_wstrb;
  logic csr_rsp_valid, csr_rsp_ready, csr_rsp_error;

  phy_clocking clocks (
    .ctrl_clk_o(ctrl_clk), .link_clk_o(link_clk),
    .unit_sym_clk_o(unit_sym_clk), .refclk_p_o(refclk_p),
    .refclk_n_o(refclk_n), .ctrl_rst_no(ctrl_rst_n),
    .link_rst_no(link_rst_n), .port_reset_no(port_reset_n),
    .unit_sym_rst_no(unit_sym_rst_n)
  );

  pcie_gen12_phy_x1_rp dut (
    .ctrl_clk_i(ctrl_clk), .ctrl_rst_ni(ctrl_rst_n),
    .link_clk_i(link_clk), .link_rst_ni(link_rst_n),
    .port_reset_ni(port_reset_n), .pcie_refclk_p_i(refclk_p),
    .pcie_refclk_n_i(refclk_n), .pcie_rx_p_i(pcie_rx_p),
    .pcie_rx_n_i(pcie_rx_n), .pcie_tx_p_o(pcie_tx_p),
    .pcie_tx_n_o(pcie_tx_n), .phy_sym_clk_o(phy_sym_clk),
    .phy_sym_rst_no(phy_sym_rst_n), .phy_dll_link_up_o(phy_dll_link_up),
    .phy_dll_data_active_o(phy_dll_data_active),
    .phy_dll_current_rate_o(phy_dll_current_rate),
    .phy_dll_link_down_evt_o(phy_dll_link_down_evt),
    .dll_tx_valid_i(dll_tx_valid), .dll_tx_ready_o(dll_tx_ready),
    .dll_tx_data_i(dll_tx_data), .dll_tx_keep_i(dll_tx_keep),
    .dll_tx_sop_i(dll_tx_sop), .dll_tx_eop_i(dll_tx_eop),
    .dll_tx_kind_i(dll_tx_kind), .dll_tx_abort_i(dll_tx_abort),
    .dll_rx_valid_o(dll_rx_valid), .dll_rx_ready_i(dll_rx_ready),
    .dll_rx_data_o(dll_rx_data), .dll_rx_keep_o(dll_rx_keep),
    .dll_rx_sop_o(dll_rx_sop), .dll_rx_eop_o(dll_rx_eop),
    .dll_rx_kind_o(dll_rx_kind), .dll_rx_abort_o(dll_rx_abort),
    .mgmt_cmd_valid_i(mgmt_cmd_valid), .mgmt_cmd_ready_o(mgmt_cmd_ready),
    .mgmt_cmd_opcode_i(mgmt_cmd_opcode), .mgmt_cmd_arg_i(mgmt_cmd_arg),
    .mgmt_rsp_valid_o(mgmt_rsp_valid), .mgmt_rsp_ready_i(mgmt_rsp_ready),
    .mgmt_rsp_status_o(mgmt_rsp_status), .port_pm_req_valid_i(pm_req_valid),
    .port_pm_req_ready_o(pm_req_ready), .port_pm_req_state_i(pm_req_state),
    .port_pm_req_exit_i(pm_req_exit), .port_pm_done_o(pm_done),
    .port_pm_fail_o(pm_fail), .port_pm_rsp_ready_i(pm_rsp_ready),
    .phy_ready_o(phy_ready), .phy_link_up_o(phy_link_up),
    .phy_data_active_o(phy_data_active), .phy_current_rate_o(phy_current_rate),
    .phy_ltssm_state_o(phy_state), .phy_ltssm_substate_o(phy_substate),
    .phy_state_reason_o(phy_reason), .phy_rx_locked_o(phy_rx_locked),
    .phy_err_valid_o(phy_err_valid), .phy_err_ready_i(phy_err_ready),
    .phy_err_code_o(phy_err_code), .phy_err_info_o(phy_err_info),
    .phy_csr_req_valid_i(csr_req_valid), .phy_csr_req_ready_o(csr_req_ready),
    .phy_csr_req_write_i(csr_req_write), .phy_csr_req_addr_i(csr_req_addr),
    .phy_csr_req_wdata_i(csr_req_wdata), .phy_csr_req_wstrb_i(csr_req_wstrb),
    .phy_csr_rsp_valid_o(csr_rsp_valid), .phy_csr_rsp_ready_i(csr_rsp_ready),
    .phy_csr_rsp_rdata_o(csr_rsp_rdata), .phy_csr_rsp_error_o(csr_rsp_error)
  );

  initial begin
    pcie_rx_p=1'b0; pcie_rx_n=1'b1;
    dll_tx_valid=0; dll_tx_data='0; dll_tx_keep='0; dll_tx_sop=0;
    dll_tx_eop=0; dll_tx_kind=0; dll_tx_abort=0; dll_rx_ready=1;
    mgmt_cmd_valid=0; mgmt_cmd_opcode='0; mgmt_cmd_arg='0; mgmt_rsp_ready=1;
    pm_req_valid=0; pm_req_state='0; pm_req_exit=0; pm_rsp_ready=1;
    phy_err_ready=1; csr_req_valid=0; csr_req_write=0; csr_req_addr='0;
    csr_req_wdata='0; csr_req_wstrb='0; csr_rsp_ready=1;
  end

  task automatic release_resets;
    clocks.release_all_resets(3ns);
  endtask

  task automatic send_mgmt(input logic [3:0] opcode_i,
                           input logic [7:0] arg_i,
                           input int unsigned max_wait_i);
    int unsigned age;
    begin
      @(negedge ctrl_clk); mgmt_cmd_opcode=opcode_i; mgmt_cmd_arg=arg_i;
      mgmt_cmd_valid=1; age=0;
      while (!mgmt_cmd_ready && age < max_wait_i) begin
        @(posedge ctrl_clk); age=age+1;
      end
      @(negedge ctrl_clk); mgmt_cmd_valid=0;
    end
  endtask

  task automatic send_tx_beat(input logic [15:0] data_i,
                              input logic [1:0] keep_i,
                              input logic sop_i, input logic eop_i,
                              input logic kind_i, input logic abort_i,
                              input int unsigned max_wait_i);
    int unsigned age;
    begin
      @(negedge link_clk); dll_tx_data=data_i; dll_tx_keep=keep_i;
      dll_tx_sop=sop_i; dll_tx_eop=eop_i; dll_tx_kind=kind_i;
      dll_tx_abort=abort_i; dll_tx_valid=1; age=0;
      while (!dll_tx_ready && age < max_wait_i) begin
        @(posedge link_clk); age=age+1;
      end
      @(negedge link_clk); dll_tx_valid=0; dll_tx_sop=0; dll_tx_eop=0;
      dll_tx_abort=0;
    end
  endtask
endmodule
