<p align="center">
  <img src="assets/logo.png" alt="macOS Dock Logo" width="256" />
</p>

# macOS Dock-Like Experience for KDE Plasma 6

A native widget for KDE Plasma 6 that brings a smooth, responsive macOS dock-like experience to your Linux desktop. Built directly on top of KDE's official Icons-Only Task Manager, it transforms the taskbar into a floating, magnified capsule while keeping all native Plasma system integrations, Wayland window management, and application workflows fully intact.

## Table of Contents

- [Installation](#installation)
- [Compatibility](#compatibility)
- [Introduction](#introduction)
- [Features](#features)
  - [Custom Icon Sizing and Spacing](#custom-icon-sizing-and-spacing)
  - [Capsule Padding and Edge Elevation](#capsule-padding-and-edge-elevation)
  - [Auto-Shrinking and Progressive Magnification](#auto-shrinking-and-progressive-magnification)
  - [Interactive Continuous Magnification Wave](#interactive-continuous-magnification-wave)
  - [Spring and Smooth Animation Physics](#spring-and-smooth-animation-physics)
  - [Hover Lift Elevation](#hover-lift-elevation)
  - [Capsule Styling, Native Blur, and Liquid Glass](#capsule-styling-native-blur-and-liquid-glass)
  - [External Running Indicator Dots](#external-running-indicator-dots)
  - [Pinned and Running Tasks Divider](#pinned-and-running-tasks-divider)
  - [Native Task Manager Shortcuts (Meta+1..9)](#native-task-manager-shortcuts-meta19)
  - [All-Edge Screen Placement Support](#all-edge-screen-placement-support)
- [How It Works and Architectural Decisions](#how-it-works-and-architectural-decisions)
  - [Why Build on Icons-Only Task Manager](#why-build-on-icons-only-task-manager)
  - [Sub-Region KWin Blur via KWindowEffects](#sub-region-kwin-blur-via-kwindoweffects)
  - [Continuous Coordinate-Based Wave Math & Micro-Sensitivity](#continuous-coordinate-based-wave-math--micro-sensitivity)
  - [Collision-Free Dynamic Spacing & Envelope Physics](#collision-free-dynamic-spacing--envelope-physics)
  - [Dynamic Layering and Elevated Hitbox Protection](#dynamic-layering-and-elevated-hitbox-protection)
  - [Padding-Anchored Status Dots](#padding-anchored-status-dots)
  - [Edge-Aware Coordinate Transformations](#edge-aware-coordinate-transformations)
  - [Unified Configuration Architecture](#unified-configuration-architecture)
- [Recommended Setup](#recommended-setup)
- [Known Limitations](#known-limitations)
- [License](#license)

---

## Installation

### Option 1: Install from KDE Store or Direct Clone (Recommended — No Compilation)

The easiest way to get macOS Dock is directly through Plasma's built-in widget installer:

1. Right-click your desktop or an existing panel and choose **Add Widgets…**
2. Click **Get New Widgets…** $\rightarrow$ **Download New Plasma Widgets…** (or visit the [KDE Store / OpenDesktop Page](https://www.opendesktop.org/p/2376880/))
3. Search for **macOS Dock** and click **Install**.

#### Alternative: Manual Pure-QML Install (Git Clone or .plasmoid)

You can clone the repository directly into your local plasmoids folder with zero build dependencies:

```bash
mkdir -p ~/git
cd ~/git
git clone https://github.com/SarbaLabs/plasma-macos-dock.git ~/.local/share/plasma/plasmoids/com.github.mattanis.macosdock
systemctl --user restart plasma-plasmashell
```

Or download `com.github.mattanis.macosdock.plasmoid` from the [Releases](https://github.com/Matt-Anis/plasma-macos-dock/releases) page and install it using:

```bash
kpackagetool6 --type Plasma/Applet --install com.github.mattanis.macosdock.plasmoid
```

> [!TIP]
> **Recommended Panel Sizing**: We recommend setting your Plasma panel thickness (height for bottom/top panels, width for left/right panels) to **100px** to provide ideal headroom for hover magnification and lift elevation (or check **Auto-adjust panel thickness** in dock settings).

> [!NOTE]
> Installing from the KDE Store, downloading the `.plasmoid` bundle, or cloning directly into your plasmoids folder runs the widget in **pure QML mode**. Core features (continuous magnification wave, animations, padding, edge elevation, translucent glass styles, and native shortcuts) work out of the box with zero compilation or build dependencies. The separate `without-blur` branch has been retired as this main codebase now natively supports pure QML mode with optional hardware blur and native application menus. Desktop actions, KDE Places and recent documents require the optional native menu module. Pin/Unpin, Test Bounce Animation and existing window actions remain available without it.

---

### Option 2: Enable Native Blur and Application Menus (Optional — Build from Source)

Compile the optional C++ modules for hardware-accelerated background blur and application context menus (desktop actions, KDE Places and recent documents). See [the menu integration guide](docs/application-context-menus.md) for architecture and validation.

#### 1. Install Build Dependencies for Your Distribution

* **Fedora / RHEL**:
  ```bash
  sudo dnf install cmake gcc-c++ python3 extra-cmake-modules qt6-qtbase-devel qt6-qtdeclarative-devel kf6-kwindowsystem-devel libplasma-devel kf6-kio-devel kf6-kservice-devel kf6-ki18n-devel kf6-knotifications-devel plasma-activities-stats-devel
  ```
* **CachyOS / Arch Linux / Manjaro / EndeavourOS**:
  ```bash
  paru -S --needed cmake gcc python extra-cmake-modules qt6-base qt6-declarative kwindowsystem libplasma kio kservice ki18n knotifications plasma-activities-stats
  ```
* **Ubuntu / Debian / Pop!_OS**:
  ```bash
  sudo apt install cmake build-essential python3 extra-cmake-modules qt6-base-dev qt6-declarative-dev qml6-module-qtquick-shapes libkf6windowsystem-dev libplasma-dev libkf6kio-dev libkf6service-dev libkf6i18n-dev libkf6notifications-dev libplasmaactivitiesstats-dev
  ```
* **openSUSE**:
  ```bash
  sudo zypper install cmake gcc-c++ python3 extra-cmake-modules qt6-base-devel qt6-declarative-devel kf6-kwindowsystem-devel libplasma6-devel kf6-kio-devel kf6-kservice-devel kf6-ki18n-devel kf6-knotifications-devel plasma6-activities-stats-devel
  ```

#### 2. Compile and Install

Clone the repository and build:

```bash
mkdir -p ~/git
cd ~/git
git clone https://github.com/SarbaLabs/plasma-macos-dock.git
cd plasma-macos-dock

# Build both native modules and install the matching QML:
./install.sh
```

Use the full installation for this feature, including when upgrading a KDE Store copy. The script also updates a user-installed applet that would otherwise override the system copy. `--plugin-only` remains available for native-only updates when the matching QML is already installed.

*(Alternatively, run standard CMake commands: `cmake -B build -S . && cmake --build build && sudo cmake --install build`)*

#### 3. Restart Plasma Shell

Restart Plasma to load the new QML blur plugin:

```bash
systemctl --user restart plasma-plasmashell
```

---

### Packaging for Release (Developers)

To create a clean `.plasmoid` bundle ready to upload to [KDE Store / OpenDesktop](https://www.opendesktop.org/p/2376880/) or attach to GitHub Releases:

```bash
./package.sh
```

This generates `com.github.mattanis.macosdock.plasmoid` in the project root.

---

## Compatibility

> [!IMPORTANT]
> **Minimum Supported Version**: **KDE Plasma 6.3.0+**
>
> * **Plasma 6.3+**: Proven to work reliably across multiple distributions (pure QML mode).
> * **Plasma 6.0 – 6.2**: Failed tests. A fix could be possible but not proven, and it is simpler to upgrade the Plasma Shell version.
> * **Plasma 5.x**: Incompatible (strictly designed for Plasma 6).

---

### Why Native Modules Require Local Compilation (No Universal Installer)

The standard `.plasmoid` widget from the KDE Store / GitHub Releases is 100% pure QML and works out of the box with zero build dependencies.

The optional C++ blur and application menu modules cannot be distributed via an automated universal installer or pre-compiled binary because development packages and library versions differ across distributions. Trying to automate this could pull incompatible dependencies. Users who want native blur or application menus should install the build dependencies for their distribution (listed above) and compile locally with CMake.

---

## Introduction

This widget provides a macOS dock-like experience inside KDE Plasma 6. It is built directly on KDE's native Icons-Only Task Manager codebase (`org.kde.plasma.icontasks`), replacing the standard flat panel look with an elevated floating dock capsule, fluid icon magnification, and refined visual styling without sacrificing stability or Wayland compatibility.

---

## Features

### Custom Icon Sizing and Spacing

Unlike standard taskbars where icon size is constrained by panel height, this dock lets you define custom icon dimensions and spacing independently.

- **How to use**: Open dock settings under **Appearance > Icons & Dimensions**. Use the **Icon size (px)** spinbox to set your base icon size (from 24px up to 256px), and adjust **Icon spacing (px)** to control the gap between neighboring icons.
- **Visual preview**:

  ![Icon Sizing and Spacing](assets/demo/size-and-spacing.gif)

### Capsule Padding and Edge Elevation

The dock sits inside a floating capsule with customizable inner padding and an elevation offset that lifts the entire dock away from the monitor edge.

- **How to use**: In dock settings under **Appearance > Icons & Dimensions**, configure **Horizontal padding (px)** and **Vertical padding (px)** to control inner capsule margins around icons. Adjust **Elevation offset (px)** to raise the dock above the screen edge.
- **Visual preview**:

  ![Capsule Padding and Elevation](assets/demo/elevation-padding.gif)

### Auto-Shrinking and Progressive Magnification

When many applications are opened or pinned, the dock prevents screen overflow by dynamically scaling down icons and spacing in real time to fit comfortably within monitor bounds (with a minimum 16px floor). As icons compress, the magnification multiplier automatically scales up progressively ($(\text{preferredSize} / \text{currentSize})^{0.75}$), ensuring that even miniature icons on an ultra-dense dock blow up to an easily recognizable, readable size on hover.

- **How to use**: This behavior is automatic. As you launch or pin more tasks exceeding your monitor width or height, the dock smoothly compresses icons to fit, expanding them back to your preferred size as windows close.
- **Visual preview**:

  ![Auto-Shrinking and Progressive Magnification](assets/demo/auto-shrink.gif)

### Interactive Continuous Magnification Wave

Hovering over dock icons triggers a smooth, continuous coordinate-based magnification wave. Rather than stepping discretely from icon to icon, the dock tracks sub-pixel mouse movement in real time across icon surfaces, expanding the nearest icon and scaling neighboring icons progressively according to continuous proximity.

- **How to use**: In dock settings under **Appearance > Magnification & Animation**, turn on **Magnify icons on hover**. Use the **Zoom scale** spinbox to choose the peak magnification factor (from 1.0x up to 3.5x), and set the **Blast radius (icons)** to specify how many neighboring icons scale alongside the hovered icon (1 to 4 items on each side).
- **Visual preview**:

  ![Interactive Magnification Wave](assets/demo/zoom.gif)

### Spring and Smooth Animation Physics

You can choose between physical spring simulation or cubic easing curves for dock entry and exit animations. Active pointer tracking follows your cursor 1:1 with zero latency, while the master dock envelope provides a calm, graceful transition when moving the cursor into or out of the dock.

- **How to use**: In dock settings under **Appearance > Magnification & Animation**, select your preference in the **Animation physics** dropdown:
  - **Spring physics**: Employs elastic simulation with subtle damping for a bouncy, tactile feel.
  - **Smooth**: Uses a clean cubic ease-out curve for steady, linear transitions.

### Hover Lift Elevation

When icons magnify on hover, they can simultaneously lift upward away from the panel base toward the cursor.

- **How to use**: Under **Appearance > Magnification & Animation**, adjust the **Hover lift (px)** spinbox (from 0px up to 32px). Higher values make icons elevate toward the mouse cursor as they scale up.

### Capsule Styling, Native Blur, and Liquid Glass

The dock background capsule can be styled in five distinct visual modes:

- **Solid**: Flat surface using your chosen custom background color.
- **Transparent**: Completely invisible container with icons floating directly above the wallpaper.
- **Translucent**: Semi-transparent tinted surface where you can pick your background color and fine-tune its opacity percentage (100% pure QML, no C++ compilation required).
- **System Blur**: Uses KWin's compositor to dynamically blur behind the rounded capsule area (requires optional C++ module).
- **Liquid Glass**: Combines live KWin background blur with an internal specular gloss sheen, tinted translucency, and a sharp border (requires optional C++ module).

#### Live Blur & Glass Tuning Steppers
When **System Blur** or **Liquid Glass** is active, you can fine-tune the optical presentation directly from the settings using native steppers:
- **Capsule opacity**: Stepper from 5% to 95% (step 5%) controlling background tint vs blur passthrough.
- **Vibrancy (saturation)**: Stepper from 0.0x to 2.0x (step 0.1x) boosting wallpaper color vibrancy behind the blur for an authentic macOS look.
- **Blur contrast**: Stepper from 0.5x to 1.5x (step 0.1x) adjusting shape contrast behind the glass.
- **Blur brightness**: Stepper from 0.5x to 1.5x (step 0.1x) adjusting background illumination.

- **How to use**: In dock settings under **Appearance > Capsule & Style**, select your preferred mode in **Container background**. Adjust the border thickness, border color, and blur tuning steppers to taste.
- **Visual preview**:

  ![Capsule Styling](assets/demo/styling.gif)

### External Running Indicator Dots

Running applications display a subtle indicator dot placed in the capsule padding beneath the icon rather than drawn over the icon graphic itself.

- **How to use**: In dock settings under **Appearance > Previews & Indicators**, check **Show indicator for running applications**. The indicator glows bright white for the active window and dims to soft translucent white for background or minimized windows.

### Pinned and Running Tasks Divider

The dock automatically generates a subtle vertical or horizontal separator line between your pinned application launchers and unpinned running windows.

- **How to use**: Pin favorite applications to your dock. When you open an unpinned app, a clean translucent divider appears automatically between the launcher section and the open window section.

### Native Task Manager Shortcuts (Meta+1..9)

The dock natively supports KDE Plasma's global task activation shortcuts. Pressing **`Meta + 1`** through **`Meta + 9`** (Windows key + number) launches the corresponding pinned app, activates its running window, or cycles through window groups without needing manual shortcut configuration.

- **How to use**: Press **`Super` / `Meta` + `1..9`** on your keyboard to instantly interact with the 1st through 9th items in your dock.

### All-Edge Screen Placement Support

The dock works on any screen edge, automatically adjusting its orientation, lift direction, indicator offset, and popup placement.

- **How to use**: Place your Plasma panel on the Bottom, Top, Left, or Right edge of your display. The dock detects the screen edge automatically, rotating the capsule layout, directing icon hover lift inward toward the desktop, and adjusting indicator dot positions.
- **Visual preview**:

  ![All Edge Placement](assets/demo/positions.gif)

---

## How It Works and Architectural Decisions

### Why Build on Icons-Only Task Manager

Developing a dock as an independent application often leads to window management desynchronization, Wayland protocol incompatibilities, missing system tray coordination, and duplicate resource consumption.

Building directly upon KDE Plasma's `org.kde.plasma.icontasks` keeps all native window tracking, LibTaskManager models, virtual desktop filters, activity assignments, window thumbnails, and MPRIS audio stream controls native to the shell. This delivers an authentic dock experience without third-party daemons or compositor workarounds.

### Sub-Region KWin Blur via KWindowEffects

In Plasma on Wayland, KWin typically applies background blur to entire top-level window surfaces. Because the dock capsule is an elevated floating element inside a larger transparent panel (`NoBackground`), applying window-level blur would create an unseemly rectangular blur slab spanning the full width or height of the screen.

To solve this, the widget incorporates a native C++ QML item (`DockBlurArea`):

1. **Scene Coordinate Mapping**: The item continuously projects its local capsule bounding box and corner radius into the top-level panel window coordinates via `mapRectToScene()`.
2. **Rounded Polygon Region**: It constructs a precise `QRegion` from a `QPainterPath` rounded rectangle that matches the capsule's dynamic width, height, and corner radius.
3. **KWin Compositor Hooks**: It passes this region to `KWindowEffects::enableBlurBehind()` and `KWindowEffects::enableBackgroundContrast()`. KWin's compositor blurs and color-tunes strictly behind the capsule pill while keeping the surrounding panel completely transparent.

### Continuous Coordinate-Based Wave Math & Micro-Sensitivity

Rather than measuring distance from discrete integer icon indices, the dock tracks continuous cursor coordinates across the entire dock. As the mouse glides across icon surfaces, `HoverHandler.point` calculates a continuous fractional hover position:

```text
continuousHoverPosition = iconIndex + cursorOffsetInIcon
distance = abs(iconIndex - continuousHoverPosition)
u = distance / (blastRadius + 0.5)
```

To eliminate the "dead zone" flat spots found in pure cosine curves (where the derivative $f'(0) = 0$ prevents immediate response to small cursor movements), the dock blends a steep linear falloff with a smooth cosine tail:

```text
linearFalloff = 1.0 - u
smoothTail = 0.5 * (1.0 + cos(pi * u))
waveFactor = (0.6 * linearFalloff + 0.4 * smoothTail) * linearFalloff
magnificationFactor = dockHoverProgress * waveFactor
```

This blended curve has an immediate non-zero slope ($f'(0) \neq 0$) directly under the cursor while preserving a silky smooth departure at the blast radius edges, delivering instant, tactile micro-movement feedback.

### Collision-Free Dynamic Spacing & Envelope Physics

To guarantee that magnified icons never overlap or glitch during rapid mouse movements, three key architectural solutions are in place:

1. **Full 1:1 Expansion Spacing**: The layout calculates extra span dynamically using 100% of each icon's expanded width rather than compressed fractional margins. Neighboring icons gracefully spread apart, preventing collisions even at maximum 3.5x magnification.
2. **Master Dock Hover Envelope (`dockHoverProgress`)**: Transitions into and out of the dock are governed by a single unified envelope. Leaving the dock triggers a calm ~260ms smooth cubic / gentle spring collapse with an exit grace delay (140ms), preventing abrupt snapping or layout jitter.
3. **Inter-Icon Gap Bridging**: Hitboxes extend across inter-icon spacing gaps (`halfSpacing`), ensuring seamless continuous hover tracking without dead-zone dropouts when gliding between adjacent icons.

### Dynamic Layering and Elevated Hitbox Protection

When icons scale up and lift toward the mouse cursor, standard layouts frequently suffer from overlapping z-order glitches or lose pointer hover as the icon geometry shifts. Two architectural choices resolve this:

1. **Dynamic Stacking Order**: Each task item computes its `z` property dynamically from its instantaneous zoom level (`Math.round(effectiveZoom * 100)`). The hovered icon always renders in front of its immediate neighbors, which in turn render in front of resting icons.
2. **Elevated Hitbox Extension**: A dedicated `hoverHitBox` item projects outward into the panel padding by `maxElevatedReach`. Even when an icon lifts 20px or 30px off the dock floor, the mouse cursor remains inside the interactive area, preventing hover flickering.

### Padding-Anchored Status Dots

In standard KDE taskbars, running indicators overlay the bottom edge of application graphics, often clashing with icon artwork.

In this dock, running indicator dots are anchored outside the icon box into the dock capsule padding margin (`padOffset`). By calculating the remaining margin between the icon edge and the capsule border, indicators float in the dedicated padding cushion, leaving application icons completely unobstructed.

### Edge-Aware Coordinate Transformations

KDE Plasma panels can be positioned on any monitor edge. Rather than assuming a bottom-panel setup, the dock evaluates an internal `effectiveLocation` property:

- Checks whether the dock is horizontal (`BottomEdge` or `TopEdge`) or vertical (`LeftEdge` or `RightEdge`).
- Automatically directs hover lift transformations inward toward the workspace.
- Anchors indicator dots into the appropriate outer padding margin (bottom, top, left, or right).
- Aligns context menus and window preview popups so they always open away from the screen edge.

### Unified Configuration Architecture

The configuration backend extends KDE's `kcfg` schema with explicit definitions for every dock parameter (`iconSize`, `elevation`, `zoomMultiplier`, `containerBackgroundColor`, and related properties). The UI is organized into dedicated sections within Kirigami form layouts, giving users immediate access to dimensions, physics, colors, and behavior without burying options in unrelated submenus.

---

## Recommended Setup

For the most authentic dock presentation:

1. **Plasma Panel Settings**:
   - Panel thickness (height / width): Set to **100px** (or let the dock auto-adjust it) for optimal hover headroom and elevation clearance.
   - Panel mode: Set to **Fit Content** or centered floating.
   - Opacity: Set panel background to **Transparent** so the dock capsule renders its own background.
2. **Dock Settings**:
   - **Icons & Dimensions**: Icon size `48px`, Icon spacing `4px`, Elevation `8px`.
   - **Magnification & Animation**: Zoom scale `1.5x`, Blast radius `2`, Animation `Spring physics`, Hover lift `12px`.
   - **Capsule & Style**: Border thickness `1px`, Container background `Solid` or `Translucent`.

---

## Known Limitations

- **No UV Refraction / Background Distortion**: While native background blur, saturation boosting, contrast adjustment, and internal surface gloss are fully supported, optical warping and UV refraction of desktop windows behind the dock are not implemented. Under Wayland, client widgets are strictly isolated from desktop framebuffers for security reasons; reading and distorting background pixels requires writing a low-level C++ KWin compositor effect (`kwin_wayland` plugin). KWin's internal C++ API changes frequently across point releases, and any crash in a compositor effect crashes the user's entire desktop session and logs them out. To keep your system completely stable and safe from session crashes, optical UV distortion of background windows was deliberately omitted.

---

## License

This project is licensed under the GNU General Public License v2.0 or later (GPL-2.0-or-later). See the project files for full copyright and licensing details.
