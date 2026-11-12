// SPDX-License-Identifier: GPL-2.0-or-later
import org.kde.plasma.core as PlasmaCore

PlasmaCore.ToolTipArea {
    // Native hover transfers can open the shared dialog before our hover timer.
    // Prepare its content on every opening, including transfers while visible.
    function updateMainItemBindings(): void {}
    onAboutToShow: updateMainItemBindings()
}
