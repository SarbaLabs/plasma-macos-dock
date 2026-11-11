# Development guidance

- Work in SarbaLabs/plasma-macos-dock. Pull requests target this fork's master.
- Communicate with the maintainer in French; keep code, UI, documentation,
  branches, commits and pull requests in English.
- Preserve GPL notices. Do not bump versions, publish releases or merge without
  an explicit request. Select only "none" in the PR release checklist.
- The optional C++ blur plugin must remain optional for pure-QML installations.
- Window effects are shared window state. Keep Qt Quick item access and
  KWindowEffects calls on the GUI thread; avoid unconditional per-frame writes.
- See docs/blur-restoration.md for evidence, lifecycle decisions, validation
  limits, deployment instructions and the pending KWin acceptance checklist.
- Keep unrelated panel geometry, dodge policy and magnification changes separate.
