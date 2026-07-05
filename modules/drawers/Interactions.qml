import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts

CustomMouseArea {
    id: root

    required property ShellScreen screen
    Config.screen: screen.name
    required property BarPopouts.Wrapper popouts
    required property ScreenState screenState
    required property Panels panels
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool osdShortcutActive
    property bool utilitiesShortcutActive

    readonly property bool isBarHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    function inBarArea(x: real, y: real): bool {
        if (Config.bar.position === "left")
            return x < bar.x + bar.implicitWidth;
        if (Config.bar.position === "right")
            return x > bar.x;
        if (Config.bar.position === "top")
            return y < bar.y + bar.implicitHeight;
        if (Config.bar.position === "bottom")
            return y > bar.y;
        return false;
    }

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = panels.topMargin + panel.y;
        const panelHeight = panel.content ? panel.content.nonAnimHeight : panel.height;
        return y >= panelY - Config.border.rounding && y <= panelY + panelHeight + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = panels.leftMargin + panel.x;
        const panelWidth = panel.content ? panel.content.nonAnimWidth : panel.width;
        return x >= panelX - Config.border.rounding && x <= panelX + panelWidth + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        const panelWidth = panel.content ? panel.content.nonAnimWidth : panel.width;
        const panelHeight = panel.content ? panel.content.nonAnimHeight : panel.height;

        if (Config.bar.position === "left")
            return x < panels.leftMargin + panel.x + panelWidth && withinPanelHeight(panel, x, y);
        if (Config.bar.position === "right")
            return x > screen.width - panels.rightMargin - panelWidth && withinPanelHeight(panel, x, y);
        if (Config.bar.position === "top")
            return y < panels.topMargin + panel.y + panelHeight && withinPanelWidth(panel, x, y);
        if (Config.bar.position === "bottom")
            return y > screen.height - panels.bottomMargin - panelHeight && withinPanelWidth(panel, x, y);
        return false;
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        if (Config.bar.position === "right")
            return x < Math.max(Config.border.minThickness, panels.leftMargin + panel.x + panel.width) && withinPanelHeight(panel, x, y);
        return x > Math.min(screen.width - Config.border.minThickness, panels.leftMargin + panel.x) && withinPanelHeight(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y < Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) && withinPanelWidth(panel, x, y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = panel.height * (1 - (panel.offsetScale ?? 0)); // qmllint disable missing-property
        return y > screen.height - Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) - (isCorner ? Config.border.rounding : 0) && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (fullscreen)
            return;
        if (inBarArea(event.x, event.y)) {
            bar.handleWheel(isBarHorizontal ? event.x : event.y, event.angleDelta);
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true

    onPressed: event => dragStart = Qt.point(event.x, event.y)
    onContainsMouseChanged: {
        if (!containsMouse) {
            // Only hide if not activated by shortcut
            if (!osdShortcutActive) {
                screenState.osd = false;
                root.panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive)
                screenState.dashboard = false;

            if (!utilitiesShortcutActive)
                screenState.utilities = false;

            if (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;

            if (Config.sidebar.showOnHover)
                screenState.sidebar = false;
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (fullscreen) {
            root.panels.osd.hovered = inRightPanel(panels.osdWrapper, x, y);
            return;
        }

        // Show bar in non-exclusive mode on hover
        if (!screenState.bar && Config.bar.showOnHover && inBarArea(x, y))
            bar.isHovered = true;

        // Show/hide bar on drag
        if (pressed && inBarArea(dragStart.x, dragStart.y)) {
            if (Config.bar.position === "left") {
                if (dragX > Config.bar.dragThreshold)
                    screenState.bar = true;
                else if (dragX < -Config.bar.dragThreshold)
                    screenState.bar = false;
            } else if (Config.bar.position === "right") {
                if (dragX < -Config.bar.dragThreshold)
                    screenState.bar = true;
                else if (dragX > Config.bar.dragThreshold)
                    screenState.bar = false;
            } else if (Config.bar.position === "top") {
                if (dragY > Config.bar.dragThreshold)
                    screenState.bar = true;
                else if (dragY < -Config.bar.dragThreshold)
                    screenState.bar = false;
            } else if (Config.bar.position === "bottom") {
                if (dragY < -Config.bar.dragThreshold)
                    screenState.bar = true;
                else if (dragY > Config.bar.dragThreshold)
                    screenState.bar = false;
            }
        }

        if (panels.sidebar.offsetScale === 1) {
            // Show osd on hover
            const showOsd = inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                screenState.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            const showSidebar = Config.bar.position === "right" ? pressed && dragStart.x < Math.max(Config.border.minThickness, panels.leftMargin + panels.sidebar.x + panels.sidebar.width) : pressed && dragStart.x > Math.min(screen.width - Config.border.minThickness, panels.leftMargin + panels.sidebar.x);

            // Show sidebar on hover (top-right corner, bounded by notification panel height)
            if (Config.sidebar.showOnHover) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifications.y + panels.notifications.height + borderThickness);
                const showSidebarHover = x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar)
                    screenState.sidebar = true;
            }

            // Show/hide session on drag
            if (pressed && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                const showThreshold = Config.bar.position === "right" ? Config.session.dragThreshold : -Config.session.dragThreshold;
                const hideThreshold = Config.bar.position === "right" ? -Config.session.dragThreshold : Config.session.dragThreshold;

                if (Config.bar.position === "right" ? dragX > showThreshold : dragX < showThreshold)
                    screenState.session = true;
                else if (Config.bar.position === "right" ? dragX < hideThreshold : dragX > hideThreshold)
                    screenState.session = false;

                // Show sidebar on drag if in session area and session is nearly fully visible
                const showSidebarThreshold = Config.bar.position === "right" ? Config.sidebar.dragThreshold : -Config.sidebar.dragThreshold;
                if (showSidebar && panels.session.offsetScale <= 0 && (Config.bar.position === "right" ? dragX > showSidebarThreshold : dragX < showSidebarThreshold))
                    screenState.sidebar = true;
            } else if (showSidebar && (Config.bar.position === "right" ? dragX > Config.sidebar.dragThreshold : dragX < -Config.sidebar.dragThreshold)) {
                // Show sidebar on drag if not in session area
                screenState.sidebar = true;
            }
        } else {
            const outOfSidebar = Config.bar.position === "right" ? x > panels.leftMargin + panels.sidebar.width * (1 - panels.sidebar.offsetScale) : x < screen.width - panels.sidebar.width * (1 - panels.sidebar.offsetScale);
            // Show osd on hover
            const showOsd = outOfSidebar && inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                screenState.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            // Show/hide session on drag
            if (pressed && outOfSidebar && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                const showThreshold = Config.bar.position === "right" ? Config.session.dragThreshold : -Config.session.dragThreshold;
                const hideThreshold = Config.bar.position === "right" ? -Config.session.dragThreshold : Config.session.dragThreshold;

                if (Config.bar.position === "right" ? dragX > showThreshold : dragX < showThreshold)
                    screenState.session = true;
                else if (Config.bar.position === "right" ? dragX < hideThreshold : dragX > hideThreshold)
                    screenState.session = false;
            }

            // Show/hide sidebar on hover
            if (Config.sidebar.showOnHover && !pressed) {
                const sidebarTriggerY = Math.max(Config.sidebar.minHoverThreshold, panels.notifications.y + panels.notifications.height + borderThickness);
                const showSidebarHover = x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x) && y <= sidebarTriggerY;
                if (showSidebarHover && !screenState.sidebar) {
                    screenState.sidebar = true;
                } else {
                    const inSidebarArea = inRightPanel(panels.sidebar, x, y) || inRightPanel(panels.sessionWrapper, x, y);
                    if (!inSidebarArea)
                        screenState.sidebar = false;
                }
            }

            // Hide sidebar on drag
            if (pressed && inRightPanel(panels.sidebar, dragStart.x, 0) && (Config.bar.position === "right" ? dragX < -Config.sidebar.dragThreshold : dragX > Config.sidebar.dragThreshold))
                screenState.sidebar = false;
        }

        // Show launcher on hover, or show/hide on drag if hover is disabled
        if (Config.launcher.showOnHover) {
            if (!screenState.launcher && inBottomPanel(panels.launcher, x, y))
                screenState.launcher = true;
        } else if (pressed && inBottomPanel(panels.launcher, dragStart.x, dragStart.y) && withinPanelWidth(panels.launcher, x, y)) {
            if (dragY < -Config.launcher.dragThreshold)
                screenState.launcher = true;
            else if (dragY > Config.launcher.dragThreshold)
                screenState.launcher = false;
        }

        // Show dashboard on hover
        const showDashboard = Config.dashboard.showOnHover && inTopPanel(panels.dashboard, x, y);

        // Always update visibility based on hover if not in shortcut mode
        if (!dashboardShortcutActive) {
            screenState.dashboard = showDashboard;
        } else if (showDashboard) {
            // If hovering over dashboard area while in shortcut mode, transition to hover control
            dashboardShortcutActive = false;
        }

        // Show/hide dashboard on drag (for touchscreen devices)
        if (pressed && inTopPanel(panels.dashboard, dragStart.x, dragStart.y) && withinPanelWidth(panels.dashboard, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                screenState.dashboard = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                screenState.dashboard = false;
        }

        // Show popouts on hover
        if (inBarArea(x, y)) {
            bar.checkPopout(isBarHorizontal ? x : y);
        } else if ((!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inLeftPanel(panels.popoutsWrapper, x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
        }

        // Show utilities on hover
        const showUtilities = !popouts.hasCurrent && panels.popoutsWrapper.offsetScale > 0.99 && (Config.bar.position === "bottom" ? inTopPanel(panels.utilities, x, y) : inBottomPanel(panels.utilities, x, y, true));

        // Always update visibility based on hover if not in shortcut mode
        if (!utilitiesShortcutActive) {
            screenState.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            utilitiesShortcutActive = false;
        }

        // If in shortcut mode, we only check if cursor is STILL in the area, but we DON'T update visibility
        // Instead, if it leaves the area, we exit shortcut mode
        if (utilitiesShortcutActive) {
            if (!(Config.bar.position === "bottom" ? inTopPanel(panels.utilities, x, y) : inBottomPanel(panels.utilities, x, y, true))) {
                utilitiesShortcutActive = false;
            }
        }
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            // If launcher is hidden, clear shortcut flags for dashboard and OSD
            if (!root.screenState.launcher) {
                root.dashboardShortcutActive = false;
                root.osdShortcutActive = false;
                root.utilitiesShortcutActive = false;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.screenState.dashboard = false;
                }
                if (!inOsdArea) {
                    root.screenState.osd = false;
                    root.panels.osd.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.screenState.dashboard) {
                // Dashboard became visible, immediately check if this should be shortcut mode
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                if (!inDashboardArea) {
                    root.dashboardShortcutActive = true;
                }
            } else {
                // Dashboard hidden, clear shortcut flag
                root.dashboardShortcutActive = false;
            }
        }

        function onOsdChanged() {
            if (root.screenState.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.screenState.utilities) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = Config.bar.position === "bottom" ? root.inTopPanel(root.panels.utilities, root.mouseX, root.mouseY) : root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.utilitiesShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.utilitiesShortcutActive = false;
            }
        }

        target: root.screenState
    }
}
