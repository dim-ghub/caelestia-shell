import QtQuick
import QtQuick.Layouts
import qs.components.controls
import qs.modules.nexus.common
import qs.services
import Caelestia.Config

PageBase {
    id: root

    title: qsTr("Quick Share")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Startup")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Auto-start on launch")
            subtext: qsTr("Enable Quick Share when the shell starts")
            checked: GlobalConfig.services.quickShareAutoStart
            onToggled: GlobalConfig.services.quickShareAutoStart = checked
        }

        SectionHeader {
            text: qsTr("Status")
        }

        ToggleRow {
            first: true
            last: true
            text: qsTr("Enable Quick Share")
            subtext: QuickShare.isEnabled ? qsTr("Discoverable by nearby devices") : qsTr("Disabled")
            checked: QuickShare.isEnabled
            onToggled: {
                QuickShare.setEnabled(checked);
                QuickShare.setVisible(checked);
            }
        }
    }
}
