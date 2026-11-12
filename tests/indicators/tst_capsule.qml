// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../contents/ui" as Dock
import "../../contents/ui/code/CapsuleGeometry.js" as Geometry
TestCase {
    id: testCase
    name: "Capsule"
    visible: true
    when: windowShown
    width: 240; height: 120
    Component { id: glow; Rectangle { width: 100; height: 60; color: "black"; property alias effect: glowItem; Dock.CapsuleGlow { id: glowItem; anchors.fill: parent; cornerRadius: 20; pointerX: 20; pointerY: 20; glowRadius: 100; glowColor: "red"; strength: 1; hovering: true } } }
    Component { id: background; Dock.LiquidGlassBackground { width: 100; height: 40 } }
    function test_defaults() {
        compare(capsuleDefaults.hoverGlowEnabled, false);
        compare(capsuleDefaults.capsuleRadiusCustom, false);
        compare(capsuleDefaults.capsuleRadius, 10);
        compare(capsuleDefaults.hoverGlowIntensity, 100);
        compare(capsuleDefaults.hoverGlowRadius, 70);
        compare(capsuleDefaults.hoverGlowOpacity, 30);
    }
    function test_radius() {
        compare(Geometry.radius(120, 60, false, 0), 20);
        compare(Geometry.radius(120, 60, true, 0), 0);
        compare(Geometry.radius(120, 60, true, 10), 10);
        compare(Geometry.radius(8, 4, true, 200), 2);
        compare(Geometry.radius(0, 0, true, 200), 0);
        const bg = createTemporaryObject(background, testCase);
        verify(bg !== null);
        verify(!bg.glowEnabled);
        bg.radius = 200;
        compare(bg.effectiveRadius, 20);
        compare(findChild(bg, "blurBridge").radius, 20);
        verify(findChild(bg, "glowLoader").item === null);
        bg.radius = 0;
        compare(bg.effectiveRadius, 0);
        compare(findChild(bg, "blurBridge").radius, 0);
        bg.glowEnabled = true;
        verify(findChild(bg, "glowLoader").item !== null);
        bg.backgroundType = 1;
        verify(findChild(bg, "glowLoader").item === null);
    }
    function test_boundaries() {
        compare(Geometry.boundary([]), -1);
        compare(Geometry.boundary([true, true]), -1);
        compare(Geometry.boundary([false, false]), -1);
        compare(Geometry.boundary([true, true, false, false]), 2);
        compare(Geometry.boundary([false, false, true]), 2);
        compare(Geometry.boundary([true, false]), 1);
        const cases = [
            [false, false, false, false], [false, false, true, true],
            [false, true, false, true], [false, true, true, false],
            [true, false, false, false], [true, false, true, false],
            [true, true, false, true], [true, true, true, true]
        ];
        for (const c of cases) compare(Geometry.gapAtEnd(c[0], c[1], c[2]), c[3]);

    }
    function test_glowPixels() {
        const obj = createTemporaryObject(glow, testCase);
        verify(obj !== null);
        wait(200);
        const image = grabImage(obj);
        // The path must leave rounded corners transparent, but paint its interior.
        compare(image.red(0, 0), 0);
        verify(image.red(20, 20) > 0);
        for (const size of [[60, 100], [8, 8], [100, 60]]) {
            obj.width = size[0]; obj.height = size[1];
            obj.effect.cornerRadius = 200;
            obj.effect.pointerX = size[0] / 2;
            obj.effect.pointerY = size[1] / 2;
            wait(50);
            const frame = grabImage(obj);
            compare(frame.red(0, 0), 0);
            verify(frame.red(Math.floor(size[0] / 2), Math.floor(size[1] / 2)) > 0);
        }
        obj.effect.cornerRadius = 0;
        wait(50);
        verify(grabImage(obj).red(1, 1) > 0);
        obj.effect.hovering = false;
        wait(200);
        compare(grabImage(obj).red(20, 20), 0);
    }
}
