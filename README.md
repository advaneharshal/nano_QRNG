# nano_QRNG

FPGA implementation of a Quantum Random Number Generator (QRNG) built around
a Time-to-Digital Converter (TDC) entropy source.

The design timestamps pulses from an external photon/avalanche detector at
high resolution, XOR-folds the low-order timestamp bits into an entropy
word, and runs a lightweight online health monitor (repetition + proportion
tests) on the output stream. A 4-digit 7-segment display shows the raw
entropy byte in hex, and status LEDs report activity/error/health.

**Verified working target: Xilinx Spartan-6E, `xc6slx9-2-tqg144` package.**

```
Photon detector ──▶ TDC / entropy extractor ──▶ Health monitor ──▶ LEDs
      (pulse)         (rtl/tdc_entropy.v)                          7-seg display (hex)
```

## Repository layout

```
nano_QRNG/
├── qrng_xilinx/            Xilinx ISE project (source of truth for the FPGA build)
│   ├── Makefile             Build/simulate/program flow
│   ├── project.cfg          Project name, target part, source file list
│   ├── qrng_top.ucf         Pin constraints (Spartan-6E board)
│   ├── rtl/                 Verilog sources
│   └── tb/                  Testbenches (ISim)
├── scripts/
│   └── install_openfpgaloader.sh   Installs openFPGALoader (see docs/PROGRAMMING.md)
├── docs/
│   ├── BUILD.md             Toolchain setup + `make` usage
│   ├── PROGRAMMING.md       Flashing the board with openFPGALoader
│   ├── HARDWARE.md          Pin mapping / board requirements
│   └── KNOWN_ISSUES.md      Known gaps in the current source tree
└── LICENSE                  GPLv3
```

## Quick start

```bash
# 1. Install the FPGA programmer (openFPGALoader)
./scripts/install_openfpgaloader.sh

# 2. Build the bitstream (requires Xilinx ISE 14.7 — see docs/BUILD.md)
cd qrng_xilinx
export XILINX=/opt/Xilinx/14.7/ISE_DS/ISE
make

# 3. Check the board is detected, then flash it
make check
make prog PROGRAMMER=openFPGALoader
```

See [`docs/BUILD.md`](docs/BUILD.md) for full toolchain setup and
[`docs/PROGRAMMING.md`](docs/PROGRAMMING.md) for programming details.
**Read [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md) before touching the
testbenches or `rtl/` — the source tree contains leftover files from an
earlier iCE40-based revision of this design that are not part of the
current Spartan-6E build.**

## License

GNU General Public License v3.0 — see [`LICENSE`](LICENSE).
