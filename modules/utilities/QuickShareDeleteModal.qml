pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

Loader {
    id: root

    required property var props
    required property matrix4x4 deformMatrix

    asynchronous: true
    anchors.fill: parent

    opacity: root.props.quickShareConfirmDeletePath ? 1 : 0
    active: opacity > 0

    sourceComponent: MouseArea {
        id: deleteConfirmation

        property string path
        property int index

        Component.onCompleted: {
            path = root.props.quickShareConfirmDeletePath;
            index = root.props.quickShareConfirmDeleteIndex;
        }

        hoverEnabled: true
        onClicked: {
            root.props.quickShareConfirmDeletePath = "";
            root.props.quickShareConfirmDeleteIndex = -1;
        }

        Item {
            anchors.fill: parent
            anchors.margins: -Tokens.padding.large
            anchors.rightMargin: -Tokens.padding.large - Config.border.thickness
            opacity: 0.5

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.extraLarge
                color: Colours.palette.m3scrim

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.radius
                    color: parent.color
                }
            }
        }

        StyledRect {
            anchors.centerIn: parent
            radius: Tokens.rounding.extraLarge
            color: Colours.palette.m3surfaceContainerHigh

            scale: 0
            Component.onCompleted: scale = Qt.binding(() => root.props.quickShareConfirmDeletePath ? 1 : 0)

            width: Math.min(parent.width - Tokens.padding.extraLargeIncreased, implicitWidth)
            implicitWidth: deleteConfirmationLayout.implicitWidth + Tokens.padding.extraExtraLarge
            implicitHeight: deleteConfirmationLayout.implicitHeight + Tokens.padding.extraExtraLarge

            MouseArea {
                anchors.fill: parent
            }

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                z: -1
                level: 3
            }

            ColumnLayout {
                id: deleteConfirmationLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large * 1.5
                spacing: Tokens.spacing.medium

                StyledText {
                    text: qsTr("Delete file?")
                    font: Tokens.font.body.large
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("File '%1' will be permanently deleted.").arg(deleteConfirmation.path)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.medium
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.medium

                    TextButton {
                        text: qsTr("Cancel")
                        type: TextButton.Text
                        onClicked: {
                            root.props.quickShareConfirmDeletePath = "";
                            root.props.quickShareConfirmDeleteIndex = -1;
                        }
                    }

                    TextButton {
                        text: qsTr("Delete")
                        type: TextButton.Text
                        onClicked: {
                            if (deleteConfirmation.path !== "") {
                                CUtils.deleteFile(Qt.resolvedUrl("file://" + deleteConfirmation.path));
                            }
                            if (deleteConfirmation.index >= 0) {
                                QuickShare.removeHistoryEntry(deleteConfirmation.index);
                            }
                            root.props.quickShareConfirmDeletePath = "";
                            root.props.quickShareConfirmDeleteIndex = -1;
                        }
                    }
                }
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
