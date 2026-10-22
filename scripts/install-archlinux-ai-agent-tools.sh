#!/usr/bin/env bash
set -Eeuo pipefail

# Install the AI-agent CLI/runtime toolset on Arch Linux. Run as a regular
# user with sudo access; do not run this script as root.

usage() {
  cat <<'USAGE'
Usage: ./install-archlinux-ai-agent-tools.sh [--with-docker] [--help]

Installs and configures:
  mise, Node.js/npm, GitHub CLI, Codex CLI, OpenCode, Herdr,
  Playwright + Chromium, Python/pip, Git, and agent shell tools.

Options:
  --with-docker  Also install Docker Engine (does not enable the daemon or
                 add your user to the root-equivalent docker group).
  -h, --help     Show this help.

Uses pacman for system packages and mise for current CLI tools. Arch Linux
requires a full system upgrade when installing packages. Does not configure
API keys or sign in to accounts.
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
if [[ "${ID:-}" != arch ]]; then
  printf 'This script targets Arch Linux; detected ID=%s.\n' "${ID:-unknown}" >&2
  exit 1
fi

for command_name in pacman sudo curl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command is missing: %s\n' "$command_name" >&2
    exit 1
  fi
done

packages=(
  alsa-lib
  at-spi2-core
  base-devel
  bubblewrap
  ca-certificates
  cairo
  cups
  fd
  fontconfig
  freetype2
  fzf
  git
  gtk3
  jq
  libdrm
  libx11
  libxcb
  libxcomposite
  libxdamage
  libxext
  libxfixes
  libxkbcommon
  libxrandr
  libxrender
  libxshmfence
  libxss
  libxtst
  mesa
  nspr
  nss
  pango
  python
  python-pip
  uv
  ripgrep
  unzip
  vulkan-icd-loader
  wl-clipboard
  xclip
  zellij
  zip
)
if ((with_docker)); then
  packages+=(docker)
fi

echo 'Performing a full Arch Linux system upgrade and installing packages.'
sudo pacman -Syu --needed -- "${packages[@]}"

echo 'Installing the latest stable mise release.'
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
if ! command -v mise >/dev/null 2>&1; then
  echo 'mise installer completed but mise is not available in ~/.local/bin.' >&2
  exit 1
fi

# Keep Bash sessions configured for mise-managed runtimes and tools.
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

playwright_browsers="$HOME/.local/share/ms-playwright"
mkdir -p "$playwright_browsers"
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
  herdr \
  'npm:playwright@latest'

echo 'Installing Playwright Chromium.'
PLAYWRIGHT_BROWSERS_PATH="$playwright_browsers" mise exec -- playwright install chromium

echo
echo 'Installed tool versions:'
mise exec -- node --version
mise exec -- npm --version
mise exec -- python --version
mise exec -- git --version
mise exec -- gh --version | head -n 1
mise exec -- codex --version
mise exec -- opencode --version
mise exec -- herdr --version
zellij --version
PLAYWRIGHT_BROWSERS_PATH="$playwright_browsers" mise exec -- playwright install --list

cat <<'NEXT'

Next steps (run the ones for accounts you use):
  gh auth login --hostname github.com --web --git-protocol https
  codex
  opencode
  herdr

Open a new Bash terminal (or run: source ~/.bashrc) to load mise and the
Playwright browser path automatically. Playwright's browser system libraries
were installed from Arch repositories; `playwright install-deps` is not used
because it targets apt-based distributions.
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
