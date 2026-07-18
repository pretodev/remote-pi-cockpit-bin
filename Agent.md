# Agent Maintenance Guide

This repository packages the official Remote Pi Cockpit Linux binaries for the
Arch User Repository. Keep changes small, reproducible, and limited to
packaging.

## Repository model

- `origin` is the public GitHub repository. Its default branch is `main`.
- `aur` is the AUR package repository. Its required branch is `master`.
- GitHub may contain documentation, but the AUR branch should contain only
  `PKGBUILD` and `.SRCINFO`.
- `PKGBUILD` is the source of truth. Regenerate `.SRCINFO` after every metadata
  change.

## Packaging invariants

- Package name: `remote-pi-cockpit-bin`.
- Supported architectures: `x86_64` and `aarch64`.
- Use only stable upstream releases tagged `cockpit-v<version>`.
- Download the official architecture-specific `.deb` artifacts.
- Pin each artifact with its published SHA-256 checksum.
- Extract only `data.tar.zst`; never execute Debian maintainer scripts.
- Keep the application bundle under `/opt/cockpit`.
- Expose the application through `/usr/bin/cockpit`.
- Install the canonical desktop, AppStream, and icon files under `/usr/share`.
- Preserve prebuilt Flutter binaries with `!strip` and `!debug`.

## Updating a release

1. Confirm the latest stable Cockpit release and both Linux artifacts upstream.
2. Update `pkgver`; reset `pkgrel` to `1`.
3. Update the `x86_64` and `aarch64` SHA-256 checksums.
4. Regenerate `.SRCINFO`:

   ```bash
   makepkg --printsrcinfo > .SRCINFO
   ```

5. Validate the package:

   ```bash
   bash -n PKGBUILD
   makepkg --verifysource
   makepkg --cleanbuild --force
   diff -u .SRCINFO <(makepkg --printsrcinfo)
   ```

6. Inspect the generated package to confirm the launcher, icons, metainfo,
   symlink, and runtime dependencies.
7. Commit and push the complete change to GitHub.
8. Publish only the package metadata to the AUR from a temporary worktree:

   ```bash
   git fetch aur master
   git worktree add /tmp/remote-pi-cockpit-aur aur/master
   cp PKGBUILD .SRCINFO /tmp/remote-pi-cockpit-aur/
   git -C /tmp/remote-pi-cockpit-aur add PKGBUILD .SRCINFO
   git -C /tmp/remote-pi-cockpit-aur commit -m "Update to <version>-<pkgrel>"
   git -C /tmp/remote-pi-cockpit-aur push aur HEAD:master
   git worktree remove /tmp/remote-pi-cockpit-aur
   ```

## Review checklist

- The working tree contains no downloaded artifacts or build output.
- `.SRCINFO` exactly matches `makepkg --printsrcinfo`.
- Both architecture checksums match the upstream release.
- `ldd` reports no missing libraries for the native architecture.
- No upstream control scripts, duplicate desktop files, or duplicate icons are
  included.
- Package changes are tested before pushing to the AUR.
