# Development status

## Maintainer acceptance — 2026-11-12

Repository: [SarbaLabs/plasma-macos-dock](https://github.com/SarbaLabs/plasma-macos-dock).
All pull requests target this fork's `master`.

- **PR #1 — blur restoration:** tested and merged before the indicator work.
  Includes panel hide/show and wallpaper-derived accent/theme updates.
- **PR #2 — native application context menus:** tested and merged before the
  indicator work. Preserve desktop actions, Places, recents, Pin/Unpin and bounce.
- **PR #3 — indicators and capsule refinements:** the maintainer has accepted the
  current result and requested final documentation/readiness preparation. The
  maintainer will perform the merge; the PR remains open until then.

The PR #3 scope includes macOS/Plasma/Custom modes, native group symbols and task
frame controls, separate unfocused colors, removal of the Custom +, corrected
separator placement, optional two-axis hover glow bounded by the capsule, and
custom pixel corner radius. Defaults preserve the prior appearance.

The final hover correction observes the common ancestor, preserving continuous
magnification events. Activation requires actual rounded-capsule entry. A
regression reproduced the high-z observer failure before the fix and passed
following the correction. The maintainer subsequently indicated readiness to merge
and confirmed finding the already implemented pixel-radius control.

This acceptance records the maintainer's actual feedback. It does not claim an
exhaustive test of every theme, screen edge, scaling factor or remote Place.
Keep the detailed regression matrices in the technical documents for future work.

## Automated evidence

Implementation head before documentation preparation:
`80664a7a0f0a37d69f1ea548799b5e35afdf5307`.
[GitHub Actions run 43174750418](https://github.com/SarbaLabs/plasma-macos-dock/actions/runs/43174750418)
passed the full build, all five CTest suites and staged installation (9.83 seconds
for CTest). Tests cover blur, actual KIO launches under D-Bus, optional native-menu
QML integration, installer workflow and indicator/capsule/pointer behavior.

Local offscreen tests supplement this evidence; they are not live Wayland visual
validation. Final documentation-only changes are checked for links, repository
references and whitespace; the PR's checks show the current commit's CI status.

## Merge and release policy

- Ready for maintainer review/manual merge into **SarbaLabs/master**.
- Release selection: **none**. No version bump or release publication.
- No automatic merge has been enabled or performed.
- After merge, update the existing `~/git/plasma-macos-dock` checkout from this
  fork's `master`, then run `./install.sh` and accept the Plasma Shell restart.
- Keep package/plugin IDs and copyright notices unchanged; upstream attribution
  is intentional and does not designate the installation source for this fork.

## Documentation map

- [README](../README.md): fork installation, updates and user-facing settings.
- [Blur restoration](blur-restoration.md): lifecycle evidence and historical checks.
- [Application menus](application-context-menus.md): KDE APIs, optional module and tests.
- [Indicators](indicators.md): rendering modes, settings, source attribution.
- [Capsule refinements](capsule-refinements.md): separator, glow, radius, hover regressions.
- [AGENTS.md](../AGENTS.md): constraints for future development sessions.
