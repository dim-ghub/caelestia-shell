pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.components.filedialog

Loader {
    id: root

    required property var props
    required property matrix4x4 deformMatrix

    asynchronous: true
    anchors.fill: parent

    FileDialog {
        id: fileDialog
        title: qsTr("Select a file to send")
        
        property string targetDeviceId: ""
        
        onAccepted: path => {
            if (targetDeviceId !== "" && path) {
                QuickShare.sendFile(targetDeviceId, path.toString().replace("file://", ""));
            }
            root.props.quickShareDeviceSelectorOpen = false;
            root.props.quickShareFileDialogOpen = false;
        }
        onRejected: {
            root.props.quickShareDeviceSelectorOpen = false;
            root.props.quickShareFileDialogOpen = false;
        }
    }

    opacity: root.props.quickShareDeviceSelectorOpen ? 1 : 0
    active: opacity > 0

    sourceComponent: MouseArea {
        id: selectorModal

        hoverEnabled: true
        onClicked: root.props.quickShareDeviceSelectorOpen = false

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
            Component.onCompleted: scale = Qt.binding(() => root.props.quickShareDeviceSelectorOpen ? 1 : 0)

            width: Math.min(parent.width - Tokens.padding.extraLargeIncreased, implicitWidth)
            implicitWidth: 350
            implicitHeight: selectorLayout.implicitHeight + Tokens.padding.extraExtraLarge

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
                id: selectorLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.large * 1.5
                spacing: Tokens.spacing.medium

                StyledText {
                    text: qsTr("Select Device")
                    font: Tokens.font.body.large
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Choose a nearby device to send the file to.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }

                StyledListView {
                    id: deviceList
                    
                    Layout.fillWidth: true
                    implicitHeight: count > 0 ? Math.min(count * 50, 200) : 50
                    clip: true
                    
                    model: QuickShare.nearbyDevices
                    
                    Connections {
                        target: QuickShare
                        function onNearbyDevicesChanged() {
                            deviceList.model = null
                            deviceList.model = QuickShare.nearbyDevices
                        }
                    }
                    
                    delegate: WrapperMouseArea {
                        required property var modelData
                        
                        width: deviceList.width
                        height: 50
                        
                        cursorShape: Qt.PointingHandCursor
                        
                        onClicked: {
                            root.props.quickShareFileDialogOpen = true
                            fileDialog.targetDeviceId = modelData.id
                            fileDialog.open()
                        }
                        
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            spacing: Tokens.spacing.medium
                            
                            MaterialIcon {
                                text: "smartphone"
                                color: Colours.palette.m3primary
                                fontStyle: Tokens.font.icon.large
                            }
                            
                            StyledText {
                                text: modelData.name
                                font: Tokens.font.body.medium
                                Layout.fillWidth: true
                            }
                        }
                    }
                    
                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("No devices found")
                        color: Colours.palette.m3outline
                        visible: deviceList.count === 0
                    }
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.medium
                    Layout.alignment: Qt.AlignRight
                    spacing: Tokens.spacing.medium

                    TextButton {
                        text: qsTr("Cancel")
                        type: TextButton.Text
                        onClicked: root.props.quickShareDeviceSelectorOpen = false
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
