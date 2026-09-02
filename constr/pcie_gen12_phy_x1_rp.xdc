# Board-independent timing constraints. Board pin/package/GT locations must be
# supplied through the approved hardware baseline, never guessed here.
create_clock -name ctrl_clk -period 10.000 [get_ports ctrl_clk_i]
create_clock -name link_clk -period 4.000  [get_ports link_clk_i]

if {[info exists ::env(PCIE_REFCLK_PERIOD_NS)]} {
  set pcie_refclk_period_ns $::env(PCIE_REFCLK_PERIOD_NS)
} else {
  set pcie_refclk_period_ns 10.000
}
create_clock -name pcie_refclk -period $pcie_refclk_period_ns [get_ports pcie_refclk_p_i]

# The generated GT Wizard owns TXOUTCLK/RXOUTCLK and BUFG_GT generated-clock
# definitions. Import its XDC unchanged, then verify 125/250 MHz clock modes.

# Optional exact GT placement supplied only after schematic/part freeze.
if {[info exists ::env(PCIE_GTY_CHANNEL_LOC)] && $::env(PCIE_GTY_CHANNEL_LOC) ne ""} {
  set gty_cells [get_cells -quiet -hier -filter {REF_NAME == GTYE4_CHANNEL}]
  if {[llength $gty_cells] != 1} {
    error "Expected exactly one GTYE4_CHANNEL before applying PCIE_GTY_CHANNEL_LOC."
  }
  set_property LOC $::env(PCIE_GTY_CHANNEL_LOC) $gty_cells
}

# Asynchronous reset assertion is intentionally untimed. Synchronous-release
# stages are timed by their destination clocks. Vivado appends _reg and a bit
# index to these RTL names. Keep the names explicit and fail if hierarchy drift
# prevents the template from resolving any reviewed release synchronizer.
set reset_release_first_stage_cells [get_cells -quiet -hier -regexp \
  {.*(ctrl_reset_sync_q_reg\[0\]|link_reset_sync_q_reg\[0\]|sym_domain_release_sync_q_reg\[0\]|link_domain_release_sync_q_reg\[0\]).*}]
if {[llength $reset_release_first_stage_cells] == 0} {
  error "Reset-release synchronizer constraint matched no cells; review synthesized names."
}
set reset_async_control_pins [get_pins -quiet \
  -of_objects $reset_release_first_stage_cells \
  -filter {REF_PIN_NAME == CLR || REF_PIN_NAME == PRE || REF_PIN_NAME == R || REF_PIN_NAME == S}]
if {[llength $reset_async_control_pins] == 0} {
  error "Reset-release synchronizers have no recognized asynchronous control pins."
}
set_false_path -from [get_ports {ctrl_rst_ni link_rst_ni port_reset_ni}] \
  -to $reset_async_control_pins

# Each event bridge samples the source-domain reset level in the destination
# clock domain solely to establish a safe Gray-counter baseline after reset.
set reset_status_first_stage_cells [get_cells -quiet -hier -regexp \
  {.*d_source_reset_sync_q_reg\[0\].*}]
if {[llength $reset_status_first_stage_cells] == 0} {
  error "Event-bridge source-reset synchronizer constraint matched no cells."
}
set_false_path -to [get_pins -quiet -of_objects $reset_status_first_stage_cells \
  -filter {REF_PIN_NAME == D}]

# Gray-pointer buses must cross within one source-clock period so implementation
# cannot destroy the single-bit-change property. Match only the named CDC
# synchronizer first stages; review the resolved object lists in Vivado.
set gray_source_cells [get_cells -quiet -hier -regexp \
  {.*(wr_gray_q_reg|rd_gray_q_reg|wr_ptr_gray_q_reg|rd_ptr_gray_q_reg|s_overflow_gray_q_reg).*}]
set gray_first_stage_cells [get_cells -quiet -hier -regexp \
  {.*(wr_gray_sync1_q_reg|rd_gray_sync1_q_reg|wr_gray_sym_meta_q_reg|rd_gray_link_meta_q_reg|d_overflow_gray_meta_q_reg).*}]
if {[llength $gray_source_cells] == 0 ||
    [llength $gray_first_stage_cells] == 0} {
  error "Gray CDC max-delay constraint matched no source or first-stage cells."
}
set_max_delay -datapath_only 4.000 \
  -from [get_pins -quiet -of_objects $gray_source_cells -filter {REF_PIN_NAME == Q}] \
  -to [get_pins -quiet -of_objects $gray_first_stage_cells -filter {REF_PIN_NAME == D}]

# Single-bit level/toggle crossings are cut only at their first synchronizer
# stage. Never false-path the destination-domain consumers or a whole clock.
set single_bit_first_stage_cells [get_cells -quiet -hier -regexp \
  {.*(crr_admission_link_sync_q_reg\[0\]|flush_link_sync_q_reg\[0\]|flush_sym_sync_q_reg\[0\]|flush_link_ack_ctrl_sync_q_reg\[0\]|flush_sym_ack_ctrl_sync_q_reg\[0\]|tx_quiesced_ctrl_sync_q_reg\[0\]|tx_capture_ctrl_sync_q_reg\[0\]|rx_active_ctrl_sync_q_reg\[0\]|rx_aligned_ctrl_sync_q_reg\[0\]|s_request_sync_q_reg\[0\]|d_ack_sync_q_reg\[0\]|native_ctrl_req_sync_q_reg\[0\]|native_ctrl_ack_sync_q_reg\[0\]|phystatus_toggle_sync_q_reg\[0\]|txratedone_toggle_sync_q_reg\[0\]|rxratedone_toggle_sync_q_reg\[0\]|txbuf_fault_toggle_sync_q_reg\[0\]|txresetdone_sync_q_reg\[0\]|rxresetdone_sync_q_reg\[0\]|cplllock_sync_q_reg\[0\]|gtpowergood_sync_q_reg\[0\]|txei_feedback_sync_q_reg\[0\]|rxelecidle_sync_q_reg\[0\]|data_enable_sym_q_reg\[0\]|txei_feedback_sym_q_reg\[0\]|rxei_gate_sym_q_reg\[0\]|sym_alive_link_meta_q_reg|link_alive_sym_meta_q_reg|capture_active_sym_meta_q_reg|gt_sym_rst_ctrl_meta_q_reg).*}]
if {[llength $single_bit_first_stage_cells] == 0} {
  error "Single-bit CDC constraint matched no first-stage synchronizers."
}
set_false_path -to [get_pins -quiet -of_objects $single_bit_first_stage_cells \
  -filter {REF_PIN_NAME == D}]

# Bundled payload is held until the synchronized request is acknowledged. Keep
# the source-to-capture datapath below one fastest symbol-clock period; the
# handshake, not independent per-bit synchronization, establishes coherence.
set held_bundle_source_cells [get_cells -quiet -hier -regexp \
  {.*(s_payload_hold_q_reg|native_ctrl_source_q_reg|phystatus_value_sym_q_reg).*}]
set held_bundle_capture_cells [get_cells -quiet -hier -regexp \
  {.*(d_payload_o_reg|native_ctrl_applied_q_reg|phystatus_value_meta_q_reg).*}]
if {[llength $held_bundle_source_cells] == 0 ||
    [llength $held_bundle_capture_cells] == 0} {
  error "Bundled-data CDC max-delay constraint matched no source or capture cells."
}
set_max_delay -datapath_only 4.000 \
  -from [get_pins -quiet -of_objects $held_bundle_source_cells -filter {REF_PIN_NAME == Q}] \
  -to [get_pins -quiet -of_objects $held_bundle_capture_cells -filter {REF_PIN_NAME == D}]

# Physical pin IOSTANDARD/LOC constraints and the GT REFCLK site are absent by
# design until the board hardware baseline is frozen.
