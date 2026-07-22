---
name: release
description: Release a requested Remote Pi Cockpit version to GitHub and the Arch User Repository. Use when the user invokes $release with a version, selects Release AUR from /skills, writes /release followed by a version, or explicitly asks to publish, ship, or release a Cockpit version.
---

# Release

Require exactly one version argument, accepting either `1.14.8` or
`cockpit-v1.14.8`. Treat explicit invocation as authorization to commit and push
the release to both configured remotes.

From the repository root, run:

```bash
bash .agents/skills/release/scripts/release.sh <version>
```

The script owns release discovery, checksums, metadata updates, package QA,
cleanup, commits, and pushes. Do not duplicate those steps with extra tool calls
or subagents. If it fails, diagnose only the reported stage, preserve any local
commit it created, and never force-push.

Return a compact result containing the published package version, GitHub commit,
AUR commit, and any failed validation. Do not print complete download, package
file-list, or `ldd` output.

For a non-publishing rehearsal, run the same script with `--dry-run`; it restores
`PKGBUILD` and `.SRCINFO` before returning.
