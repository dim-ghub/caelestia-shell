import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Hyprland")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2



        NavRow {
            first: true
            icon: "data_object"
            label: qsTr("Variables")
            status: qsTr("Manage your hyprland variables")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            icon: "keyboard"
            label: qsTr("Keybinds")
            status: qsTr("Manage your hyprland keybinds")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            last: true
            icon: "settings_suggest"
            label: qsTr("User configuration")
            status: qsTr("Advanced configuration options")
            onClicked: root.nState.openSubPage(3)
        }
    }
}
