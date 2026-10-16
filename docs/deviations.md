# Deviations and integration assumptions

The frozen design contract is `E:\08_obsidian\01_PCIE\PCIe Gen2 x1 Root Port 物理层（PHY）设计 SPEC.md`.
This file records every point that cannot be frozen from that document alone. None
of the entries below permits Gen3+, multilane operation, a DLL character interface,
or a second RX SKP-deleting elastic buffer.

## D-001 — Board and final FPGA identity are not frozen

The exact FPGA part/package/speed grade, GTY channel and quad, reference-clock
frequency/topology, transceiver LOCs, and package pins are not stated in the SPEC.
`scripts/create_project.tcl` therefore requires `PCIE_FPGA_PART`; the XDC requires
the integrator to provide board-specific LOC/pin data. No invented package pin or
GT channel is supplied.

## D-002 — GT Wizard-owned values remain deliberately unresolved

The synthesis branch instantiates the GTYE4 primitives so that the architectural
port mapping is explicit. Values owned by the final Vivado GT Wizard — primitive
attributes, PLL selection, CPLL/QPLL wiring, clock-correction sequence attributes,
reset helper details, and final width/tie-off choices — are marked only as
`TODO(Wizard)` inside `pcie_gty_adapter_x1.v`. This is required by SPEC 6.7 rather
than an unfinished RTL algorithm. `scripts/gt_wizard_notes.md` is the replacement
checklist. Any concrete constants or high-bit tie-offs adjacent to those markers
exist only so the ungenerated branch remains valid Verilog; they are not
frozen hardware values and must all be replaced as one Wizard-reviewed unit before
synthesis or implementation evidence is accepted.

## D-003 — System-integration limits use configurable project defaults

The SPEC explicitly requires several values to be frozen by the system integration
contract but does not supply those values. The Verilog RTL retains the following
conservative defaults as module-local constants; the unchanged TB compatibility
timing package carries the same values:

- `CTRL_CLK_HZ = 100_000_000`;
- `PHY_MAX_PACKET_BYTES = 4128`;
- two whole-packet TX slots and two whole-packet RX slots;
- `PHY_RX_BACKPRESSURE_MAX_CYCLES = 4096`;
- bounded retry counts, GT/reset/power watchdogs, and debounce/filter depths defined
  in the RTL and `tb/tb_common/pcie_gen12_phy_timing_pkg.sv`.

These are implementation parameters, not claims that PCIe Base Specification 2.1
mandates those exact integration limits. Protocol timing/count values and helper
arithmetic are preserved in module-local Verilog declarations; the SystemVerilog
timing package is used only by verification. `SIM_TIME_SCALE` affects testbench
elaboration only and is forced to unity under synthesis.

## D-004 — Behavioral GT model is a digital contract model

`gty_behavioral_model.v` models the normalized character/control contract,
8b/10b legality, running disparity, comma alignment, bounded native operations,
polarity, electrical-idle indication, and SKP-only elastic-buffer correction. It
does not model analog termination, jitter, eye closure, CDR dynamics, real serial
channel loss, or electrical compliance. Its scalar serial pins convey activity;
the decoded-character stream is an internal deterministic digital loopback model.
Those analog/electrical properties remain board and GT Wizard verification work.

## D-005 — PHY-V-015 needs hardware

The `tb_PHY_V_015` source performs only the pre-board E1 contract/configuration
checks and reports the E3 hardware portion as `NOT_RUN`. Real Gen1/Gen2 endpoint
interoperability, repeated cold starts, retraining, fallback, and sustained traffic
must be executed on the final FPGA board. This repository never reports that test
as passed by RTL simulation.

## D-006 — No local Vivado execution evidence

The initial 2026-09-02 delivery contained static evidence only. During the
2026-10-16 Verilog conversion, open-source compilation and Verilator regressions
were run against both the original SV commit and the converted sources. Seven
tests pass; eight stop at identical pre-existing failures in both versions.
The detailed boundary and results are in `docs/verilog-migration.md`.
No Vivado/XSim, synthesis, implementation, GT Wizard generation, timing/CDC closure
or board run was performed. The Tcl/XDC sources remain inputs for those steps.

## D-007 — GT TX-buffer fault reuses the frozen GT-reset error class

SPEC 8.1 defines no dedicated TX-buffer error code. A GT-reported TX-buffer fault
therefore maps to `8'h0D` (`ERR_GT_RESET_TIMEOUT`), whose frozen action is the
required full-GT reset and safe-port fallback. This preserves the required action,
severity, first-error priority, and LTSSM destination without inventing an error
code outside the frozen `8'h01`–`8'h13` namespace; the symbolic name is necessarily
broader than this particular GT fault source.
