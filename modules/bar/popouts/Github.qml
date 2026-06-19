pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services as Services

Item {
    id: root

    required property var popouts
    property var days: []
    property int total: 0
    property string username: ""
    property string lastError: ""

    implicitWidth: layout.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 3

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        StyledText {
            text: root.username.length > 0 ? `@${root.username}` : "GitHub"
            font.weight: 600
        }

        StyledText {
            text: root.lastError.length > 0 ? `Error: ${root.lastError}` : `Last 7 days: ${root.total} commits`
            color: root.lastError.length > 0 ? Services.Colours.palette.m3error : Services.Colours.palette.m3secondary
        }

        StyledRect {
            Layout.topMargin: Tokens.spacing.medium
            implicitWidth: ctaRow.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: ctaRow.implicitHeight + Tokens.padding.medium * 2
            color: Services.Colours.palette.m3primaryContainer
            radius: Tokens.rounding.medium

            StateLayer {
                color: Services.Colours.palette.m3onPrimaryContainer
                radius: parent.radius
                onClicked: {
                    root.popouts.hasCurrent = false;
                    Qt.openUrlExternally("https://github.com/" + root.username);
                }
            }

            RowLayout {
                id: ctaRow

                anchors.centerIn: parent
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.leftMargin: Tokens.padding.small
                    text: "Open profile"
                    color: Services.Colours.palette.m3onPrimaryContainer
                }

                MaterialIcon {
                    text: "chevron_right"
                    color: Services.Colours.palette.m3onPrimaryContainer
                    font: Tokens.font.icon.large
                }
            }
        }
    }
}
