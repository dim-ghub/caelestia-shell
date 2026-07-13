import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledSwitch {
    id: root

    property bool showDelete: false
    signal deleted()

    property string subtext
    property alias first: bg.first
    property alias last: bg.last
    readonly property alias bg: bg

    Layout.fillWidth: true

    horizontalPadding: Tokens.padding.largeIncreased
    verticalPadding: Tokens.padding.medium
    font: Tokens.font.body.small

    implicitWidth: implicitContentWidth + implicitIndicatorWidth + horizontalPadding * 2
    implicitHeight: Math.max(implicitContentHeight, implicitIndicatorHeight) + verticalPadding * 2
    cLayer: 2

    indicator.anchors.verticalCenter: verticalCenter
    indicator.anchors.right: right
    indicator.anchors.rightMargin: root.horizontalPadding

    onPressed: stateLayer.press(stateLayer.mouseX, stateLayer.mouseY)

    background: ConnectedRect {
        id: bg

        StateLayer {
            id: stateLayer

            manualPressOverride: root.pressed
        }
    }

    contentItem: Item {
        anchors.left: parent.left
        anchors.right: root.indicator.left
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: Tokens.spacing.medium

        implicitWidth: column.implicitWidth
        implicitHeight: column.implicitHeight

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            RowLayout {
                width: parent.width
                spacing: Tokens.spacing.small

                StyledText {
                    id: label
                    text: root.text
                    font: root.font
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width - (delBtn.visible ? delBtn.implicitWidth + parent.spacing : 0)
                }

                IconButton {
                    id: delBtn
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
                anchors.left: parent.left
                anchors.right: parent.right

                visible: root.subtext
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }
    }
}
