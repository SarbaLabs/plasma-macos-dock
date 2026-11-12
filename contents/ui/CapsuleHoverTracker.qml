// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// Observe hover independently of task tooltip/preview state. This overlay has
// no mouse/tap handlers and never blocks the task's pointer handlers.
Item {
    id: root
    required property Item capsule
    required property var taskSource
    property bool vertical: false
    property Item hoveredTask: null
    signal positionUpdated(Item task, point position)

    function updatePosition(position: point): void {
        let candidate = null;
        let distance = Infinity;
        for (let i = 0; taskSource && i < taskSource.count; ++i) {
            const task = taskSource.itemAt(i);
            if (!task || !task.visible) continue;
            const region = task.glowHitRegion;
            if (!region) continue;
            const local = region.mapFromItem(root, position.x, position.y);
            if (local.x < 0 || local.y < 0 || local.x > region.width || local.y > region.height) continue;
            const center = task.mapToItem(root, task.width / 2, task.height / 2);
            const delta = Math.abs(vertical ? position.y - center.y : position.x - center.x);
            if (delta < distance) { candidate = task; distance = delta; }
        }
        hoveredTask = candidate;
        if (candidate) {
            positionUpdated(candidate, root.mapToItem(capsule, position.x, position.y));
        }
    }
    function refresh(): void {
        if (pointer.hovered) updatePosition(pointer.point.position);
    }
    Connections {
        target: root.taskSource
        ignoreUnknownSignals: true
        function onItemAdded() { Qt.callLater(root.refresh); }
        function onItemRemoved() { Qt.callLater(root.refresh); }
    }
    HoverHandler {
        id: pointer
        blocking: false
        onPointChanged: if (hovered) root.updatePosition(point.position)
        onHoveredChanged: {
            if (hovered) root.updatePosition(point.position);
            else root.hoveredTask = null;
        }
    }
}
