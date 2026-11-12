// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.ksvg as KSvg

// Plasma themes combine running state and background in one task FrameSvg.
// When backgrounds are disabled, retain only the native panel-facing border.
Item {
    id: root
    property int edge: 0
    property var prefixes: ["normal"]
    Item {
        id: strip
        clip: true
        readonly property real thickness: Math.max(1, root.edge === 0 ? svg.margins.bottom
            : root.edge === 1 ? svg.margins.top : root.edge === 2 ? svg.margins.left : svg.margins.right)
        width: root.edge < 2 ? root.width : Math.min(root.width, thickness)
        height: root.edge < 2 ? Math.min(root.height, thickness) : root.height
        x: root.edge === 3 ? root.width - width : 0
        y: root.edge === 0 ? root.height - height : 0
        KSvg.FrameSvgItem {
            id: svg
            x: -strip.x
            y: -strip.y
            width: root.width
            height: root.height
            imagePath: "widgets/tasks"
            prefix: root.prefixes
        }
    }
}
