pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

ConnectedRect {
    id: root

    property bool showDelete: false
    signal deleted()

    property alias label: label.text
    property string subtext
    property real value
    property real from: 0
    property real to: 99
    property real stepSize: 1

    signal moved(value: real)

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    id: label
                    text: root.label
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }

                IconButton {
                    icon: "delete"
                    type: IconButton.Text
                    font: Tokens.font.icon.small
                    visible: root.showDelete
                    onClicked: root.deleted()
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledSpinBox {
            from: root.from
            to: root.to
            stepSize: root.stepSize
            value: root.value
            cLayer: 2
            onValueModified: root.moved(value)
        }
    }
}
