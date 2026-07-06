import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root
    title: qsTr("Shimeji characters")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable Shimeji")
            checked: Config.shimeji.enabled
            onToggled: GlobalConfig.shimeji.enabled = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            text: qsTr("Auto-hide Shimeji")
            subtext: qsTr("Hide Shimeji when a window is open")
            checked: Config.shimeji.autoHide
            onToggled: GlobalConfig.shimeji.autoHide = checked
            enabled: Config.shimeji.enabled
        }

        StepperRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Shimeji count per screen")
            from: 1
            to: 9999
            stepSize: 1
            value: Config.shimeji.count
            onMoved: GlobalConfig.shimeji.count = value
            enabled: Config.shimeji.enabled
        }
    }
}
