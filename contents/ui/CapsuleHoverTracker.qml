// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import "code/CapsuleGeometry.js" as Geometry

// Observe from the common ancestor, not a higher-stacked sibling. A sibling
// can suppress descendant hover delivery even with blocking disabled.
HoverHandler {
    id: root
    blocking: false
    readonly property Item observationItem: parent
    required property Item capsule
    property real cornerRadius: 0
    required property var taskSource
    property bool vertical: false
    property Item hoveredTask: null
    signal positionUpdated(Item task, point position)

    function updatePosition(position: point): void {
        const mapped = observationItem.mapToItem(capsule, position.x, position.y);
        if (!Geometry.containsPoint(capsule.width, capsule.height, cornerRadius, mapped.x, mapped.y)) {
            hoveredTask = null;
            return;
        }
        let candidate = null;
        let distance = Infinity;
        for (let i = 0; taskSource && i < taskSource.count; ++i) {
            const task = taskSource.itemAt(i);
            if (!task || !task.visible) continue;
            const center = task.mapToItem(observationItem, task.width / 2, task.height / 2);
            const delta = Math.abs(vertical ? position.y - center.y : position.x - center.x);
            if (delta < distance) { candidate = task; distance = delta; }
        }
        hoveredTask = candidate;
        if (candidate) {
            positionUpdated(candidate, mapped);
        }
    }
    function refresh(): void {
        if (enabled && hovered) updatePosition(point.position);
    }
    readonly property Connections modelChanges: Connections {
        target: root.enabled ? root.taskSource : null
        ignoreUnknownSignals: true
        function onItemAdded() { Qt.callLater(root.refresh); }
        function onItemRemoved() { Qt.callLater(root.refresh); }
    }
    readonly property Connections capsuleChanges: Connections {
        target: root.enabled ? root.capsule : null
        function onXChanged() { Qt.callLater(root.refresh); }
        function onYChanged() { Qt.callLater(root.refresh); }
        function onWidthChanged() { Qt.callLater(root.refresh); }
        function onHeightChanged() { Qt.callLater(root.refresh); }
    }
    readonly property Connections capsuleParentChanges: Connections {
        target: root.enabled && root.capsule ? root.capsule.parent : null
        function onXChanged() { Qt.callLater(root.refresh); }
        function onYChanged() { Qt.callLater(root.refresh); }
    }
    onCornerRadiusChanged: Qt.callLater(refresh)
    onPointChanged: if (enabled && hovered) updatePosition(point.position)
    onHoveredChanged: {
        if (enabled && hovered) updatePosition(point.position);
        else hoveredTask = null;
    }
    onEnabledChanged: {
        if (!enabled) hoveredTask = null;
    }
}
