# Hardware Notes

## Target device

- **FPGA:** Xilinx Spartan-6E, part `xc6slx9-2-tqg144` (LX9, speed grade
  -2, 144-pin TQFP), as set in `qrng_xilinx/project.cfg`.
- If your board uses a different Spartan-6 density/package (e.g. LX16,
  or a different footprint), update `TARGET_PART` in `project.cfg` to
  match before building.

## External entropy source

The design expects a single-bit TTL pulse train on `photon_pulse`,
generated externally by whatever physical entropy source you're pairing
with the FPGA (e.g. an avalanche photodiode + comparator front end, or
an equivalent pulse-generating circuit). The FPGA itself only timestamps
and processes pulses that already arrive on this pin — it does not
generate or condition the analog entropy signal.

## Pin mapping (`qrng_top.ucf`)

| Signal | Pin | Direction | Notes |
|---|---|---|---|
| `clk` | P84 | in | Board clock input |
| `rst_n` | P1 | in | Active-low reset |
| `photon_pulse` | P45 | in | External entropy pulse input |
| `uart_tx` | P117 | out | Currently tied idle-high (placeholder, no UART TX logic implemented yet — see `KNOWN_ISSUES.md`) |
| `uart_rx` | P116 | in | Unused by current logic |
| `led_activity` | P33 | out | Lit while entropy FIFO is non-empty |
| `led_error` | P32 | out | Lit on FIFO overflow |
| `led_health_ok` | P30 | out | Lit while health monitor passes |
| `entropy_valid` | P29 | out | Pulses when a new entropy word is ready |
| `digit_pos[3:0]` | P127, P131, P132, P133 | out | 7-segment digit-select lines |
| `entropy_seg_out[7:0]` | P134, P137–P143 | out | 7-segment segment lines (active levels depend on your display's common anode/cathode wiring) |

**These pin numbers were carried over as-is from the source project and
match a specific Spartan-6E development board's physical pinout.**
Before building for your own board:

1. Confirm each pin number against your board's schematic/datasheet.
2. Re-map any pin here that doesn't correspond to the same physical
   signal on your hardware (clock source, reset button, LEDs, 7-segment
   display, and the entropy pulse input header in particular).

`qrng_xilinx/rtl/tmp.ucf` is a **separate, unused constraints file** for
an 8-bit `entropy_byte` bus and is not referenced by the Makefile or
`project.cfg` — see [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

## Programming interface

Programming is done over the board's JTAG interface via `openFPGALoader`
(see [`PROGRAMMING.md`](PROGRAMMING.md)). Most Spartan-6 dev boards in
this class expose JTAG through an onboard USB-to-FTDI (FT2232H) chip,
which is what the Makefile's `-c ft2232` cable selection assumes.
