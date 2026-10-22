#!/usr/bin/env bash
set -Eeuo pipefail

# Install fonts, media playback, file manager, and Kitty on Debian 13.
# Also add the matching Intel VA-API driver for the detected HD Graphics 4000.

usage() {
  cat <<'USAGE'
Usage: ./install-debian13-fonts-media-apps.sh [--help]

Installs broad Noto and Asian font coverage, Liberation fonts, mpv, PCManFM,
Kitty, and X.Org/Mesa graphics support. On Intel HD Graphics 4000 systems it
also installs the i965 VA-API driver for mpv hardware video decoding.

Run as a regular user with sudo access on Debian 13 (Trixie).

Options:
  -h, --help  Show this help.
USAGE
}

while (($#)); do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if ((EUID == 0)); then
  echo 'Run this script as your regular user, not with sudo.' >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo 'Cannot identify this operating system (/etc/os-release is missing).' >&2
  exit 1
fi
# shellcheck source=/etc/os-release
source /etc/os-release
if [[ "$ID" != debian || "${VERSION_ID:-}" != 13 || "${VERSION_CODENAME:-}" != trixie ]]; then
  printf 'This script targets Debian 13 (Trixie); detected ID=%s VERSION_ID=%s CODENAME=%s.\n' \
    "${ID:-unknown}" "${VERSION_ID:-unknown}" "${VERSION_CODENAME:-unknown}" >&2
  exit 1
fi

for command_name in apt-get sudo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is missing: %s\n' "$command_name" >&2
    exit 1
  fi
done

packages=(
  fontconfig
  fonts-arphic-ukai
  fonts-arphic-uming
  fonts-baekmuk
  fonts-indic
  fonts-liberation2
  fonts-noto-cjk
  fonts-noto-cjk-extra
  fonts-noto-color-emoji
  fonts-noto-core
  fonts-noto-extra
  fonts-noto-mono
  fonts-noto-ui-core
  fonts-noto-ui-extra
  fonts-noto-unhinted
  fonts-takao
  fonts-wqy-microhei
  fonts-wqy-zenhei
  gvfs-backends
  gvfs-fuse
  kitty
  libgl1-mesa-dri
  lxde-icon-theme
  mpv
  pcmanfm
  xserver-xorg
)

# The inspected machine has PCI ID 8086:0166 (Ivy Bridge Intel HD Graphics
# 4000). The kernel i915 driver and Xorg's built-in modesetting driver are
# used for display; i965-va-driver supplies its VA-API video acceleration.
intel_hd4000_found=0
for pci_device in /sys/bus/pci/devices/*; do
  [[ -r "$pci_device/vendor" && -r "$pci_device/device" && -r "$pci_device/class" ]] || continue
  read -r pci_vendor <"$pci_device/vendor"
  read -r pci_device_id <"$pci_device/device"
  read -r pci_class <"$pci_device/class"
  if [[ "$pci_vendor" == 0x8086 && "$pci_device_id" == 0x0166 && "$pci_class" == 0x030000 ]]; then
    intel_hd4000_found=1
    break
  fi
done

if ((intel_hd4000_found)); then
  packages+=(i965-va-driver vainfo)
  echo 'Detected Intel HD Graphics 4000 (8086:0166); adding i965 VA-API support.'
else
  echo 'Intel HD Graphics 4000 (8086:0166) was not detected; using Debian’s standard Mesa graphics stack.'
fi

echo 'Refreshing APT metadata and installing fonts, apps, and graphics packages.'
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${packages[@]}"

fc-cache -f

cat <<'NEXT'

Installed fonts, mpv, PCManFM, Kitty, and the Debian X.Org/Mesa graphics stack.
On this Intel HD Graphics 4000, mpv can request hardware decoding with:
  mpv --hwdec=vaapi video-file

The kernel i915 driver is supplied by Debian's Linux kernel. X.Org uses its
built-in modesetting driver; no separate legacy Intel Xorg driver is needed.
NEXT
