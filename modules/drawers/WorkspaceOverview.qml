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
    
    implicitWidth: 200
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
                    
                    property var hlMonitor: Hypr.monitorFor(root.screen)?.lastIpcObject
                    property real mw: hlMonitor && hlMonitor.width ? hlMonitor.width : 1920
                    property real mh: hlMonitor && hlMonitor.height ? hlMonitor.height : 1080
                    property real mx: hlMonitor && hlMonitor.x ? hlMonitor.x : 0
                    property real my: hlMonitor && hlMonitor.y ? hlMonitor.y : 0

                    width: ListView.view.width
                    implicitHeight: width * (mh / mw)

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
                        // Do not clip here so the drag target can float out

                        Repeater {
                            model: wsDelegate.windows
                            delegate: Item {
                                id: windowContainer
                                required property var modelData
                                
                                property var ipc: modelData.lastIpcObject
                                
                                x: ipc && ipc.at ? ((ipc.at[0] - wsDelegate.mx) / wsDelegate.mw * parent.width) : 0
                                y: ipc && ipc.at ? ((ipc.at[1] - wsDelegate.my) / wsDelegate.mh * parent.height) : 0
                                width: ipc && ipc.size ? (ipc.size[0] / wsDelegate.mw * parent.width) : 0
                                height: ipc && ipc.size ? (ipc.size[1] / wsDelegate.mh * parent.height) : 0

                                StyledRect {
                                    id: windowRect
                                    anchors.fill: parent
                                    color: Colours.palette.m3surface
                                    border.width: 1
                                    border.color: Colours.palette.m3outlineVariant
                                    radius: Tokens.rounding.small
                                    clip: true
                                    
                                    ScreencopyView {
                                        anchors.fill: parent
                                        captureSource: windowContainer.modelData.wayland ?? null
                                        live: windowRect.visible
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 32
                                        height: 32
                                        radius: Tokens.rounding.small
                                        color: Colours.tPalette.m3surface
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        source: Icons.getAppIcon(windowContainer.modelData.lastIpcObject.class ?? "", "image-missing")
                                        implicitSize: 20
                                        asynchronous: true
                                    }
                                }

                                Rectangle {
                                    id: dragRect
                                    width: parent.width
                                    height: parent.height
                                    color: dragArea.drag.active ? Colours.palette.m3primary : "transparent"
                                    opacity: dragArea.drag.active ? 0.3 : 0
                                    radius: Tokens.rounding.small
                                    
                                    Drag.active: dragArea.drag.active
                                    Drag.hotSpot.x: width / 2
                                    Drag.hotSpot.y: height / 2
                                    Drag.source: windowContainer.modelData
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    drag.target: dragRect
                                    drag.axis: Drag.XAndYAxis
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    onReleased: {
                                        if (drag.active) {
                                            dragRect.Drag.drop();
                                            dragRect.x = 0;
                                            dragRect.y = 0;
                                        }
                                    }
                                    
                                    onClicked: {
                                        if (!drag.active) {
                                            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${windowContainer.modelData.address}" })` : `focuswindow address:0x${windowContainer.modelData.address}`);
                                            screenState.workspaceDrawer = false;
                                        }
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
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Tokens.padding.medium
                    }
                }
            }
        }
    }
}
