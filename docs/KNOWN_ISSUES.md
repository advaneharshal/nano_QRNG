# Known Issues / Source Tree Notes

The current source tree carries some leftovers from an earlier design
iteration. None of these block the verified Spartan-6E build, but they're
worth knowing about before you extend the design or hand it to someone
else.

## 1. `rtl/qrng_top.v` contains two versions of the top module

The **active** module (the one actually compiled — see below) targets
the Spartan-6E board directly: `clk`, `rst_n`, `photon_pulse`, `uart_tx`,
`uart_rx`, `led_activity`, `led_error`, `led_health_ok`, `entropy_valid`,
`digit_pos`, `entropy_seg_out`.

Below it, wrapped in a `/* ... */` block comment, is an **older,
inactive** version of `qrng_top` written for a Lattice iCE40HX8K target
(`clk_12m`, `apd_pulse`, an SPI slave interface to an external MCU, a
UART debug interface, `led_health`/`led_data`/`led_error`, etc.). This
version references `entropy_fifo`, `spi_slave`, and `uart` modules and is
not compiled — it's dead code kept for reference. It also doesn't match
the `TDC` module in `rtl/tdc_entropy.v` port-for-port (that file only
implements the Spartan-6E-era `tdc_entropy_extractor`/`health_monitor`
pair), so this commented-out version would not build even if
un-commented without further rework.

## 2. `rtl/entropy_fifo.v`, `rtl/spi_slave.v`, `rtl/uart.v` are unused

These three files belong to the inactive iCE40/SPI-MCU version described
above. `qrng_xilinx/project.cfg` only lists `rtl/qrng_top.v` in
`VSOURCE`, which in turn only `` `include ``s `rtl/tdc_entropy.v` — so
these three files are never pulled into the current Spartan-6E build.
They're kept in the tree for reference/possible reuse, not because the
build needs them.

## 3. `tb/tb_qrng_top.v` targets the wrong top-level module

This testbench instantiates `qrng_top` with the **old iCE40 port list**
(`clk_12m`, `apd_pulse`, `spi_*`, `led_health`, `led_data`, `dbg_*`),
which does not match the ports of the currently active `qrng_top` module
described in issue #1. As checked in, this testbench will fail to
elaborate against the current RTL (`make isim TB=tb_qrng_top` will not
work).

`tb/tb_tdc_entropy.v` is consistent with the current RTL and is the one
to use for simulating the entropy extraction path — see
[`BUILD.md`](BUILD.md) for how to enable it via `project.cfg`.

If you want a working top-level testbench, `tb_qrng_top.v` needs to be
rewritten against the current `qrng_top` port list (and driven with the
`photon_pulse` signal instead of `apd_pulse`/SPI transactions).

## 4. `rtl/tmp.ucf` is a separate, unused constraints file

It only maps an 8-bit `entropy_byte[7:0]` bus to pins and is not
referenced anywhere by `Makefile` or `project.cfg` (the build's
constraints file is `qrng_top.ucf`, set via `CONSTRAINTS ?=
$(PROJECT).ucf`). Looks like a scratch/earlier constraints file; safe to
ignore for the current build, or delete once you're sure nothing local
depends on it.

## 5. `uart_tx` is a placeholder

In the active `qrng_top`, `uart_tx` is simply tied high
(`assign uart_tx = 1'b1;`) with `// TODO` comments noting that a UART
transmitter and an external SHA-3 conditioner are not yet implemented.
The entropy stream is currently only observable via the 7-segment
display and the `entropy_valid`/LED status signals — there is no serial
output of entropy bytes yet.

## 6. Board pin mapping is board-specific

The pin locations in `qrng_top.ucf` were carried over from the original
board this was developed on. Verify every pin against your own Spartan-6E
board's schematic before building — see [`HARDWARE.md`](HARDWARE.md).
