/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
// State sizing, segment emphasis and overflow concept adapted from Fancy Tasks NG.
// Layout is independent of its Flow/task infrastructure and bounded to the slot.
import QtQuick
import "code/IndicatorLogic.js" as Logic

Item {
    id: root
    required property var configuration
    property int effectiveEdge: 0 // bottom, top, left, right; already un-rotated
    property real horizontalPadding: 8
    property real verticalPadding: 8
    property int windowCount: 0
    property int activeIndex: -1
    property var minimizedWindows: []
    property bool hovered: false
    property color accentColor: "#3daee9"
    property color dominantColor: "transparent"
    readonly property int edge: Logic.edge(configuration, effectiveEdge)
    readonly property bool vertical: edge >= 2
    readonly property real padding: Math.max(1, vertical ? horizontalPadding : verticalPadding)
    readonly property bool animated: Logic.flag(configuration, "indicatorAnimations", true)
    readonly property color baseColor: Logic.baseColor(Logic.number(configuration, "indicatorColorSource", 0, 0, 2),
        accentColor, dominantColor, configuration.indicatorCustomColor || "#3daee9")
    readonly property var segments: Logic.segments(configuration, windowCount, activeIndex, hovered,
        Math.max(0, vertical ? height : width), padding)
    readonly property real lane: segments.reduce((max, s) => Math.max(max, s.thickness), 0)
    readonly property real edgeDistance: Math.min(Logic.number(configuration, "indicatorEdgeDistance", 2, 0, 32), Math.max(0, padding - lane))

    Repeater {
        model: root.segments.length
        delegate: Rectangle {
            id: segment
            required property int index
            objectName: "indicatorSegment" + index
            readonly property var modelData: root.segments[index] || ({active: false, overflow: false, index: index, length: 0, thickness: 0, offset: 0})
            readonly property real cross: {
                const alignment = Logic.number(root.configuration, "indicatorAlignment", 1, 0, 2);
                const difference = root.lane - modelData.thickness;
                return alignment === 0 ? 0 : alignment === 1 ? difference / 2 : difference;
            }
            readonly property real outside: root.padding - root.edgeDistance - modelData.thickness - cross
            readonly property color ink: Logic.segmentColor(root.baseColor, modelData.active, root.windowCount > 1,
                root.minimizedWindows[modelData.index] === true, root.configuration)
            width: root.vertical ? modelData.thickness : modelData.length
            height: root.vertical ? modelData.length : modelData.thickness
            x: root.vertical ? (root.edge === 2 ? -outside - width : root.width + outside) : modelData.offset
            y: root.vertical ? modelData.offset : (root.edge === 1 ? -outside - height : root.height + outside)
            radius: Math.min(width, height) * (Logic.number(root.configuration, "indicatorStyle", 0, 0, 2) === 0 ? 100 : Logic.number(root.configuration, "indicatorRoundness", 100, 0, 100)) / 200
            color: modelData.overflow ? "transparent" : ink
            Behavior on x { enabled: root.animated; NumberAnimation { duration: 120 } }
            Behavior on y { enabled: root.animated; NumberAnimation { duration: 120 } }
            Behavior on width { enabled: root.animated; NumberAnimation { duration: 120 } }
            Behavior on height { enabled: root.animated; NumberAnimation { duration: 120 } }
            Behavior on color { enabled: root.animated; ColorAnimation { duration: 120 } }
            Rectangle {
                visible: segment.modelData.overflow
                anchors.centerIn: parent
                width: parent.width
                height: Math.min(parent.height, Math.max(1, parent.height / 4))
                color: segment.ink
            }
            Rectangle {
                visible: segment.modelData.overflow
                anchors.centerIn: parent
                height: parent.height
                width: Math.min(parent.width, Math.max(1, parent.width / 4))
                color: segment.ink
            }
        }
    }
}
