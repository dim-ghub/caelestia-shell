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
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen

    readonly property ScreenState screenState: ShellState.forScreen(screen)
    property real offsetScale: screenState.workspaceDrawer ? 0 : 1

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.leftMargin: Config.bar.position === "left" ? 0 : (-implicitWidth - Tokens.spacing.medium) * offsetScale
    
    implicitWidth: 120
    visible: offsetScale < 1
    opacity: 1 - offsetScale

    Behavior on offsetScale { Anim {} }

    Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            StyledText {
                text: qsTr("Workspaces")
                font: Tokens.font.title.large
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Tokens.spacing.small
            }

            ListView {
                id: wsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Tokens.spacing.medium

                model: 10

                delegate: Item {
                    id: wsDelegate
                    required property int index
                    readonly property int workspaceId: index + 1
                    // Fallback to Hyprland.activeWorkspace if monitor activeWorkspace is not ready yet
                    readonly property int activeWsId: Hypr.monitorFor(root.screen)?.activeWorkspace?.id ?? Hyprland.activeWorkspace?.id ?? 1
                    readonly property bool isActive: activeWsId === workspaceId
                    property list<var> windows: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === workspaceId)

                    width: ListView.view.width
                    implicitHeight: 96

                    StyledRect {
                        anchors.fill: parent
                        color: isActive ? Colours.tPalette.m3surfaceVariant : (wsDelegate.windows.length === 0 ? Colours.tPalette.m3surfaceContainer : "transparent")
                        radius: Tokens.rounding.large
                        border.width: isActive ? 2 : 0
                        border.color: isActive ? Colours.palette.m3primary : "transparent"
                    }

                    DropArea {
                        anchors.fill: parent
                        onDropped: drop => {
                            const client = drop.source;
                            if (client) {
                                Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.window.move({ window = "address:0x${client.address}", workspace = "${workspaceId}", follow = false })` : `movetoworkspace ${workspaceId},address:0x${client.address}`);
                            }
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.large
                        onClicked: {
                            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.workspace({ workspace = "${workspaceId}" })` : `workspace ${workspaceId}`);
                            screenState.workspaceDrawer = false;
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium

                        RowLayout {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: wsIdText.top
                            anchors.bottomMargin: Tokens.spacing.small
                            spacing: 4
                            visible: wsDelegate.windows.length > 0

                            Repeater {
                                model: wsDelegate.windows
                                delegate: StyledRect {
                                    id: windowRect
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Colours.palette.m3outlineVariant
                                    radius: Tokens.rounding.medium
                                    
                                    IconImage {
                                        anchors.centerIn: parent
                                        source: Icons.getAppIcon(windowRect.modelData.lastIpcObject.class ?? "", "image-missing")
                                        implicitSize: 24
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        id: dragRect
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.width: dragArea.drag.active ? 2 : 0
                                        border.color: Colours.palette.m3primary
                                        
                                        Drag.active: dragArea.drag.active
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2
                                        Drag.source: windowRect.modelData
                                    }

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        drag.target: dragRect
                                        drag.axis: Drag.XAndYAxis
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onClicked: {
                                            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${windowRect.modelData.address}" })` : `focuswindow address:0x${windowRect.modelData.address}`);
                                            screenState.workspaceDrawer = false;
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            id: wsIdText
                            text: workspaceId.toString()
                            font: Tokens.font.title.large
                            color: isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: wsDelegate.windows.length > 0 ? parent.bottom : undefined
                            anchors.verticalCenter: wsDelegate.windows.length === 0 ? parent.verticalCenter : undefined
                        }
                    }
                }
            }
        }
    }
}
