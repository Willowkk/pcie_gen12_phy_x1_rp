# RTL language migration — 2026-10-16

The reference is commit `156401f995a20db097c4df4cd8c8c4ff0bf0c1a2`.
This change converts the RTL language while retaining the existing datapath,
state encodings, priorities, clocks, resets, CDC handshakes, default constants,
module names and ports. Existing testbench behavior is retained, including its
observed failures.

## Source organization

- `rtl/` contains 14 `.v` files defining 17 modules, including the three CDC
  helpers in `pcie_gen12_phy_x1_rp.v`. It contains no SystemVerilog sources.
- Packed structures and enums become Verilog vectors and local constants;
  package functions become module-local functions. Cast helper functions retain
  the original truncation, extension and signedness. Sequential blocks use
  `always`; combinational blocks use `always @*` with an initialization trigger
  to retain the original `always_comb` time-zero evaluation.
- The two original packages are byte-identical copies under `tb/tb_common/`.
  They serve the SV testbenches and golden models and are excluded from the
  Vivado synthesis fileset. All previously existing TB files are unchanged.
- `GT_BEHAV_MODEL` still selects the GT behavior model; the default adapter
  branch still instantiates the same vendor primitives. `SYNTHESIS` still
  selects unscaled timing. Wizard placeholders and their TODO comments remain.
- Vivado scripts assign RTL files the `Verilog` type and verification sources
  the `SystemVerilog` type. Recreate an older Vivado project before simulation.

The mechanical lowering used [sv2v v0.0.13](https://github.com/zachjs/sv2v/tree/v0.0.13)
separately for all four macro configurations; the resulting conditional branches
were retained in the Verilog files. Every module has `timescale 1ns/1ps`, matching
the original `timeunit` and `timeprecision`. The remaining SV `2ns`/`4ns` literals
were expressed as numeric delays under that timescale. The three-bit `$onehot0`
operation was expressed as pairwise comparisons of known 1 bits, preserving its
behavior for X and Z inputs.

Verilog has no standard two-state `bit`/`int` type. Its parameter vectors are
four-state; parameter values, widths and signedness match for every known-valued
override exercised here. Equivalence for hypothetical X/Z parameter overrides
is not claimed. Verilog also has no `$fatal`/`$error` severity API: the GT model's
invalid-parameter guards report their diagnostics and call `$stop(1)`, while
the original nonfatal TX parameter errors remain printed diagnostics. Batch
runners must treat a stop or an error diagnostic as failure; Icarus `vvp -N`
makes a stop exit unsuccessfully. This concerns simulation diagnostics and does
not change synthesizable datapath/control behavior.

## Compilation and interface checks

Run from the repository root with Python 3.10+ and pyslang 11.0.0 installed:

```text
python scripts/check_verilog.py
python scripts/check_verilog.py --baseline 156401f --iverilog iverilog
```

The baseline commit must be available locally. The checker extracts it into a
temporary directory and checks:

- The manifest exactly covers 14 Verilog RTL and 30 SV verification files.
- The relocated packages match their original bytes.
- RTL parses as IEEE 1364-2005 in all four macro combinations, and all mixed
  RTL/TB sources elaborate without unexpected errors.
- A lexical gate rejects residual SV syntax, time literals and non-Verilog
  system functions, including extensions a compiler might otherwise accept.
- The native GT path reports only the original unavailable `IBUFDS_GTE4`,
  `BUFG_GT` and `GTYE4_CHANNEL` modules; the behavior path has no errors.
- All 80 native / 82 behavioral instantiated RTL interfaces match, including
  port ordering, directions, widths and signedness. Known parameter values,
  widths and signedness match, including the TB overrides. The external top
  remains 69 ports: 32 inputs and 37 outputs.

The optional Icarus check uses `-g2005 -i -tnull`; `-i` skips unavailable vendor
modules whose identities are checked by pyslang. Separately, Icarus 11.0 passed
all four configurations under both `-g2001` and `-g2005`. The behavior path also
compiled without ignoring unresolved modules. Non-error lint diagnostics remain.
The committed [static report](validation/verilog-static-checks.json) records the
four configurations and their interface comparisons.

## Original/converted simulation comparison

Each top was compiled independently with the same flags against the original
commit and the converted tree. The installed Verilator Python distribution was
`5.48.0`, carrying snapshot build `4e853d8` (runtime banner `5.49`).
For example, with a working `verilator` executable:

```text
verilator --binary --timing --assert -Wno-fatal -DGT_BEHAV_MODEL --top-module tb_PHY_V_002 --Mdir build/verilator/PHY_V_002 -f scripts/filelist.f -j 2
build/verilator/PHY_V_002/Vtb_PHY_V_002
```

All 15 tops compile in both versions. The checked result/failure signatures and
first failure timestamps match for every top:

| Test | Original SV | Converted Verilog | Observed result |
|---|---|---|---|
| PHY-V-001 | FAIL | FAIL | Safety assertion, `phy_assertions.sv:44`, time 842000 |
| PHY-V-002 | PASS | PASS | 50 checks |
| PHY-V-003 | PASS | PASS | 21 checks |
| PHY-V-004 | FAIL | FAIL | TX reset seed: 1483 vs ffff, time 20000 |
| PHY-V-005 | PASS | PASS | 4269 checks, including GT encode/decode helpers |
| PHY-V-006 | FAIL | FAIL | EIEOS 32-TS1 cadence: f7bc vs fcbc, time 240000 |
| PHY-V-007 | FAIL | FAIL | SKP due before legal packet boundary, time 2968000 |
| PHY-V-008 | PASS | PASS | 39 checks |
| PHY-V-009 | FAIL | FAIL | Rate changes before normalized completion, time 425000 |
| PHY-V-010 | PASS | PASS | 82 checks |
| PHY-V-011 | FAIL | FAIL | PM request acceptance bound, time 1035000 |
| PHY-V-012 | FAIL | FAIL | Management request acceptance bound, time 1665000 |
| PHY-V-013 | FAIL | FAIL | Committed TX beat visibility, time 356000 |
| PHY-V-014 | PASS | PASS | 23 checks, including internal counter/history probes |
| PHY-V-015 | E1 PASS | E1 PASS | 12 pre-board checks; E3 hardware `NOT_RUN` |

The [regression record](validation/verilog-regression-comparison.json) contains
the captured signatures, additional helper checks and LF-normalized RTL SHA-256
hashes for the tested sources.

Times are the simulator's printed values with 1 ps precision. A failing run stops
at its first error, so matching failures do not establish equivalence after that
point. These results are regression evidence for the language change, not formal
equivalence or a full protocol validation pass. No existing failing logic or TB
expectation was changed to make the migration appear to pass.

The four-state `$onehot0` replacement was also compared exhaustively over all 64
three-bit 0/1/X/Z combinations. All three invalid GT parameter guards halt with
Icarus `vvp -N` exit code 1. Tcl 8.6 stub checks confirm source membership, file
types, GT synthesis exclusion and all 15 launch selections; these checks do not
execute Vivado. GT Wizard integration, Vivado/XSim, synthesis, implementation,
timing/CDC closure and board interoperability remain unverified.
