pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    property string deviceName: "Unknown Device"
    property string fileName: "unknown_file.txt"
    property string fileSize: "0 B"
    property bool active: false

    implicitWidth: layout.implicitWidth + Tokens.padding.large * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    
    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainerHigh

    opacity: active ? 1 : 0
    scale: active ? 1 : 0
    visible: opacity > 0

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.medium

            MaterialIcon {
                text: "near_me"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                text: qsTr("Quick Share Request")
                font: Tokens.font.body.large
                Layout.fillWidth: true
            }
        }

        StyledText {
            text: qsTr("%1 wants to share '%2' (%3) with you.").arg(root.deviceName).arg(root.fileName).arg(root.fileSize)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.medium
            Layout.fillWidth: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Tokens.spacing.medium
            Layout.topMargin: Tokens.spacing.small

            TextButton {
                text: qsTr("Decline")
                type: TextButton.Text
                onClicked: {
                    QuickShare.rejectIncomingTransfer();
                    QuickShare.hasPendingTransfer = false;
                }
            }

            TextButton {
                text: qsTr("Accept")
                type: TextButton.Filled
                onClicked: {
                    QuickShare.acceptIncomingTransfer();
                    QuickShare.hasPendingTransfer = false;
                }
            }
        }
    }

    Behavior on opacity {
        Anim {}
    }
    
    Behavior on scale {
        Anim {}
    }
}
