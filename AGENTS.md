# Development guidance

- Work in SarbaLabs/plasma-macos-dock. Pull requests target this fork's master.
- Communicate with the maintainer in French; keep code, UI, documentation,
  branches, commits and pull requests in English.
- Preserve GPL notices. Do not bump versions, publish releases or merge without
  an explicit request. Select only "none" in the PR release checklist.
- The optional C++ blur plugin must remain optional for pure-QML installations.
- Window effects are shared window state. Keep Qt Quick item access and
  KWindowEffects calls on the GUI thread; avoid unconditional per-frame writes.
- Plasma theme changes can clear NoBackground effects without any geometry or
  visibility notification. Restore after Plasma::Theme::themeChanged through
  the existing coalesced queue, not directly on an earlier palette event.
- See docs/blur-restoration.md for evidence, lifecycle decisions, validation
  limits, deployment instructions and the pending KWin acceptance checklist.
- Keep unrelated panel geometry, dodge policy and magnification changes separate.
- Application context menus use a separate optional native module. See
  docs/application-context-menus.md. Preserve ContextMenu.qml's Pin/Unpin and
  Test Bounce Animation handlers; never instantiate Plasma's full private Backend
  or concatenate shell command strings for Places/recents.
- Indicators are pure QML; see docs/indicators.md. Preserve the default macOS dot,
  bounded Custom delegates, effective-edge orientation and independent native
  group/frame overrides. Do not extract colors from the animated icon item.
- Capsule refinements: see docs/capsule-refinements.md. Share effectiveRadius
  across visible surfaces and the blur bridge. Glow must fill a rounded path,
  remain optional, and never capture animated icons. Separator spacing follows
  the logical group boundary and the delegate's visual leading edge.
- Glow pointer observation belongs on the tasks' common ancestor. A high-z sibling
  can suppress continuous task hover even with blocking:false. Keep regression
  coverage for hover movement as well as clicks, and gate light on rounded entry.
