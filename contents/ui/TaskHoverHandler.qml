// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// ToolTipArea accepts hover events before an ancestor HoverHandler sees them.
// Share the task's existing observation with the glow without adding a hit area.
HoverHandler {
    id: root
    property var capsuleTracker: null
    signal positionUpdated(point position)

    function report(): void {
        if (!enabled || !hovered) return;
        if (capsuleTracker) capsuleTracker.trackFromItem(parent, point.position);
        positionUpdated(point.position);
    }
    onPointChanged: report()
    onHoveredChanged: {
        if (hovered) report();
        else if (capsuleTracker) capsuleTracker.releaseItem(parent);
    }
    onEnabledChanged: {
        if (!enabled && capsuleTracker) capsuleTracker.releaseItem(parent);
    }
    readonly property Connections trackerChanges: Connections {
        target: root.capsuleTracker
        function onEnabledChanged() { root.report(); }
    }
}
