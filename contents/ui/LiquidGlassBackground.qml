/*
    SPDX-FileCopyrightText: 2024 Matt Anis
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import "code/CapsuleGeometry.js" as Geometry

Item {
    id: root

    property real radius: Math.min(width, height) / 3
    readonly property real effectiveRadius: Geometry.radius(width, height, true, radius)
    property bool glowEnabled: false
    property bool glowHovering: false
    property point glowPosition: Qt.point(width / 2, height / 2)
    property color glowColor: Kirigami.Theme.highlightColor
    property real glowIntensity: 1
    property real glowRadius: 70
    property real glowOpacity: 0.3
    property int backgroundType: 0 // 0 = Solid, 1 = Transparent, 2 = Translucent, 3 = SystemBlur, 4 = LiquidGlass
    property color customBackgroundColor: "#202024"
    property int customBorderWidth: 1
    property color customBorderColor: "#38ffffff"
    property bool isVertical: false

    property real blurOpacity: 0.35
    property real blurSaturation: 1.3
    property real blurContrast: 1.0
    property real blurBrightness: 1.0

    // Check if the optional C++ blur plugin is installed and ready
    readonly property bool hasBlurPlugin: {
        const comp = Qt.createComponent("BlurAreaBridge.qml");
        return comp.status === Component.Ready;
    }

    // C++ KWin blur region loader (only activated for SystemBlur and LiquidGlass if plugin is installed)
    Loader {
        id: blurBridgeLoader
        objectName: "blurBridge"
        anchors.fill: parent
        active: (root.backgroundType === 3 || root.backgroundType === 4) && root.hasBlurPlugin
        asynchronous: false
        source: root.hasBlurPlugin ? "BlurAreaBridge.qml" : ""
        property real radius: root.effectiveRadius
        property real saturation: root.blurSaturation
        property real contrast: root.blurContrast
        property real intensity: root.blurBrightness
    }

    // ==========================================
    // MODE 0: SOLID BACKGROUND
    // ==========================================
    Rectangle {
        id: solidBackground
        visible: root.backgroundType === 0
        anchors.fill: parent
        radius: root.effectiveRadius
        color: root.customBackgroundColor
        border.color: !glowLoader.active && root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
        border.width: root.customBorderWidth
    }

    // ==========================================
    // MODE 2: TRANSLUCENT & MODE 3: SYSTEM BLUR
    // (Translucent is pure QML tint; System Blur adds KWin blur behind it)
    // ==========================================
    Rectangle {
        id: translucentOrBlurBackground
        visible: root.backgroundType === 2 || root.backgroundType === 3
        anchors.fill: parent
        radius: root.effectiveRadius
        color: Qt.rgba(root.customBackgroundColor.r, root.customBackgroundColor.g, root.customBackgroundColor.b, root.blurOpacity)
        border.color: !glowLoader.active && root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
        border.width: root.customBorderWidth
    }

    // ==========================================
    // MODE 4: LIQUID GLASS
    // ==========================================
    Item {
        id: liquidGlassContainer
        visible: root.backgroundType === 4
        anchors.fill: parent

        // Single clean glass base rectangle with crisp border
        Rectangle {
            id: glassBase
            anchors.fill: parent
            radius: root.effectiveRadius
            color: {
                const isDark = Kirigami.Theme.backgroundColor.hslLightness < 0.5;
                return isDark
                    ? Qt.rgba(0.12, 0.12, 0.15, root.blurOpacity)
                    : Qt.rgba(0.96, 0.97, 1.0, root.blurOpacity);
            }
            border.color: !glowLoader.active && root.customBorderWidth > 0 ? root.customBorderColor : "transparent"
            border.width: root.customBorderWidth
        }
    }
    Loader {
        id: glowLoader
        objectName: "glowLoader"
        anchors.fill: parent
        active: root.glowEnabled && root.backgroundType !== 1
        sourceComponent: CapsuleGlow {
            cornerRadius: root.effectiveRadius
            pointerX: root.glowPosition.x
            pointerY: root.glowPosition.y
            glowRadius: Math.max(1, root.glowRadius)
            intensity: Math.max(0, Math.min(2, root.glowIntensity))
            strength: Math.max(0, Math.min(1, root.glowOpacity))
            hovering: root.glowHovering
            glowColor: root.glowColor
        }
    }
    // Gloss and border stay above the optional glow.
    Item {
        anchors.fill: parent
        visible: root.backgroundType === 4
        // Internal gloss sheen inset safely inside the border
        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(0, root.customBorderWidth)
            radius: Math.max(0, root.effectiveRadius - root.customBorderWidth)
            color: "transparent"
            gradient: Gradient {
                orientation: root.isVertical ? Gradient.Horizontal : Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.04) }
                GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.01) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.06) }
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: glowLoader.active && root.customBorderWidth > 0
        radius: root.effectiveRadius
        color: "transparent"
        border.width: root.customBorderWidth
        border.color: root.customBorderColor
    }

}

