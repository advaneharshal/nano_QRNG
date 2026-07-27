#!/usr/bin/env bash
###############################################################################
# install_openfpgaloader.sh
#
# Installs openFPGALoader (https://github.com/trabucayre/openFPGALoader),
# the open-source FPGA programmer used by this project's Makefile
# (`make prog PROGRAMMER=openFPGALoader`) to flash the .bit file produced by
# the Xilinx ISE flow onto a Spartan-6E board over JTAG/FTDI.
#
# Strategy:
#   1. Try the distro package first (fast, but often an older version).
#   2. Fall back to building the latest release from source if the package
#      is missing, too old, or --from-source is passed.
#   3. Install udev rules so the board can be accessed without sudo.
#
# Supported package managers: apt (Debian/Ubuntu/WSL), dnf (Fedora/RHEL),
# pacman (Arch), brew (macOS - dependencies only, then build from source).
#
# Usage:
#   ./install_openfpgaloader.sh              # auto: package, else build
#   ./install_openfpgaloader.sh --from-source # force build from source
#   ./install_openfpgaloader.sh --version v0.12.1   # pin a release tag
#
###############################################################################

set -euo pipefail

FORCE_SOURCE=0
OFL_VERSION="latest"
INSTALL_PREFIX="/usr/local"
BUILD_DIR="$(mktemp -d /tmp/openfpgaloader-build.XXXXXX)"

log()  { printf '\n\033[1;34m[install_openfpgaloader]\033[0m %s\n' "$1"; }
warn() { printf '\n\033[1;33m[install_openfpgaloader][WARN]\033[0m %s\n' "$1"; }
die()  { printf '\n\033[1;31m[install_openfpgaloader][ERROR]\033[0m %s\n' "$1"; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --from-source) FORCE_SOURCE=1 ;;
        --version) OFL_VERSION="$2"; shift ;;
        --prefix) INSTALL_PREFIX="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 [--from-source] [--version <tag>] [--prefix <path>]"
            exit 0
            ;;
        *) die "Unknown argument: $1" ;;
    esac
    shift
done

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "This script needs root privileges (or sudo installed)."
    SUDO="sudo"
fi

cleanup() { rm -rf "$BUILD_DIR"; }
trap cleanup EXIT

###############################################################################
# Detect package manager
###############################################################################

PKG_MGR=""
if command -v apt-get >/dev/null 2>&1; then
    PKG_MGR="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
elif command -v brew >/dev/null 2>&1; then
    PKG_MGR="brew"
else
    warn "No supported package manager found (apt/dnf/pacman/brew)."
    warn "Continuing with source build only; you must install build tools manually if this fails."
    PKG_MGR="none"
fi

log "Detected package manager: $PKG_MGR"

###############################################################################
# Step 1: Try installing the distro package (unless --from-source)
###############################################################################

try_package_install() {
    case "$PKG_MGR" in
        apt)
            $SUDO apt-get update -qq
            $SUDO apt-get install -y openfpgaloader
            ;;
        dnf)
            $SUDO dnf install -y openFPGALoader || $SUDO dnf install -y openfpgaloader
            ;;
        pacman)
            $SUDO pacman -Sy --noconfirm openfpgaloader
            ;;
        brew)
            brew install openfpgaloader
            ;;
        *)
            return 1
            ;;
    esac
}

if [ "$FORCE_SOURCE" -eq 0 ] && [ "$PKG_MGR" != "none" ]; then
    log "Attempting package-manager install first..."
    if try_package_install; then
        if command -v openFPGALoader >/dev/null 2>&1; then
            log "openFPGALoader installed via package manager: $(openFPGALoader --Version 2>/dev/null || echo 'version unknown')"
            log "If this is an old version (Spartan-6 support / ft2232 cable issues), re-run with --from-source."
            exit 0
        fi
    else
        warn "Package install failed or package unavailable. Falling back to source build."
    fi
else
    log "Skipping package manager step (--from-source requested or no package manager)."
fi

###############################################################################
# Step 2: Build from source
###############################################################################

log "Installing build dependencies for source build..."

case "$PKG_MGR" in
    apt)
        $SUDO apt-get update -qq
        $SUDO apt-get install -y \
            git gzip cmake pkg-config make g++ \
            libftdi1-2 libftdi1-dev \
            libhidapi-hidraw0 libhidapi-dev \
            libudev-dev zlib1g-dev
        ;;
    dnf)
        $SUDO dnf install -y git gzip cmake pkgconf-pkg-config make gcc-c++ \
            libftdi-devel hidapi-devel systemd-devel zlib-devel
        ;;
    pacman)
        $SUDO pacman -Sy --noconfirm git cmake make gcc pkgconf libftdi libusb zlib hidapi gzip
        ;;
    brew)
        brew install --only-dependencies openfpgaloader || true
        brew install cmake pkg-config zlib libftdi hidapi
        ;;
    none)
        warn "No package manager detected - assuming build tools (git, cmake, g++, pkg-config) and libftdi1/libusb-1.0/libhidapi/zlib dev headers are already installed."
        ;;
esac

log "Cloning openFPGALoader source (version: $OFL_VERSION)..."
git clone --recursive https://github.com/trabucayre/openFPGALoader.git "$BUILD_DIR/openFPGALoader"
cd "$BUILD_DIR/openFPGALoader"

if [ "$OFL_VERSION" != "latest" ]; then
    git checkout "$OFL_VERSION"
fi

log "Configuring build (CMake, prefix=$INSTALL_PREFIX)..."
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" ..

log "Compiling (this can take a few minutes)..."
NPROC="$(command -v nproc >/dev/null 2>&1 && nproc || echo 2)"
cmake --build . --parallel "$NPROC"

log "Installing openFPGALoader to $INSTALL_PREFIX ..."
$SUDO cmake --install .

# Refresh shared library cache on Linux
if command -v ldconfig >/dev/null 2>&1; then
    $SUDO ldconfig
fi

###############################################################################
# Step 3: udev rules so the board can be used without root (Linux only)
###############################################################################

if [ -f "99-openfpgaloader.rules" ] && [ "$(uname -s)" = "Linux" ]; then
    log "Installing udev rules for non-root JTAG/FTDI access..."
    $SUDO cp 99-openfpgaloader.rules /etc/udev/rules.d/
    $SUDO udevadm control --reload-rules
    $SUDO udevadm trigger

    if command -v getent >/dev/null 2>&1 && getent group plugdev >/dev/null 2>&1; then
        TARGET_USER="${SUDO_USER:-$USER}"
        $SUDO usermod -aG plugdev "$TARGET_USER" || true
        warn "Added '$TARGET_USER' to the 'plugdev' group. Log out/in (or reboot / restart WSL) for this to take effect."
    fi
fi

###############################################################################
# Verify
###############################################################################

if command -v openFPGALoader >/dev/null 2>&1; then
    log "openFPGALoader installed successfully:"
    openFPGALoader --Version || true
    log "Next steps:"
    echo "  1. Plug in your Spartan-6E board's JTAG/FTDI USB cable."
    echo "  2. Run: openFPGALoader --detect     (or: make check, from qrng_xilinx/)"
    echo "  3. Program the board with: make prog PROGRAMMER=openFPGALoader"
else
    die "Installation finished but 'openFPGALoader' was not found on PATH. Check that $INSTALL_PREFIX/bin is on your PATH."
fi
