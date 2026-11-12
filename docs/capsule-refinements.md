# Capsule refinements and separator boundary

> **Status (2026-11-12):** See [development status](development-status.md) for
> maintainer acceptance and merge readiness. Earlier pending checks below record
> the investigation history; they do not override the latest acceptance decision.
> For current installation/update instructions, use [README](../README.md#installation).


## Separator

The old separator was attached to `firstUnpinnedIndex`, with spacing always at
the local left/top edge. Reversing the visual order moved that task but not its
reserved edge, leaving the separator outside the unpinned group. Index zero also
prevented a divider if the model itself started with unpinned tasks.

`CapsuleGeometry.boundary()` now finds the first pinned-state transition, in
either direction. A single gap belongs to the following model delegate. Its
local edge follows horizontal reverse/RTL mirroring, or the vertical reverse
counter-rotation. The icon, running dot, Custom slot, divider and hover-coordinate
calculation all account for that same gap. There is no extra gap if every task
has the same pinned state. Repeater insertion/removal, index changes and pinned
state bindings invalidate the boundary; pointer motion does not rescan the list.

The model's grouping/sorting is unchanged. The divider still uses the existing
16 px gap and its original stroke. This assumes the existing contiguous pinned
and unpinned groups; deliberately interleaving groups does not add more dividers.

## Hover glow

Appearance → Capsule & Style provides:

| Key | Default | Range |
|---|---|---|
| hoverGlowEnabled | false | on/off |
| hoverGlowIntensity | 100% | 0–200% |
| hoverGlowRadius | 70 logical px | 1–256 |
| hoverGlowOpacity | 30% | 0–100% |
| capsuleRadiusCustom | false | automatic/custom |
| capsuleRadius | 10 logical px | 0–200, further clamped to geometry |

`CapsuleGlow.qml` fills a circular-arc rounded rectangle with a Qt Quick Shapes
radial gradient. The shape itself bounds the fill; it is not a rectangular clip
of an overflowing light texture. There is no ShaderEffectSource, offscreen mask,
blur pass, native plugin or timer. Pointer movement updates the gradient center;
only capsule geometry changes rebuild the path. Opacity fades in/out in 140 ms,
and source color changes blend in 120 ms. Position follows pointer coordinates
directly to avoid adding lag to magnification.

`CapsuleHoverTracker.qml` independently observes hover from the tasks' common ancestor
with a non-blocking HoverHandler, even when zoom is disabled. It maps both X and
Y into the capsule without snapping either coordinate to its center. Selection
first checks the capsule's actual rounded bounds, then chooses the nearest visible
task along the dock axis (including capsule padding). It does not depend on the tooltip's
`containsMouse` or `isTaskHovered` state. It handles delegate replacement through
coalesced Repeater notifications; no timer is introduced. A shared lazy `Kirigami.ImageColors` instance reads each
application's `model.decoration`, serving both Custom indicators and the glow.
Visited task colors remain cached while glow is enabled. SVG/raster icon sources
use Kirigami's native decoder; unavailable colors use the live Plasma accent.
Pinned non-running launchers use the same path. Disabling glow unloads its Shape
and all color extractors not needed by Custom indicators. No scene capture is
performed during pointer movement.

The glow is drawn above the base tint, below Liquid Glass gloss and a single
border pass, and behind task content. All four visible backgrounds support it.
Fully Transparent mode deliberately suppresses the glow and its color extraction
to preserve the mode's meaning. No Plasma panel background or global theme is
modified; the larger transparent magnification area never becomes the glow surface.

Fancy Tasks NG's Task.qml was inspected: it uses Kirigami.ImageColors and
MultiEffect to colorize a Plasma task frame. We reuse the native color-extraction
API already used by our indicators, but implement the capsule gradient directly;
no Fancy glow/frame-effect code or new third-party assets are copied.
Reference: https://github.com/DayDve/FancyTasksNG/blob/master/package/contents/ui/Task.qml
Qt radial gradient API: https://doc.qt.io/qt-6/qml-qtquick-shapes-radialgradient.html

QtQuick.Shapes is provided by qt6-declarative on CachyOS. Distributions splitting
QML runtime modules need the Shapes module (Debian: qml6-module-qtquick-shapes).
The full existing installer remains the supported installation route.

## Shared corner geometry

Automatic mode retains `min(width, height) / 3`. Custom mode clamps the requested
radius to `[0, min(width, height) / 2]`; zero is square. The background component
also clamps its input defensively. The resulting `effectiveRadius` drives solid,
translucent and glass bases, border, inset gloss, glow path and blur loader.
`BlurAreaBridge.qml` already forwards the loader's radius to `cornerRadius`.
`DockBlurItem::setCornerRadius()` already invalidates its cached rectangle and
reapplies blur/contrast, so no change to the proven native lifecycle is needed.
A new native regression checks radius-only transitions, including return to zero,
against both registered regions. No panel dimensions or padding are modified.

## Validation and remaining desktop checks

New tests cover schema defaults, unfocused/active/minimized color combinations,
ignored obsolete overflow settings, segment limits, both logical group orders,
all reverse/RTL orientation combinations, radius clamping, lazy glow unloading,
transparent mode, blur-loader radius forwarding and native radius-only updates.
A real offscreen software-rendered pixel test checks that rounded corners stay
unpainted, the interior glows, zero radius paints square corners, small/vertical
capsules stay bounded, and leaving hover fades the light away. This is rendered
component coverage, not live Plasma/KWin or GPU-performance validation.

Local validation on 2026-11-12: isolated Qt 6.8.2 / KF6 6.13 compilation passed;
all four available CTest suites passed in 9.72 seconds (blur, native-menu QML
bridge, installer workflow, indicators/capsule). QML parsing and git whitespace
checks passed. Full KIO launch tests require D-Bus, unavailable in this workspace;
they run with the other suites and staged installation in PR #3's CI checks.

Desktop regression matrix for future changes:

- Pin/unpin and open/close windows with both group orders, all four panel edges,
  reverse mode/RTL, grouped tasks and magnification near the separator.
- Separate unfocused color across applications and within groups, with/without
  dimming and minimized desaturation. Native group symbols remain; Custom + is gone.
- Halo while zoom is enabled/disabled; transitions between running apps and pinned
  launchers; fade on leave; immediate enable/disable; no stale color after icon changes.
- Solid, Translucent, System Blur and Liquid Glass; Transparent suppresses glow.
  Test radius 0/5/10/20 and maximum clamp with varied size, floating panels and HiDPI.
- Glow stays inside corners and below icons/badges/indicators/gloss/border during
  zoom and bounce. Test actual GPU responsiveness, multi-screen and hide/show.
- Wallpaper-derived accent changes, blur restoration, menus/Places/recents,
  Pin/Unpin, Test Bounce Animation, tooltips, progress/audio overlays and pure QML.
- Restart Plasma Shell and confirm settings persist. The disabled defaults must
  preserve the previous appearance.

Update the existing checkout with `git fetch origin`,
`git switch feature/advanced-dock-indicators`, `git pull --ff-only`, then
`./install.sh`. Accept its Plasma Shell restart prompt. Install the full plasmoid,
not only the optional native plugins. Do not create a competing user/system copy.

## Follow-up: running-task hover and two-axis tracking

Desktop feedback identified disappearance over running applications and requested
true two-axis pointer tracking. The previous halo was gated by task tooltip/hover
state and explicitly centered one axis. The latter is directly confirmed in the
old mapping; the exact selective Plasma event sequence is not reproduced in the
headless environment. The new independent observer removes this coupling and
leaves task zoom, tooltip, click and context-menu handlers unchanged.

A QML pointer integration test covers a launcher and a running-task fixture with
indicators and a hover-enabled MouseArea, while `isTaskHovered` remains false.
It verifies both coordinates, transition between tasks, leave detection, rotated
coordinate mapping and click delivery through the observer. Rendered pixel tests
also exercise a gradient center outside the capsule while keeping rounded corners
unpainted. Confirm the reported running-application case on the real desktop,
including tooltip previews and any enabled native task frames.

## Follow-up: preserve magnification hover delivery

The previous high-z sibling observer allowed clicks but prevented continuous
HoverHandler updates in underlying tasks. A new regression test reproduced this
failure before the fix; testing clicks alone was insufficient. The observer is
now itself a HoverHandler directly attached to the common ancestor, with no
higher-stacked item or reparented child handler. The regression passes with the
observer enabled and disabled; task magnification handlers remain unchanged.

Glow activation now requires the pointer tip inside the capsule's rounded shape,
using the same clamped corner radius. The larger magnification hit area no longer
activates it. Entry tests include points above/below the capsule, excluded rounded
corners, interior/padding and two-axis motion. Existing fade-out is retained after
leaving; it cannot be newly activated by mere proximity. When disabled the
observer and its model connections are inactive; there is no visual input layer.

Validation of the magnification follow-up: the continuous-task-hover regression
failed on the high-z observer and passed after attaching the observer to the
common ancestor. All four locally available CTest suites passed (10.04 seconds);
additional capsule-movement and disabled-observer tests passed. Desktop zoom and
running-task appearance still require maintainer confirmation on Plasma Wayland.

## Follow-up: shared native tooltip hover (after PR #3 merge)

The maintainer's recording shows the application label staying on the previous
application after the tooltip opens, together with the glow disappearing until
leaving and re-entering the dock. Magnification still follows the pointer.

Two independent mechanisms were verified:

- Plasma `ToolTipArea` accepts hover events. A real native ToolTipArea fixture
  prevented the ancestor-only glow observer from receiving task hover, whereas
  the earlier MouseArea fixture did not. `blocking: false` on the ancestor does
  not make native item hover delivery transparent.
- `ToolTipArea::hoverEnterEvent()` calls `showToolTip()` directly when transferring
  an already visible shared dialog. Updating the shared delegate only in our
  separate timer misses that path; the timer's old `!toolTipOpen` guard can also
  skip it. Native dialog visibility notifications are shared by previously
  connected areas and cannot identify the current owner.

See [libplasma ToolTipArea](https://github.com/KDE/libplasma/blob/master/src/declarativeimports/core/tooltiparea.cpp).
The existing TriangleMouseFilter was inspected but not identified as the cause:
these failures reproduce without it. Its interactive-preview handoff remains
unchanged. Exact compositor event ordering in the recording is not reproduced
by the offscreen test.

`TaskToolTipArea.qml` now prepares shared bindings on `aboutToShow`, covering both
native transfers and explicit timer openings. The actual binding owner sets
`toolTipAreaItem`; a dialog visibility broadcast no longer claims ownership.
The fallback timer also checks whether its task owns the content.

`TaskHoverHandler.qml` shares the existing task hover observation with the capsule
tracker as well as magnification. It adds no input surface and changes neither
hit geometry nor zoom calculations. The common-ancestor tracker still observes
padding, but uses the task's mapped pointer coordinates while native items accept
hover. Leaving the current source schedules one coalesced refresh so adjacent
enter/leave ordering cannot clear the new owner. Both paths use the existing
rounded-capsule entry test and rendering mask. Disabled glow performs no mapping
or task scan. No periodic timer, shader, blur, indicator or menu changes are needed.

### Regression evidence and remaining desktop checks

`tests/indicators/tst_tooltiphover.qml` uses the installed Plasma ToolTipArea and
real shared tooltip window, with the production hover and tooltip components.
Five cases cover horizontal/vertical orientation, interactive/non-interactive
windows and disabled glow. They exercise repeated native content transfers,
continuous pointer input, both coordinates, clicks, option changes while
stationary, rounded-corner exclusion, proximity rejection and leaving the dock.
Removing either the content hook or task forwarding makes its regression fail.
Earlier MouseArea and rendered capsule tests remain in place.

Local Qt 6.8.2 / Plasma runtime 6.3 offscreen validation: all four locally available
CTest suites pass, including the five new scenarios. Native build and QML parsing
pass. The full KIO application-menu suite requires a D-Bus session unavailable in
this local sandbox; CI runs that existing suite. This is not full desktop visual
validation or a claim of Plasma 6.8 Wayland reproduction.

On CachyOS, leave the pointer still until the name/preview opens, then cross several
pinned and running applications repeatedly without leaving the bar. Check that
labels/previews, glow color/position and magnification all follow the current
application. Move into an interactive window preview and back; check media controls,
grouped previews, context menus and clicks. Repeat with glow/zoom disabled, along
all panel edges, and after panel hide/show. The light must still activate only
inside the rounded capsule and fade on exit.

Install the complete plasmoid using `./install.sh` from
`fix/tooltip-hover-continuity`; accept its Plasma Shell restart prompt. Existing
configuration and optional native plugins use the established installation path.

### Maintainer acceptance — 2026-11-13

After installing the tooltip correction, the maintainer confirmed that everything
works and requested PR #4 preparation for manual merge. The reported stale-name
and disappearing-glow scenario is therefore accepted on the actual CachyOS
desktop. The broader checklist above remains useful for future regression work;
this confirmation does not assert that every listed combination was exercised.

Implementation CI passed all five CTest suites, the native build and staged
installation: [run 43213041215](https://github.com/SarbaLabs/plasma-macos-dock/actions/runs/43213041215).
No source changes were made after this acceptance; release selection stays none.
