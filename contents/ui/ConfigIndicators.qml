// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: root
    readonly property bool custom: cfg_indicatorMode === 2
    readonly property bool customEnabled: custom && cfg_customIndicatorsEnabled
    property alias cfg_indicatorMode: indicatorModeControl.currentIndex
    property alias cfg_nativeGroupIndicator: nativeGroupIndicatorControl.currentIndex
    property alias cfg_taskDecorations: taskDecorationsControl.currentIndex
    property alias cfg_customIndicatorsEnabled: customIndicatorsEnabledControl.checked
    property alias cfg_indicatorAnimations: indicatorAnimationsControl.checked
    property alias cfg_indicatorStyle: indicatorStyleControl.currentIndex
    property alias cfg_indicatorOverride: indicatorOverrideControl.checked
    property alias cfg_indicatorEdge: indicatorEdgeControl.currentIndex
    property alias cfg_indicatorEdgeDistance: indicatorEdgeDistanceControl.value
    property alias cfg_indicatorThickness: indicatorThicknessControl.value
    property alias cfg_indicatorLength: indicatorLengthControl.value
    property alias cfg_indicatorRoundness: indicatorRoundnessControl.value
    property alias cfg_indicatorSpacing: indicatorSpacingControl.value
    property alias cfg_indicatorAlignment: indicatorAlignmentControl.currentIndex
    property alias cfg_indicatorResizeActive: indicatorResizeActiveControl.checked
    property alias cfg_indicatorActiveThickness: indicatorActiveThicknessControl.value
    property alias cfg_indicatorActiveLength: indicatorActiveLengthControl.value
    property alias cfg_indicatorResizeHover: indicatorResizeHoverControl.checked
    property alias cfg_indicatorHoverSeparate: indicatorHoverSeparateControl.checked
    property alias cfg_indicatorHoverThickness: indicatorHoverThicknessControl.value
    property alias cfg_indicatorHoverLength: indicatorHoverLengthControl.value
    property alias cfg_indicatorGroupSeparate: indicatorGroupSeparateControl.checked
    property alias cfg_indicatorGroupThickness: indicatorGroupThicknessControl.value
    property alias cfg_indicatorGroupLength: indicatorGroupLengthControl.value
    property alias cfg_indicatorMaxSegments: indicatorMaxSegmentsControl.value
    property alias cfg_indicatorUnfocusedColorEnabled: unfocusedColorEnabled.checked
    property color cfg_indicatorUnfocusedColor: "#3daee9"
    property alias cfg_indicatorHighlightActive: indicatorHighlightActiveControl.checked
    property alias cfg_indicatorDimInactive: indicatorDimInactiveControl.checked
    property alias cfg_indicatorInactiveOpacity: indicatorInactiveOpacityControl.value
    property alias cfg_indicatorDesaturate: indicatorDesaturateControl.checked
    property alias cfg_indicatorColorSource: indicatorColorSourceControl.currentIndex
    property color cfg_indicatorCustomColor: "#3daee9"
    readonly property var previewConfiguration: ({
        indicatorMode: cfg_indicatorMode,
        nativeGroupIndicator: cfg_nativeGroupIndicator,
        taskDecorations: cfg_taskDecorations,
        customIndicatorsEnabled: cfg_customIndicatorsEnabled,
        indicatorAnimations: cfg_indicatorAnimations,
        indicatorStyle: cfg_indicatorStyle,
        indicatorOverride: cfg_indicatorOverride,
        indicatorEdge: cfg_indicatorEdge,
        indicatorEdgeDistance: cfg_indicatorEdgeDistance,
        indicatorThickness: cfg_indicatorThickness,
        indicatorLength: cfg_indicatorLength,
        indicatorRoundness: cfg_indicatorRoundness,
        indicatorSpacing: cfg_indicatorSpacing,
        indicatorAlignment: cfg_indicatorAlignment,
        indicatorResizeActive: cfg_indicatorResizeActive,
        indicatorActiveThickness: cfg_indicatorActiveThickness,
        indicatorActiveLength: cfg_indicatorActiveLength,
        indicatorResizeHover: cfg_indicatorResizeHover,
        indicatorHoverSeparate: cfg_indicatorHoverSeparate,
        indicatorHoverThickness: cfg_indicatorHoverThickness,
        indicatorHoverLength: cfg_indicatorHoverLength,
        indicatorGroupSeparate: cfg_indicatorGroupSeparate,
        indicatorGroupThickness: cfg_indicatorGroupThickness,
        indicatorGroupLength: cfg_indicatorGroupLength,
        indicatorMaxSegments: cfg_indicatorMaxSegments,
        indicatorUnfocusedColorEnabled: cfg_indicatorUnfocusedColorEnabled,
        indicatorUnfocusedColor: cfg_indicatorUnfocusedColor,
        indicatorHighlightActive: cfg_indicatorHighlightActive,
        indicatorDimInactive: cfg_indicatorDimInactive,
        indicatorInactiveOpacity: cfg_indicatorInactiveOpacity,
        indicatorDesaturate: cfg_indicatorDesaturate,
        indicatorColorSource: cfg_indicatorColorSource,
        indicatorCustomColor: cfg_indicatorCustomColor
    })
    QtDialogs.ColorDialog {
        id: colorDialog
        selectedColor: root.cfg_indicatorCustomColor
        onAccepted: root.cfg_indicatorCustomColor = selectedColor
    }
    Kirigami.FormLayout {
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("Mode default keeps macOS unchanged. Plasma enables native task frames and the group symbol. Overrides apply only to this dock.")
        }
        QQC2.ComboBox {
            id: indicatorModeControl
            visible: true
            Kirigami.FormData.label: i18n("Indicator mode:")
            model: [i18n("macOS"), i18n("Plasma"), i18n("Custom")]
            currentIndex: 0
        }
        QQC2.ComboBox {
            id: nativeGroupIndicatorControl
            visible: true
            Kirigami.FormData.label: i18n("Native group symbol:")
            model: [i18n("Mode default"), i18n("Enabled"), i18n("Disabled")]
            currentIndex: 0
        }
        QQC2.ComboBox {
            id: taskDecorationsControl
            visible: true
            Kirigami.FormData.label: i18n("Plasma task decorations:")
            model: [i18n("Mode default"), i18n("Enabled"), i18n("Disabled")]
            currentIndex: 0
        }
        Kirigami.Separator { visible: root.custom; Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Custom indicators") }
        QQC2.CheckBox {
            id: customIndicatorsEnabledControl
            visible: root.custom
            text: i18n("Show running indicators")
            checked: true
        }
        QQC2.CheckBox {
            id: indicatorAnimationsControl
            visible: root.customEnabled
            text: i18n("Animate state changes")
            checked: true
        }
        QQC2.ComboBox {
            id: indicatorStyleControl
            visible: root.customEnabled
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Dots"), i18n("Line"), i18n("Dashes")]
            currentIndex: 0
        }
        QQC2.CheckBox {
            id: indicatorOverrideControl
            visible: root.customEnabled
            text: i18n("Override indicator position")
            checked: false
        }
        QQC2.ComboBox {
            id: indicatorEdgeControl
            visible: root.customEnabled && root.cfg_indicatorOverride
            Kirigami.FormData.label: i18n("Position:")
            model: [i18n("Bottom"), i18n("Top"), i18n("Left"), i18n("Right")]
            currentIndex: 0
        }
        QQC2.SpinBox {
            id: indicatorEdgeDistanceControl
            visible: root.customEnabled
            Kirigami.FormData.label: i18n("Distance from capsule edge (px):")
            from: 0; to: 32; value: 2
            editable: true
        }
        QQC2.SpinBox {
            id: indicatorThicknessControl
            visible: root.customEnabled
            Kirigami.FormData.label: i18n("Inactive thickness (px):")
            from: 1; to: 24; value: 4
            editable: true
        }
        QQC2.SpinBox {
            id: indicatorLengthControl
            visible: root.customEnabled && root.cfg_indicatorStyle !== 0
            Kirigami.FormData.label: i18n("Inactive length (px):")
            from: 1; to: 160; value: 12
            editable: true
        }
        QQC2.SpinBox {
            id: indicatorRoundnessControl
            visible: root.customEnabled && root.cfg_indicatorStyle !== 0
            Kirigami.FormData.label: i18n("Corner roundness (%):")
            from: 0; to: 100; value: 100
            editable: true
        }
        QQC2.SpinBox {
            id: indicatorSpacingControl
            visible: root.customEnabled
            Kirigami.FormData.label: i18n("Segment spacing (px):")
            from: 0; to: 16; value: 2
            editable: true
        }
        QQC2.ComboBox {
            id: indicatorAlignmentControl
            visible: root.customEnabled
            Kirigami.FormData.label: i18n("Thickness alignment:")
            model: [i18n("Toward capsule edge"), i18n("Centered"), i18n("Toward icon")]
            currentIndex: 1
        }
        Kirigami.Separator { visible: root.custom; Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("State dimensions") }
        QQC2.CheckBox {
            id: indicatorResizeActiveControl
            visible: root.customEnabled
            text: i18n("Resize on activation")
            checked: true
        }
        QQC2.SpinBox {
            id: indicatorActiveThicknessControl
            visible: root.customEnabled && root.cfg_indicatorResizeActive
            Kirigami.FormData.label: i18n("Active thickness (px):")
            from: 1; to: 24; value: 5
            editable: true
        }
        QQC2.SpinBox {
            id: indicatorActiveLengthControl
            visible: root.customEnabled && root.cfg_indicatorResizeActive && root.cfg_indicatorStyle !== 0
            Kirigami.FormData.label: i18n("Active length (px):")
            from: 1; to: 160; value: 20
            editable: true
        }
        QQC2.CheckBox {
            id: indicatorResizeHoverControl
            visible: root.customEnabled
            text: i18n("Resize on hover")
            checked: false
        }
        QQC2.CheckBox {
            id: indicatorHoverSeparateControl
            visible: root.customEnabled && root.cfg_indicatorResizeHover
            text: i18n("Use separate hover dimensions")
            checked: true
        }
        QQC2.SpinBox {
            id: indicatorHoverThicknessControl
            visible: root.customEnabled && root.cfg_indicatorResizeHover && root.cfg_indicatorHoverSeparate
            Kirigami.FormData.label: i18n("Hover thickness (px):")
            from: 1; to: 24; value: 6
            editable: true
        }
        QQC2.SpinBox {
            id: indicatorHoverLengthControl
            visible: root.customEnabled && root.cfg_indicatorResizeHover && root.cfg_indicatorHoverSeparate && root.cfg_indicatorStyle !== 0
            Kirigami.FormData.label: i18n("Hover length (px):")
            from: 1; to: 160; value: 24
            editable: true
        }
        QQC2.CheckBox {
            id: indicatorGroupSeparateControl
            visible: root.customEnabled
            text: i18n("Use separate grouped dimensions")
            checked: false
        }
        QQC2.SpinBox {
            id: indicatorGroupThicknessControl
            visible: root.customEnabled && root.cfg_indicatorGroupSeparate
            Kirigami.FormData.label: i18n("Grouped thickness (px):")
            from: 1; to: 24; value: 4
            editable: true
        }
        QQC2.SpinBox {
            id: indicatorGroupLengthControl
            visible: root.customEnabled && root.cfg_indicatorGroupSeparate && root.cfg_indicatorStyle !== 0
            Kirigami.FormData.label: i18n("Grouped length (px):")
            from: 1; to: 160; value: 8
            editable: true
        }
        Kirigami.Separator { visible: root.custom; Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Multiple windows") }
        QQC2.SpinBox {
            id: indicatorMaxSegmentsControl
            visible: root.customEnabled
            Kirigami.FormData.label: i18n("Maximum window segments:")
            from: 1; to: 8; value: 4
            editable: true
        }
        QQC2.CheckBox {
            id: indicatorHighlightActiveControl
            visible: root.customEnabled
            text: i18n("Highlight the active window in a group")
            checked: true
        }
        QQC2.CheckBox {
            id: indicatorDimInactiveControl
            visible: root.customEnabled
            text: i18n("Dim inactive segments")
            checked: true
        }
        QQC2.SpinBox {
            id: indicatorInactiveOpacityControl
            visible: root.customEnabled && (root.cfg_indicatorDimInactive || root.cfg_indicatorHighlightActive)
            Kirigami.FormData.label: i18n("Inactive opacity (%):")
            from: 0; to: 100; value: 55
            editable: true
        }
        QQC2.CheckBox {
            id: indicatorDesaturateControl
            visible: root.customEnabled
            text: i18n("Desaturate minimized windows")
            checked: false
        }
        Kirigami.Separator { visible: root.custom; Kirigami.FormData.isSection: true; Kirigami.FormData.label: i18n("Colors") }
        QQC2.ComboBox {
            id: indicatorColorSourceControl
            visible: root.customEnabled
            Kirigami.FormData.label: i18n("Indicator color:")
            model: [i18n("Plasma accent"), i18n("Application icon"), i18n("Custom color")]
            currentIndex: 0
        }
        QQC2.Button {
            visible: root.customEnabled && root.cfg_indicatorColorSource === 2
            Kirigami.FormData.label: i18n("Custom color:")
            text: root.cfg_indicatorCustomColor.toString()
            onClicked: colorDialog.open()
        }
        QQC2.CheckBox {
            id: unfocusedColorEnabled
            visible: root.customEnabled
            text: i18n("Use a separate unfocused indicator color")
        }
        QQC2.Button {
            visible: root.customEnabled && root.cfg_indicatorUnfocusedColorEnabled
            Kirigami.FormData.label: i18n("Unfocused color:")
            text: root.cfg_indicatorUnfocusedColor.toString()
            onClicked: unfocusedDialog.open()
        }
        QtDialogs.ColorDialog {
            id: unfocusedDialog
            selectedColor: root.cfg_indicatorUnfocusedColor
            onAccepted: root.cfg_indicatorUnfocusedColor = selectedColor
        }
        QQC2.Label {
            visible: root.customEnabled
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18n("Indicators fit within the task slot and capsule padding. Lines use a shared length; dashes use a length per window. Hover dimensions take precedence over active and grouped dimensions. Icon colors fall back to the Plasma accent.")
        }
        Item {
            visible: root.customEnabled
            implicitWidth: 200
            implicitHeight: 100
            Kirigami.FormData.label: i18n("Preview (hover to test):")
            Rectangle {
                anchors.centerIn: parent
                width: 180; height: 70; radius: 12
                color: Kirigami.Theme.alternateBackgroundColor
            }
            CustomIndicators {
                anchors.centerIn: parent
                width: 140; height: 40
                configuration: root.previewConfiguration
                windowCount: 6
                activeIndex: 1
                horizontalPadding: 12; verticalPadding: 12
                minimizedWindows: [true, false, false, false, false, false]
                hovered: previewHover.hovered
                accentColor: Kirigami.Theme.highlightColor
                HoverHandler { id: previewHover }
                Text {
                    anchors.centerIn: parent
                    text: i18n("6 windows")
                    color: Kirigami.Theme.textColor
                }
            }
        }
    }
}
