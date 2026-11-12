# Blur restoration after panel transitions

## Scope and evidence

Reported environment: CachyOS, Plasma 6.8, Wayland, bottom panel in Dodge
Windows mode; reproduced by the reporter with native KWin blur and Better Blur
DX. System Blur and Liquid Glass share the optional DockBlurArea implementation.
This change does not implement refraction, alter panel geometry or change
magnification.

Verified in the original dock source:

- The rectangle cache survives QWindow visibility changes. updateBlurRegion()
  checks item visibility but originally did not check window visibility/exposure.
- An unchanged rectangle prevents both blur and contrast requests.
- main.qml sets the containment background to NoBackground.
- Hover changes task sizes and therefore the capsule rectangle. This provides a
  code path that bypasses the stale cache, consistent with the reported recovery.
  Actual event traces on the reporter's machine have not been captured.

Additional upstream source evidence (inspected 2026-11-12):

- [PanelView::updateMask](https://github.com/KDE/plasma-workspace/blob/master/shell/panelview.cpp)
  explicitly disables both effects for NoBackground. Mask changes and floating
  animation completion call this function. Thus external invalidation is not
  limited to destruction of a compositor surface.
- [WaylandAutoHideScreenEdge](https://github.com/KDE/plasma-workspace/blob/master/shell/autohidescreenedge.cpp)
  activates/deactivates a compositor screen-edge protocol object. A dodge cycle
  must not be assumed to call QWindow::hide()/show().
- [KWindowSystem's Wayland backend](https://github.com/KDE/kwindowsystem/blob/master/src/platforms/wayland/windoweffects.cpp)
  caches effect requests itself and reinstalls remembered effects on exposure.
  It removes remembered requests when enableBlurBehind/enableBackgroundContrast
  is called with false. Simply claiming that KWin discards all blur on hide is
  therefore not supported by this evidence.
- [Panel.qml](https://github.com/KDE/plasma-desktop/blob/master/desktoppackage/contents/views/Panel.qml)
  exposes panelMask, floatingness and touchingWindow.
- [QQuickWindow documentation](https://doc.qt.io/qt-6/qquickwindow.html#afterAnimating)
  documents afterAnimating as a GUI-thread signal; beforeRendering is emitted
  from the render thread. The old AutoConnection is not proof of a thread race,
  but afterAnimating makes GUI-thread ownership explicit and avoids queued work
  per rendered frame under the threaded render loop.

Inspected source blob IDs: PanelView 5c0ac43e7126b99332454886d59b9d7767ba0c73,
Wayland effects 7018b5b962db21292bf927d512978a4e73e0156f,
screen edge db4b1b4c73bd00331cb9e42cc8aa6076c8bf1a4e.
These upstream master snapshots are evidence of mechanisms, not proof of the
exact installed Qt/KF/Plasma revisions or event ordering on CachyOS.

**Diagnosis:** the dock's cache models geometry but not the lifetime/ownership
of window effects. Both window lifecycle changes and Plasma overwriting effects
can invalidate it. The exact triggering sequence in the reported session still
requires a real KWin test.

## Implementation

DockBlurItem observes Show/Hide/Expose/Move/Resize and platform surface events.
It invalidates its rectangle and coalesces restoration in a single zero-delay
timer, after the triggering event handler has returned. Restoration waits for a
visible, exposed window; future exposure schedules a new attempt. There is no
periodic retry and no arbitrary sleep.

The restoration pass disables and re-enables both effects to bypass the
KWindowSystem cache too, using the current rounded region and tuning values.
It requests a frame to commit the new surface state. Normal afterAnimating
checks retain the rectangle cache, so idle frames do not send effect updates.
During panel floating/mask animation, notifications can cause a coalesced restore
per event-loop turn; this work stops with the animation.

BlurAreaBridge discovers a visual ancestor with the panel's mask/floating
properties and observes its mask, floatingness and touching-window notifications.
This covers compositor-managed dodge and the final floating animation update,
even if QWindow.visible remains true. The connection is optional and tolerates
missing signals; it does not import private Plasma C++ types. This is nevertheless
an integration dependency on Plasma's QML panel properties and must be rechecked
when Plasma changes its panel implementation.

Pending work is stopped on window transfer/surface teardown. QPointer protects
window destruction; timer callbacks belong to the item and all geometry and
effect operations run on its GUI thread. Disabled/invisible items clear effects.
Tracking starts for an already attached constructor parent as well as subsequent
windowChanged notifications; the self-connection is removed before QQuickItem's
base destructor detaches the item. Surface teardown clears remembered effects
while the surface is still valid.
The existing optional loader and pure-QML fallback are unchanged. A method guard
also tolerates updating the QML package before updating the native plugin.

Like the original implementation, this assumes one dock effect owner per panel.
It does not arbitrate multiple blur-writing widgets sharing the same window.

## Automated validation

The QtTest executable uses the production DockBlurItem and real Qt Quick
windows, with recording replacements for the two KWindowEffects calls.
It checks 20 hide/show cycles without pointer events, rounded regions and tuning,
idle-frame caching, coalescing, enable/disable, item visibility, exposure,
window transfer, pending destruction and the actual QML bridge against a
synthetic panel that clears effects while the window stays visible.
Thread checks reject effect calls outside the GUI thread.

The fake backend verifies requests, not compositor rendering. It cannot prove
visual correctness, Wayland surface timing or Better Blur DX compatibility.

Local validation completed on Debian 13 using dependencies extracted into an
isolated directory (no system installation): GCC 14.2, CMake 3.31.6, Qt 6.8.2,
KWindowSystem 6.13.0. Debug compilation of both the real native plugin and test
executable passed. CTest passed 1/1 executable (three regression cases plus
QtTest setup/cleanup), 0 failures, in 1.26 seconds using Qt's offscreen platform
and software renderer. Whitespace and workflow YAML parsing checks passed.
The tests caught constructor-parent tracking and destructor connection problems
during development; both were corrected before the successful run.

The Blur lifecycle checks workflow reproduces the build and offscreen tests in
Debian trixie. No GitHub workflow execution was reported after the initial
branch push; local results above are independent of GitHub Actions availability.
No real Plasma/KWin, hardware rendering, threaded render loop or CachyOS visual
acceptance test has been performed in this environment.

## CachyOS: update an existing installation

Save any unrelated local source edits before checking out the branch. Keep your
existing panel and dock settings; do not remove/re-add the widget.

```bash
paru -S --needed git cmake gcc make extra-cmake-modules qt6-base qt6-declarative kwindowsystem libplasma
git clone --branch fix/blur-after-panel-restore https://github.com/SarbaLabs/plasma-macos-dock.git plasma-macos-dock-blur-fix
cd plasma-macos-dock-blur-fix
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_PLUGIN_ONLY=ON -DBUILD_TESTING=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

For an existing checkout, fetch origin and switch to
fix/blur-after-panel-restore instead of cloning over the directory.

Before installing, locate the existing module. The upstream install.sh uses
/usr; an installation made with different CMake settings may use /usr/local
or a custom QML import path. Avoid leaving a second, shadowing plugin:

```bash
qtpaths6 --query QT_INSTALL_QML
find /usr/lib/qt6/qml /usr/local/lib ~/.local/lib -path '*/com/github/mattanis/macosdock/blur/libdockblurplugin.so' -print 2>/dev/null
```

For the usual /usr installation, back up the module directory
/usr/lib/qt6/qml/com/github/mattanis/macosdock/blur and the existing user widget
directory ~/.local/share/plasma/plasmoids/com.github.mattanis.macosdock to a
timestamped backup directory. Check package ownership with
`paru -Qo /usr/lib/qt6/qml/com/github/mattanis/macosdock/blur/libdockblurplugin.so`.
If package-owned, rebuild the owning package instead of overwriting its files.
If installed under a custom prefix, use that original prefix/QML directory in
CMake and back up that location instead.

Install only the native module system-wide, and update the user widget package:

```bash
sudo cmake --install build
kpackagetool6 --type Plasma/Applet --upgrade .
systemctl --user restart plasma-plasmashell.service
```

The CMake install touches only the module library and qmldir in plugin-only
mode; it does not replace the system-wide widget. If the widget exists only
system-wide, use `kpackagetool6 --type Plasma/Applet --install .` to create a
user installation rather than using sudo for kpackagetool6.

**Both the native plugin and BlurAreaBridge.qml must be updated.** Updating only
the plugin misses Plasma's mask/floating notifications. Restart Plasma Shell
after both updates to unload the previous shared library. Panels and the desktop
briefly disappear; applications stay open. If the systemd user service is not
available, log out and log back in instead.

Rollback: restore the backed-up plugin and widget directories and restart Plasma
Shell again. If you created a new user widget overlay over a system installation,
remove that user package with kpackagetool6 to return to the system package.
Do not use the upstream uninstall script as a rollback for this update.

## Manual acceptance checklist (pending)

Use a detailed wallpaper or window behind the capsule. First test native KWin
blur, then Better Blur DX separately; do not enable both effects simultaneously.
Record Plasma, Qt and Frameworks versions, effect used, panel edge and outcome.

1. Select System Blur: verify rounded blur immediately after shell restart.
2. Put the pointer well outside the dock. Maximize/overlap a window to hide the
   panel, then minimize/move it away using keyboard shortcuts. Blur must return
   with the capsule, without hovering it. Repeat at least 20 times, including
   rapid cycles and multiple overlapping windows.
3. Repeat with Liquid Glass. Switch repeatedly between both modes and a solid
   background; disabled blur must leave no stale region.
4. Enter/leave the dock and magnify icons: check rounded boundaries, padding,
   saturation, contrast and brightness, including non-default values.
5. Check Always Visible, floating/non-floating panels and all four screen edges.
6. Restart Plasma Shell and check initial appearance again.
7. In a separate test account/session without the native module, install the QML
   package and verify all existing pure-QML modes and fallback behavior. Do not
   uninstall a working plugin merely to perform this test.

If blur still disappears, report whether floating transitions occurred and
whether the panel window actually became unexposed. The unverified possibilities
include Plasma changing its panel properties or another widget overwriting
effects after the queued pass. Do not replace event handling with a permanent
polling timer to conceal such a failure.

## Follow-up: wallpaper-derived accent colors (2026-11-12)

### User validation and newly isolated trigger

The maintainer installed the first fix on CachyOS / Plasma 6.8 / Wayland and
confirmed that the original hide/show bug is resolved. The first GitHub Actions
build/test also passed (run 43054923570). The initial validation history above is
retained; it did not cover wallpaper-driven palette changes.

The remaining failure occurs on the built-in wallpaper slideshow, **only when
wallpaper-derived accent colors are enabled**, as confirmed by the maintainer.
The visible dock loses blur until hover or panel/window interaction. Wallpaper
changes with that accent option disabled do not reproduce the reported issue.

### Source-verified mechanism

1. [ImageStackView.replaceWhenLoaded](https://github.com/KDE/plasma-workspace/blob/master/wallpapers/image/imagepackage/contents/ui/ImageStackView.qml)
   updates the wallpaper accent color when the new image is activated.
2. [DesktopView::setAccentColorFromWallpaper](https://github.com/KDE/plasma-workspace/blob/master/shell/desktopview.cpp)
   sends the accent color to the accent-color service when this feature applies.
3. [AccentColorService::setAccentColor](https://github.com/KDE/plasma-workspace/blob/master/kcms/colors/accentColorService/accentColorService.cpp)
   applies the color scheme and broadcasts PaletteChanged. It also starts
   KWin's BlendChanges animation; this is not itself evidence of lost blur state.
4. [ThemePrivate::eventFilter / colorsChanged](https://github.com/KDE/libplasma/blob/master/src/plasma/private/theme_p.cpp)
   handles ApplicationPaletteChange and schedules a deferred themeChanged
   notification. [Plasma::Theme](https://github.com/KDE/libplasma/blob/master/src/plasma/theme.cpp)
   instances forward the shared theme's notification.
5. PanelView connects its themeChanged signal directly to updateMask. With the
   dock's NoBackground containment, updateMask disables both blur and contrast.
   It need not change the QML panelMask property, visibility or capsule geometry.
6. None of the previous restore triggers observes that theme notification.
   The rectangle cache remains unchanged, so normal geometry checks do not
   repair the externally cleared effects.

This extends the original shared-window-effect invalidation diagnosis, but the
new trigger is a **deferred palette/theme update**, not a hide/show event.
Listening only to ApplicationPaletteChange could restore too early, before
Plasma's own deferred update clears the effects again.

Also inspected KWin's blur surface-state tracking and BlendChanges effect:
the latter temporarily redirects windows for a cross-fade and then unredirects
them; it does not call KWindowEffects to disable the client's blur request.
There is no evidence here that every wallpaper transition discards panel
surfaces or requires reapplying effects unconditionally.

Additional inspected source blob IDs: ThemePrivate
fcba0a277e955559e8afe05f08660f910ece72cd; Theme
ad5c1badc1d93786bf17f02389d11b9956126aa2; DesktopView
271fe12d410364493541af557b45b36e1ebcda67; KWin Blur
f81c64429c90978c721720c2786decd7130e9c71; BlendChanges
fc163a2f808c3a2b7b49138475dea83cb6871638.
These are inspected upstream snapshots, not runtime traces from the user's
installation. The user's accent-color A/B observation corroborates the path.

### Minimal implementation extension

Each native DockBlurItem owns a Plasma::Theme observer, connected to the existing
scheduleBlurRestore slot. Its zero-delay, single-shot queue runs after the
synchronous theme notification fan-out, regardless of whether PanelView or the
dock receives the signal first. Further theme notifications schedule their own
coalesced pass. The previous visibility, surface, mask and floating-state
handling is preserved.

No new polling, wallpaper listener, hour-based timer, animation delay or QML
change is introduced. Hidden/disabled items remain subject to the existing
guards, and exposure restores the current region when the panel returns.
The QObject-owned observer is disconnected/destroyed with the native item.

The native build now links Plasma::Plasma. libplasma development packages were
already listed in README; CMake and CI now require them explicitly. Config and
CoreAddons are discovered explicitly for older Plasma CMake exports. Pure-QML
installations still need no native build or extra QML import.

### Regression results and limits

- Before adding the observer, both new data rows failed: a real libplasma
  ApplicationPaletteChange -> deferred themeChanged caused the simulated
  NoBackground panel handler to clear effects, with no restoration.
- After adding it, the real plugin and regression executable compiled in Debug.
  Full CTest passed 1/1 executable in 8.59 seconds: five regression rows plus
  setup/cleanup, 7 QtTest passes, 0 failures.
- Environment: Debian 13, GCC 14.2, Qt 6.8.2, KF6 6.13.0, libplasma 6.3.5,
  offscreen/software rendering. KWindowSystem's missing offscreen platform
  plugin warning is expected; effect requests are recorded by the test backend.
- The new test uses the real Plasma theme notification machinery, with the
  simulated panel theme connected both before and after the native dock's
  theme. Each order checks 20 stationary palette cycles without pointer events,
  rounded regions and non-default tuning, updates while hidden, an update after
  a queued panel restoration, disabled blur and no effect writes on idle frames.
- All earlier hide/show, exposure, surface, window-transfer and QML bridge tests
  still pass. Whitespace checks pass.

This is not a real wallpaper slideshow or KWin rendering test. The new fix still
requires CachyOS visual validation for both System Blur and Liquid Glass, actual
overlapping floating animations, Better Blur DX and pure-QML fallback. The prior
hide/show behavior is user-confirmed; do not infer that all other checklist items
were tested. No changes to geometry, styling, magnification or version numbers.

### Update the already-tested installation

For the maintainer's existing ~/git/plasma-macos-dock checkout:

```bash
cd ~/git/plasma-macos-dock
git switch fix/blur-after-panel-restore
git pull --ff-only origin fix/blur-after-panel-restore
paru -S --needed libplasma
./install.sh --plugin-only
ctest --test-dir build --output-on-failure
```

This follow-up changes only native runtime behavior; the previously installed
QML bridge stays valid. The existing install script compiles in Release and
replaces the native module under /usr using sudo. Keep the backup/prefix/package
ownership precautions described earlier if the original module was installed
elsewhere or belongs to a package. No removal/re-addition of the widget is needed.

Accept the install script's Plasma Shell restart prompt, or restart once after
installation with `systemctl --user restart plasma-plasmashell.service`.
A restart is required to unload the previous shared library.

To test without waiting an hour, use the built-in slideshow's **Next Wallpaper
Image** contextual action on the desktop. Keep the pointer away from the dock.
With wallpaper-derived accent colors enabled, advance through images with
different dominant colors at least 20 times, allowing each transition to finish;
also test a few rapid advances. Repeat in System Blur and Liquid Glass, with the
panel visible, hidden behind a window, and during floating/overlap transitions.
Check ordinary theme/color changes as well. The accent-disabled case is a useful
control, not a workaround. Record the exact Plasma/Qt/KF versions and any remaining
flicker or loss; visual success is pending the maintainer's confirmation.

## Follow-up: installed-plugin test isolation (2026-11-12)

The maintainer reports that the updated dock works correctly on CachyOS, but
Qt 6.12's test run fails at panelResetWhileWindowStaysVisible's initial blur
assertion. The other lifecycle and palette tests pass. This report is not a
claim that every manual acceptance scenario has been completed.

Reproduced locally on Qt 6.8.2 by placing the real native module on the QML
import path: QML loads that plugin despite the test's qmlRegisterType call,
replacing the instrumented DockBlurItem registration. Calls then go to the real
KWindowEffects backend instead of the test recorder, so its blur flag stays
false. This is test contamination by the installed module, not evidence of a
new runtime blur failure or a Qt 6.12-only regression.

The test now gives a temporary plugin-free qmldir precedence over installed
modules and protects its registered type with qmlProtectModule. The descriptor
is necessary because the bridge's unversioned import still resolves a qmldir;
protecting the registration alone does not stop that plugin lookup.
A build-local copy of the real plugin and qmldir is
explicitly added to the test import path to exercise this situation on clean CI
runners too. No production source, installed plugin or QML behavior is changed.
The offscreen warning "Could not find any platform plugin" is expected from
KWindowSystem; unlike the failed assertion, it does not fail the test.

Validation: the unisolated test reproduced the exact initial blur assertion
failure with the native plugin on the import path. After isolation, the full
suite passes locally with that plugin fixture: 1/1 CTest executable, seven
QtTest passes, zero failures, 8.55 seconds on Qt 6.8.2. Qt 6.12 remains to be
checked by the maintainer; no production fix is required by this result.

To update only the tests in an existing configured checkout:

```bash
cd ~/git/plasma-macos-dock
git pull --ff-only origin fix/blur-after-panel-restore
cmake --build build --parallel
ctest --test-dir build --output-on-failure
```

No reinstall or Plasma Shell restart is required for this test-only correction.
