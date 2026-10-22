# Debian 13 AI/Agentic Installation

Installation scripts for a Debian 13 (Trixie) CLI-first system using dwm,
LightDM, Codex, OpenCode, and selected desktop utilities.

## Scripts

Run each script as your regular user with `sudo` access. Do not run them with
`sudo`; each script requests elevation only for system package and service
changes.

1. `scripts/install-debian13-ai-agent-tools.sh` installs mise, Node.js/npm,
   GitHub CLI, Codex, OpenCode, Playwright, Chromium, and CLI dependencies.
2. `scripts/install-debian13-dwm.sh` installs X.Org, dwm, dmenu, st, and
   LightDM, then configures LightDM to autologin the account running the script
   to dwm.
3. `scripts/install-debian13-fonts-media-apps.sh` installs Noto and Asian
   fonts, Liberation fonts, mpv, PCManFM, Kitty, and Mesa graphics packages.
   It detects Intel HD Graphics 4000 (PCI ID `8086:0166`) and installs the
   matching i965 VA-API driver for hardware video decoding.
4. `scripts/install-archlinux-ai-agent-tools.sh` installs the AI-agent CLI
   toolset, `uv` for isolated Python tooling, Herdr for managing agent
   sessions, and Zellij as a terminal multiplexer on Arch Linux. It is the Arch
   port of the first script only; it also offers an optional GitHub CLI web
   sign-in prompt. The dwm and fonts/media scripts remain Debian 13 scripts.

Example:

```sh
cd scripts
./install-debian13-ai-agent-tools.sh
./install-debian13-dwm.sh
./install-debian13-fonts-media-apps.sh
```

On Arch Linux, run only the AI-agent tools installer:

```sh
./install-archlinux-ai-agent-tools.sh
```

The Debian scripts install packages from Debian's Trixie repositories; the
Arch AI-agent script uses pacman and performs a full system upgrade, as
required by Arch package management. All scripts use the latest mise-managed
CLI tools and do not configure API credentials or sign in to accounts.

## Notes

- The dwm script enables passwordless LightDM autologin for the account that
  runs it. Anyone with physical access can enter that account's session.
- `mpv --hwdec=vaapi video-file` requests Intel hardware video decoding.
- The AI tools script installs Playwright's Chromium build and system
  dependencies; it does not install a full desktop environment.
