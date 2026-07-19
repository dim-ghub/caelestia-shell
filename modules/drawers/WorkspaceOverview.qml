pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.utils

StyledWindow {
    id: root

    required property ShellScreen screen

    readonly property ScreenState screenState: ShellState.forScreen(screen)
    property real visibleOffset: screenState.workspaceDrawer ? 1 : 0

    name: "workspaceOverview"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true

    width: 350
    x: (visibleOffset - 1) * width
    visible: visibleOffset > 0

    Behavior on visibleOffset { Anim {} }

    Rectangle {
        anchors.fill: parent
        color: Colours.palette.m3surface
        radius: Tokens.rounding.large
        border.width: Config.border.thickness
        border.color: Colours.palette.m3outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                MaterialIcon {
                    text: "dashboard"
                    fontStyle: Tokens.font.icon.large
                }
                StyledText {
                    text: qsTr("Workspace Overview")
                    font: Tokens.font.title.large
                    Layout.fillWidth: true
                }
                StateLayer {
                    radius: Tokens.rounding.medium
                    implicitWidth: closeIcon.implicitWidth + Tokens.padding.small
                    implicitHeight: closeIcon.implicitHeight + Tokens.padding.small
                    onClicked: screenState.workspaceDrawer = false
                    MaterialIcon {
                        id: closeIcon
                        anchors.centerIn: parent
                        text: "close"
                        fontStyle: Tokens.font.icon.medium
                    }
                }
            }

            ListView {
                id: wsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacing.large

                model: Hyprland.workspaces.values.filter(ws => ws.id > 0).sort((a, b) => a.id - b.id)

                delegate: Rectangle {
                    id: wsDelegate
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: contentCol.implicitHeight + Tokens.padding.medium * 2
                    color: Colours.palette.m3surfaceVariant
                    radius: Tokens.rounding.medium

                    DropArea {
                        anchors.fill: parent
                        onDropped: drop => {
                            const client = drop.source;
                            if (client) {
                                Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", workspace = "${modelData.id}", follow = false })` : `movetoworkspace ${modelData.id},address:0x${client.address}`);
                            }
                        }
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        StyledText {
                            text: qsTr("Workspace ") + modelData.name
                            font: Tokens.font.title.medium
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            // Get windows for this workspace
                            property list<var> windows: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === modelData.id)

                            Repeater {
                                model: parent.windows

                                delegate: Item {
                                    id: windowItem
                                    required property var modelData
                                    
                                    width: 120
                                    height: 120

                                    Rectangle {
                                        id: dragRect
                                        anchors.fill: parent
                                        color: Colours.palette.m3surface
                                        radius: Tokens.rounding.small
                                        border.width: 1
                                        border.color: dragArea.drag.active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                                        
                                        Drag.active: dragArea.drag.active
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2
                                        Drag.source: modelData

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: Tokens.padding.small
                                            spacing: Tokens.spacing.small

                                            RowLayout {
                                                Layout.fillWidth: true
                                                IconImage {
                                                    source: Icons.getAppIcon(modelData.lastIpcObject.class ?? "", "image-missing")
                                                    implicitSize: 16
                                                    asynchronous: true
                                                }
                                                StyledText {
                                                    text: modelData.lastIpcObject.class ?? ""
                                                    font: Tokens.font.label.small
                                                    color: Colours.palette.m3onSurface
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            ClippingWrapperRectangle {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                color: "transparent"
                                                radius: Tokens.rounding.small

                                                ScreencopyView {
                                                    captureSource: modelData.wayland ?? null // qmllint disable unresolved-type
                                                    live: windowItem.visible
                                                    constraintSize.width: 100
                                                    constraintSize.height: 80
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: dragArea
                                            anchors.fill: parent
                                            drag.target: dragRect
                                            drag.axis: Drag.XAndYAxis
                                            
                                            // Handle click to focus window
                                            onClicked: {
                                                Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                                                screenState.workspaceDrawer = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
