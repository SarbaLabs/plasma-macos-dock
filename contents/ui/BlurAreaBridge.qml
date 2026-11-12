/*
    SPDX-FileCopyrightText: 2024 Matt Anis
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import com.github.mattanis.macosdock.blur as BlurPlugin

BlurPlugin.DockBlurArea {
    id: blurArea
    anchors.fill: parent
    blurEnabled: true
    cornerRadius: parent && parent.radius !== undefined ? parent.radius : 0
    saturation: parent && parent.saturation !== undefined ? parent.saturation : 1.0
    contrast: parent && parent.contrast !== undefined ? parent.contrast : 1.0
    intensity: parent && parent.intensity !== undefined ? parent.intensity : 1.0

    // Wayland dodge can leave QWindow.visible unchanged. PanelView also clears
    // window effects when its NoBackground mask/floating state is updated.
    // Discover the panel root through the visual parents, without importing
    // private Plasma types or changing any panel geometry.
    readonly property Item panelBackground: {
        let item = parent;
        while (item) {
            if ("panelMask" in item && "floatingness" in item) {
                return item;
            }
            item = item.parent;
        }
        return null;
    }

    function restorePanelBlur(): void {
        // Allow the QML package to be updated before its optional native module.
        if (typeof blurArea.scheduleBlurRestore === "function") {
            blurArea.scheduleBlurRestore();
        }
    }

    onPanelBackgroundChanged: restorePanelBlur()

    Connections {
        target: blurArea.panelBackground
        ignoreUnknownSignals: true
        function onPanelMaskChanged() { blurArea.restorePanelBlur(); }
        function onFloatingnessChanged() { blurArea.restorePanelBlur(); }
        function onTouchingWindowChanged() { blurArea.restorePanelBlur(); }
    }
}

