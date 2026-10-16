# PCIe Gen1/Gen2 8b/10b x1 Root Port PHY

This repository implements the frozen contract in
`E:\08_obsidian\01_PCIE\PCIe Gen2 x1 Root Port 物理层（PHY）设计 SPEC.md`.
It is a Downstream/Root-Port, x1, full-duplex, Gen1/Gen2 design. There is no
Gen3 128b/130b path, multilane striping/reversal/deskew, or DLL-visible ordered-set
interface.

## Clock-domain architecture

The design keeps three explicit domains:

- `link_clk_i`: DLL packet streams and whole-packet TX/RX buffers;
- GT-produced `phy_sym_clk_o`: continuous two-character TX/RX datapaths, ordered
  sets, scrambling, framing and SKP scheduling;
- stable `ctrl_clk_i`: LTSSM, protocol timers, GT transaction sequencing, management,
  status and error CSRs.

Multi-bit domain crossings use asynchronous FIFOs or held bundled-data snapshots.
Pulses are first captured in their source domain and then transferred with a
request/acknowledge toggle; a Gray-coded overflow counter replays every observable
bridge overrun into the control-domain error path. The long-lived ordered-set
command crosses as a coherent desired-level snapshot so an unchanged command is
not reissued as duplicate batches. Each domain combines its infrastructure reset
with `port_reset_ni`, asserts asynchronously, and deasserts synchronously. The
symbol clock is produced by the GT adapter; fabric RTL does not synthesize a
substitute clock.

## Data and control flow

TX accepts only DLL packet bytes and boundaries. `phy_tx_packet_buffer_cdc`
validates and commits a complete packet before publishing it in the symbol domain.
`phy_tx_framer_scheduler` emits STP/SDP, payload and END/EDB without an in-packet
bubble. Its fixed arbitration is forced state sequence/EIOS/Compliance, then due
SKP, then an admitted packet, then scrambled D00.0 Logical Idle.

`phy_scrambler_descrambler` applies the PCIe Gen1/Gen2 LFSR rules per character:
COM resets, K bypasses, SKP holds, and ordinary data advances eight bits. The GT
adapter owns 8b/10b, running disparity, comma alignment and the sole RX SKP-deleting
elastic buffer.

RX classifies code errors before K/disparity interpretation, identifies ordered-set
candidates separately from packet framing, descrambles packet/logical-idle data,
and commits a packet only after END/EDB and whole-packet error validation.
`phy_rx_packet_buffer_cdc` never publishes a fatally contaminated packet.

The LTSSM consumes only qualified events. It controls ordered-set selection and
issues Detect/Rate/Power requests through `phy_clock_reset_rate_ctrl`; it never
parses raw symbols or drives a GT primitive. The GT adapter serializes those native
transactions and binds each result atomically to its operation context.

## Source map

- `rtl/**/*.v`: Verilog-2005 implementation; shared encodings, packed records,
  timing/count/capacity constants and pure helpers are module-local. RTL has no
  SystemVerilog package dependency.
- `tb/tb_common/pcie_gen12_phy_pkg.sv` and
  `tb/tb_common/pcie_gen12_phy_timing_pkg.sv`: unchanged SystemVerilog compatibility
  packages for the existing testbenches, excluded from synthesis.
- `rtl/gt/gty_behavioral_model.v`: simulation-only digital GT contract model.
- `rtl/gt/pcie_gty_adapter_x1.v`: behavioral/synthesis dual path and normalized GT
  boundary.
- `rtl/phy_*`: packet CDC, framing, scrambling, ordered sets, SKP accounting,
  clock/reset/rate control, timers, LTSSM, and status/error logic.
- `rtl/pcie_gen12_phy_x1_rp.v`: exact SPEC 4.1–4.5 external boundary and all CDC
  integration.
- `tb/golden`: independent scrambler, 8b/10b and ordered-set reference models.
- `tb/tb_common` and `tb/tb_PHY_V_001` … `tb/tb_PHY_V_015`: self-checking
  verification sources.
- `constr`, `scripts`: board template, source ordering, project creation and xsim
  launch inputs.

## Compilation order

Use `scripts/filelist.f`: 14 Verilog RTL files and 30 SystemVerilog verification
files. The required order is TB compatibility packages, behavioral GT model, GT
adapter, symbol/link/control modules, top, golden models, common verification
sources, and finally the selected testbench top. Do not allow a simulator to infer
package ordering from directory enumeration. `scripts/create_project.tcl` audits
all `.v`/`.sv` sources, requires `.v` under `rtl/`, sets RTL file type to `Verilog`
and verification file type to `SystemVerilog`, and keeps TB packages in `sim_1`.

## Future Vivado simulation

From the repository root, set `PCIE_FPGA_PART` to the final full part name, then:

```tcl
vivado -mode batch -source scripts/create_project.tcl
vivado -mode batch -source scripts/run_sim.tcl -tclargs PHY_V_001
vivado -mode batch -source scripts/run_sim.tcl -tclargs all
```

The simulation fileset defines `GT_BEHAV_MODEL`, so no generated Wizard output is
needed for the digital testbench path. Each testbench owns a finite watchdog and
must terminate with a checked PASS/FAIL result; `PHY-V-015` explicitly leaves the
E3 board portion unrun.

## Future GT Wizard integration and synthesis

1. Generate a GTYE4 Wizard configuration for the final device/quad using
   `scripts/gt_wizard_notes.md`; replace every `TODO(Wizard)` item as one reviewed
   unit rather than guessing primitive attributes independently.
2. Freeze board pins, GT LOC, reference-clock topology and clock periods in
   `constr/pcie_gen12_phy_x1_rp.xdc`, then review every CDC exception against the
   post-Wizard hierarchy.
3. Run synthesis/implementation with `pcie_gen12_phy_x1_rp` as top and without
   `GT_BEHAV_MODEL`; treat all critical warnings, unconstrained paths, CDC findings,
   and GT DRCs as failures until dispositioned.

## Present evidence and limits

On 2026-10-16, the RTL was converted to Verilog-2005 and the original SV testbench
sources were retained. Strict RTL compilation and mixed-language elaboration pass
in all four `GT_BEHAV_MODEL` / `SYNTHESIS` configurations, apart from the same three
unavailable vendor primitives in the native GT path. Top-level ports and the
known-valued parameters exercised by the existing testbenches match the SV baseline.

All 15 original and converted testbench tops compile and have identical observed
Verilator results: seven pass and eight fail at the same first checks and times.
These pre-existing failures are retained to keep this change limited to the RTL
language conversion. This is regression evidence, not a full equivalence proof or
a passing protocol suite. `PHY-V-015` covers pre-board E1 only; E3 remains `NOT_RUN`.
No Vivado/XSim, synthesis, implementation, timing/CDC closure or hardware pass is
claimed. See [the migration record](verilog-migration.md) for commands, individual
results and language compatibility details, and [deviations](deviations.md) for
the remaining integration assumptions.
