# Capsule refinements and separator boundary

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

`CapsuleHoverTracker.qml` independently observes hover above the task content
with a non-blocking HoverHandler, even when zoom is disabled. It maps both X and
Y into the capsule without snapping either coordinate to its center. Selection
uses the existing task hit regions, so it does not depend on the tooltip's
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

Before merging, validate on CachyOS Wayland:

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
