// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import org.kde.plasma.core as PlasmaCore
import "../../contents/ui" as Dock

TestCase {
    id: testCase
    name: "NativeTooltipHover"
    width: 320; height: 320
    visible: true
    when: windowShown

    Component {
        id: fixture
        Item {
            id: scene
            width: 300; height: 300
            property bool vertical: false
            property bool interactiveTips: false
            property alias tracker: tracker
            property alias tasks: tasks
            property alias content: content
            property point lastPosition: Qt.point(-1, -1)
            property int hoverMoves: 0
            property int clicks: 0
            Item {
                id: capsule
                x: 10; y: 10
                width: scene.vertical ? 80 : 200
                height: scene.vertical ? 200 : 80
            }
            Item {
                id: content
                width: 80; height: 30
                property int ownerIndex: -1
                Text { text: "Application " + content.ownerIndex }
            }
            Repeater {
                id: tasks
                model: 2
                delegate: Dock.TaskToolTipArea {
                    id: task
                    required property int index
                    x: scene.vertical ? 0 : index * 100
                    y: scene.vertical ? index * 100 : 0
                    width: 100; height: 100
                    location: scene.vertical ? PlasmaCore.Types.LeftEdge : PlasmaCore.Types.BottomEdge
                    mainItem: content
                    interactive: scene.interactiveTips
                    property bool tipOpen: false
                    onToolTipVisibleChanged: visible => tipOpen = visible
                    function updateMainItemBindings(): void { content.ownerIndex = index; }
                    Dock.TaskHoverHandler {
                        capsuleTracker: tracker
                        onPositionUpdated: scene.hoverMoves++
                    }
                    TapHandler { onTapped: scene.clicks++ }
                }
            }
            Dock.CapsuleHoverTracker {
                id: tracker
                capsule: capsule
                cornerRadius: 15
                taskSource: tasks
                vertical: scene.vertical
                onPositionUpdated: (task, position) => scene.lastPosition = position
            }
        }
    }

    function test_nativeTransfer_data() {
        return [
            {tag: "horizontal-label", vertical: false, interactive: false, glow: true},
            {tag: "horizontal-preview", vertical: false, interactive: true, glow: true},
            {tag: "vertical-label", vertical: true, interactive: false, glow: true},
            {tag: "vertical-preview", vertical: true, interactive: true, glow: true},
            {tag: "glow-disabled", vertical: false, interactive: false, glow: false}
        ];
    }
    function test_nativeTransfer(data) {
        const scene = createTemporaryObject(fixture, testCase, {
            vertical: data.vertical, interactiveTips: data.interactive
        });
        scene.tracker.enabled = data.glow;
        mouseMove(scene, 40, 40);
        if (data.glow) tryVerify(() => scene.tracker.hoveredTask === scene.tasks.itemAt(0));
        // Use the real Plasma dialog, not a fake visibility flag. Its native
        // hoverEnterEvent transfers ownership without calling our hover timer.
        scene.tasks.itemAt(0).showToolTip();
        tryCompare(scene.tasks.itemAt(0), "tipOpen", true);
        compare(scene.content.ownerIndex, 0);
        for (let cycle = 0; cycle < 3; ++cycle) {
            for (const index of [1, 0]) {
                const primary = index * 100 + 40;
                mouseMove(scene, data.vertical ? 40 : primary, data.vertical ? primary : 40);
                tryCompare(scene.content, "ownerIndex", index);
                if (data.glow) tryVerify(() => scene.tracker.hoveredTask === scene.tasks.itemAt(index));
                else compare(scene.tracker.hoveredTask, null);
                const before = scene.hoverMoves;
                for (let delta = 1; delta <= 5; ++delta) {
                    mouseMove(scene, (data.vertical ? 40 : primary) + delta,
                        (data.vertical ? primary : 40) + delta);
                }
                verify(scene.hoverMoves >= before + 4, "Continuous magnification input survives the tooltip");
                if (data.glow) compare(scene.lastPosition,
                    Qt.point((data.vertical ? 40 : primary) - 5, (data.vertical ? primary : 40) - 5));
            }
        }
        mouseClick(scene, 45, 45);
        compare(scene.clicks, 1);
        // Changing the option while stationary must work without a re-entry.
        scene.tracker.enabled = false;
        compare(scene.tracker.hoveredTask, null);
        scene.tracker.enabled = true;
        tryVerify(() => scene.tracker.hoveredTask === scene.tasks.itemAt(0));
        mouseMove(scene, 11, 11); // Rounded corner, still inside the native task.
        tryCompare(scene.tracker, "hoveredTask", null);
        mouseMove(scene, 40, 5); // Magnification hit area outside the capsule.
        tryCompare(scene.tracker, "hoveredTask", null);
        mouseMove(scene, 290, 290);
        tryCompare(scene.tracker, "hoveredTask", null);
        scene.tasks.itemAt(0).hideToolTip();
        tryCompare(scene.tasks.itemAt(0), "tipOpen", false);
    }
}
