# Native application context menus

## Scope and architecture

The original QML backend returned empty lists from jumpListActions, placesActions
and recentDocumentActions. ContextMenu.qml already supports the QAction lists,
section headings, submenus and the Show All Places signal. It is retained without
changes, including its Pin/Unpin/activity-launcher logic, Test Bounce Animation,
window/group/media actions and applet/panel configuration. Launcher persistence
and bounce implementation are unchanged.

ApplicationMenuBridge.qml forwards only those three methods and showAllPlaces to
a focused optional native backend. NativeApplicationMenuBackend.qml is loaded
dynamically, so an absent or incompatible native module leaves empty lists and
all existing QML actions available. This works independently of the selected
background style and of the optional blur module.

The separate module `com.github.mattanis.macosdock.menus` is installed alongside,
not inside, the existing blur module. `BUILD_NATIVE_MENUS=OFF` permits building the
blur plugin without the new dependencies. The normal installer builds both.
No global shortcuts, TaskManager instances, resource tracking service, compositor
hooks or polling are introduced. The full private Plasma Backend is deliberately
not instantiated: its constructor also sets up global shortcuts.

## KDE mechanisms and maintenance

The focused backend adapts the menu-related implementation from
[KDE's task manager backend](https://github.com/KDE/plasma-desktop/blob/master/applets/taskmanager/backend.cpp)
(reviewed 2026-11-12, blob `1005d2a98135b14e11e74c2dd5a808463c52b8b5`).
Original GPL copyright notices are retained.

- **Desktop actions:** resolve `applications:` IDs through KService, or use the
  local desktop-entry path. KService/KServiceAction supply localized text, icons,
  separators and NoDisplay metadata. KIO::ApplicationLauncherJob launches the
  selected KServiceAction, without parsing or executing shell command strings.
- **Places:** only services declaring the FileManager category receive Places.
  KFilePlacesModel supplies actual bookmarks and URLs. Its isHidden check also
  respects hidden groups. The first group remains inline; later groups use
  native QMenu submenus. As in Plasma, more than seven top-level entries are
  shortened to five plus a More action, which reopens the existing context menu
  with all Places. Selection uses ApplicationLauncherJob::setUrls({url}); spaces
  and remote URLs remain structured arguments. Removable-device discovery and
  availability depend on KDE's model and the desktop session, as upstream.
- **Recents:** KActivities::Stats::ResultSet queries UsedResources for the service
  agent and current activity, ordered by recent use, limited to five displayed
  entries. Section headings distinguish downloads, connections and folders.
  Forget uses the same KDE Stats query and does not maintain a private database.
  The activity-manager configuration is re-read at construction and activation;
  NoApplications and per-application allow/block policy are respected. Recorded
  resource filtering remains KDE's responsibility. A MIME mismatch uses
  KApplicationTrader's preferred service, as upstream.
- **Ownership:** QActions belong to the menu passed from QML. Native submenus
  are deleted when that owner is destroyed; connections have the backend as their
  context. KIO jobs retain their own service/action and URL values after the menu
  closes. KNotificationJobUiDelegate reports launch errors through KDE.
- **Translations:** native strings use the existing
  `plasma_applet_org.kde.plasma.taskmanager` catalog explicitly. Application and
  Places labels remain supplied by KDE. Existing QML localization is unchanged.

The native System Settings popularity ranking is intentionally not copied: its
ordinary desktop actions are available, but ranking is outside this feature's
scope. Do not replace this focused backend with the complete private applet
backend or change pin persistence when maintaining these integrations.

Additional native build dependencies: Qt Widgets, KF6 KIO (including
KIOFileWidgets/KIOGui), Service, I18n, Notifications and PlasmaActivitiesStats.
The transitive dependencies are resolved by CMake/package management. Tests also
use Python 3, kbuildsycoca6 and dbus-run-session.

## Validation

Local environment: Debian 13, GCC 14.2, Qt 6.8.2, KF6 6.13 and Plasma libraries
6.3.x, using isolated dependency packages. No graphical Plasma/KWin session.

Completed locally:

- Native modules and regression binaries compile.
- BUILD_NATIVE_MENUS=OFF configures and builds the existing blur-only module.
- Real KService cache and desktop action metadata: names/icons, NoDisplay,
  application-ID/local URL resolution, missing services/actions and ownership.
- Real KFilePlacesModel: custom local and remote bookmarks, hidden Places,
  grouped submenu construction and Show All Places signal.
- Disabled/per-application-blocked recent history returns no actions.
- QML bridge loads the actual plugin, returns its actions and forwards its signal;
  without the optional component it returns an empty list and remains usable.
- Existing blur lifecycle tests pass, including theme/palette restoration.
- Installer branching tests use command stubs: no privileged operations occur.
  Full installation updates an existing user override, including equal-version
  development updates; plugin-only installation leaves QML untouched. Full mode
  explicitly resets a cached BUILD_PLUGIN_ONLY=ON setting.
- Shell syntax and diff whitespace checks pass.

The workspace prohibits D-Bus socket creation. Consequently local subprocess
launch validation is unavailable; the full CTest suite runs those integration
cases under dbus-run-session in GitHub Actions. They activate real KIO jobs into
a probe executable and inspect the actual argv for desktop actions, a profile
argument with spaces, a local Place with spaces and an sftp URL with spaces.
No shell parsing, mocked launcher or remote server is used for these tests.
A passing argument test does not establish that a real remote server is reachable.

Positive recent-history results/forgetting across activities, real Firefox and
Dolphin behavior, menu focus/layout, pin persistence and bounce animation require
the manual desktop checks below. Preserving their existing handlers is not a
claim of graphical validation.

## Installation on CachyOS

For an existing checkout, after fetching/checking out the feature branch:

```bash
cd ~/git/plasma-macos-dock
git fetch origin
git switch --track origin/feature/native-application-context-menus
paru -S --needed cmake gcc extra-cmake-modules qt6-base qt6-declarative kwindowsystem libplasma kio kservice ki18n knotifications plasma-activities-stats python
git pull --ff-only
./install.sh
ctest --test-dir build --output-on-failure
```

If the local feature branch already exists, use `git switch
feature/native-application-context-menus` instead of `--track`.

Use the full installer for the first menu update: both the QML bridge and native
module are needed. `--plugin-only` cannot add the bridge to old QML.
The script installs to `/usr`, with the QML modules in KDE_INSTALL_QMLDIR and the
applet in `/usr/share/plasma/plasmoids/com.github.mattanis.macosdock`.
An existing `${XDG_DATA_HOME:-$HOME/.local/share}/plasma/plasmoids/com.github.mattanis.macosdock`
copy takes precedence; full installation also copies the matching contents and
metadata there. Applet configuration is outside this package and is preserved.
KPackage's upgrade command rejects equal versions, so this development workflow
copies package files as the CMake installation does, without a version bump.

Accept the installer's Plasma Shell restart prompt, or run:

```bash
systemctl --user restart plasma-plasmashell.service
```

Restart is needed to load the changed native module/QML; no logout or system
reboot is needed. Restart may briefly remove panels and the desktop.

## Desktop acceptance checklist (maintainer)

- Firefox, pinned and unpinned/running: verify desktop actions from its installed
  desktop entry. Launch New Private Window and Profile Manager if advertised.
- Dolphin: compare Places with its sidebar, including a custom bookmark such as
  `~/Documents/Folder with spaces`; ensure one correct directory opens. Check
  hidden Places/groups, remote bookmarks, submenus and the More action.
- An application with recent files: check current-activity filtering, launch,
  Forget, disabled history and per-application privacy changes. No empty recent
  section should appear for an application without results.
- Pin/unpin a launcher, a running app and a grouped app; close/reopen the menu and
  restart Plasma to confirm persistence. Check activity-specific pinning too.
  There must be no duplicate Pin/Unpin actions.
- Trigger Test Bounce Animation on pinned and running apps. Confirm the existing
  bounce, magnification, mouse hover and open-menu interaction are unchanged.
- Exercise launch/close, grouped-window close, minimize/maximize, desktops,
  activities, grouping, MPRIS controls and dock/panel configuration.
- Use keyboard and mouse in menus/submenus; check all four panel edges on Wayland.
- Check System Blur and Liquid Glass, panel hide/show and wallpaper accent updates.
- On a pure-QML installation without the menu module, verify that the existing
  menu, Pin/Unpin, bounce and configuration actions still work without errors.

Do not merge or release until the maintainer has validated the desktop behavior.
