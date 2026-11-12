// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../contents/ui" as Dock

TestCase {
    id: testCase
    name: "GlowTracking"
    visible: true
    when: windowShown
    width: 240; height: 120
    Component {
        id: fixture
        Item {
            id: scene
            width: 240; height: 120
            property alias tracker: tracker
            property point lastPosition: Qt.point(-1, -1)
            property Item lastTask: null
            property int clicks: 0
            Item { id: capsule; x: 10; y: 20; width: 200; height: 70 }
            Repeater {
                id: tasks
                model: 2
                delegate: Rectangle {
                    required property int index
                    x: 10 + index * 90; y: 10; width: 90; height: 90
                    color: index === 0 ? "blue" : "green"
                    property bool isRunning: index === 1
                    property bool isTaskHovered: false // Tooltip state must not gate the light.
                    readonly property Item glowHitRegion: this
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: scene.clicks++ }
                    Rectangle { visible: parent.isRunning; width: 4; height: 4; y: 80 }
                }
            }
            Dock.CapsuleHoverTracker {
                id: tracker
                anchors.fill: parent
                z: 10000
                capsule: capsule
                taskSource: tasks
                onPositionUpdated: (task, position) => { scene.lastTask = task; scene.lastPosition = position; }
            }
        }
    }
    function test_launchersAndRunningTasks() {
        const scene = createTemporaryObject(fixture, testCase);
        mouseMove(scene, 40, 35);
        tryVerify(() => scene.tracker.hoveredTask !== null);
        verify(!scene.lastTask.isRunning);
        compare(scene.lastPosition, Qt.point(30, 15));
        mouseMove(scene, 130, 65);
        tryVerify(() => scene.lastTask !== null && scene.lastTask.isRunning);
        compare(scene.lastPosition, Qt.point(120, 45));
        verify(!scene.lastTask.isTaskHovered);
        mouseClick(scene, 130, 65);
        compare(scene.clicks, 1);
        mouseMove(scene, 140, 80);
        compare(scene.lastPosition, Qt.point(130, 60));
        mouseMove(scene, 230, 110);
        tryCompare(scene.tracker, "hoveredTask", null);
    }
    function test_mappingBothAxesAndRotation() {
        const scene = createTemporaryObject(fixture, testCase);
        scene.rotation = 180;
        scene.tracker.updatePosition(Qt.point(40, 35));
        compare(scene.lastPosition, Qt.point(30, 15));
        scene.tracker.vertical = true;
        scene.tracker.updatePosition(Qt.point(50, 75));
        compare(scene.lastPosition, Qt.point(40, 55));
    }
}
