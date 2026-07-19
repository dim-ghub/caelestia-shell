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
    
    implicitWidth: 160
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
                font.bold: true
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

                delegate: StyledRect {
                    id: wsDelegate
                    readonly property int workspaceId: index + 1
                    // Fallback to Hyprland.activeWorkspace if monitor activeWorkspace is not ready yet
                    readonly property int activeWsId: Hypr.monitorFor(root.screen)?.activeWorkspace?.id ?? Hyprland.activeWorkspace?.id ?? 1
                    readonly property bool isActive: activeWsId === workspaceId

                    width: ListView.view.width
                    implicitHeight: Math.max(90, contentCol.implicitHeight + Tokens.padding.medium * 2)
                    color: isActive ? Colours.tPalette.m3surfaceVariant : Colours.tPalette.m3surfaceContainer
                    radius: Tokens.rounding.large
                    border.width: isActive ? 2 : 0
                    border.color: isActive ? Colours.palette.m3primary : "transparent"

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
                        radius: parent.radius
                        onClicked: {
                            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.workspace({ workspace = "${workspaceId}" })` : `workspace ${workspaceId}`);
                            screenState.workspaceDrawer = false;
                        }
                    }

                    ColumnLayout {
                        id: contentCol
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        Flow {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: wsDelegate.width - Tokens.padding.medium * 2
                            spacing: Tokens.spacing.small
                            
                            property list<var> windows: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === workspaceId)

                            Repeater {
                                model: parent.windows

                                delegate: IconImage {
                                    id: windowIcon
                                    required property var modelData
                                    
                                    source: Icons.getAppIcon(modelData.lastIpcObject.class ?? "", "image-missing")
                                    implicitSize: 24
                                    asynchronous: true
                                    
                                    Rectangle {
                                        id: dragRect
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.width: dragArea.drag.active ? 2 : 0
                                        border.color: Colours.palette.m3primary
                                        
                                        Drag.active: dragArea.drag.active
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2
                                        Drag.source: modelData
                                    }

                                    MouseArea {
                                        id: dragArea
                                        anchors.fill: parent
                                        drag.target: dragRect
                                        drag.axis: Drag.XAndYAxis
                                        cursorShape: Qt.PointingHandCursor
                                        
                                        onClicked: {
                                            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                                            screenState.workspaceDrawer = false;
                                        }
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: workspaceId.toString()
                            font: Tokens.font.title.large
                            color: isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font.bold: true
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }
}
