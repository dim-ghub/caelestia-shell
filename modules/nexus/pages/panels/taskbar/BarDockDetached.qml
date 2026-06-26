pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> positionItems: [
        MenuItem {
            property string value: "top"

            text: qsTr("Top")
        },
        MenuItem {
            property string value: "bottom"

            text: qsTr("Bottom")
        },
        MenuItem {
            property string value: "left"

            text: qsTr("Left")
        },
        MenuItem {
            property string value: "right"

            text: qsTr("Right")
        }
    ]

    title: qsTr("Detached dock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Position")
        }

        ToggleRow {
            first: true
            text: qsTr("Detached from taskbar")
            subtext: qsTr("Place the dock in its own separate wrapper")
            checked: Config.bar.dock.detached
            onToggled: GlobalConfig.bar.dock.detached = checked
        }

        SelectRow {
            Layout.fillWidth: true
            label: qsTr("Position")
            subtext: qsTr("Screen edge to place the dock on")
            active: {
                for (let i = 0; i < positionItems.length; i++) {
                    if (positionItems[i].value === Config.bar.dock.position)
                        return positionItems[i];
                }
                return positionItems[1];
            }
            menuItems: positionItems
            onSelected: item => GlobalConfig.bar.dock.position = item.value
        }

        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            last: true
            first: true
            text: qsTr("Persistent")
            subtext: qsTr("Keep the dock visible at all times. When off, the dock appears on hover.")
            checked: Config.bar.dock.persistent
            onToggled: GlobalConfig.bar.dock.persistent = checked
        }
    }
}
