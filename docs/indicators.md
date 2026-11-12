# Advanced dock indicators

> **Status (2026-11-12):** See [development status](development-status.md) for
> maintainer acceptance and merge readiness. Earlier pending checks below record
> the investigation history; they do not override the latest acceptance decision.
> For current installation/update instructions, use [README](../README.md#installation).


## Architecture and compatibility

The default `indicatorMode=0` retains the original `runningDot` in `Task.qml`,
including its size, color, opacity, anchors and animation. No configuration
migration is needed. Unknown mode values fall back to macOS.

- **macOS (0):** original running dot.
- **Plasma (1):** the existing `KSvg.FrameSvgItem`, using `widgets/tasks`,
  normal/focus/minimized/attention states and Plasma's oriented prefix fallbacks.
  This is the theme's actual task frame, not a painted imitation.
- **Custom (2):** `CustomIndicators.qml`, with bounded geometry computed by
  `code/IndicatorLogic.js` and model events adapted by `IndicatorTaskState.qml`.

`nativeGroupIndicator` and `taskDecorations` independently accept Mode default
(0), Enabled (1), Disabled (2). Mode default enables both in Plasma mode and
neither in macOS/Custom mode, preserving existing installations. Existing popup
frames remain enabled in Mode default. Disabling frames changes their opacity;
the frame remains available to task logic and sizing. The capsule and blur are
unaffected. Explicit overrides survive mode changes.

Plasma themes combine state and background in one SVG. With Plasma mode and
frames disabled, `NativeTaskIndicator.qml` clips the actual frame to its
panel-facing margin. Themes that express state only in the center may show little
or no state distinction in this combination. Enable decorations for the complete
native theme appearance. This is a theme limitation, not a replacement theme.

The previously disabled group SVG was also absent from the dock's task creation
path. It is now loaded on demand for actual groups with more than one child,
using the theme's `group-expander-bottom/top/left/right` elements. It has no input
handler. **The native group symbol is the only grouped-window marker.** The
experimental Custom + has been removed following desktop testing; an old
`indicatorOverflow` value is ignored, without rewriting unrelated saved settings.

## Custom settings

All settings are declared in `contents/config/main.xml`, exposed by the separate
Indicators page and persisted through Plasma's existing KConfig infrastructure.
No native module or new runtime dependency is required.

| Setting | Default / behavior |
|---|---|
| Show indicators / animate | Enabled / enabled (120 ms state transitions) |
| Style | Dots; also Line (shared length) and Dashes (per-window length) |
| Position | Effective panel edge; optional bottom/top/left/right override |
| Edge distance | 2 logical px from the visible capsule edge |
| Inactive dimensions | 4 px thickness, 12 px length |
| Active dimensions | Resize enabled; 5 px thickness, 20 px length |
| Hover dimensions | Resize disabled; separate 6 px / 24 px, or reuse active sizes |
| Group dimensions | Separate sizes disabled; 4 px / 8 px when enabled |
| Roundness / spacing / alignment | 100%, 2 px, centered thickness |
| Maximum segments | 4 (range 1–8); no Custom + |
| Separate unfocused color | Disabled; saved color #3daee9 |
| Active group emphasis / dim inactive | Both enabled |
| Inactive opacity / minimized desaturation | 55% / disabled |
| Color | Plasma accent; optionally icon dominant color or custom #3daee9 |

Dots remain circular regardless of saved dash roundness. Sizing precedence is
hover, active, grouped, inactive. Hover can reuse saved active dimensions even
when activation resizing is disabled. Disabled controls do not erase settings.
The preview uses the same renderer, six windows and one active window.

Geometry fits the current task slot and existing capsule padding: requests that
would extend the dock are clamped, rather than expanding the panel. Custom edge
overrides may therefore offer less space on the icon-facing side of very thin
layouts. Values are logical pixels and follow Qt scaling. Effective location is
already the dock's visual location; reverse-layout transforms are not applied a
second time. Indicators stay at the task base during bounce, like the original
dot, and never contribute to layout or pointer handling.

## Model and performance

The renderer creates at most eight window segments.
A numeric Repeater model preserves delegate identity through hover/zoom. The
model adapter coalesces model signals with `Qt.callLater`, queries at most eight
minimized roles, and identifies the active child through the active model index
and its parent. If the active child is beyond the limit, the final segment carries
the active state. It summarizes hidden windows; it is not individually
desaturated based on unqueried hidden children.

There are no timers or per-frame model scans. Dominant colors are lazily extracted
with `Kirigami.ImageColors` from `model.decoration`, not a grab of the animated
icon. Missing/transparent colors fall back to the live Plasma accent. Native and
Custom extras are unloaded outside their selected mode; the group SVG is loaded
only when visible. No shaders, offscreen effects or native plugin are added.

## References and licensing

- [KDE Task.qml](https://github.com/KDE/plasma-desktop/blob/master/applets/taskmanager/qml/Task.qml)
  (reviewed blob `90530078c5f812301770e79841e27206c44321a5`).
- [KDE GroupExpanderOverlay.qml](https://github.com/KDE/plasma-desktop/blob/master/applets/taskmanager/qml/GroupExpanderOverlay.qml)
  (reviewed blob `c9b85cf02e13ad1e656556f04a1ac0f12b68c562`).
- [Fancy Tasks NG Indicators.qml](https://github.com/DayDve/FancyTasksNG/blob/master/package/contents/ui/Indicators.qml)
  (reviewed blob `3abd8634a71b64a9c687dcf6c89a1e968834c62d`),
  ConfigIndicators.qml, ConfigAppearance.qml, GroupExpanderOverlay.qml and schema.
- [Kirigami ImageColors](https://github.com/KDE/kirigami/blob/master/src/imagecolors.h).

Fancy's inspected indicator/configuration source files explicitly use
GPL-2.0-or-later, despite a GPLv3 root LICENSE. The adapted state sizing,
active-child membership and overflow approaches retain the relevant Vitaliy Elin
and SushiTrash copyright notices and GPL-2.0-or-later identifiers. KDE's existing
group component retains Eike Hein's notice. No unrelated Fancy architecture or
assets are imported. The repository's existing license remains unchanged.

## Automated validation

Qt Quick tests cover mode defaults, independent native overrides, running/group
counts, segment limits and hidden active children, dimension precedence, size bounds,
edge selection, colors/desaturation, bounded model updates and stable delegates.
They instantiate the real configuration page and native components, and check
all four group symbols against the installed Breeze task SVG. The model adapter
uses a fake model in these tests; it does not substitute for a live TasksModel
acceptance test. Existing native menu, blur and installer tests remain intact.

Build tests with `BUILD_TESTING=ON`; CTest runs `indicators` offscreen. Qt Quick
Test and its QML module are test-only dependencies. CI installs these plus the
existing Plasma/Kirigami/KSvg/KCM modules and checks a staged full installation.

### Validation record (2026-11-12)

- Local isolated Qt 6.8.2 / KF6 6.13: compilation and four available CTest
  suites passed (blur, native-menu QML bridge, installer, indicators).
- GitHub Actions run [43164663165](https://github.com/SarbaLabs/plasma-macos-dock/actions/runs/43164663165):
  full build, all five CTest suites passed in 9.45 seconds, including actual
  KIO application launches under D-Bus; staged full installation passed.
- Indicator suite: eight test functions plus setup/cleanup, including defaults
  read from the real KConfig XML and compared to configuration-page properties.
- Follow-up assertions check actual Custom segment placement on all four edges
  and round dots after switching from square dashes. Disabled Custom indicators
  also unload the model adapter and icon-color extractor.
- No live Plasma session was used for acceptance. The local workspace cannot
  host a D-Bus session; CI provides that coverage, not live compositor coverage.

## CachyOS installation and acceptance

For a new local tracking branch:

```sh
cd ~/git/plasma-macos-dock
git fetch origin
git switch --track origin/feature/advanced-dock-indicators
./install.sh
```

If the branch already exists, use `git switch feature/advanced-dock-indicators`
and `git pull --ff-only` instead. The installer updates the complete plasmoid and
optional native components. Do not install only the C++ plugin for this change.
Use its Plasma restart prompt; if deferred, restart later with
`systemctl --user restart plasma-plasmashell.service`. No logout or global theme
change is required. Preserve the installer's existing handling of user/system
plasmoid copies; do not create a second copy manually.

Retain this matrix for future desktop regression testing:

- Existing and fresh settings: original macOS dots, no new frame/group by default.
- Switch all modes repeatedly; saved Custom values persist after Shell restart.
- Plasma: active/inactive/minimized/attention and grouped SVGs in Breeze and an
  alternate theme; test explicit group/frame overrides in all modes.
- Custom: one window, groups up to/above limit, active child before/after limit,
  close/open/reorder/focus windows, ungroup to one, pinned non-running launcher.
- All styles, hover/active/group sizing priority, opacity, minimized desaturation,
  accent/theme changes, icon color fallback and custom color.
- Bottom/top/left/right, reverse layout, floating/non-floating, multiple screens,
  HiDPI, small/large icons, 40 px at 1.5x zoom and larger zoom; no clipping,
  overlap, jitter or panel expansion. Test edge overrides with the native group symbol.
- Magnification on/off, bounce and Test Bounce Animation, badges/audio/progress.
- Native context actions, Places (including spaces), recents, Pin/Unpin,
  window actions; System Blur/Liquid Glass, hide/show and wallpaper accent changes.
- Pure-QML install without either optional plugin: indicators and settings work.

Headless component checks do not establish visual correctness, live Wayland
focus behavior, screen placement or compositor performance. The maintainer accepted PR #3 for manual merge on 2026-11-12. This does not
assert that every edge/theme/scale combination in the matrix was individually tested.

## Refinements after desktop acceptance (2026-11-12)

The maintainer confirmed the three modes work on CachyOS. The Custom + did not
work reliably there and was explicitly retired, rather than adding another
window-group marker. Its schema entry, UI, delegate branches and obsolete tests
were removed; the maximum segment limit and hidden-active-child handling remain.

Custom indicators can now select a separate unfocused color. The pipeline is:
choose active source or optional unfocused color, optionally desaturate minimized
windows, then apply inactive opacity. This uses the existing active child index,
so inactive members of the focused group also receive the unfocused color. The
option defaults off, preserving the previous automatic colors and opacity.

See [capsule-refinements.md](capsule-refinements.md) for the separator, optional
hover glow, radius synchronization, additional tests and manual checks.
