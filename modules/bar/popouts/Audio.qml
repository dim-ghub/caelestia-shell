pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property PopoutState popouts

    width: 300
    implicitWidth: 300
    implicitHeight: layout.implicitHeight

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.normal

        StyledText {
            Layout.leftMargin: Tokens.padding.small
            text: qsTr("Audio")
            font.weight: 500
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: cardLayout.implicitHeight + Tokens.padding.normal * 2
            radius: Tokens.rounding.normal
            color: Colours.tPalette.m3surfaceContainer
            clip: true

            ColumnLayout {
                id: cardLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.normal
                spacing: Tokens.spacing.normal

                StyledText {
                    text: qsTr("Output device")
                    font.weight: 500
                }

                Repeater {
                    model: Audio.sinks

                    StyledRadioButton {
                        id: control

                        required property PwNode modelData

                        ButtonGroup.group: sinks
                        checked: Audio.sink?.id === modelData.id
                        onClicked: Audio.setAudioSink(modelData)
                        text: modelData.description
                    }
                }

                StyledText {
                    Layout.topMargin: Tokens.spacing.smaller
                    text: qsTr("Input device")
                    font.weight: 500
                }

                Repeater {
                    model: Audio.sources

                    StyledRadioButton {
                        required property PwNode modelData

                        ButtonGroup.group: sources
                        checked: Audio.source?.id === modelData.id
                        onClicked: Audio.setAudioSource(modelData)
                        text: modelData.description
                    }
                }

                StyledText {
                    Layout.topMargin: Tokens.spacing.smaller
                    Layout.bottomMargin: -Tokens.spacing.small / 2
                    text: qsTr("Volume (%1)").arg(Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`)
                    font.weight: 500
                }

                CustomMouseArea {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.normal * 3

                    onWheel: event => {
                        if (event.angleDelta.y > 0)
                            Audio.incrementVolume();
                        else if (event.angleDelta.y < 0)
                            Audio.decrementVolume();
                    }

                    StyledSlider {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        implicitHeight: parent.implicitHeight

                        value: Audio.volume
                        onMoved: Audio.setVolume(value)

                        Behavior on value {
                            Anim {}
                        }
                    }
                }
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.small
            text: qsTr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }
}
