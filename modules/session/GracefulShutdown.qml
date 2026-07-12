pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Services
import QtQuick.Effects
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import M3Shapes

StyledWindow {
    id: root

    name: "gracefulShutdown"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    
    // We bind visibility to whether a command is currently pending
    property list<string> pendingCommand
    property bool isActive: pendingCommand.length > 0
    
    visible: isActive || closeAnim.running

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    readonly property var activeApps: {
        let apps = [];
        if (Hypr.toplevels && Hypr.toplevels.values) {
            for (let i = 0; i < Hypr.toplevels.values.length; ++i) {
                let t = Hypr.toplevels.values[i];
                let cls = (t.lastIpcObject?.class || t.lastIpcObject?.initialClass || "").toLowerCase();
                let title = (t.title || "").toLowerCase();
                if (t.pid === Config.session.pid || cls.includes("quickshell") || cls.includes("caelestia") || cls.startsWith("org.hyprland") ||
                    title.includes("quickshell") || title.includes("caelestia") || title.includes("antigravity"))
                    continue;
                apps.push(t);
            }
        }
        return apps;
    }
    
    onActiveAppsChanged: {
        if (Config.session.gracefulShutdownDry !== true && isActive && activeApps.length === 0) {
            executeAndClose();
        }
    }
    
    function startSequence(command) {
        pendingCommand = command;
        
        let sentAny = false;
        if (Hypr.toplevels && Hypr.toplevels.values) {
            for (let i = 0; i < Hypr.toplevels.values.length; ++i) {
                let t = Hypr.toplevels.values[i];
                let cls = (t.initialClass || t["class"] || "").toLowerCase();
                let title = (t.initialTitle || t.title || "").toLowerCase();
                if (t.pid === Config.session.pid || cls.includes("quickshell") || cls.includes("caelestia") || cls.startsWith("org.hyprland") ||
                    title.includes("quickshell") || title.includes("caelestia") || title.includes("antigravity"))
                    continue;
                    
                if (Config.session.gracefulShutdownDry !== true) {
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${t.address}" })` : `closewindow address:0x${t.address}`);
                }
                sentAny = true;
            }
        }
        
        if (Config.session.gracefulShutdownDry !== true && (!sentAny || activeApps.length === 0)) {
            executeAndClose();
        }
    }
    
    function executeAndClose() {
        if (pendingCommand.length > 0) {
            // Check if this is the logout command
            let isLogout = true;
            if (pendingCommand.length === Config.session.commands.logout.length) {
                for (let i = 0; i < pendingCommand.length; i++) {
                    if (pendingCommand[i] !== Config.session.commands.logout[i]) {
                        isLogout = false;
                        break;
                    }
                }
            } else {
                isLogout = false;
            }

            if (Config.session.gracefulShutdownDry !== true) {
                if (isLogout) {
                    Hypr.dispatch(Hypr.usingLua ? "hl.dsp.exit()" : "exit");
                } else {
                    if (!SessionManager.exec(pendingCommand))
                        Quickshell.execDetached(pendingCommand);
                }
            }
        }
        close();
    }
    
    function close() {
        pendingCommand = [];
    }
    
    onIsActiveChanged: {
        if (isActive) {
            closeAnim.stop()
            openAnim.start()
        } else {
            openAnim.stop()
            closeAnim.start()
        }
    }
    
    ParallelAnimation {
        id: openAnim
        SequentialAnimation {
            ParallelAnimation {
                Anim { target: dialogContainer; property: "opacity"; to: 1; duration: Tokens.anim.durations.small }
                Anim { target: dialogContainer; property: "scale"; to: 1; type: Anim.Emphasized; duration: 400 }
            }
        }
    }
    
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            Anim { target: dialogContainer; property: "scale"; to: 0; type: Anim.Emphasized; duration: 400 }
            Anim { target: dialogContainer; property: "opacity"; to: 0; type: Anim.Standard; duration: Tokens.anim.durations.small }
        }
    }
    
    MouseArea {
        anchors.fill: parent
    }

    StyledRect {
        id: fullBg
        anchors.fill: parent
        color: Colours.palette.m3surface
        opacity: dialogContainer.opacity
    }

    Item {
        id: dialogContainer
        
        width: 700
        height: dialogContent.implicitHeight + Tokens.padding.large * 2
        anchors.centerIn: parent
        scale: 0
        opacity: 0

        StyledRect {
            id: dialogBg
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.layer(Colours.palette.m3surface, 0)
            
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.palette.m3shadow, 0.7)
            }
        }
        
        ColumnLayout {
            id: dialogContent
            width: parent.width - Tokens.padding.large * 2
            anchors.centerIn: parent
            spacing: Tokens.spacing.large
            
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: titleLayout.implicitHeight + Tokens.padding.large * 2
                color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                radius: Tokens.rounding.large
                
                ColumnLayout {
                    id: titleLayout
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: Config.session.gracefulShutdownDry ? qsTr("Dry Run: Apps to close") : qsTr("Logging out...")
                        font: Tokens.font.title.builders.large.weight(Font.Medium).build()
                        color: Colours.palette.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    StyledText {
                        Layout.fillWidth: true
                        text: Config.session.gracefulShutdownDry ? qsTr("Dry mode is enabled. These apps would be closed, but no action will be taken.") : qsTr("Waiting for your apps to exit. You can force quit if necessary, but unsaved progress may be lost.")
                        font: Tokens.font.body.medium
                        color: Colours.palette.m3onSurfaceVariant
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(500, listLayout.implicitHeight + Tokens.padding.large * 2)
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                radius: Tokens.rounding.medium
                clip: true
                
                ScrollView {
                    anchors.fill: parent
                    contentWidth: availableWidth
                    
                    ColumnLayout {
                        id: listLayout
                        width: parent.width
                        spacing: Tokens.spacing.extraSmall
                        
                        Repeater {
                            model: root.activeApps
                            
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: appContent.implicitHeight + Tokens.padding.medium * 2
                                
                                ColumnLayout {
                                    id: appContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: Tokens.padding.medium
                                    spacing: Tokens.spacing.extraSmall
                                    
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: (modelData.lastIpcObject?.class || modelData.lastIpcObject?.initialClass) ? (modelData.lastIpcObject.class || modelData.lastIpcObject.initialClass) : "Unknown App"
                                        font: Tokens.font.body.large
                                        color: Colours.palette.m3onSurface
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignLeft
                                    }
                                    
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.title || ""
                                        font: Tokens.font.body.medium
                                        color: Colours.palette.m3onSurfaceVariant
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignLeft
                                        visible: modelData.title !== undefined && modelData.title !== "" && modelData.title !== (modelData.lastIpcObject?.class || modelData.lastIpcObject?.initialClass)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium
                
                Item { Layout.fillWidth: true }
                
                TextButton {
                    text: qsTr("Cancel")
                    type: TextButton.Text
                    onClicked: root.close()
                }
                
                TextButton {
                    text: Config.session.gracefulShutdownDry ? qsTr("Close") : qsTr("Force quit")
                    type: TextButton.Filled
                    onClicked: root.executeAndClose()
                }
            }
        }
    }
}
