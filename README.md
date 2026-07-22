# Remote Pi Cockpit for Arch Linux

This repository contains the AUR packaging for
[Remote Pi Cockpit](https://github.com/jacobaraujo7/remote_pi), a desktop
multi-pane interface for the Pi coding agent.

The package uses the official Linux binaries published by the upstream project
and supports both `x86_64` and `aarch64`.

## Installation

Install from the [AUR](https://aur.archlinux.org/packages/remote-pi-cockpit-bin)
with your preferred helper:

```bash
yay -S remote-pi-cockpit-bin
```

```bash
paru -S remote-pi-cockpit-bin
```

After installation, launch **Cockpit** from your application menu or run:

```bash
cockpit
```

## Package layout

- The application bundle is installed in `/opt/cockpit`.
- The executable is available as `/usr/bin/cockpit`.
- Desktop, AppStream, and icon files are installed under `/usr/share`.
- Debian maintainer scripts from the upstream artifacts are not executed.

## Building locally

Clone this repository and build it with `makepkg`:

```bash
git clone https://github.com/pretodev/remote-pi-cockpit-bin.git
cd remote-pi-cockpit-bin
makepkg -si
```

## Updating

AUR helpers detect new package revisions normally:

```bash
yay -Syu
```

Codex automatically reads [AGENTS.md](AGENTS.md) for the concise release path.
For the complete package maintenance procedure, see [Agent.md](Agent.md).

The repository also provides a Codex release skill. Select **Release AUR** from
`/skills`, or invoke it directly with a version:

```text
$release 1.14.8
```

## License

The packaging files in this repository describe upstream software currently
published as `LicenseRef-proprietary`. Refer to the
[upstream repository](https://github.com/jacobaraujo7/remote_pi) for the
licensing terms of each Remote Pi component.
