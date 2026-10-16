# GTYE4 / GT Wizard freeze checklist

`pcie_gty_adapter_x1.v` intentionally keeps the normalized §4.6 boundary stable while the board-specific GT Wizard result is unavailable. Do not expose native GT ports above this adapter.

Before synthesis/implementation, generate a single-lane UltraScale+ GTY customization for the exact XCVU9P part, package, speed grade, GT quad/channel, and board REFCLK. Copy the generated primitive attributes, legal constant tie-offs, clock helper, reset helper, and DRP/rate sequence into the marked `TODO(Wizard)` integration points. Do not infer them from another device or Vivado release.

Freeze and review all of the following:

- hard TX/RX 8b/10b enabled; external width is two decoded characters (`TX/RX_DATA_WIDTH=20`, 16 payload bits plus control);
- `TXDATA[15:0]` / `TXCTRL2[1:0]` and `RXDATA[15:0]` / `RXCTRL0..3[1:0]` byte ordering against §4.6;
- `TXUSRCLK=TXUSRCLK2` and `RXUSRCLK=RXUSRCLK2` from the generated `TXOUTCLK/RXOUTCLK` helper, 125 MHz at Gen1 and 250 MHz at Gen2;
- TX buffer enabled (`TX_XCLK_SEL=TXOUT`) and RX elastic buffer / clock correction enabled (`RX_XCLK_SEL=RXDES`);
- PCIe Gen1/Gen2 `CLK_COR_SEQ_*`, `CLK_COR_MIN_LAT`, `CLK_COR_MAX_LAT`, `CBCC_DATA_SOURCE_SEL`, comma plus/minus alignment, and channel bonding disabled for x1;
- CPLL versus QPLL selection, `TXRATE/RXRATE`, `TXOUT_DIV/RXOUT_DIV`, `TXRATEDONE/RXRATEDONE`, DRP requirements, and rate-change reset sequence;
- `GTPOWERGOOD`, PLL lock, `TX/RXUSERRDY`, `TX/RXRESETDONE`, TX/RX buffer reinitialization, and synchronous user reset release;
- Receiver Detect mapping (`TXPD/RXPD=P1`, `TXELECIDLE`, `TXDETECTRX`, atomic `PHYSTATUS+RXSTATUS` capture); only RXSTATUS `000` and `011` are legal in Detect context;
- `TXPD/RXPD`, `TXELECIDLE/RXELECIDLE`, RX Electrical Idle detector mode, and reset-on-power-up behavior;
- `RXPOLARITY`, static-only TX polarity, `TXDEEMPH`, `TXSWING`, `TXMARGIN`, RX termination, CDR, and validated LPM/DFE policy;
- normalized `RXCLKCORCNT` (`00/01/10/11`) and `RXBUFSTATUS` (`000/001/010/101/110`) mapping without inventing a buffer-reset-done port;
- protocol Loopback/Compliance remaining in logical PHY, distinct from the explicitly selected native `LOOPBACK` diagnostic mode;
- physical `GTYE4_CHANNEL` LOC, REFCLK buffer/site, clock region reachability, and pin assignment from the approved schematic.

After insertion, rerun compile order, elaboration, CDC/RDC, clock-interaction, DRC, synthesis, implementation, and the full PHY-V suite. Those future results—not this checklist—close E2/E3 evidence.
