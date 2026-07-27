# Build Guide

This project uses a **Xilinx ISE 14.7** command-line flow (`xst` →
`ngdbuild` → `map` → `par` → `bitgen`), driven by `qrng_xilinx/Makefile`.
ISE 14.7 is the last release with Spartan-6 support and is the toolchain
this design has been verified against.

## 1. Dependencies

| Requirement | Why it's needed | Notes |
|---|---|---|
| **Xilinx ISE 14.7 (WebPACK, free)** | Synthesis, place & route, bitstream generation (`xst`, `ngdbuild`, `map`, `par`, `bitgen`) for Spartan-6 | Proprietary, requires a free Xilinx/AMD account to download. Last version to support Spartan-6; no longer maintained. |
| **GNU Make** | Drives the whole build (`Makefile`) | `sudo apt install make` |
| **Bash / coreutils** | Makefile shell commands | Present by default on Linux/WSL |
| **32-bit compatibility libraries** (Linux only) | ISE 14.7 ships 32-bit binaries | See below |
| **openFPGALoader** | Programs the board over JTAG (`make prog`) | See [`scripts/install_openfpgaloader.sh`](../scripts/install_openfpgaloader.sh) and [`PROGRAMMING.md`](PROGRAMMING.md) |

ISE's own ISim is used for simulation (`make isim` / `make isimgui`) — no
separate open-source simulator (Icarus/Verilator) is required or used by
this Makefile.

### Installing Xilinx ISE 14.7 on modern Linux / WSL

ISE 14.7 predates modern distros and needs some compatibility packages on
Ubuntu 20.04+ / most current WSL Ubuntu images:

```bash
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y \
    libc6:i386 libstdc++6:i386 libxft2:i386 libxext6:i386 \
    libxtst6:i386 libx11-6:i386
```

Then run the ISE installer from the extracted Xilinx installation archive
(`xsetup`) and install to a path such as `/opt/Xilinx/14.7`. If the
installer or `xst`/`bitgen` refuse to start, running them inside a 32-bit
chroot or a dedicated older Ubuntu/CentOS VM/container is the common
workaround — this is a known limitation of ISE 14.7 on current kernels,
not specific to this project.

## 2. Configuring the build

Build parameters live in [`qrng_xilinx/project.cfg`](../qrng_xilinx/project.cfg):

```make
PROJECT     = qrng_top
TARGET_PART = xc6slx9-2-tqg144
XILINX      = /opt/Xilinx/14.7/ISE_DS/ISE/
PROGRAMMER  = openFPGALoader
VSOURCE     = rtl/qrng_top.v
```

- `TARGET_PART` must match your board's exact Spartan-6 device/package.
- `XILINX` must point at your local ISE install (override with an
  environment variable if it differs from the checked-in default —
  `export XILINX=/path/to/ISE_DS/ISE` before running `make`).
- `VSOURCE` intentionally lists only `rtl/qrng_top.v`. That file pulls in
  `rtl/tdc_entropy.v` itself via `` `include ``, so both are compiled.
  Other files under `rtl/` are **not** part of this build — see
  [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md).

## 3. Building

```bash
cd qrng_xilinx
make            # synthesize, map, place & route, generate build/qrng_top.bit
make clean      # remove the build/ directory
```

Build products (including the final `.bit` file) are written to
`qrng_xilinx/build/`, which is intentionally not committed to the repo.

## 4. Simulation (ISim)

The checked-in `project.cfg` does **not** currently set `VTEST`/`VHDTEST`,
so `make test` has nothing to build until you add one. To simulate the
entropy extractor testbench, add this line to `project.cfg`:

```make
VTEST = tb/tb_tdc_entropy.v
```

Then:

```bash
make test                    # build the testbench executable(s) listed in VTEST/VHDTEST
make isim TB=tb_tdc_entropy   # run in batch mode
make isimgui TB=tb_tdc_entropy
```

`TB` must name a testbench listed under `VTEST`/`VHDTEST`. Only
`tb_tdc_entropy` currently elaborates cleanly against the active RTL —
`tb_qrng_top` targets an older, incompatible version of the top-level
module and will fail to elaborate as-is. See
[`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) for details.

## 5. Programming

```bash
make check                          # openFPGALoader --detect
make prog PROGRAMMER=openFPGALoader # flash build/qrng_top.bit
```

Full details, including cable selection and driver setup, are in
[`PROGRAMMING.md`](PROGRAMMING.md).
