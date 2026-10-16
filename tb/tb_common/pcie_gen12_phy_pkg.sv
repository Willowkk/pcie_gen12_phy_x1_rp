package pcie_gen12_phy_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  // Frozen protocol constants and shared types for the PCIe Gen1/Gen2 8b/10b
  // x1 Root Port PHY. Enumerations match the project-local interfaces frozen
  // by SPEC section 4.6 and the package requirements in section 10.1.

  typedef enum logic [5:0] {
    LTSSM_RESET         = 6'h00,
    LTSSM_DETECT        = 6'h01,
    LTSSM_POLLING       = 6'h02,
    LTSSM_CONFIGURATION = 6'h03,
    LTSSM_L0            = 6'h04,
    LTSSM_RECOVERY      = 6'h05,
    LTSSM_L0S           = 6'h06,
    LTSSM_L1            = 6'h07,
    LTSSM_L2_L3_READY   = 6'h08,
    LTSSM_DISABLED      = 6'h09,
    LTSSM_LOOPBACK      = 6'h0a,
    LTSSM_HOT_RESET     = 6'h0b
  } pcie_ltssm_state_t;

  typedef enum logic [5:0] {
    LTSSM_SS_RESET_WAIT_READY      = 6'h00,
    LTSSM_SS_DETECT_QUIET          = 6'h01,
    LTSSM_SS_DETECT_ACTIVE         = 6'h02,
    LTSSM_SS_POLLING_ACTIVE        = 6'h03,
    LTSSM_SS_POLLING_COMPLIANCE    = 6'h04,
    LTSSM_SS_POLLING_CONFIGURATION = 6'h05,
    LTSSM_SS_CFG_LINKWIDTH_START   = 6'h06,
    LTSSM_SS_CFG_LINKWIDTH_ACCEPT  = 6'h07,
    LTSSM_SS_CFG_LANENUM_WAIT      = 6'h08,
    LTSSM_SS_CFG_LANENUM_ACCEPT    = 6'h09,
    LTSSM_SS_CFG_COMPLETE          = 6'h0a,
    LTSSM_SS_CFG_IDLE              = 6'h0b,
    LTSSM_SS_L0_ACTIVE             = 6'h0c,
    LTSSM_SS_RECOVERY_RCVRLOCK     = 6'h0d,
    LTSSM_SS_RECOVERY_RCVRCFG      = 6'h0e,
    LTSSM_SS_RECOVERY_SPEED        = 6'h0f,
    LTSSM_SS_RECOVERY_IDLE         = 6'h10,
    LTSSM_SS_L0S_TX_ENTRY          = 6'h11,
    LTSSM_SS_L0S_TX_IDLE           = 6'h12,
    LTSSM_SS_L0S_TX_FTS            = 6'h13,
    LTSSM_SS_L0S_RX_ENTRY          = 6'h14,
    LTSSM_SS_L0S_RX_IDLE           = 6'h15,
    LTSSM_SS_L0S_RX_FTS            = 6'h16,
    LTSSM_SS_L1_ENTRY              = 6'h17,
    LTSSM_SS_L1_IDLE               = 6'h18,
    LTSSM_SS_L1_EXIT               = 6'h19,
    LTSSM_SS_L2_READY_IDLE         = 6'h1a,
    LTSSM_SS_L2_READY_RESTART      = 6'h1b,
    LTSSM_SS_DISABLED_IDLE         = 6'h1c,
    LTSSM_SS_LOOPBACK_ENTRY        = 6'h1d,
    LTSSM_SS_LOOPBACK_ACTIVE       = 6'h1e,
    LTSSM_SS_LOOPBACK_EXIT         = 6'h1f,
    LTSSM_SS_HOT_RESET_ENTRY       = 6'h20,
    LTSSM_SS_HOT_RESET_ACTIVE      = 6'h21,
    LTSSM_SS_HOT_RESET_EXIT        = 6'h22
  } pcie_ltssm_substate_t;

  typedef enum logic [3:0] {
    TX_MODE_ELECTRICAL_IDLE = 4'h0,
    TX_MODE_LOGICAL_IDLE    = 4'h1,
    TX_MODE_TS1             = 4'h2,
    TX_MODE_TS2             = 4'h3,
    TX_MODE_SKP             = 4'h4,
    TX_MODE_FTS             = 4'h5,
    TX_MODE_EIOS            = 4'h6,
    TX_MODE_EIEOS           = 4'h7,
    TX_MODE_COMPLIANCE      = 4'h8,
    TX_MODE_PACKET          = 4'h9,
    TX_MODE_LOOPBACK        = 4'ha
  } pcie_tx_mode_t;

  typedef enum logic [2:0] {
    OS_KIND_TS1   = 3'h0,
    OS_KIND_TS2   = 3'h1,
    OS_KIND_SKP   = 3'h2,
    OS_KIND_FTS   = 3'h3,
    OS_KIND_EIOS  = 3'h4,
    OS_KIND_EIEOS = 3'h5,
    OS_KIND_NONE  = 3'h7
  } pcie_os_kind_t;

  typedef enum logic {
    PKT_KIND_TLP  = 1'b0,
    PKT_KIND_DLLP = 1'b1
  } pcie_packet_kind_t;

  typedef enum logic [1:0] {
    PHY_POWER_P0  = 2'b00,
    PHY_POWER_P0S = 2'b01,
    PHY_POWER_P1  = 2'b10,
    PHY_POWER_P2  = 2'b11
  } pcie_phy_power_state_t;

  typedef enum logic [3:0] {
    PHY_CMD_ENABLE        = 4'h0,
    PHY_CMD_DISABLE       = 4'h1,
    PHY_CMD_RETRAIN       = 4'h2,
    PHY_CMD_SET_RATE      = 4'h3,
    PHY_CMD_HOT_RESET     = 4'h4,
    PHY_CMD_LOOPBACK      = 4'h5,
    PHY_CMD_COMPLIANCE    = 4'h6,
    PHY_CMD_CLEAR_ERROR   = 4'h7,
    PHY_CMD_SET_PM_POLICY = 4'h8
  } pcie_mgmt_opcode_t;

  typedef enum logic [3:0] {
    MGMT_RSP_OK       = 4'h0,
    MGMT_RSP_BUSY     = 4'h1,
    MGMT_RSP_REJECTED = 4'h2,
    MGMT_RSP_TIMEOUT  = 4'h3,
    MGMT_RSP_FAILED   = 4'h4
  } pcie_mgmt_rsp_status_t;

  typedef enum logic [1:0] {
    PM_REQ_L0S         = 2'd0,
    PM_REQ_L1          = 2'd1,
    PM_REQ_L2_L3_READY = 2'd2
  } pcie_pm_request_state_t;

  typedef enum logic [2:0] {
    OS_REPEAT_SINGLE       = 3'd0,
    OS_REPEAT_CONTINUOUS   = 3'd1,
    OS_REPEAT_UNTIL_ACCEPT = 3'd2,
    OS_REPEAT_FIXED_2      = 3'd3,
    OS_REPEAT_FIXED_8      = 3'd4,
    OS_REPEAT_FIXED_1024   = 3'd5,
    OS_REPEAT_FIXED_32     = 3'd6
  } pcie_os_repeat_mode_t;

  typedef struct packed {
    logic       valid;
    logic       is_ts2;
    logic       link_num_is_pad;
    logic       lane_num_is_pad;
    logic [7:0] link_num;
    logic [4:0] lane_num;
    logic [7:0] n_fts;
    logic [1:0] rate_id;
    logic [7:0] training_ctrl;
  } pcie_ts_fields_t;

  typedef enum logic [7:0] {
    ERR_NONE                      = 8'h00,
    ERR_RX_DISPARITY              = 8'h01,
    ERR_RX_CODE                   = 8'h02,
    ERR_RX_ALIGN_LOSS             = 8'h03,
    ERR_RX_OS_INVALID             = 8'h04,
    ERR_SCRAMBLER_SYNC            = 8'h05,
    ERR_SKP_DEADLINE              = 8'h06,
    ERR_RXBUF_UNDERFLOW           = 8'h07,
    ERR_RXBUF_OVERFLOW            = 8'h08,
    ERR_LTSSM_TIMEOUT             = 8'h09,
    ERR_DETECT_TIMEOUT            = 8'h0a,
    ERR_RATE_CHANGE               = 8'h0b,
    ERR_GT_PLL_UNLOCK             = 8'h0c,
    ERR_GT_RESET_TIMEOUT          = 8'h0d,
    ERR_TX_FRAMING                = 8'h0e,
    ERR_RX_FRAMING                = 8'h0f,
    ERR_RX_PACKET_BUFFER_OVERFLOW = 8'h10,
    ERR_LINK_LOSS                 = 8'h11,
    ERR_CDC_EVENT_OVERFLOW        = 8'h12,
    ERR_RATE_NOT_QUIESCED         = 8'h13
  } pcie_phy_error_code_t;

  typedef enum logic [2:0] {
    SEVERITY_INFO        = 3'd0,
    SEVERITY_CORRECTABLE = 3'd1,
    SEVERITY_LOCAL       = 3'd2,
    SEVERITY_PROTOCOL    = 3'd3,
    SEVERITY_LINK        = 3'd4,
    SEVERITY_FATAL       = 3'd5
  } pcie_error_severity_t;

  typedef enum logic [2:0] {
    PACKET_ACTION_NONE   = 3'd0,
    PACKET_ACTION_COMMIT = 3'd1,
    PACKET_ACTION_ABORT  = 3'd2,
    PACKET_ACTION_DROP   = 3'd3,
    PACKET_ACTION_FLUSH  = 3'd4
  } pcie_packet_action_t;

  typedef enum logic [7:0] {
    REASON_RESET_ASSERTED     = 8'h00,
    REASON_READY_AND_ENABLED  = 8'h01,
    REASON_TIMER_EXPIRED      = 8'h02,
    REASON_RECEIVER_PRESENT   = 8'h03,
    REASON_RECEIVER_ABSENT    = 8'h04,
    REASON_TS1_QUALIFIED      = 8'h05,
    REASON_TS2_QUALIFIED      = 8'h06,
    REASON_IDLE_QUALIFIED     = 8'h07,
    REASON_RATE_REQUESTED     = 8'h08,
    REASON_RATE_COMPLETE      = 8'h09,
    REASON_RATE_FAILED        = 8'h0a,
    REASON_LINK_LOSS          = 8'h0b,
    REASON_MANAGEMENT_REQUEST = 8'h0c,
    REASON_POWER_REQUEST      = 8'h0d,
    REASON_POWER_COMPLETE     = 8'h0e,
    REASON_HOT_RESET          = 8'h0f,
    REASON_LOOPBACK           = 8'h10,
    REASON_DISABLE_LINK       = 8'h11,
    REASON_PROTOCOL_ERROR     = 8'h12,
    REASON_FATAL_ERROR        = 8'h13,
    REASON_RETRY_EXHAUSTED    = 8'h14,
    REASON_FALLBACK_GEN1      = 8'h15,
    REASON_PM_REQUEST         = 8'h16,
    REASON_PM_EXIT            = 8'h17,
    REASON_COMPLIANCE         = 8'h18,
    REASON_RX_EIOS            = 8'h19,
    REASON_RX_EIEOS           = 8'h1a,
    REASON_RX_FTS             = 8'h1b
  } pcie_state_reason_t;

  typedef enum logic [3:0] {
    CHAR_CLASS_DATA         = 4'h0,
    CHAR_CLASS_TS           = 4'h1,
    CHAR_CLASS_SKP          = 4'h2,
    CHAR_CLASS_EIOS         = 4'h3,
    CHAR_CLASS_EIEOS        = 4'h4,
    CHAR_CLASS_FTS          = 4'h5,
    CHAR_CLASS_COMPLIANCE   = 4'h6,
    CHAR_CLASS_LOGICAL_IDLE = 4'h7,
    CHAR_CLASS_FRAME        = 4'h8,
    CHAR_CLASS_COM          = 4'h9,
    CHAR_CLASS_PAD          = 4'ha,
    CHAR_CLASS_UNKNOWN      = 4'hf
  } pcie_character_class_t;

  typedef enum logic [1:0] {
    LFSR_ACTION_ADV8   = 2'b00,
    LFSR_ACTION_BYPASS = 2'b01,
    LFSR_ACTION_HOLD   = 2'b10,
    LFSR_ACTION_RESET  = 2'b11
  } pcie_lfsr_action_t;

  typedef enum logic [1:0] {
    RETRY_HOLD      = 2'b00,
    RETRY_INCREMENT = 2'b01,
    RETRY_CLEAR     = 2'b10
  } pcie_retry_action_t;

  typedef enum logic [2:0] {
    GT_OP_NONE   = 3'd0,
    GT_OP_DETECT = 3'd1,
    GT_OP_RATE   = 3'd2,
    GT_OP_POWER  = 3'd3
  } pcie_gt_operation_t;

  typedef enum logic [1:0] {
    GT_CLKCOR_NONE  = 2'b00,
    GT_CLKCOR_SKIP1 = 2'b01,
    GT_CLKCOR_SKIP2 = 2'b10,
    GT_CLKCOR_ADD1  = 2'b11
  } pcie_gt_rx_clkcor_t;

  typedef enum logic [2:0] {
    GT_RXBUF_NOMINAL   = 3'b000,
    GT_RXBUF_BELOW_MIN = 3'b001,
    GT_RXBUF_ABOVE_MAX = 3'b010,
    GT_RXBUF_UNDERFLOW = 3'b101,
    GT_RXBUF_OVERFLOW  = 3'b110
  } pcie_gt_rxbuf_status_t;

  typedef struct packed {
    logic                  valid;
    pcie_gt_operation_t    operation;
    logic                  rate_target_gen2;
    pcie_phy_power_state_t power_state;
    logic                  tx_electrical_idle;
    logic                  rx_polarity_invert;
    logic                  tx_deemphasis;
    logic                  tx_swing;
    logic [2:0]            tx_margin;
    logic                  compliance_enable;
    logic [2:0]            loopback_mode;
  } pcie_gt_request_t;

  typedef struct packed {
    logic                  valid;
    pcie_gt_operation_t    operation;
    logic                  success;
    logic                  timeout;
    logic                  receiver_present;
    logic                  current_rate_gen2;
    pcie_phy_power_state_t power_state;
    logic [7:0]            fault_code;
  } pcie_gt_completion_t;

  typedef enum logic [3:0] {
    EVT_SRC_LTSSM = 4'h0,
    EVT_SRC_TX    = 4'h1,
    EVT_SRC_RX    = 4'h2,
    EVT_SRC_OS    = 4'h3,
    EVT_SRC_SCR   = 4'h4,
    EVT_SRC_SKP   = 4'h5,
    EVT_SRC_GTY   = 4'h6,
    EVT_SRC_CDC   = 4'h7
  } pcie_event_source_t;

  typedef struct packed {
    logic               valid;
    logic               fatal;
    pcie_event_source_t source;
    logic [7:0]         code;
    logic [31:0]        info;
  } pcie_status_event_t;

  // PCIe 2.1 TS training-control byte definitions.
  localparam logic [7:0] TS_CTRL_HOT_RESET        = 8'h01;
  localparam logic [7:0] TS_CTRL_DISABLE_LINK     = 8'h02;
  localparam logic [7:0] TS_CTRL_LOOPBACK         = 8'h04;
  localparam logic [7:0] TS_CTRL_DISABLE_SCRAMBLE = 8'h08;
  localparam logic [7:0] TS_CTRL_COMPLIANCE_RX    = 8'h10;
  localparam logic [7:0] TS_CTRL_SPEED_CHANGE     = 8'h20;

  // Management command argument encodings frozen for this project.
  localparam logic [0:0] PHY_CMD_SET_RATE_ARG_GEN2    = 1'b1;
  localparam logic [0:0] PHY_CMD_SET_RATE_ARG_GEN1    = 1'b0;
  localparam logic [2:0] PHY_CMD_LOOPBACK_ARG_DISABLE = 3'b000;
  localparam logic [2:0] PHY_CMD_LOOPBACK_ARG_NEAR    = 3'b001;
  localparam logic [2:0] PHY_CMD_LOOPBACK_ARG_FAR     = 3'b010;
  localparam logic [7:0] PHY_CMD_CLEAR_ERROR_ARG_ALL  = 8'hff;

  // PCIe 8b/10b control/data symbols used by this design.
  localparam logic [7:0] K_COM  = 8'hbc;  // K28.5 COM
  localparam logic [7:0] K_SKP  = 8'h1c;  // K28.0
  localparam logic [7:0] K_FTS  = 8'h3c;  // K28.1
  localparam logic [7:0] K_SDP  = 8'h5c;  // K28.2
  localparam logic [7:0] K_EIOS = 8'h7c;  // K28.3
  localparam logic [7:0] K_EIE  = 8'hfc;  // K28.7
  localparam logic [7:0] K_STP  = 8'hfb;  // K27.7
  localparam logic [7:0] K_END  = 8'hfd;  // K29.7
  localparam logic [7:0] K_EDB  = 8'hfe;  // K30.7
  localparam logic [7:0] K_PAD  = 8'hf7;  // K23.7
  localparam logic [7:0] D_TS1  = 8'h4a;  // D10.2
  localparam logic [7:0] D_TS2  = 8'h45;  // D5.2
  localparam logic [7:0] D_COMPLIANCE_D21_5 = 8'hb5;
  localparam logic [7:0] D_COMPLIANCE_D10_2 = 8'h4a;
  localparam logic [7:0] D_LOGICAL_IDLE = 8'h00; // PCIe 2.1 logical-idle data character.
  localparam logic [1:0] RATE_ID_GEN1_SUPPORTED = 2'b01;
  localparam logic [1:0] RATE_ID_GEN2_SUPPORTED = 2'b10;

  // PCIe 2.1 section 4.2.3 scrambler polynomial x^16+x^5+x^4+x^3+1.
  localparam logic [15:0] PCIE_SCRAMBLER_SEED = 16'hffff;
  localparam int unsigned PCIE_SCRAMBLER_TAP_16 = 15;
  localparam int unsigned PCIE_SCRAMBLER_TAP_5  = 4;
  localparam int unsigned PCIE_SCRAMBLER_TAP_4  = 3;
  localparam int unsigned PCIE_SCRAMBLER_TAP_3  = 2;

  // Status/error CSR byte addresses shared by RTL and the self-checking TBs.
  localparam logic [11:0] CSR_ID_VERSION        = 12'h000;
  localparam logic [11:0] CSR_STATUS            = 12'h004;
  localparam logic [11:0] CSR_LTSSM             = 12'h008;
  localparam logic [11:0] CSR_STATE_REASON      = 12'h00c;
  localparam logic [11:0] CSR_FIRST_ERROR_CODE  = 12'h010;
  localparam logic [11:0] CSR_FIRST_ERROR_INFO  = 12'h014;
  localparam logic [11:0] CSR_ERROR_STICKY      = 12'h018;
  localparam logic [11:0] CSR_EVENT_STATUS      = 12'h01c;
  localparam logic [11:0] CSR_COUNTER_BASE      = 12'h020;
  localparam logic [11:0] CSR_HISTORY_BASE      = 12'h080;
  localparam logic [11:0] CSR_OBSERVATION_CLEAR = 12'h0c0;

  function automatic logic is_ts_training_ctrl_set(
    input logic [7:0] training_ctrl,
    input logic [7:0] mask
  );
    return ((training_ctrl & mask) == mask);
  endfunction

  function automatic pcie_error_severity_t error_severity(
    input pcie_phy_error_code_t code
  );
    unique case (code)
      ERR_RX_DISPARITY,
      ERR_RX_CODE:
        return SEVERITY_CORRECTABLE;

      ERR_TX_FRAMING,
      ERR_RATE_NOT_QUIESCED:
        return SEVERITY_LOCAL;

      ERR_RX_OS_INVALID,
      ERR_RX_FRAMING:
        return SEVERITY_PROTOCOL;

      ERR_RX_ALIGN_LOSS,
      ERR_SCRAMBLER_SYNC,
      ERR_SKP_DEADLINE,
      ERR_LTSSM_TIMEOUT,
      ERR_DETECT_TIMEOUT,
      ERR_RATE_CHANGE,
      ERR_LINK_LOSS:
        return SEVERITY_LINK;

      ERR_RXBUF_UNDERFLOW,
      ERR_RXBUF_OVERFLOW,
      ERR_GT_PLL_UNLOCK,
      ERR_GT_RESET_TIMEOUT,
      ERR_RX_PACKET_BUFFER_OVERFLOW,
      ERR_CDC_EVENT_OVERFLOW:
        return SEVERITY_FATAL;

      default:
        return SEVERITY_INFO;
    endcase
  endfunction

  function automatic pcie_packet_action_t error_packet_action(
    input pcie_phy_error_code_t code
  );
    unique case (code)
      ERR_RX_DISPARITY,
      ERR_RX_CODE,
      ERR_RX_FRAMING,
      ERR_SCRAMBLER_SYNC:
        return PACKET_ACTION_DROP;

      ERR_TX_FRAMING:
        return PACKET_ACTION_ABORT;

      ERR_RXBUF_UNDERFLOW,
      ERR_RXBUF_OVERFLOW,
      ERR_RX_PACKET_BUFFER_OVERFLOW,
      ERR_GT_PLL_UNLOCK,
      ERR_GT_RESET_TIMEOUT,
      ERR_CDC_EVENT_OVERFLOW:
        return PACKET_ACTION_FLUSH;

      default:
        return PACKET_ACTION_NONE;
    endcase
  endfunction

  // Smaller number means higher first-error priority per SPEC section 8.2.
  function automatic logic [2:0] error_priority(
    input pcie_phy_error_code_t code
  );
    unique case (code)
      ERR_GT_PLL_UNLOCK,
      ERR_GT_RESET_TIMEOUT:
        return 3'd0;

      ERR_RXBUF_UNDERFLOW,
      ERR_RXBUF_OVERFLOW,
      ERR_RX_PACKET_BUFFER_OVERFLOW,
      ERR_CDC_EVENT_OVERFLOW:
        return 3'd1;

      ERR_RX_ALIGN_LOSS,
      ERR_LINK_LOSS:
        return 3'd2;

      ERR_TX_FRAMING,
      ERR_RX_FRAMING,
      ERR_RX_OS_INVALID,
      ERR_RATE_NOT_QUIESCED:
        return 3'd3;

      ERR_RX_CODE,
      ERR_RX_DISPARITY,
      ERR_SCRAMBLER_SYNC,
      ERR_SKP_DEADLINE,
      ERR_LTSSM_TIMEOUT,
      ERR_DETECT_TIMEOUT,
      ERR_RATE_CHANGE:
        return 3'd4;

      default:
        return 3'd7;
    endcase
  endfunction

  function automatic pcie_ltssm_state_t error_recovery_target(
    input pcie_phy_error_code_t code
  );
    unique case (code)
      ERR_RXBUF_UNDERFLOW,
      ERR_RXBUF_OVERFLOW,
      ERR_GT_PLL_UNLOCK,
      ERR_GT_RESET_TIMEOUT,
      ERR_RX_PACKET_BUFFER_OVERFLOW,
      ERR_CDC_EVENT_OVERFLOW,
      ERR_RX_OS_INVALID,
      ERR_DETECT_TIMEOUT:
        return LTSSM_DETECT;
      ERR_TX_FRAMING,
      ERR_RATE_NOT_QUIESCED:
        return LTSSM_L0;
      default:
        return LTSSM_RECOVERY;
    endcase
  endfunction

  function automatic logic error_is_fatal(input pcie_phy_error_code_t code);
    return (error_severity(code) == SEVERITY_FATAL);
  endfunction

  // Compatibility aliases for the partially written tree being normalized.
  localparam pcie_ltssm_state_t LTSSM_STATE_RESET         = LTSSM_RESET;
  localparam pcie_ltssm_state_t LTSSM_STATE_DETECT        = LTSSM_DETECT;
  localparam pcie_ltssm_state_t LTSSM_STATE_POLLING       = LTSSM_POLLING;
  localparam pcie_ltssm_state_t LTSSM_STATE_CONFIGURATION = LTSSM_CONFIGURATION;
  localparam pcie_ltssm_state_t LTSSM_STATE_L0            = LTSSM_L0;
  localparam pcie_ltssm_state_t LTSSM_STATE_RECOVERY      = LTSSM_RECOVERY;
  localparam pcie_ltssm_state_t LTSSM_STATE_L0S           = LTSSM_L0S;
  localparam pcie_ltssm_state_t LTSSM_STATE_L1            = LTSSM_L1;
  localparam pcie_ltssm_state_t LTSSM_STATE_L23_READY     = LTSSM_L2_L3_READY;
  localparam pcie_ltssm_state_t LTSSM_STATE_DISABLED      = LTSSM_DISABLED;
  localparam pcie_ltssm_state_t LTSSM_STATE_LOOPBACK      = LTSSM_LOOPBACK;
  localparam pcie_ltssm_state_t LTSSM_STATE_HOT_RESET     = LTSSM_HOT_RESET;

  localparam pcie_ltssm_substate_t LTSSM_SUB_RESET_WAIT            = LTSSM_SS_RESET_WAIT_READY;
  localparam pcie_ltssm_substate_t LTSSM_SUB_DETECT_QUIET          = LTSSM_SS_DETECT_QUIET;
  localparam pcie_ltssm_substate_t LTSSM_SUB_DETECT_ACTIVE         = LTSSM_SS_DETECT_ACTIVE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_POLLING_ACTIVE        = LTSSM_SS_POLLING_ACTIVE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_POLLING_COMPLIANCE    = LTSSM_SS_POLLING_COMPLIANCE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_POLLING_CONFIGURATION = LTSSM_SS_POLLING_CONFIGURATION;
  localparam pcie_ltssm_substate_t LTSSM_SUB_CFG_LINKWIDTH_START   = LTSSM_SS_CFG_LINKWIDTH_START;
  localparam pcie_ltssm_substate_t LTSSM_SUB_CFG_LINKWIDTH_ACCEPT  = LTSSM_SS_CFG_LINKWIDTH_ACCEPT;
  localparam pcie_ltssm_substate_t LTSSM_SUB_CFG_LANENUM_WAIT      = LTSSM_SS_CFG_LANENUM_WAIT;
  localparam pcie_ltssm_substate_t LTSSM_SUB_CFG_LANENUM_ACCEPT    = LTSSM_SS_CFG_LANENUM_ACCEPT;
  localparam pcie_ltssm_substate_t LTSSM_SUB_CFG_COMPLETE          = LTSSM_SS_CFG_COMPLETE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_CFG_IDLE              = LTSSM_SS_CFG_IDLE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L0_ACTIVE             = LTSSM_SS_L0_ACTIVE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_RECOVERY_RCVRLOCK     = LTSSM_SS_RECOVERY_RCVRLOCK;
  localparam pcie_ltssm_substate_t LTSSM_SUB_RECOVERY_RCVRCFG      = LTSSM_SS_RECOVERY_RCVRCFG;
  localparam pcie_ltssm_substate_t LTSSM_SUB_RECOVERY_SPEED        = LTSSM_SS_RECOVERY_SPEED;
  localparam pcie_ltssm_substate_t LTSSM_SUB_RECOVERY_IDLE         = LTSSM_SS_RECOVERY_IDLE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L0S_TX_ENTRY          = LTSSM_SS_L0S_TX_ENTRY;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L0S_TX_IDLE           = LTSSM_SS_L0S_TX_IDLE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L0S_TX_FTS            = LTSSM_SS_L0S_TX_FTS;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L0S_RX_ENTRY          = LTSSM_SS_L0S_RX_ENTRY;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L0S_RX_IDLE           = LTSSM_SS_L0S_RX_IDLE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L0S_RX_FTS            = LTSSM_SS_L0S_RX_FTS;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L1_ENTRY              = LTSSM_SS_L1_ENTRY;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L1_IDLE               = LTSSM_SS_L1_IDLE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L1_EXIT               = LTSSM_SS_L1_EXIT;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L23_ENTRY             = LTSSM_SS_L2_READY_IDLE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_L23_RESTART           = LTSSM_SS_L2_READY_RESTART;
  localparam pcie_ltssm_substate_t LTSSM_SUB_DISABLED_IDLE         = LTSSM_SS_DISABLED_IDLE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_LOOPBACK_ENTRY        = LTSSM_SS_LOOPBACK_ENTRY;
  localparam pcie_ltssm_substate_t LTSSM_SUB_LOOPBACK_ACTIVE       = LTSSM_SS_LOOPBACK_ACTIVE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_LOOPBACK_EXIT         = LTSSM_SS_LOOPBACK_EXIT;
  localparam pcie_ltssm_substate_t LTSSM_SUB_HOT_RESET_ENTRY       = LTSSM_SS_HOT_RESET_ENTRY;
  localparam pcie_ltssm_substate_t LTSSM_SUB_HOT_RESET_ACTIVE      = LTSSM_SS_HOT_RESET_ACTIVE;
  localparam pcie_ltssm_substate_t LTSSM_SUB_HOT_RESET_EXIT        = LTSSM_SS_HOT_RESET_EXIT;

  localparam pcie_tx_mode_t TX_MODE_DISABLED = TX_MODE_ELECTRICAL_IDLE;
  localparam pcie_character_class_t CHAR_CLASS_IDLE = CHAR_CLASS_LOGICAL_IDLE;

  localparam pcie_state_reason_t REASON_CMD_ENABLE        = REASON_READY_AND_ENABLED;
  localparam pcie_state_reason_t REASON_DETECT_PRESENT    = REASON_RECEIVER_PRESENT;
  localparam pcie_state_reason_t REASON_DETECT_ABSENT     = REASON_RECEIVER_ABSENT;
  localparam pcie_state_reason_t REASON_DETECT_TIMEOUT    = REASON_TIMER_EXPIRED;
  localparam pcie_state_reason_t REASON_TIMEOUT           = REASON_TIMER_EXPIRED;
  localparam pcie_state_reason_t REASON_RX_TS1_QUALIFIED  = REASON_TS1_QUALIFIED;
  localparam pcie_state_reason_t REASON_RX_TS2_QUALIFIED  = REASON_TS2_QUALIFIED;
  localparam pcie_state_reason_t REASON_RX_IDLE_QUALIFIED = REASON_IDLE_QUALIFIED;
  localparam pcie_state_reason_t REASON_SPEED_CHANGE      = REASON_RATE_REQUESTED;
  localparam pcie_state_reason_t REASON_RATE_DONE         = REASON_RATE_COMPLETE;
  localparam pcie_state_reason_t REASON_RATE_FAIL         = REASON_RATE_FAILED;
  localparam pcie_state_reason_t REASON_CMD_DISABLE       = REASON_DISABLE_LINK;
  localparam pcie_state_reason_t REASON_CMD_RETRAIN       = REASON_MANAGEMENT_REQUEST;
  localparam pcie_state_reason_t REASON_CMD_HOT_RESET     = REASON_HOT_RESET;
  localparam pcie_state_reason_t REASON_CMD_LOOPBACK      = REASON_LOOPBACK;
  localparam pcie_state_reason_t REASON_CMD_COMPLIANCE    = REASON_COMPLIANCE;
  localparam pcie_state_reason_t REASON_EXIT_LOW_POWER    = REASON_PM_EXIT;

  typedef pcie_mgmt_opcode_t phy_mgmt_opcode_t;

endpackage
