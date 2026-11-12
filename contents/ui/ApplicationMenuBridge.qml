// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

QtObject {
    id: bridge
    property QtObject nativeBackend: null
    readonly property bool available: nativeBackend !== null
    signal showAllPlaces()

    // Load the optional module in a separate component so missing native code
    // never prevents the applet or its existing menu actions from loading.
    Component.onCompleted: {
        const component = Qt.createComponent("NativeApplicationMenuBackend.qml");
        if (component.status === Component.Ready) {
            nativeBackend = component.createObject(bridge);
            if (nativeBackend) {
                nativeBackend.showAllPlaces.connect(bridge.showAllPlaces);
            }
        }
        component.destroy();
    }

    function jumpListActions(launcherUrl, owner) {
        return nativeBackend ? nativeBackend.jumpListActions(launcherUrl, owner) : [];
    }
    function placesActions(launcherUrl, showAll, owner) {
        return nativeBackend ? nativeBackend.placesActions(launcherUrl, showAll, owner) : [];
    }
    function recentDocumentActions(launcherUrl, owner) {
        return nativeBackend ? nativeBackend.recentDocumentActions(launcherUrl, owner) : [];
    }
}
