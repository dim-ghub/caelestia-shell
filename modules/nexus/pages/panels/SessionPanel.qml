pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Session Menu")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            checked: Config.session.enabled
            onToggled: GlobalConfig.session.enabled = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            text: qsTr("Graceful shutdown")
            subtext: qsTr("Politely asks apps to close before powering off or logging out")
            checked: Config.session.gracefulShutdown
            onToggled: GlobalConfig.session.gracefulShutdown = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            text: qsTr("Vim Keybinds")
            subtext: qsTr("Use hjkl to navigate the session menu")
            checked: Config.session.vimKeybinds
            onToggled: GlobalConfig.session.vimKeybinds = checked
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the session menu opens")
            value: Config.session.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.session.dragThreshold = v
        }
    }
}
