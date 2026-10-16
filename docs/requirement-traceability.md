# Requirement traceability

This table is the implementation map for every frozen `PHY-CAP`, `PHY-DP`,
`PHY-OS`, `PHY-LT`, `PHY-GT`, `PHY-RST`, `PHY-ERR`, `PHY-DBG`, `PHY-INV`, and
`PHY-V` identifier. A TB reference identifies verification intent, not a passing
requirement. The 2026-10-16 original/converted simulation results, including eight
pre-existing failures, are recorded separately in `docs/verilog-migration.md`.

## Cross-cutting invariants

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-INV-001 | `phy_ltssm_ctrl`: cold-start Gen1 state/rate policy and Gen2 request guard; `phy_clock_reset_rate_ctrl`: committed current-rate result | `tb_PHY_V_009`: Gen1 prerequisite and fallback checks |
| PHY-INV-002 | `phy_ltssm_ctrl`: separate link-context and L0-only data-active equations; `phy_status_error`: coherent link-domain snapshot | `tb_PHY_V_008`, `tb_PHY_V_010`, `tb_PHY_V_013` |
| PHY-INV-003 | Top `dll_tx_*`/`dll_rx_*` ports contain bytes/boundaries only; ordered-set/K/electrical-idle signals remain internal | Top-interface assertion set in `tb_common/phy_assertions.sv` |
| PHY-INV-004 | GT normalized TX has `data/is_k` and no ready; `phy_tx_framer_scheduler` always selects forced OS, due SKP, committed packet, or Logical Idle | `tb_PHY_V_003`, `tb_PHY_V_004` |
| PHY-INV-005 | `phy_ltssm_ctrl` requests Receiver Detect only in Detect.Active; L0 loss uses EI/lock/decode events | `tb_PHY_V_002`, `tb_PHY_V_010` |
| PHY-INV-006 | `phy_clock_reset_rate_ctrl`, GT adapter and LTSSM use busy/done/fail plus timer-bank timeout for every operation | `tb_PHY_V_002`, `tb_PHY_V_009`, `tb_PHY_V_011` |
| PHY-INV-007 | `gty_behavioral_model` elastic queue changes occupancy only for complete SKP ordered sets; no PL deletion buffer exists | `tb_PHY_V_007` sequence scoreboard |
| PHY-INV-008 | RX classifier accumulates packet fatal state; RX packet CDC publishes only committed clean/EDB-valid packets | `tb_PHY_V_005`, `tb_PHY_V_013` |

## Capability

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-CAP-001 | `pcie_gen12_phy_pkg`: downstream-role training defaults; `phy_ltssm_ctrl`: Root-Port command and training behavior | `tb_PHY_V_008`, `tb_PHY_V_012` |
| PHY-CAP-002 | Independent TX and RX packet CDC/datapaths instantiated concurrently at x1 width | `tb_PHY_V_013` simultaneous-flow case |
| PHY-CAP-003 | `phy_clock_reset_rate_ctrl` and GT adapter implement committed Gen1/Gen2 rate state | `tb_PHY_V_009` |
| PHY-CAP-004 | Reset/Enable path enters Detect at Gen1 before any Recovery.Speed request | `tb_PHY_V_001`, `tb_PHY_V_008`, `tb_PHY_V_009` |
| PHY-CAP-005 | LTSSM bounded Gen2 retry and Gen1 fallback; `phy_current_rate_o` changes only after full completion | `tb_PHY_V_009` Gen1-only/rate-fail cases |
| PHY-CAP-006 | GT adapter synchronizes `gt_rx_polarity_invert_i`; no multilane logic exists | `tb_PHY_V_005` polarity case |

## Datapath

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-DP-001 | `phy_tx_framer_scheduler` inserts STP/SDP and END/EDB; `phy_rx_classifier_deframer` reverses framing | `tb_PHY_V_003`, `tb_PHY_V_013` |
| PHY-DP-002 | TX/RX packet CDC plus two-character framers connect packet beats to normalized GT character beats | `tb_PHY_V_003`, `tb_PHY_V_013` |
| PHY-DP-003 | `phy_scrambler_descrambler`: seed `16'hFFFF`, centralized tap helpers, eight bit steps/ordinary character | `golden_scrambler.sv`, `tb_PHY_V_004` |
| PHY-DP-004 | Scrambler per-character actions implement COM reset, K bypass, SKP hold and ordinary advance | `tb_PHY_V_004` focused action cases |
| PHY-DP-005 | 8b/10b and running disparity exist only in GT adapter/model; PL sends decoded 8-bit characters | `golden_8b10b.sv`, `tb_PHY_V_005` |
| PHY-DP-006 | Adapter provides aligned per-character K/code/disparity/comma sidebands | `tb_PHY_V_005` |
| PHY-DP-007 | Scheduler fallback is D00.0 and scrambler applies normal data advance; Electrical Idle is a separate GT control | `tb_PHY_V_004`, `tb_PHY_V_008` |

## Ordered sets and clock compensation

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-OS-001 | `phy_ordered_set` has generators/detectors for TS1, TS2, SKP, FTS, EIOS and EIEOS | `golden_ordered_set.sv`, `tb_PHY_V_006` |
| PHY-OS-002 | `pcie_ts_fields_t` and ordered-set parser carry Link, Lane, N_FTS, Rate ID and Training Control | `tb_PHY_V_006` field sweep |
| PHY-OS-003 | Hot Reset/Loopback/Disable/Speed Change are TS control bits in `pcie_ts_fields_t`, not OS enum members | `tb_PHY_V_006`, `tb_PHY_V_012` |
| PHY-OS-004 | Ordered-set RX validates complete length/type/fields and exposes only threshold-qualified events | `tb_PHY_V_006` truncation/wrong-order/count cases |
| PHY-OS-005 | LTSSM selects Gen2 Recovery.RcvrLock context; `phy_ordered_set` owns the exact 32-TS1/EIEOS cadence while the scheduler keeps due-SKP priority independent | `tb_PHY_V_006`, `tb_PHY_V_009`, `tb_PHY_V_010` |
| PHY-OS-006 | `phy_skp_clock_comp` produces deadlines; scheduler inserts only at legal boundaries; GT model owns RX add/delete | `tb_PHY_V_007` |
| PHY-OS-007 | SKP module and GT normalized status emit missed deadline, illegal correction and buffer errors | `tb_PHY_V_007`, `tb_PHY_V_014` |

## LTSSM

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-LT-001 | `phy_ltssm_ctrl` main-state enum and transitions cover Detect, Polling, Configuration, L0, Recovery, Disabled | `tb_PHY_V_008`, `tb_PHY_V_010`, `tb_PHY_V_012` |
| PHY-LT-002 | Explicit L0s, L1, L2/L3 Ready, Hot Reset, Loopback and Polling.Compliance state/substate cases | `tb_PHY_V_011`, `tb_PHY_V_012` |
| PHY-LT-003 | Configuration and Recovery substate enums/cases remain distinct, including Recovery.Speed | `tb_PHY_V_008`, `tb_PHY_V_009` |
| PHY-LT-004 | Each LTSSM case owns hold/exit, timer ID and timeout/failure transition; default recovery is explicit | `tb_PHY_V_008` through `tb_PHY_V_012` |
| PHY-LT-005 | L0 transition logic consumes debounced electrical-idle, alignment-loss and sustained-decode events | `tb_PHY_V_010` |
| PHY-LT-006 | Recovery.Speed request/complete/fail route is LTSSM → controller → adapter → controller → LTSSM | `tb_PHY_V_009` |
| PHY-LT-007 | Disabled feature policies return rejected/failed management responses; enabled maintenance states have bounded exits | `tb_PHY_V_011`, `tb_PHY_V_012` |

## GT adapter

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-GT-001 | Synthesis branch of `pcie_gty_adapter_x1` contains the only `IBUFDS_GTE4`, `BUFG_GT` and `GTYE4_CHANNEL` instances | Future Vivado DRC/implementation; not a behavioral-TB claim |
| PHY-GT-002 | Adapter/controller Receiver Detect FSMs provide request, busy, atomic done/result, fail/fault and timeout | `tb_PHY_V_002` |
| PHY-GT-003 | Adapter maps TX Electrical Idle and synchronizes/deglitches RX Electrical Idle | `tb_PHY_V_001`, `tb_PHY_V_010`, `tb_PHY_V_011` |
| PHY-GT-004 | `phy_power_state_e` P0/P0s/P1/P2 and LTSSM mapping are separate state machines | `tb_PHY_V_011` |
| PHY-GT-005 | Rate FSM exposes request/busy/done/fail; current rate commits after clock/reset/buffer reinitialization | `tb_PHY_V_009` |
| PHY-GT-006 | De-emphasis, swing, margin, compliance and diagnostic loopback controls terminate at adapter | `tb_PHY_V_005`, `tb_PHY_V_012` |
| PHY-GT-007 | Adapter source-domain context captures native PHYSTATUS/RXSTATUS before event transfer | `tb_PHY_V_002`, `tb_PHY_V_009` |
| PHY-GT-008 | Repository scan confines GT primitives/Wizard-native wiring to `rtl/gt/pcie_gty_adapter_x1.v` | Static source-boundary audit |
| PHY-GT-009 | All electrical/CDR/equalizer attributes are Wizard-owned items in `gt_wizard_notes.md`; no Gen3 Equalization state exists | Future Wizard review and Vivado DRC |

## Reset and CDC

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-RST-001 | Per-domain reset synchronizers asynchronously assert and synchronously release combined infrastructure/port resets | `tb_PHY_V_001` phase sweep |
| PHY-RST-002 | Controller safe gates force TX Electrical Idle and disable packet admission/commit while unready/rate-changing/fatal | `tb_PHY_V_001`, `tb_PHY_V_009`, `tb_PHY_V_014` |
| PHY-RST-003 | Packet paths use Gray-pointer asynchronous FIFOs; events use toggle/ack CDC with counted Gray overflow replay; coherent status/TS/OS bundles use held snapshots | CDC assertions plus future Vivado CDC report |

## Error and debug

| ID | RTL evidence | Verification evidence |
|---|---|---|
| PHY-ERR-001 | `phy_status_error` implements first-error latch, W1C sticky bits, saturating per-code counters, recent-event history and held error output | `tb_PHY_V_014` |
| PHY-ERR-002 | `pcie_error_code_e` defines every `8'h01`–`8'h13`; producers attach unique categories/info | `tb_PHY_V_014` code/category sweep |
| PHY-ERR-003 | RX fatal-drop gate and LTSSM/controller fatal requests route errors to Recovery, Detect or reset-safe behavior | `tb_PHY_V_010`, `tb_PHY_V_013`, `tb_PHY_V_014` |
| PHY-DBG-001 | Status/CSR paths expose state, substate, reason, timer, rate, lock, buffer levels and error records | `tb_PHY_V_014` CSR read/write/error cases |

## Verification IDs

| ID | Self-checking source | Checked scenario and principal oracle |
|---|---|---|
| PHY-V-001 | `tb/tb_PHY_V_001/tb_PHY_V_001.sv` | Reset/clock phase safety and GT-not-ready packet gate; assertions plus watchdog |
| PHY-V-002 | `tb/tb_PHY_V_002/tb_PHY_V_002.sv` | Detect present/absent/timeout/invalid status and atomic pairing; transaction scoreboard |
| PHY-V-003 | `tb/tb_PHY_V_003/tb_PHY_V_003.sv` | TLP/DLLP framing, odd byte, abort and malformed input; character-stream scoreboard |
| PHY-V-004 | `tb/tb_PHY_V_004/tb_PHY_V_004.sv` | Scrambler vector, COM/K/SKP actions and TX→RX inversion; `golden_scrambler` |
| PHY-V-005 | `tb/tb_PHY_V_005/tb_PHY_V_005.sv` | Legal D/K, both RD states, errors, comma and polarity; `golden_8b10b` |
| PHY-V-006 | `tb/tb_PHY_V_006/tb_PHY_V_006.sv` | Six ordered-set types, fields, counts and malformed sequences; `golden_ordered_set` |
| PHY-V-007 | `tb/tb_PHY_V_007/tb_PHY_V_007.sv` | Clock compensation, SKP-only mutation, ordering and buffer fault injection; sequence scoreboard |
| PHY-V-008 | `tb/tb_PHY_V_008/tb_PHY_V_008.sv` | Gen1 Detect→Polling→Configuration→L0 plus hold/timeout/fallback; LTSSM transition oracle |
| PHY-V-009 | `tb/tb_PHY_V_009/tb_PHY_V_009.sv` | Up/down rate, Gen1-only, rate/clock/reset failures; controller/LTSSM transaction oracle |
| PHY-V-010 | `tb/tb_PHY_V_010/tb_PHY_V_010.sv` | EI, alignment, sustained decode, PLL/fault and retraining; state/error assertions |
| PHY-V-011 | `tb/tb_PHY_V_011/tb_PHY_V_011.sv` | L0s/L1/L2 entry/exit, FTS and Electrical Idle; PM handshake/state assertions |
| PHY-V-012 | `tb/tb_PHY_V_012/tb_PHY_V_012.sv` | Hot Reset, Disabled, Loopback and Compliance; management response/state assertions |
| PHY-V-013 | `tb/tb_PHY_V_013/tb_PHY_V_013.sv` | Whole-packet commit/drop, protocol stability, max frame and bounded RX backpressure; packet scoreboard |
| PHY-V-014 | `tb/tb_PHY_V_014/tb_PHY_V_014.sv` | First/sticky/W1C/saturation/history/overflow/priority and CSR errors; register oracle |
| PHY-V-015 | `tb/tb_PHY_V_015/tb_PHY_V_015.sv` | E1 pre-board configuration checks only; E3 board interoperability explicitly `NOT_RUN` |
