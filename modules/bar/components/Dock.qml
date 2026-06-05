pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    property int modelUpdateTrigger: 0

    readonly property int padding: Tokens.padding.normal
    readonly property int spacing: Tokens.spacing.small

    anchors.fill: parent

    StyledRect {
        id: container

        color: root.modelDataArray.length > 0 ? Colours.tPalette.m3surfaceContainer : "transparent"
        radius: Tokens.rounding.full

        implicitWidth: bar.isHorizontal ? layout.implicitWidth + padding * 2 : Tokens.sizes.bar.innerWidth
        implicitHeight: bar.isHorizontal ? Tokens.sizes.bar.innerWidth : layout.implicitHeight + padding * 2

        x: bar.width / 2 - width / 2 - (root.parent ? root.parent.x : 0)
        y: bar.height / 2 - height / 2 - (root.parent ? root.parent.y : 0)

        property var _appsValues: DesktopEntries.applications.values
        on_AppsValuesChanged: root.rebuildModel()
        
        Behavior on implicitWidth {
            enabled: bar.isHorizontal
            Anim { type: Anim.DefaultSpatial }
        }
        Behavior on implicitHeight {
            enabled: !bar.isHorizontal
            Anim { type: Anim.DefaultSpatial }
        }

        Item {
            id: layout
            
            anchors.centerIn: parent
            implicitWidth: bar.isHorizontal ? rowLayout.implicitWidth : colLayout.implicitWidth
            implicitHeight: bar.isHorizontal ? rowLayout.implicitHeight : colLayout.implicitHeight

            Row {
                id: rowLayout
                visible: bar.isHorizontal
                anchors.centerIn: parent
                spacing: root.spacing

                Repeater {
                    id: repeaterHoriz
                    model: bar.isHorizontal ? root.modelDataArray : null
                    delegate: dockDelegate
                }
            }

            Column {
                id: colLayout
                visible: !bar.isHorizontal
                anchors.centerIn: parent
                spacing: root.spacing

                Repeater {
                    id: repeaterVert
                    model: !bar.isHorizontal ? root.modelDataArray : null
                    delegate: dockDelegate
                }
            }
        }

        Component {
            id: dockDelegate

            Item {
                id: delegateItem
                    width: Tokens.sizes.bar.innerWidth * 0.8
                    height: Tokens.sizes.bar.innerWidth * 0.8
                    implicitWidth: width
                    implicitHeight: height

                    required property var modelData

                    property bool isActive: {
                        const activeTop = Hyprland.activeToplevel;
                        if (!activeTop) return false;
                        
                        if (activeTop.lastIpcObject && delegateItem.modelData.appClass) {
                            const activeClass = (activeTop.lastIpcObject.class || activeTop.lastIpcObject.initialClass || "").toLowerCase();
                            const appId = delegateItem.modelData.appClass.toLowerCase();
                            if (activeClass && (activeClass === appId || activeClass.includes(appId) || appId.includes(activeClass))) {
                                return true;
                            }
                        }
                        
                        for (const top of delegateItem.modelData.toplevels) {
                            if (top.address && top.address === activeTop.address) return true;
                        }
                        return false;
                    }

                    property bool hasWindows: {
                        const dummy = root.modelUpdateTrigger;
                        return delegateItem.modelData.toplevels.length > 0;
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.normal
                        
                        color: delegateItem.isActive ? Colours.palette.m3onSurface : "transparent"
                        opacity: delegateItem.isActive ? 0.1 : 0
                        
                        acceptedButtons: Qt.LeftButton | Qt.RightButton

                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                if (modelData.toplevels.length > 0) {
                                    Hypr.dispatch(`focuswindow address:${modelData.toplevels[0].address}`);
                                } else if (modelData.entry) {
                                    if (modelData.entry.runInTerminal) {
                                        Quickshell.execDetached({
                                            command: ["app2unit", "--", ...GlobalConfig.general.apps.terminal, `${Quickshell.shellDir}/assets/wrap_term_launch.sh`, ...modelData.entry.command],
                                            workingDirectory: modelData.entry.workingDirectory
                                        });
                                    } else {
                                        Quickshell.execDetached({
                                            command: ["app2unit", "--", ...modelData.entry.command],
                                            workingDirectory: modelData.entry.workingDirectory
                                        });
                                    }
                                }
                            } else if (mouse.button === Qt.RightButton) {
                                bar.popouts.currentName = "dockcontext";
                                bar.popouts.currentCenter = bar.isHorizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                                bar.popouts.dockModel = modelData;
                                bar.popouts.hasCurrent = true;
                            }
                        }
                        
                        onEntered: {
                            if (bar.popouts.hasCurrent && bar.popouts.currentName === "dockcontext") return;
                            bar.popouts.currentName = "dockhover";
                            bar.popouts.currentCenter = bar.isHorizontal ? delegateItem.mapToItem(null, delegateItem.width / 2, 0).x : (delegateItem.mapToItem(null, 0, delegateItem.height / 2).y ?? 0);
                            bar.popouts.dockModel = modelData;
                            bar.popouts.hasCurrent = true;
                        }
                    }

                    IconImage {
                        id: icon
                        anchors.centerIn: parent
                        implicitSize: Math.round(((delegateItem.width || 0) * 0.7) / 2) * 2 || 0
                        source: Icons.getAppIcon(modelData.iconName, "image-missing")
                        asynchronous: true
                    }

                    Row {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 0
                        spacing: 2
                        visible: delegateItem.hasWindows
                        
                        Repeater {
                            model: {
                                const dummy = root.modelUpdateTrigger;
                                return Math.min(2, delegateItem.modelData.toplevels.length);
                            }
                            
                            delegate: Rectangle {
                                required property int index
                                width: (index === 0 && delegateItem.isActive) ? 16 : 2
    
                                height: 2
    
                                radius: 1
    
                                color: delegateItem.isActive ? Colours.palette.m3primary : Colours.palette.m3onSurface
    
                                Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 250 } }
                            }
                        }
                    }
                }
            }
        }

    function handleHover(relPos: real, isHorizontal: bool): void {
        // Don't close dock context menu
        if (bar.popouts.hasCurrent && bar.popouts.currentName === "dockcontext") return;

        const itemSize = Tokens.sizes.bar.innerWidth * 0.8;
        const itemWidthWithSpacing = itemSize + spacing;
        const adjustedPos = isHorizontal ? relPos - container.x - padding : relPos - container.y - padding;
        
        // Only close if cursor is completely outside dock bounds
        if (adjustedPos < 0 || adjustedPos >= modelDataArray.length * itemWidthWithSpacing) {
            bar.popouts.hasCurrent = false;
            return;
        }
        
        const index = Math.floor(adjustedPos / itemWidthWithSpacing);
        const activeRepeater = isHorizontal ? repeaterHoriz : repeaterVert;
        const item = activeRepeater.itemAt(index);
        
        if (item) {
            bar.popouts.currentName = "dockhover";
            bar.popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
            bar.popouts.dockModel = modelDataArray[index];
            bar.popouts.hasCurrent = true;
        }
    }

    property var modelDataArray: []

    function rebuildModel(): void {
        const apps = [];

        const pinnedIds = GlobalConfig.launcher.favouriteApps || [];
        
        for (const entry of DesktopEntries.applications.values) {
            if (Strings.testRegexList(pinnedIds, entry.id)) {
                apps.push({
                    id: entry.id,
                    isPinned: true,
                    entry: entry,
                    toplevels: [],
                    appClass: entry.id.replace(".desktop", ""),
                    iconName: entry.id
                });
            }
        }
        
        for (const toplevel of Hyprland.toplevels.values) {
            const ipc = toplevel.lastIpcObject;
            if (!ipc) continue;
            const appClass = ipc.class || ipc.initialClass;
            if (!appClass) continue;
            
            let found = false;
            for (const app of apps) {
                if (app.appClass.toLowerCase() === appClass.toLowerCase() || 
                    app.id.toLowerCase().includes(appClass.toLowerCase()) || 
                    appClass.toLowerCase().includes(app.id.toLowerCase().replace(".desktop", ""))) {
                    app.toplevels.push(toplevel);
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                const entry = DesktopEntries.applications.values.find(e => e.id.toLowerCase().includes(appClass.toLowerCase()) || appClass.toLowerCase().includes(e.id.toLowerCase().replace(".desktop", ""))) || null;
                apps.push({
                    id: appClass,
                    isPinned: false,
                    entry: entry,
                    toplevels: [toplevel],
                    appClass: appClass,
                    iconName: entry ? entry.id : appClass
                });
            }
        }
        
        let changed = apps.length !== root.modelDataArray.length;
        if (!changed) {
            for (let i = 0; i < apps.length; i++) {
                if (apps[i].id !== root.modelDataArray[i].id || apps[i].toplevels.length !== root.modelDataArray[i].toplevels.length) {
                    changed = true;
                    break;
                }
                for (let j = 0; j < apps[i].toplevels.length; j++) {
                    if (apps[i].toplevels[j].address !== root.modelDataArray[i].toplevels[j].address) {
                        changed = true;
                        break;
                    }
                }
                if (changed) break;
            }
        }
        
        if (changed) {
            root.modelDataArray = apps;
            repeaterHoriz.model = null;
            repeaterVert.model = null;
            repeaterHoriz.model = bar.isHorizontal ? apps : null;
            repeaterVert.model = !bar.isHorizontal ? apps : null;
        }
        
        root.modelUpdateTrigger += 1;
    }

    property var _toplevels: Hyprland.toplevels.values
    on_ToplevelsChanged: {
        root.rebuildModel()
        delayedRebuildTimer.restart()
    }
    
    Timer {
        id: delayedRebuildTimer
        interval: 100
        repeat: false
        onTriggered: root.rebuildModel()
    }
    
    property var activeTop: Hyprland.activeToplevel
    onActiveTopChanged: {
        root.rebuildModel()
        delayedRebuildTimer.restart()
    }

    Connections {
        target: GlobalConfig.launcher
        function onFavouriteAppsChanged(): void {
            root.rebuildModel();
        }
    }

    Component.onCompleted: root.rebuildModel()
}