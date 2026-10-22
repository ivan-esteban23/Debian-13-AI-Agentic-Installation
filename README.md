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

Example:

```sh
cd scripts
./install-debian13-ai-agent-tools.sh
./install-debian13-dwm.sh
./install-debian13-fonts-media-apps.sh
```

The scripts install packages from Debian's Trixie repositories and the latest
mise-managed CLI tools. They do not configure API credentials or sign in to
accounts.

## Notes

- The dwm script enables passwordless LightDM autologin for the account that
  runs it. Anyone with physical access can enter that account's session.
- `mpv --hwdec=vaapi video-file` requests Intel hardware video decoding.
- The AI tools script installs Playwright's Chromium build and system
  dependencies; it does not install a full desktop environment.
