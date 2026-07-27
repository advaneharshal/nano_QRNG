# Programming the Board (openFPGALoader)

This project uses [openFPGALoader](https://github.com/trabucayre/openFPGALoader),
an open-source, multi-vendor FPGA programmer, instead of Xilinx `iMPACT`.
It talks to the board over the same JTAG/FTDI USB cable and is
significantly easier to script and to run on modern Linux distros / WSL
than `iMPACT`.

## 1. Install

From the repo root:

```bash
./scripts/install_openfpgaloader.sh
```

What it does:

1. Tries your distro's package manager first (`apt`, `dnf`, `pacman`, or
   `brew`) for a quick install.
2. If that package is missing or you pass `--from-source`, it installs
   the required build dependencies (`libftdi1`, `libhidapi`, `libudev`,
   `zlib`, `cmake`, a C++ compiler) and builds the latest openFPGALoader
   from source.
3. Installs the project's udev rules (`99-openfpgaloader.rules`) and adds
   your user to the `plugdev` group, so the board can be accessed without
   `sudo`.

Options:

```bash
./scripts/install_openfpgaloader.sh --from-source        # force a source build
./scripts/install_openfpgaloader.sh --version v0.12.1     # pin a specific release tag
./scripts/install_openfpgaloader.sh --prefix /usr/local   # custom install prefix
```

> **Why source might be needed:** the `openfpgaloader` package shipped in
> some distro repos is old and can be missing support for newer cable
> variants or FTDI chip revisions. If `openFPGALoader --detect` doesn't
> find your board after a package install, re-run the script with
> `--from-source`.

After installation, **unplug and replug the board's USB cable** (or
reboot/restart your WSL session) so the new udev rules and group
membership take effect.

## 2. Detecting the board

```bash
openFPGALoader --detect
```

or, from `qrng_xilinx/`:

```bash
make check
```

This should report the JTAG chain and identify the Spartan-6 device. If
nothing is detected:

- Confirm the USB cable is a JTAG-capable cable (not just a UART/power
  cable) and is plugged into the board's JTAG/programming USB port.
- Confirm udev rules were applied (`ls /etc/udev/rules.d/ | grep openfpga`)
  and that you replugged the board after installing them.
- On WSL specifically, USB devices must be attached to the WSL instance
  (e.g. via `usbipd`) before Linux tools can see them — a native Linux
  install typically does not need this extra step.

## 3. Cable selection

`qrng_xilinx/Makefile` currently invokes:

```make
openFPGALoader -c ft2232 $(BITFILE)
```

`-c ft2232` selects a generic FT2232-based JTAG cable. Many Spartan-6
dev boards (including common Spartan-6 LX9 "Mimas"-style boards) use an
onboard FT2232H for JTAG, which this matches. **If your board uses a
different cable/adapter** (e.g. a Digilent HS1/HS2/JTAG-SMT2, an
Xilinx Platform Cable USB, or a different FTDI part), replace `ft2232`
with the correct cable identifier. See the full list with:

```bash
openFPGALoader --list-cables
```

and update the `prog:` target in the Makefile (or override
`XC3SPROG_CABLE`/pass `-c <cable>` directly) accordingly.

## 4. Flashing

```bash
cd qrng_xilinx
make                                 # produces build/qrng_top.bit
make check                           # optional: confirm board is detected
make prog PROGRAMMER=openFPGALoader  # flash the bitstream
```

By default, `openFPGALoader` performs an SRAM (volatile) configuration —
the bitstream is lost on power-cycle, which is normal and expected for
day-to-day FPGA development. Consult `openFPGALoader --help` for flash
(non-volatile) programming options if your board has an onboard SPI/BPI
configuration flash you want to program instead.
