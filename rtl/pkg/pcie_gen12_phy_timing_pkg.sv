package pcie_gen12_phy_timing_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  // The package carries both frozen protocol-visible timing/count constants and
  // project-local watchdog bounds. Every value is documented with its source or
  // marked as a project integration contract per SPEC sections 6.5, 6.8, 8 and
  // 10.1. Synthesis always uses the unscaled values; SIM_TIME_SCALE is a test
  // bench convenience only.

  parameter int unsigned CTRL_CLK_HZ    = 100_000_000; // Project clock contract; PCIe 2.1 does not prescribe ctrl_clk.
  parameter int unsigned SIM_TIME_SCALE = 1;           // Project-only TB override; synthesis ignores scaling.

  // PCIe Base Specification 2.1, LTSSM Detect.Quiet minimum dwell.
  localparam int unsigned DETECT_QUIET_MIN_US      = 12_000; // PCIe 2.1 §4.2.6.1.1.
  // Project watchdog matching Detect.Active bounded completion expectation.
  localparam int unsigned DETECT_ACTIVE_TIMEOUT_US = 12_000; // PCIe 2.1 §4.2.6.1.2 plus project watchdog.

  // PCIe 2.1 LTSSM state watchdogs and minimum stay timers.
  localparam int unsigned POLLING_ACTIVE_TIMEOUT_US    = 24_000; // PCIe 2.1 §4.2.6.2.1.
  localparam int unsigned POLLING_CONFIG_TIMEOUT_US    = 48_000; // PCIe 2.1 §4.2.6.2.3.
  localparam int unsigned CONFIGURATION_TIMEOUT_US     = 48_000; // PCIe 2.1 §4.2.6.3 project aggregate bound.
  localparam int unsigned RECOVERY_RCVRLOCK_TIMEOUT_US = 24_000; // PCIe 2.1 §4.2.6.4.1.
  localparam int unsigned RECOVERY_RCVRCFG_TIMEOUT_US  = 48_000; // PCIe 2.1 §4.2.6.4.2.
  localparam int unsigned RECOVERY_SPEED_TIMEOUT_US    = 1_000;  // PCIe 2.1 §4.2.6.4.3.
  localparam int unsigned RECOVERY_IDLE_TIMEOUT_US     = 2_000;  // PCIe 2.1 §4.2.6.4.4.
  localparam int unsigned L0S_EXIT_TIMEOUT_US          = 2_000;  // PCIe 2.1 §4.2.6.6 project exit watchdog.
  localparam int unsigned L1_ENTRY_TIMEOUT_US          = 24_000; // PCIe 2.1 §4.2.6.7 project entry watchdog.
  localparam int unsigned L1_EXIT_TIMEOUT_US           = 48_000; // PCIe 2.1 §4.2.6.7 project exit watchdog.
  localparam int unsigned L2_READY_TIMEOUT_US          = 48_000; // PCIe 2.1 §4.2.6.8 project watchdog.
  localparam int unsigned HOT_RESET_MIN_HOLD_US        = 2_000;  // PCIe 2.1 §4.2.6.11.
  localparam int unsigned LOOPBACK_ENTRY_TIMEOUT_US    = 24_000; // PCIe 2.1 §4.2.6.10 project watchdog.
  localparam int unsigned LOOPBACK_EXIT_TIMEOUT_US     = 24_000; // PCIe 2.1 §4.2.6.10 project watchdog.
  localparam int unsigned DISABLED_MIN_HOLD_US         = 2_000;  // PCIe 2.1 §4.2.6.9 project hold.

  // Ordered-set/idle qualification counts from SPEC sections 6.4, 7.1 and 7.3.
  localparam int unsigned POLLING_ACTIVE_MIN_TS1_TX     = 1_024; // PCIe 2.1 §4.2.6.2.1.
  localparam int unsigned POLLING_ACTIVE_TS_QUAL_COUNT  = 8;     // PCIe 2.1 §4.2.6.2.1.
  localparam int unsigned POLLING_CONFIG_TS2_QUAL_COUNT = 8;     // PCIe 2.1 §4.2.6.2.3.
  localparam int unsigned CFG_LINKWIDTH_TS_COUNT        = 2;     // PCIe 2.1 §4.2.6.3 Linkwidth.
  localparam int unsigned CFG_LANENUM_TS_COUNT          = 2;     // PCIe 2.1 §4.2.6.3 Lanenum.
  localparam int unsigned CFG_COMPLETE_TS2_COUNT        = 8;     // PCIe 2.1 §4.2.6.3.5.
  localparam int unsigned CFG_IDLE_COUNT                = 8;     // PCIe 2.1 §4.2.6.3.6.
  localparam int unsigned RECOVERY_TS_COUNT             = 8;     // PCIe 2.1 §4.2.6.4.
  localparam int unsigned RECOVERY_IDLE_COUNT           = 8;     // PCIe 2.1 §4.2.6.4.4.
  localparam int unsigned LOGICAL_IDLE_QUAL_COUNT       = 8;     // PCIe 2.1 Configuration/Recovery Idle.
  localparam int unsigned GEN2_EIEOS_TS1_PERIOD         = 32;    // PCIe 2.1 §4.2.6.4.1.

  // PCIe 2.1 clock tolerance compensation window.
  localparam int unsigned SKP_SCHEDULE_INTERVAL_SYMBOLS = 1_180; // PCIe 2.1 §4.2.7.
  localparam int unsigned SKP_LATEST_INTERVAL_SYMBOLS   = 1_538; // PCIe 2.1 §4.2.7.
  localparam int unsigned SKP_ORDERED_SET_SYMBOLS       = 4;     // PCIe 2.1 §4.2.7.

  // Project watchdogs around adapter-native transactions required to terminate.
  localparam int unsigned GT_RESET_TIMEOUT_US     = 48_000; // Project watchdog supporting PCIe 2.1 reset entry.
  localparam int unsigned GT_RATE_TIMEOUT_US      = 1_000;  // Project watchdog supporting PCIe 2.1 Recovery.Speed.
  localparam int unsigned GT_DETECT_TIMEOUT_US    = 12_000; // Project watchdog supporting PCIe 2.1 Detect.Active.
  localparam int unsigned GT_POWER_TIMEOUT_US     = 48_000; // Project watchdog supporting PCIe 2.1 L1/L2 transitions.
  localparam int unsigned GT_CLOCK_STABLE_CYCLES  = 32;     // Project qualifier supporting PCIe 2.1 rate completion.
  localparam int unsigned GT_BUFFER_REINIT_CYCLES = 16;     // Project qualifier supporting PCIe 2.1 rate completion.

  // Project digital filters for normalized RX electrical-idle/alignment status.
  localparam int unsigned RX_EI_ASSERT_STABLE_CYCLES   = 8;  // Project filter for PCIe 2.1 Electrical Idle events.
  localparam int unsigned RX_EI_DEASSERT_STABLE_CYCLES = 16; // Project filter for PCIe 2.1 Electrical Idle exit.
  localparam int unsigned RX_ALIGNMENT_STABLE_CYCLES   = 16; // Project qualifier for PCIe 2.1 Recovery.RcvrLock.
  localparam int unsigned RX_DECODE_ERROR_THRESHOLD    = 8;  // Project threshold for PCIe 2.1 Receiver Error recovery.

  // DLL/PHY whole-packet contract, frozen by project integration.
  localparam int unsigned PHY_MAX_PACKET_BYTES           = 4_128; // PCIe 2.1 §2.2 max payload plus project reserve.
  localparam int unsigned PHY_TX_WHOLE_PACKET_SLOTS      = 2;     // Project capacity contract for PCIe max packet.
  localparam int unsigned PHY_RX_WHOLE_PACKET_SLOTS      = 2;     // SPEC §4.3 integration minimum.
  localparam int unsigned PHY_RX_BACKPRESSURE_MAX_CYCLES = 4_096; // Project DLL/PHY backpressure contract.

  // Project retry budgets demanded by SPEC section 8.2 bounded recovery rules.
  localparam int unsigned LTSSM_RETRY_MAX  = 3; // Project bound implementing PCIe 2.1 LTSSM fallback.
  localparam int unsigned DETECT_RETRY_MAX = 8; // Project bound implementing PCIe 2.1 Detect retry.
  localparam int unsigned RATE_RETRY_MAX   = 2; // Project bound implementing PCIe 2.1 Recovery.Speed fallback.

  typedef enum logic [5:0] {
    TIMER_NONE               = 6'h00,
    TIMER_DETECT_QUIET       = 6'h01,
    TIMER_DETECT_ACTIVE      = 6'h02,
    TIMER_POLLING_ACTIVE     = 6'h03,
    TIMER_POLLING_CONFIG     = 6'h04,
    TIMER_CONFIGURATION      = 6'h05,
    TIMER_RECOVERY_RCVRLOCK  = 6'h06,
    TIMER_RECOVERY_RCVRCFG   = 6'h07,
    TIMER_RECOVERY_SPEED     = 6'h08,
    TIMER_RECOVERY_IDLE      = 6'h09,
    TIMER_L0S_EXIT           = 6'h0a,
    TIMER_L1_ENTRY           = 6'h0b,
    TIMER_L1_EXIT            = 6'h0c,
    TIMER_L2_READY           = 6'h0d,
    TIMER_HOT_RESET          = 6'h0e,
    TIMER_LOOPBACK_ENTRY     = 6'h0f,
    TIMER_LOOPBACK_EXIT      = 6'h10,
    TIMER_DISABLED_HOLD      = 6'h11,
    TIMER_GT_RESET           = 6'h12,
    TIMER_GT_DETECT          = 6'h13,
    TIMER_GT_RATE            = 6'h14,
    TIMER_GT_POWER           = 6'h15
  } pcie_timer_id_t;

  function automatic int unsigned usec_to_ctrl_cycles(input int unsigned usec_value);
    longint unsigned product;
    product = longint'(CTRL_CLK_HZ) * longint'(usec_value);
    return int'((product + 999_999) / 1_000_000);
  endfunction

  function automatic int unsigned sim_scaled_cycles(
    input int unsigned base_cycles,
    input int unsigned sim_scale
  );
`ifdef SYNTHESIS
    return base_cycles;
`else
    if (sim_scale <= 1) begin
      return base_cycles;
    end
    return (base_cycles + sim_scale - 1) / sim_scale;
`endif
  endfunction

  function automatic int unsigned timer_default_cycles(
    input pcie_timer_id_t id,
    input int unsigned    sim_scale
  );
    int unsigned cycles;
    unique case (id)
      TIMER_DETECT_QUIET:      cycles = usec_to_ctrl_cycles(DETECT_QUIET_MIN_US);
      TIMER_DETECT_ACTIVE:     cycles = usec_to_ctrl_cycles(DETECT_ACTIVE_TIMEOUT_US);
      TIMER_POLLING_ACTIVE:    cycles = usec_to_ctrl_cycles(POLLING_ACTIVE_TIMEOUT_US);
      TIMER_POLLING_CONFIG:    cycles = usec_to_ctrl_cycles(POLLING_CONFIG_TIMEOUT_US);
      TIMER_CONFIGURATION:     cycles = usec_to_ctrl_cycles(CONFIGURATION_TIMEOUT_US);
      TIMER_RECOVERY_RCVRLOCK: cycles = usec_to_ctrl_cycles(RECOVERY_RCVRLOCK_TIMEOUT_US);
      TIMER_RECOVERY_RCVRCFG:  cycles = usec_to_ctrl_cycles(RECOVERY_RCVRCFG_TIMEOUT_US);
      TIMER_RECOVERY_SPEED:    cycles = usec_to_ctrl_cycles(RECOVERY_SPEED_TIMEOUT_US);
      TIMER_RECOVERY_IDLE:     cycles = usec_to_ctrl_cycles(RECOVERY_IDLE_TIMEOUT_US);
      TIMER_L0S_EXIT:          cycles = usec_to_ctrl_cycles(L0S_EXIT_TIMEOUT_US);
      TIMER_L1_ENTRY:          cycles = usec_to_ctrl_cycles(L1_ENTRY_TIMEOUT_US);
      TIMER_L1_EXIT:           cycles = usec_to_ctrl_cycles(L1_EXIT_TIMEOUT_US);
      TIMER_L2_READY:          cycles = usec_to_ctrl_cycles(L2_READY_TIMEOUT_US);
      TIMER_HOT_RESET:         cycles = usec_to_ctrl_cycles(HOT_RESET_MIN_HOLD_US);
      TIMER_LOOPBACK_ENTRY:    cycles = usec_to_ctrl_cycles(LOOPBACK_ENTRY_TIMEOUT_US);
      TIMER_LOOPBACK_EXIT:     cycles = usec_to_ctrl_cycles(LOOPBACK_EXIT_TIMEOUT_US);
      TIMER_DISABLED_HOLD:     cycles = usec_to_ctrl_cycles(DISABLED_MIN_HOLD_US);
      TIMER_GT_RESET:          cycles = usec_to_ctrl_cycles(GT_RESET_TIMEOUT_US);
      TIMER_GT_DETECT:         cycles = usec_to_ctrl_cycles(GT_DETECT_TIMEOUT_US);
      TIMER_GT_RATE:           cycles = usec_to_ctrl_cycles(GT_RATE_TIMEOUT_US);
      TIMER_GT_POWER:          cycles = usec_to_ctrl_cycles(GT_POWER_TIMEOUT_US);
      default:                 cycles = 1;
    endcase
    return sim_scaled_cycles(cycles, sim_scale);
  endfunction

  // Stable compatibility aliases used by the module interfaces; their source
  // values remain the single frozen constants above.
  localparam int unsigned PHY_TX_PACKET_SLOTS        = PHY_TX_WHOLE_PACKET_SLOTS;
  localparam int unsigned PHY_RX_PACKET_SLOTS        = PHY_RX_WHOLE_PACKET_SLOTS;
  localparam int unsigned TS_COUNT_POLLING_ACTIVE    = POLLING_ACTIVE_TS_QUAL_COUNT;
  localparam int unsigned TS_COUNT_POLLING_CONFIG    = POLLING_CONFIG_TS2_QUAL_COUNT;
  localparam int unsigned LOGICAL_IDLE_QUALIFY_COUNT = LOGICAL_IDLE_QUAL_COUNT;

  localparam int unsigned LTSSM_TIMEOUT_DETECT_QUIET      = usec_to_ctrl_cycles(DETECT_QUIET_MIN_US);
  localparam int unsigned LTSSM_TIMEOUT_DETECT_ACTIVE     = usec_to_ctrl_cycles(DETECT_ACTIVE_TIMEOUT_US);
  localparam int unsigned LTSSM_TIMEOUT_POLLING_ACTIVE    = usec_to_ctrl_cycles(POLLING_ACTIVE_TIMEOUT_US);
  localparam int unsigned LTSSM_TIMEOUT_POLLING_CONFIG    = usec_to_ctrl_cycles(POLLING_CONFIG_TIMEOUT_US);
  localparam int unsigned LTSSM_TIMEOUT_CONFIGURATION     = usec_to_ctrl_cycles(CONFIGURATION_TIMEOUT_US);
  localparam int unsigned LTSSM_TIMEOUT_RECOVERY_RCVRLOCK = usec_to_ctrl_cycles(RECOVERY_RCVRLOCK_TIMEOUT_US);
  localparam int unsigned LTSSM_TIMEOUT_RECOVERY_RCVRCFG  = usec_to_ctrl_cycles(RECOVERY_RCVRCFG_TIMEOUT_US);
  localparam int unsigned LTSSM_TIMEOUT_RECOVERY_SPEED    = usec_to_ctrl_cycles(RECOVERY_SPEED_TIMEOUT_US);
  localparam int unsigned LTSSM_TIMEOUT_RECOVERY_IDLE     = usec_to_ctrl_cycles(RECOVERY_IDLE_TIMEOUT_US);

endpackage
