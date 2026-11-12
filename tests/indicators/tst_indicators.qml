// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtTest
import "../../contents/ui" as Dock
import "../../contents/ui/code/IndicatorLogic.js" as Logic

TestCase {
    id: testCase
    name: "Indicators"
    when: windowShown
    width: 200; height: 150
    Component { id: indicator; Dock.CustomIndicators { width: 40; height: 40; configuration: ({}); windowCount: 3; activeIndex: 1 } }
    Component { id: state; Dock.IndicatorTaskState { tasksModel: fakeModel; taskIndex: 2; minimizedRole: 9; enabled: true; grouped: true; windowCount: 100; limit: 4 } }
    QtObject {
        id: fakeModel
        property var activeTask: ({valid: true, row: 50})
        property int parentRow: 2
        property int reads: 0
        signal dataChanged()
        signal rowsRemoved()
        function parent(index) { return {valid: true, row: parentRow}; }
        function makeModelIndex(parent, child) { return {parent: parent, row: child}; }
        function data(index, role) { reads++; return index.row === 0; }
    }
    Component { id: nativeStrip; Dock.NativeTaskIndicator { width: 40; height: 40 } }
    Component { id: nativeGroup; Dock.GroupExpanderOverlay { iconTarget: testCase; grouped: true } }
    function test_nativeThemeElements() {
        let strip = createTemporaryObject(nativeStrip, testCase);
        verify(strip !== null);
        let group = createTemporaryObject(nativeGroup, testCase);
        verify(group !== null);
        verify(testThemePath.length > 0);
        group.imagePath = testThemePath;
        for (let edge = 0; edge < 4; edge++) {
            strip.edge = edge;
            group.edge = edge;
            verify(group.naturalSize.width > 0);
            verify(group.naturalSize.height > 0);
            verify(group.x >= 0 && group.x + group.width <= width);
            verify(group.y >= 0 && group.y + group.height <= height);
        }
        group.grouped = false;
        verify(!group.visible);
    }
    function test_configurationPage() {
        const component = Qt.createComponent("../../contents/ui/ConfigIndicators.qml");
        compare(component.status, Component.Ready, component.errorString());
        const page = createTemporaryObject(component, testCase);
        verify(page !== null);
        verify(Object.keys(indicatorDefaults).length >= 30);
        for (const key of Object.keys(indicatorDefaults)) {
            const actual = page["cfg_" + key];
            verify(actual !== undefined, key);
            compare(actual.toString(), indicatorDefaults[key].toString(), key);
        }
        page.cfg_indicatorMode = 2;
        verify(page.custom);
        page.cfg_indicatorMaxSegments = 8;
        compare(page.previewConfiguration.indicatorMaxSegments, 8);
        page.cfg_indicatorMode = 0;
        verify(!page.custom);
        compare(page.cfg_indicatorMaxSegments, 8);
    }
    function test_modesAndDefaults() {
        compare(Logic.mode({}), 0);
        compare(Logic.mode({indicatorMode: 1}), 1);
        compare(Logic.mode({indicatorMode: 2}), 2);
        compare(Logic.mode({indicatorMode: 99}), 0);
        verify(!Logic.nativeEnabled(0, 0, false));
        verify(Logic.nativeEnabled(0, 1, false));
        verify(Logic.nativeEnabled(1, 0, false));
        verify(!Logic.nativeEnabled(2, 1, false));
        verify(Logic.nativeEnabled(0, 0, true)); // Existing popup frames.
    }
    function test_countAndLimit() {
        compare(Logic.count(false, false, 8), 0);
        compare(Logic.count(true, false, 0), 1);
        compare(Logic.count(true, true, 12), 12);
        let obj = createTemporaryObject(indicator, testCase);
        compare(obj.segments.length, 3);
        obj.windowCount = 100;
        compare(obj.segments.length, 4);
        obj.activeIndex = 50;
        verify(obj.segments[3].active);
        compare(obj.segments[3].index, -1); // Do not inherit a visible minimized child's state.
        obj.configuration = {indicatorOverflow: true}; // Obsolete saved key is ignored.
        compare(obj.segments.length, 4);
        verify(obj.segments[3].active);
        compare(obj.segments[3].index, -1); // Do not inherit a visible minimized child's state.
        obj.configuration = {indicatorMaxSegments: 1000};
        compare(obj.segments.length, 8);
        obj.windowCount = 1;
        compare(obj.segments.length, 1);
        verify(obj.segments[0].overflow === undefined);
        obj.configuration = {customIndicatorsEnabled: false};
        compare(obj.segments.length, 0);
    }
    function test_dimensionsAndBounds() {
        const cfg = {indicatorStyle: 2, indicatorLength: 12, indicatorActiveLength: 24,
            indicatorActiveThickness: 6, indicatorAnimations: false};
        let obj = createTemporaryObject(indicator, testCase, {width: 120, configuration: cfg});
        compare(obj.segments[1].length, 24);
        compare(obj.segments[0].length, 12);
        obj.configuration = Object.assign({}, cfg, {indicatorGroupSeparate: true, indicatorGroupLength: 8});
        compare(obj.segments[0].length, 8);
        obj.configuration = Object.assign({}, cfg, {indicatorResizeHover: true, indicatorHoverLength: 30});
        obj.hovered = true;
        compare(obj.segments[0].length, 30);
        for (let size of [1, 16, 40, 60, 160]) {
            obj.width = size;
            for (let s of obj.segments) {
                verify(s.length >= 0 && s.offset >= -0.001);
                verify(s.offset + s.length <= size + 0.001);
                verify(s.thickness <= obj.padding);
            }
        }
    }
    function test_edgesAndColors() {
        let obj = createTemporaryObject(indicator, testCase, {configuration: {indicatorAnimations: false}});
        for (let edge = 0; edge < 4; edge++) {
            obj.effectiveEdge = edge;
            compare(obj.edge, edge);
            compare(obj.vertical, edge >= 2);
            const segment = findChild(obj, "indicatorSegment0");
            verify(segment !== null);
            verify(segment.x >= -obj.padding);
            verify(segment.y >= -obj.padding);
            verify(segment.x + segment.width <= obj.width + obj.padding);
            verify(segment.y + segment.height <= obj.height + obj.padding);
            if (edge === 0) verify(segment.y >= obj.height);
            if (edge === 1) verify(segment.y + segment.height <= 0);
            if (edge === 2) verify(segment.x + segment.width <= 0);
            if (edge === 3) verify(segment.x >= obj.width);
            obj.configuration = {indicatorOverride: true, indicatorEdge: (edge+1)%4, indicatorAnimations: false};
            compare(obj.edge, (edge+1)%4);
            obj.configuration = {indicatorAnimations: false};
        }
        obj.configuration = {indicatorStyle: 0, indicatorRoundness: 0, indicatorAnimations: false};
        const dot = findChild(obj, "indicatorSegment0");
        compare(dot.width, dot.height);
        compare(dot.radius, dot.width / 2); // Dash roundness must not turn dots into squares.
        obj.accentColor = "red";
        compare(obj.baseColor, Qt.rgba(1,0,0,1));
        obj.configuration = {indicatorColorSource: 1};
        compare(obj.baseColor, Qt.rgba(1,0,0,1)); // Missing icon color fallback.
        obj.dominantColor = "blue";
        compare(obj.baseColor, Qt.rgba(0,0,1,1));
        obj.configuration = {indicatorColorSource: 2, indicatorCustomColor: "green"};
        compare(obj.baseColor, Qt.color("green"));
        let c = Logic.segmentColor(Qt.rgba(1,0,0,1), false, true, true, {indicatorDesaturate: true, indicatorInactiveOpacity: 20});
        fuzzyCompare(c.r, c.g, 0.01);
        fuzzyCompare(c.a, 0.2, 0.01);
    }
    function test_unfocusedColor() {
        const red = Qt.color("red"), blue = Qt.color("blue");
        const cfg = {indicatorUnfocusedColorEnabled: true, indicatorUnfocusedColor: blue,
            indicatorDimInactive: false, indicatorHighlightActive: false};
        compare(Logic.segmentColor(red, true, true, false, cfg), red);
        compare(Logic.segmentColor(red, false, true, false, cfg), blue);
        compare(Logic.segmentColor(red, false, false, false, cfg), blue);
        cfg.indicatorDimInactive = true;
        cfg.indicatorInactiveOpacity = 25;
        fuzzyCompare(Logic.segmentColor(red, false, true, false, cfg).a, 0.25, 0.01);
        cfg.indicatorDesaturate = true;
        const gray = Logic.segmentColor(red, false, true, true, cfg);
        fuzzyCompare(gray.r, gray.b, 0.01);
        cfg.indicatorUnfocusedColorEnabled = false;
        cfg.indicatorDimInactive = false;
        compare(Logic.segmentColor(red, false, false, false, cfg), red);
    }
    function test_modelEventsAreBounded() {
        fakeModel.reads = 0;
        fakeModel.parentRow = 2;
        let obj = createTemporaryObject(state, testCase);
        tryCompare(obj, "activeIndex", 50);
        compare(obj.minimizedWindows.length, 4);
        verify(obj.minimizedWindows[0]);
        verify(fakeModel.reads <= 8);
        fakeModel.activeTask = {valid: true, row: 1};
        tryCompare(obj, "activeIndex", 1);
        fakeModel.parentRow = 8;
        fakeModel.dataChanged();
        tryCompare(obj, "activeIndex", -1);
        obj.grouped = false;
        obj.active = true;
        obj.windowCount = 1;
        tryCompare(obj, "activeIndex", 0);
        tryCompare(obj, "minimizedWindows", [false]);
        obj.enabled = false;
        tryCompare(obj, "activeIndex", -1);
        compare(obj.minimizedWindows.length, 0);
    }
    function test_segmentItemsSurviveHoverAndZoom() {
        let obj = createTemporaryObject(indicator, testCase, {configuration: {indicatorAnimations: false}});
        const segment = findChild(obj, "indicatorSegment0");
        verify(segment !== null);
        // Repeater owns a bounded number of delegates; changing state changes
        // geometry rather than replacing the model with a new object list.
        for (let i = 0; i < 20; ++i) { obj.width = 40 + i; obj.hovered = !obj.hovered; }
        compare(findChild(obj, "indicatorSegment0"), segment);
    }
}
