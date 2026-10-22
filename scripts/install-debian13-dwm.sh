#!/usr/bin/env bash
set -Eeuo pipefail

# Install a minimal X11 session with Debian's dwm, dmenu, st, and LightDM.
# Run on Debian 13 (Trixie) as the regular account that should auto-login.

usage() {
  cat <<'USAGE'
Usage: ./install-debian13-dwm.sh [--help]

Installs the X.Org server, LightDM, and a minimal dwm session with dmenu,
st, fonts, and X11 utilities. Configures LightDM to automatically log in
the account running this script to dwm. No full desktop is installed.
If ~/.xinitrc does not exist, creates one for manual startx use.

LightDM is enabled for boot. Reboot after installation to enter dwm.

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

for command_name in apt-get sudo systemctl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is missing: %s\n' "$command_name" >&2
    exit 1
  fi
done

packages=(
  dbus-x11
  dwm
  fonts-dejavu-core
  lightdm
  lightdm-gtk-greeter
  stterm
  suckless-tools
  x11-xserver-utils
  xclip
  xinit
  xserver-xorg
)

# Configure autologin before LightDM is installed, since its package may start
# the service during installation. Debian's dwm package provides the session
# name used below as /usr/share/xsessions/dwm.desktop.
login_user="$(id -un)"
lightdm_config="$(mktemp)"
trap 'rm -f "$lightdm_config"' EXIT
cat >"$lightdm_config" <<LIGHTDM_CONFIG
[Seat:*]
autologin-user=$login_user
autologin-user-timeout=0
autologin-session=dwm
user-session=dwm
greeter-session=lightdm-gtk-greeter
LIGHTDM_CONFIG
sudo install -D -o root -g root -m 0644 "$lightdm_config" \
  /etc/lightdm/lightdm.conf.d/50-autologin-dwm.conf
rm -f "$lightdm_config"
trap - EXIT

echo 'Refreshing APT metadata and installing dwm, LightDM, and X11 packages.'
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${packages[@]}"
sudo systemctl enable lightdm.service

# Keep the user's existing X startup configuration. Only supply a basic dwm
# session when there is no ~/.xinitrc yet.
xinitrc="$HOME/.xinitrc"
if [[ ! -e "$xinitrc" ]]; then
  cat >"$xinitrc" <<'XINITRC'
#!/bin/sh
exec dwm
XINITRC
  chmod 0755 "$xinitrc"
  echo "Created $xinitrc to start dwm with startx."
else
  echo "Kept existing $xinitrc unchanged. Ensure it starts dwm, then use startx."
fi

cat <<'NEXT'

Installed dwm, dmenu, st, LightDM, X.Org, and X11 utilities. No full desktop
environment was installed. LightDM will automatically log in as the account
that ran this script and start dwm.

Reboot to start LightDM and automatically enter dwm. For manual X startup,
log in on a local text console and run:
  startx

Debian's st package is named stterm but provides the `st` command. The dwm
package uses Debian's default configuration; customize it separately if you
want different key bindings or appearance.
NEXT
