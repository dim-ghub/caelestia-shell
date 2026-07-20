pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
Item {
    id: root

    required property ShellScreen screen

    readonly property ScreenState screenState: ShellState.forScreen(screen)
    property real offsetScale: screenState.workspaceDrawer ? 0 : 1

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.leftMargin: (-implicitWidth - Tokens.spacing.medium) * offsetScale
    
    implicitWidth: 200
    visible: offsetScale < 0.999
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

            VerticalFadeListView {
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
                    
                    property int activeDrags: 0
                    z: activeDrags > 0 ? 100 : 0
                    
                    property list<var> windows: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === workspaceId)
                    
                    property var hlMonitor: {
                        let ws = Hyprland.workspaces.values.find(w => w.id === workspaceId);
                        if (ws && ws.monitor) return ws.monitor.lastIpcObject;
                        return Hypr.monitorFor(root.screen)?.lastIpcObject;
                    }
                    property bool isPortrait: hlMonitor && hlMonitor.transform % 2 !== 0
                    property real mw: hlMonitor && hlMonitor.width ? (isPortrait ? hlMonitor.height : hlMonitor.width) : 1920
                    property real mh: hlMonitor && hlMonitor.height ? (isPortrait ? hlMonitor.width : hlMonitor.height) : 1080
                    property real mx: hlMonitor && hlMonitor.x ? hlMonitor.x : 0
                    property real my: hlMonitor && hlMonitor.y ? hlMonitor.y : 0
                    
                    property real inactiveOffsetX: {
                        if (isActive || windows.length === 0) return 0;
                        let firstWindow = windows[0].lastIpcObject;
                        if (!firstWindow || !firstWindow.at || !firstWindow.size) return 0;
                        let center = firstWindow.at[0] - mx + firstWindow.size[0]/2;
                        return Math.floor(center / mw) * mw;
                    }
                    property real inactiveOffsetY: {
                        if (isActive || windows.length === 0) return 0;
                        let firstWindow = windows[0].lastIpcObject;
                        if (!firstWindow || !firstWindow.at || !firstWindow.size) return 0;
                        let center = firstWindow.at[1] - my + firstWindow.size[1]/2;
                        return Math.floor(center / mh) * mh;
                        return Math.floor(center / mh) * mh;
                    }
                    
                    property real contentMinX: {
                        if (windows.length === 0) return 0;
                        let min = mw;
                        for (let i = 0; i < windows.length; i++) {
                            let w = windows[i].lastIpcObject;
                            if (w && w.at && w.size) {
                                let left = Math.max(0, w.at[0] - mx - inactiveOffsetX);
                                if (left < min) min = left;
                            }
                        }
                        return min === mw ? 0 : min;
                    }
                    property real contentMaxX: {
                        if (windows.length === 0) return mw;
                        let max = 0;
                        for (let i = 0; i < windows.length; i++) {
                            let w = windows[i].lastIpcObject;
                            if (w && w.at && w.size) {
                                let right = Math.min(mw, w.at[0] - mx - inactiveOffsetX + w.size[0]);
                                if (right > max) max = right;
                            }
                        }
                        return max > 0 ? max : mw;
                    }
                    property real contentMinY: {
                        if (windows.length === 0) return 0;
                        let min = mh;
                        for (let i = 0; i < windows.length; i++) {
                            let w = windows[i].lastIpcObject;
                            if (w && w.at && w.size) {
                                let top = Math.max(0, w.at[1] - my - inactiveOffsetY);
                                if (top < min) min = top;
                            }
                        }
                        return min === mh ? 0 : min;
                    }
                    property real contentMaxY: {
                        if (windows.length === 0) return mh;
                        let max = 0;
                        for (let i = 0; i < windows.length; i++) {
                            let w = windows[i].lastIpcObject;
                            if (w && w.at && w.size) {
                                let bottom = Math.min(mh, w.at[1] - my - inactiveOffsetY + w.size[1]);
                                if (bottom > max) max = bottom;
                            }
                        }
                        return max > 0 ? max : mh;
                    }
                    
                    property real targetMw: {
                        if (windows.length === 0) return mw;
                        let w = contentMaxX - contentMinX;
                        if (w > mw * 0.8 && w < mw) return w;
                        return mw;
                    }
                    property real targetMh: {
                        if (windows.length === 0) return mh;
                        let h = contentMaxY - contentMinY;
                        if (h > mh * 0.8 && h < mh) return h;
                        return mh;
                    }
                    property real targetMinX: targetMw < mw ? contentMinX : 0
                    property real targetMinY: targetMh < mh ? contentMinY : 0

                    property real effectiveMw: targetMw
                    property real effectiveMh: targetMh
                    property real effectiveMinX: targetMinX
                    property real effectiveMinY: targetMinY

                    Behavior on effectiveMw { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on effectiveMh { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on effectiveMinX { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on effectiveMinY { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                    width: ListView.view.width
                    implicitHeight: width * (effectiveMh / effectiveMw)

                    Item {
                        id: bgContainer
                        anchors.fill: parent
                        clip: true

                        layer.enabled: true
                        layer.effect: Mask {
                            maskSource: maskItem
                        }

                        Image {
                            id: wallpaperImage
                            width: (wsDelegate.mw / wsDelegate.effectiveMw) * parent.width
                            height: (wsDelegate.mh / wsDelegate.effectiveMh) * parent.height
                            x: -(wsDelegate.effectiveMinX / wsDelegate.effectiveMw) * parent.width
                            y: -(wsDelegate.effectiveMinY / wsDelegate.effectiveMh) * parent.height
                            source: Wallpapers.current ? (Wallpapers.getThumbnailPath(Wallpapers.current) || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true

                            StyledRect {
                                anchors.fill: parent
                                color: Colours.palette.m3surfaceContainer
                                opacity: isActive ? 0.3 : 0.6
                            }
                        }
                    }

                    Item {
                        id: maskItem
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: Tokens.rounding.large
                            color: "black"
                        }
                    }

                    StyledRect {
                        anchors.fill: parent
                        color: "transparent"
                        radius: Tokens.rounding.large
                        border.width: isActive ? 2 : 0
                        border.color: isActive ? Colours.palette.m3primary : "transparent"
                        
                        Behavior on border.color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
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
                            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = "${workspaceId}" })` : `workspace ${workspaceId}`);
                            screenState.workspaceDrawer = false;
                        }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: Tokens.spacing.small
                        // Do not clip here so the drag target can float out

                        Repeater {
                            id: windowRepeater
                            model: wsDelegate.windows
                            delegate: Item {
                                id: windowContainer
                                required property var modelData
                                
                                property var ipc: modelData.lastIpcObject
                                
                                property real rawLogicalX: ipc && ipc.at ? (ipc.at[0] - wsDelegate.mx - wsDelegate.inactiveOffsetX) : 0
                                property real rawLogicalY: ipc && ipc.at ? (ipc.at[1] - wsDelegate.my - wsDelegate.inactiveOffsetY) : 0
                                property real rawLogicalW: ipc && ipc.size ? ipc.size[0] : 0
                                property real rawLogicalH: ipc && ipc.size ? ipc.size[1] : 0
                                
                                property bool isDragging: dragArea.drag.active
                                onIsDraggingChanged: {
                                    if (isDragging) wsDelegate.activeDrags++;
                                    else wsDelegate.activeDrags--;
                                }
                                z: dragArea.drag.active ? 100 : 0

                                Behavior on rawLogicalX { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                Behavior on rawLogicalY { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                Behavior on rawLogicalW { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                Behavior on rawLogicalH { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                
                                x: ((rawLogicalX - wsDelegate.effectiveMinX) / wsDelegate.effectiveMw * parent.width)
                                y: ((rawLogicalY - wsDelegate.effectiveMinY) / wsDelegate.effectiveMh * parent.height)
                                width: (rawLogicalW / wsDelegate.effectiveMw * parent.width)
                                height: (rawLogicalH / wsDelegate.effectiveMh * parent.height)

                                Item {
                                    id: windowVisualProxy
                                    width: parent.width
                                    height: parent.height
                                    
                                    opacity: dragArea.drag.active ? 0.8 : 1
                                    scale: dragArea.drag.active ? 1.05 : 1
                                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    
                                    Drag.active: dragArea.drag.active
                                    Drag.keys: ["window"]
                                    Drag.hotSpot.x: width / 2
                                    Drag.hotSpot.y: height / 2
                                    Drag.source: windowContainer.modelData

                                    StyledRect {
                                        id: windowBg
                                        anchors.fill: parent
                                        color: Colours.palette.m3surfaceContainer
                                        radius: Tokens.rounding.medium
                                    }

                                    Rectangle {
                                        id: windowMask
                                        anchors.fill: parent
                                        radius: Tokens.rounding.medium
                                        layer.enabled: true
                                        visible: false
                                    }

                                    Item {
                                        anchors.fill: parent
                                        layer.enabled: true
                                        layer.effect: Mask {
                                            maskSource: windowMask
                                        }

                                        Item {
                                            anchors.fill: parent
                                            clip: true

                                            StyledRect {
                                                anchors.fill: parent
                                                color: Colours.palette.m3surfaceContainer
                                                opacity: isActive ? 0.3 : 0.6
                                            }
                                        }

                                        ScreencopyView {
                                            anchors.fill: parent
                                            captureSource: windowContainer.modelData.wayland ?? null
                                            live: windowBg.visible
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 32
                                            height: 32
                                            radius: Tokens.rounding.medium
                                            color: Colours.tPalette.m3surface
                                        }

                                        IconImage {
                                            anchors.centerIn: parent
                                            source: Icons.getAppIcon(windowContainer.modelData.lastIpcObject.class ?? "", "image-missing")
                                            width: 64
                                            height: 64
                                            scale: 20 / 64
                                            asynchronous: true
                                        }
                                    }

                                    StyledRect {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.width: 2
                                        border.color: dragArea.containsMouse ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                                        radius: Tokens.rounding.medium
                                        
                                        Behavior on border.color { ColorAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    }
                                }

                                MouseArea {
                                    id: dragArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    drag.target: windowVisualProxy
                                    drag.axis: Drag.XAndYAxis
                                    cursorShape: Qt.PointingHandCursor
                                    
                                    property bool wasDragged: false
                                    property real pressX: 0
                                    property real pressY: 0

                                    onPressed: (mouse) => {
                                        wasDragged = false;
                                        pressX = mouse.x;
                                        pressY = mouse.y;
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (Math.abs(mouse.x - pressX) > 5 || Math.abs(mouse.y - pressY) > 5) {
                                            wasDragged = true;
                                        }
                                    }

                                    onReleased: (mouse) => {
                                        if (wasDragged) {
                                            windowVisualProxy.Drag.drop();
                                            windowVisualProxy.x = 0;
                                            windowVisualProxy.y = 0;
                                        } else {
                                            Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${windowContainer.modelData.address}" })` : `focuswindow address:0x${windowContainer.modelData.address}`);
                                            screenState.workspaceDrawer = false;
                                        }
                                        wasDragged = false;
                                    }

                                    onClicked: mouse => {
                                        mouse.accepted = true;
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        id: wsIdText
                        visible: windowRepeater.count === 0
                        text: workspaceId.toString()
                        font: Tokens.font.title.large
                        color: isActive ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.rightMargin: Tokens.spacing.medium
                        anchors.bottomMargin: 0
                    }
                }
            }
        }
    }
}
