// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Shapes
import "code/CapsuleGeometry.js" as Geometry

// Fill only the capsule path: no rectangular mask, source capture or blur pass.
Shape {
    id: root
    property real cornerRadius: 0
    property real pointerX: width / 2
    property real pointerY: height / 2
    property real glowRadius: 70
    property real intensity: 1
    property real strength: 0.3
    property bool hovering: false
    property color glowColor: "#3daee9"
    opacity: hovering ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 140 } }
    Behavior on glowColor { ColorAnimation { duration: 120 } }
    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: root.pointerX
            centerY: root.pointerY
            focalX: centerX
            focalY: centerY
            centerRadius: Math.max(1, root.glowRadius)
            GradientStop { position: 0; color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, Math.min(1, root.strength * root.intensity)) }
            GradientStop { position: 0.45; color: Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, Math.min(1, root.strength * root.intensity) * 0.35) }
            GradientStop { position: 1; color: "transparent" }
        }
        PathSvg { path: Geometry.roundedPath(root.width, root.height, root.cornerRadius) }
    }
}
