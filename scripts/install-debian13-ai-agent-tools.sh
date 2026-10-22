#!/usr/bin/env bash
set -Eeuo pipefail

# Install the CLI/runtime toolset used on the author's Omarchy setup onto a
# freshly installed Debian 13 (Trixie) system. Run as a regular user with sudo
# access; do not run as root.

usage() {
  cat <<'USAGE'
Usage: ./install-debian13-ai-agent-tools.sh [--with-docker] [--help]

Installs and configures:
  mise, Node.js/npm, GitHub CLI, Codex CLI, OpenCode,
  Playwright + its Chromium browser, Python/pip, Git, and agent shell tools.

Options:
  --with-docker  Also install Docker Engine (does not enable the daemon or
                 add your user to the root-equivalent docker group).
  -h, --help     Show this help.

This script refreshes APT metadata and installs Debian packages, then installs
the latest mise-managed tools. It does not perform a full Debian upgrade,
install a desktop environment, configure API keys, or sign in to accounts.
USAGE
}

with_docker=0
while (($#)); do
  case "$1" in
    --with-docker) with_docker=1 ;;
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

for command_name in apt-get sudo curl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is missing: %s\n' "$command_name" >&2
    exit 1
  fi
done

packages=(
  build-essential
  bubblewrap
  ca-certificates
  curl
  fd-find
  fzf
  git
  jq
  python-is-python3
  python3
  python3-pip
  ripgrep
  unzip
  wl-clipboard
  xclip
  zip
)
if ((with_docker)); then
  packages+=(docker.io)
fi

echo 'Refreshing APT metadata and installing Debian packages.'
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${packages[@]}"

# Use mise's official Linux installer for its current stable binary.
echo 'Installing the latest stable mise release.'
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  echo 'mise installer completed but mise is not available in ~/.local/bin.' >&2
  exit 1
fi

# Ensure Bash loads mise in future terminal sessions. The current script uses
# mise exec below, so it does not depend on a shell restart.
bashrc="$HOME/.bashrc"
touch "$bashrc"
if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC_PATH'

# Make user-installed command line tools available in Bash.
export PATH="$HOME/.local/bin:$PATH"
BASHRC_PATH
fi
if ! grep -Fq 'mise activate bash' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC_MISE'

# Load mise-managed runtimes and agent CLIs.
eval "$(mise activate bash)"
BASHRC_MISE
fi

# Debian names the fd package executable fdfind; provide the usual fd command.
mkdir -p "$HOME/.local/bin"
ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"

playwright_tmp="$HOME/.cache/playwright-tmp"
playwright_browsers="$HOME/.local/share/ms-playwright"
mkdir -p "$playwright_tmp" "$playwright_browsers"

# Playwright stages browser archives in Node's temporary directory. Use a
# home-directory temp path so a small /tmp tmpfs cannot truncate the download.
# Keep its browser path in .bashrc so later Playwright runs find the same build.
if ! grep -Fq 'export PLAYWRIGHT_BROWSERS_PATH=' "$bashrc"; then
  cat >>"$bashrc" <<'BASHRC_PLAYWRIGHT'

# Keep Playwright browser binaries in a stable user-owned directory.
export PLAYWRIGHT_BROWSERS_PATH="$HOME/.local/share/ms-playwright"
BASHRC_PLAYWRIGHT
fi
export PLAYWRIGHT_BROWSERS_PATH="$playwright_browsers"

echo 'Installing the latest mise-managed agent tools and runtimes.'
mise use --global \
  node@latest \
  gh@latest \
  codex@latest \
  opencode@latest \
  'npm:playwright@latest'

echo 'Installing Playwright Chromium and its Debian system dependencies.'
TMPDIR="$playwright_tmp" \
PLAYWRIGHT_BROWSERS_PATH="$playwright_browsers" \
  mise exec -- playwright install --with-deps chromium

echo
echo 'Installed tool versions:'
mise exec -- node --version
mise exec -- npm --version
mise exec -- python --version
mise exec -- git --version
mise exec -- gh --version | head -n 1
mise exec -- codex --version
mise exec -- opencode --version
PLAYWRIGHT_BROWSERS_PATH="$playwright_browsers" mise exec -- playwright install --list

cat <<'NEXT'

Next steps (run the ones for accounts you use):
  gh auth login --hostname github.com --web --git-protocol https
  codex
  opencode

Open a new Bash terminal (or run: source ~/.bashrc) to load mise and the
Playwright browser path automatically. Debian 13 is supported by the current
Playwright release.
NEXT

if ((with_docker)); then
  cat <<'DOCKER_NOTE'

Docker was installed but the daemon was not enabled. To start it:
  sudo systemctl enable --now docker.service

This script did not add your user to the docker group; membership grants
root-equivalent access. Use sudo with Docker unless you deliberately choose
to grant that access.
DOCKER_NOTE
fi

