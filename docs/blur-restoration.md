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

Local editing environment: Debian 13, no CMake or Qt/KF development headers.
Local compilation could not run; package installation was unavailable.
Whitespace checks passed. The Blur lifecycle checks workflow builds the real
plugin and runs the tests offscreen in Debian trixie with Qt 6/KF6.
Consult the pull request checks for the actual execution result.

## CachyOS: update an existing installation

Save any unrelated local source edits before checking out the branch. Keep your
existing panel and dock settings; do not remove/re-add the widget.

```bash
paru -S --needed git cmake gcc make extra-cmake-modules qt6-base qt6-declarative kwindowsystem
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
