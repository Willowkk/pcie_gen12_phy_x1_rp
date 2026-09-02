# SystemVerilog-2017 compile order. Paths are relative to the project root.
# Keep every .sv source exactly once; scripts/create_project.tcl audits this list.
rtl/pkg/pcie_gen12_phy_pkg.sv
rtl/pkg/pcie_gen12_phy_timing_pkg.sv

# Synthesizable hierarchy. GT_BEHAV_MODEL is defined only for sim_1.
rtl/gt/gty_behavioral_model.sv
rtl/gt/pcie_gty_adapter_x1.sv
rtl/phy_scrambler_descrambler.sv
rtl/phy_tx_packet_buffer_cdc.sv
rtl/phy_tx_framer_scheduler.sv
rtl/phy_rx_classifier_deframer.sv
rtl/phy_rx_packet_buffer_cdc.sv
rtl/phy_ordered_set.sv
rtl/phy_skp_clock_comp.sv
rtl/phy_clock_reset_rate_ctrl.sv
rtl/phy_timer_bank.sv
rtl/phy_ltssm_ctrl.sv
rtl/phy_status_error.sv
rtl/pcie_gen12_phy_x1_rp.sv

# Reference packages and common verification infrastructure, providers before
# consumers.
tb/golden/golden_scrambler.sv
tb/golden/golden_8b10b.sv
tb/golden/golden_ordered_set.sv
tb/tb_common/phy_tb_pkg.sv
tb/tb_common/phy_clocking.sv
tb/tb_common/phy_dll_if.sv
tb/tb_common/phy_ctrl_if.sv
tb/tb_common/phy_gt_norm_if.sv
tb/tb_common/phy_gt_model_probe.sv
tb/tb_common/phy_scoreboards.sv
tb/tb_common/phy_assertions.sv
tb/tb_common/phy_watchdog.sv
tb/tb_common/phy_top_harness.sv

# V008 defines phy_ltssm_tb_fixture and therefore precedes V009--V012.
tb/tb_PHY_V_001/tb_PHY_V_001.sv
tb/tb_PHY_V_002/tb_PHY_V_002.sv
tb/tb_PHY_V_003/tb_PHY_V_003.sv
tb/tb_PHY_V_004/tb_PHY_V_004.sv
tb/tb_PHY_V_005/tb_PHY_V_005.sv
tb/tb_PHY_V_006/tb_PHY_V_006.sv
tb/tb_PHY_V_007/tb_PHY_V_007.sv
tb/tb_PHY_V_008/tb_PHY_V_008.sv
tb/tb_PHY_V_009/tb_PHY_V_009.sv
tb/tb_PHY_V_010/tb_PHY_V_010.sv
tb/tb_PHY_V_011/tb_PHY_V_011.sv
tb/tb_PHY_V_012/tb_PHY_V_012.sv
tb/tb_PHY_V_013/tb_PHY_V_013.sv
tb/tb_PHY_V_014/tb_PHY_V_014.sv
tb/tb_PHY_V_015/tb_PHY_V_015.sv
