/*
    SPDX-FileCopyrightText: 2025-2026 Vitaliy Elin <daydve@smbit.pro>
    SPDX-FileCopyrightText: 2025 SushiTrash <strash137@gmail.com>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
// Model-index membership follows Fancy Tasks NG. Read only a bounded set of
// children and refresh on model events, never on pointer or animation frames.
import QtQuick

QtObject {
    id: root
    required property var tasksModel
    required property int taskIndex
    required property int minimizedRole
    property bool enabled: false
    property bool grouped: false
    property bool active: false
    property bool minimized: false
    property int windowCount: 0
    property int limit: 4
    property int activeIndex: -1
    property var minimizedWindows: []

    function refresh() {
        if (!enabled || !tasksModel) { activeIndex = -1; minimizedWindows = []; return; }
        const current = tasksModel.activeTask;
        const parent = current && current.valid ? tasksModel.parent(current) : null;
        activeIndex = grouped
            ? (parent && parent.valid && parent.row === taskIndex ? current.row : -1)
            : (active ? 0 : -1);
        const values = [];
        for (let i = 0; i < Math.min(windowCount, Math.max(1, Math.min(8, limit))); ++i) {
            values.push(grouped ? Boolean(tasksModel.data(tasksModel.makeModelIndex(taskIndex, i), minimizedRole)) : minimized);
        }
        minimizedWindows = values;
    }
    function schedule() { Qt.callLater(refresh); }
    onEnabledChanged: schedule()
    onTaskIndexChanged: schedule()
    onGroupedChanged: schedule()
    onActiveChanged: schedule()
    onMinimizedChanged: schedule()
    onWindowCountChanged: schedule()
    onLimitChanged: schedule()
    onTasksModelChanged: schedule()
    Component.onCompleted: schedule()
    readonly property Connections modelChanges: Connections {
        target: root.enabled ? root.tasksModel : null
        ignoreUnknownSignals: true
        function onActiveTaskChanged() { root.schedule(); }
        function onDataChanged() { root.schedule(); }
        function onRowsInserted() { root.schedule(); }
        function onRowsRemoved() { root.schedule(); }
        function onRowsMoved() { root.schedule(); }
        function onModelReset() { root.schedule(); }
        function onLayoutChanged() { root.schedule(); }
    }
}
