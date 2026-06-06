pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar

StyledWindow {
    id: root

    Config.screen: screen.name

    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool hasSpecialWorkspace: (monitor?.lastIpcObject.specialWorkspace?.name.length ?? 0) > 0
    readonly property bool hasFullscreen: {
        if (hasSpecialWorkspace) {
            const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
            if (!specialName)
                return false;
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
    }

    property real fsTransitionProg: hasFullscreen ? 1 : 0
    readonly property real sdfBorderOffset: 2 * fsTransitionProg // SDFs joins are not exact, so offset by 2px to ensure nothing shows
    readonly property real borderThickness: contentItem.Config.border.thickness * (1 - fsTransitionProg)
    readonly property real borderRounding: contentItem.Config.border.rounding * (1 - fsTransitionProg)
    readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : contentItem.Config.border.thickness

    readonly property int dragMaskPadding: {
        if (focusGrab.active || panels.popouts.isDetached)
            return 0;

        if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace.lastIpcObject.windows > 0)
            return 0;

        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (contentItem.Config[panel].enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold);
        return Math.max(...thresholds);
    }

    onHasFullscreenChanged: {
        visibilities.launcher = false;
        visibilities.session = false;
        visibilities.dashboard = false;
        panels.popouts.close();
    }

    name: "drawers"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: fsTransitionProg > 0 && contentItem.Config.general.showOverFullscreen ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session || panels.dashboard.needsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: hasFullscreen ? emptyRegion : regions

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on fsTransitionProg {
        Anim {}
    }

    Region {
        id: emptyRegion

        x: panels.notifications.x + panels.leftMargin
        y: panels.notifications.y + panels.topMargin
        width: panels.notifications.width
        height: panels.notifications.height

        Region {
            x: root.width - width
            y: panels.osdWrapper.y + panels.topMargin
            width: panels.osdWrapper.width * (1 - panels.osd.offsetScale) + panels.topMargin
            height: panels.osd.height
        }
    }

    Regions {
        id: regions

        bar: bar
        panels: panels
        win: root
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: (visibilities.launcher && root.contentItem.Config.launcher.enabled) || (visibilities.session && root.contentItem.Config.session.enabled) || (visibilities.sidebar && root.contentItem.Config.sidebar.enabled) || (!root.contentItem.Config.dashboard.showOnHover && visibilities.dashboard && root.contentItem.Config.dashboard.enabled) || (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1)
        windows: [root]
        onCleared: {
            visibilities.launcher = false;
            visibilities.session = false;
            visibilities.sidebar = false;
            visibilities.dashboard = false;
            panels.popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: visibilities.session && Config.session.enabled ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {}
        }
    }

    Item {
        id: layoutContainer
        Config.screen: root.screen.name
        anchors.fill: parent
        opacity: GlobalConfig.appearance.pitchBlack ? 1 : (Colours.transparency.enabled ? Colours.transparency.base : 1)

        readonly property bool sidebarShouldFlatCorner: panels.popouts.hasCurrent && (panels.popouts.currentName !== "dockhover" && panels.popouts.currentName !== "dockcontext" && panels.popouts.currentName !== "activewindow")
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        BlobGroup {
            id: blobGroup

            color: GlobalConfig.appearance.pitchBlack ? "#000000" : Colours.palette.m3surface
            smoothing: root.contentItem.Config.border.smoothing

            Behavior on color {
                CAnim {}
            }
        }

        BlobInvertedRect {
            Config.screen: root.screen.name
            anchors.fill: parent
            anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
            group: blobGroup
            radius: root.borderRounding
            borderLeft: (Config.bar.position === "left" ? bar.implicitWidth : root.borderThickness) - anchors.margins - root.sdfBorderOffset
            borderRight: (Config.bar.position === "right" ? bar.implicitWidth : root.borderThickness) - anchors.margins - root.sdfBorderOffset
            borderTop: (Config.bar.position === "top" ? bar.implicitHeight : root.borderThickness) - anchors.margins - root.sdfBorderOffset
            borderBottom: (Config.bar.position === "bottom" ? bar.implicitHeight : root.borderThickness) - anchors.margins - root.sdfBorderOffset
        }

        PanelBg {
            id: dashBg

            panel: panels.dashboard
            deformAmount: 0.1
        }

        PanelBg {
            id: launcherBg

            panel: panels.launcher
            deformAmount: 0.1
        }

        PanelBg {
            id: sessionBg

            panel: panels.sessionWrapper
            deformAmount: 0.2
            x: panels.sessionWrapper.x + panels.session.x + panels.leftMargin
            implicitWidth: panels.session.width
        }

        PanelBg {
            id: sidebarBg

            panel: panels.sidebar
            deformAmount: 0.03
            implicitHeight: panel.height * (1 / rawDeformMatrix.m22) + 2
            readonly property real offsetScale: panels.sidebar.offsetScale
            readonly property bool sidebarShouldFlat: layoutContainer.sidebarShouldFlatCorner || (offsetScale <= 0.08 && (Config.bar.position === "bottom" || Config.bar.position === "top"))
            exclude: {
                const list = [];
                if (offsetScale <= 0.08) {
                    list.push(utilsBg);
                    if (layoutContainer.sidebarShouldFlatCorner && (Config.bar.position === "bottom" || Config.bar.position === "top")) {
                        list.push(popoutBg);
                    }
                }
                return list;
            }
            topLeftRadius: {
                if (Config.bar.position === "bottom") {
                    return (sidebarShouldFlat || offsetScale > 0.3) ? radius : Math.max(0, Math.min(1, offsetScale / 0.3)) * radius;
                } else if (Config.bar.position === "top") {
                    return (layoutContainer.sidebarShouldFlatCorner ? 0 : radius);
                } else {
                    return radius;
                }
            }
            topRightRadius: {
                if (Config.bar.position === "bottom") {
                    return (sidebarShouldFlat || offsetScale > 0.3) ? radius : Math.max(0, Math.min(1, offsetScale / 0.3)) * radius;
                } else if (Config.bar.position === "top") {
                    return (layoutContainer.sidebarShouldFlatCorner ? 0 : radius);
                } else {
                    return radius;
                }
            }
            bottomLeftRadius: Config.bar.position === "bottom"
                ? (layoutContainer.sidebarShouldFlatCorner ? 0 : radius)
                : (sidebarShouldFlat || offsetScale > 0.3) ? radius : Math.max(0, Math.min(1, offsetScale / 0.3)) * radius
            bottomRightRadius: Config.bar.position === "bottom"
                ? (layoutContainer.sidebarShouldFlatCorner ? 0 : radius)
                : (sidebarShouldFlat || offsetScale > 0.3) ? radius : Math.max(0, Math.min(1, offsetScale / 0.3)) * radius
        }

        PanelBg {
            id: osdBg

            panel: panels.osdWrapper
            deformAmount: 0.25
            x: panels.osdWrapper.x + panels.osd.x + panels.leftMargin
            implicitWidth: panels.osd.width
        }

        PanelBg {
            id: notifsBg

            panel: panels.notifications
        }

        PanelBg {
            id: utilsBg

            panel: panels.utilities
            deformAmount: panels.sidebar.visible ? 0.1 : 0.15
            exclude: panels.sidebar.offsetScale > 0.08 ? [] : [sidebarBg]
            topLeftRadius: Config.bar.position === "bottom" ? radius : (Config.bar.position === "right" ? radius : Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius)
            topRightRadius: Config.bar.position === "bottom" ? radius : (Config.bar.position === "right" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius)
            bottomLeftRadius: Config.bar.position === "bottom" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius
            bottomRightRadius: Config.bar.position === "bottom" ? Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * radius : radius
        }

        PanelBg {
            id: popoutBg

            // Extra width/height to prevent dynamic movement deformation partially detaching panel from bar
            property real extraShift: panels.popouts.isDetached ? 0 : 0.2

            panel: panels.popoutsWrapper
            deformAmount: panels.popouts.isDetached ? 0.05 : panels.popouts.hasCurrent ? 0.15 : 0.1
            exclude: (panels.sidebar.offsetScale <= 0.08 && (Config.bar.position === "bottom" || Config.bar.position === "top")) ? [sidebarBg] : []
            topLeftRadius: (Config.bar.position === "bottom" && panels.sidebar.offsetScale <= 0.08) ? 0 : radius
            topRightRadius: (Config.bar.position === "bottom" && panels.sidebar.offsetScale <= 0.08) ? 0 : radius
            bottomLeftRadius: (Config.bar.position === "top" && panels.sidebar.offsetScale <= 0.08) ? 0 : radius
            bottomRightRadius: (Config.bar.position === "top" && panels.sidebar.offsetScale <= 0.08) ? 0 : radius
            x: {
                const baseX = panels.popoutsWrapper.x + panels.popouts.x + panels.leftMargin;
                if (bar.position === "left")
                    return baseX - panels.popouts.implicitWidth * extraShift;
                return baseX;
            }
            implicitWidth: {
                if (bar.position === "left" || bar.position === "right")
                    return panels.popouts.implicitWidth * (1 + extraShift);
                return panels.popouts.implicitWidth;
            }
            y: {
                const baseY = panels.popoutsWrapper.y + panels.popouts.y + panels.topMargin;
                if (bar.position === "top")
                    return baseY - panels.popouts.implicitHeight * extraShift;
                return baseY;
            }
            implicitHeight: {
                if (bar.position === "top" || bar.position === "bottom")
                    return panels.popouts.implicitHeight * (1 + extraShift);
                return panels.popouts.implicitHeight;
            }

            Behavior on extraShift {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
        }
    }

    DrawerVisibilities {
        id: visibilities

        Component.onCompleted: Visibilities.load(root.screen, this)
    }

    Interactions {
        id: interactions

        screen: root.screen
        popouts: panels.popouts
        visibilities: visibilities
        panels: panels
        bar: bar
        borderThickness: root.borderLayoutThickness
        fullscreen: root.hasFullscreen

        Panels {
            id: panels

            screen: root.screen
            visibilities: visibilities
            bar: bar
            borderThickness: root.borderThickness

            utilities.horizontalStretch: (sidebarBg.rawDeformMatrix.m11 - 1) / 2 + 1
            utilities.deformMatrix: utilsBg.rawDeformMatrix

            dashboard.transform: Matrix4x4 {
                matrix: dashBg.deformMatrix
            }
            launcher.transform: Matrix4x4 {
                matrix: launcherBg.deformMatrix
            }
            session.transform: Matrix4x4 {
                matrix: sessionBg.deformMatrix
            }
            sidebar.transform: Matrix4x4 {
                matrix: sidebarBg.deformMatrix
            }
            osd.transform: Matrix4x4 {
                matrix: osdBg.deformMatrix
            }
            notifications.transform: Matrix4x4 {
                matrix: notifsBg.deformMatrix
            }
            utilities.transform: Matrix4x4 {
                matrix: utilsBg.deformMatrix
            }
            popouts.transform: Matrix4x4 {
                matrix: popoutBg.deformMatrix
            }
        }

        BarWrapper {
            id: bar

            screen: root.screen
            visibilities: visibilities
            popouts: panels.popouts

            fullscreen: root.hasFullscreen

            Component.onCompleted: Visibilities.registerBar(root.screen, this)
        }

        states: [
            State {
                name: "left"
                Config.screen: root.screen.name
                when: Config.bar.position === "left"
                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: bar.implicitWidth
                    height: undefined
                }
            },
            State {
                name: "right"
                Config.screen: root.screen.name
                when: Config.bar.position === "right"
                AnchorChanges {
                    target: bar
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: bar.implicitWidth
                    height: undefined
                }
            },
            State {
                name: "top"
                Config.screen: root.screen.name
                when: Config.bar.position === "top"
                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: undefined
                }
                PropertyChanges {
                    target: bar
                    width: undefined
                    height: bar.implicitHeight
                }
            },
            State {
                name: "bottom"
                Config.screen: root.screen.name
                when: Config.bar.position === "bottom"
                AnchorChanges {
                    target: bar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                }
                PropertyChanges {
                    target: bar
                    width: undefined
                    height: bar.implicitHeight
                }
            }
        ]
    }

    component PanelBg: BlobRect {
        required property Item panel
        property real deformAmount: 0.15
        Config.screen: root.screen.name

        group: blobGroup
        x: panel.x + panels.leftMargin
        y: panel.y + panels.topMargin
        implicitWidth: panel.width
        implicitHeight: panel.height
        radius: Tokens.rounding.large
        deformScale: (deformAmount * Config.appearance.deformScale) / 10000
        opacity: panel.opacity
    }
}
