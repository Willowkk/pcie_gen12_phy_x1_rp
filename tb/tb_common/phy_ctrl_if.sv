interface phy_ctrl_if(input logic ctrl_clk_i);
  timeunit 1ns;
  timeprecision 1ps;

  logic mgmt_cmd_valid, mgmt_cmd_ready;
  logic [3:0] mgmt_cmd_opcode;
  logic [7:0] mgmt_cmd_arg;
  logic mgmt_rsp_valid, mgmt_rsp_ready;
  logic [3:0] mgmt_rsp_status;
  logic pm_req_valid, pm_req_ready, pm_req_exit, pm_done, pm_fail, pm_rsp_ready;
  logic [1:0] pm_req_state;
  logic csr_req_valid, csr_req_ready, csr_req_write;
  logic [11:0] csr_req_addr;
  logic [31:0] csr_req_wdata, csr_rsp_rdata;
  logic [3:0] csr_req_wstrb;
  logic csr_rsp_valid, csr_rsp_ready, csr_rsp_error;

  task automatic drive_idle;
    begin
      mgmt_cmd_valid=0; mgmt_cmd_opcode='0; mgmt_cmd_arg='0; mgmt_rsp_ready=1;
      pm_req_valid=0; pm_req_state='0; pm_req_exit=0; pm_rsp_ready=1;
      csr_req_valid=0; csr_req_write=0; csr_req_addr='0; csr_req_wdata='0;
      csr_req_wstrb='0; csr_rsp_ready=1;
    end
  endtask

  task automatic send_mgmt(input logic [3:0] opcode_i, input logic [7:0] arg_i);
    begin
      @(negedge ctrl_clk_i); mgmt_cmd_opcode=opcode_i; mgmt_cmd_arg=arg_i; mgmt_cmd_valid=1;
      do @(posedge ctrl_clk_i); while (!mgmt_cmd_ready);
      @(negedge ctrl_clk_i); mgmt_cmd_valid=0;
    end
  endtask

  task automatic send_pm(input logic [1:0] state_i, input logic exit_i);
    begin
      @(negedge ctrl_clk_i); pm_req_state=state_i; pm_req_exit=exit_i; pm_req_valid=1;
      do @(posedge ctrl_clk_i); while (!pm_req_ready);
      @(negedge ctrl_clk_i); pm_req_valid=0;
    end
  endtask

  task automatic csr_request(input logic write_i, input logic [11:0] addr_i,
                             input logic [31:0] data_i, input logic [3:0] strb_i);
    begin
      @(negedge ctrl_clk_i); csr_req_write=write_i; csr_req_addr=addr_i;
      csr_req_wdata=data_i; csr_req_wstrb=strb_i; csr_req_valid=1;
      do @(posedge ctrl_clk_i); while (!csr_req_ready);
      @(negedge ctrl_clk_i); csr_req_valid=0;
    end
  endtask
endinterface
