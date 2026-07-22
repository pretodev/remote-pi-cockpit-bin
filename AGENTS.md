# Codex Guide

This repository publishes `remote-pi-cockpit-bin` to GitHub and the AUR. Keep
changes small, reproducible, and limited to packaging. Read `Agent.md` for the
full maintenance procedure.

## Fast path

When the user provides a version and asks to release or publish it:

1. Use the repo skill `$release` and its deterministic release script. Treat
   the request as authorization to update, validate, commit, and push to both
   `origin/main` and `aur/master`; do not ask for a second confirmation.
2. Do not reproduce the release steps manually unless the script fails. The
   skill validates both artifacts, package layout, native dependencies, pushes,
   and cleanup while keeping tool output compact.

## Delegation

- For a normal two-file version bump, work directly; spawning agents would cost
  more tokens than it saves.
- Use at most two subagents only when independent work can run concurrently or
  a check fails: `release-scout` for upstream release metadata and
  `package-auditor` for local packaging QA.
- Keep subagents read-only. They return short findings with exact commands,
  hashes, or file references; the main agent owns all edits, commits, and pushes.
- Never nest subagents.

## Safety

- Never publish drafts, prereleases, missing artifacts, or mismatched checksums.
- Never execute Debian maintainer scripts.
- Never put documentation or Codex setup files on the AUR branch.
- Do not use destructive Git commands. Preserve unrelated user changes.
