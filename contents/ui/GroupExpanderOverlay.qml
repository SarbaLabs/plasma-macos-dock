/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.ksvg as KSvg

KSvg.SvgItem {
    id: arrow
    required property Item iconTarget
    property int edge: 0 // bottom, top, left, right in the task's visual coordinates
    property bool grouped: false
    visible: grouped
    imagePath: "widgets/tasks"
    elementId: ["group-expander-bottom", "group-expander-top", "group-expander-left", "group-expander-right"][edge]
    width: Math.min(naturalSize.width, iconTarget.width)
    height: Math.min(naturalSize.height, iconTarget.height)
    x: edge === 2 ? 0 : edge === 3 ? parent.width - width : iconTarget.x + (iconTarget.width - width) / 2
    y: edge === 1 ? 0 : edge === 0 ? parent.height - height : iconTarget.y + (iconTarget.height - height) / 2
}
