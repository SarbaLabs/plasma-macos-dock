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
            property alias capsuleItem: capsule
            property point lastPosition: Qt.point(-1, -1)
            property Item lastTask: null
            property int clicks: 0
            property int hoverMoves: 0
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
                    HoverHandler { onPointChanged: if (hovered) scene.hoverMoves++ }
                    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: scene.clicks++ }
                    Rectangle { visible: parent.isRunning; width: 4; height: 4; y: 80 }
                }
            }
            Dock.CapsuleHoverTracker {
                id: tracker
                cornerRadius: 15
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
    function test_onlyInsideCapsule() {
        const scene = createTemporaryObject(fixture, testCase);
        mouseMove(scene, 40, 15); // Inside the enlarged task hit region, above the bar.
        compare(scene.tracker.hoveredTask, null);
        mouseMove(scene, 11, 21); // Inside its rectangular bounds, outside the rounded corner.
        compare(scene.tracker.hoveredTask, null);
        mouseMove(scene, 40, 25);
        tryVerify(() => scene.tracker.hoveredTask !== null);
        mouseMove(scene, 15, 55); // Capsule padding still selects the nearest application.
        tryVerify(() => scene.tracker.hoveredTask !== null);
        mouseMove(scene, 40, 95);
        compare(scene.tracker.hoveredTask, null);
    }
    function test_capsuleMovementKeepsPointerMapping() {
        const scene = createTemporaryObject(fixture, testCase);
        mouseMove(scene, 40, 40);
        tryCompare(scene, "lastPosition", Qt.point(30, 20));
        scene.capsuleItem.x = 15;
        tryCompare(scene, "lastPosition", Qt.point(25, 20));
        scene.capsuleItem.y = 60;
        tryCompare(scene.tracker, "hoveredTask", null);
    }
    function test_disabledTrackerLeavesTaskHoverWorking() {
        const scene = createTemporaryObject(fixture, testCase);
        mouseMove(scene, 40, 40);
        tryVerify(() => scene.tracker.hoveredTask !== null);
        scene.tracker.enabled = false;
        compare(scene.tracker.hoveredTask, null);
        const initial = scene.hoverMoves;
        for (let x = 45; x < 80; x += 5) mouseMove(scene, x, 40);
        verify(scene.hoverMoves >= initial + 5);
        compare(scene.tracker.hoveredTask, null);
    }
    function test_continuousTaskHover() {
        const scene = createTemporaryObject(fixture, testCase);
        mouseMove(scene, 30, 40);
        const initial = scene.hoverMoves;
        for (let x = 40; x < 80; x += 5) mouseMove(scene, x, 40);
        verify(scene.hoverMoves >= initial + 6, "Task hover must keep receiving pointer movement");
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
