pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    property alias enabled: props.enabled

    property bool _autoEnabled: false

    function evaluateAutoEnable(): void {
        const regexes = GlobalConfig.utilities.gameMode.autoEnableRegexes;
        if (!GlobalConfig.utilities.gameMode.autoEnable || regexes.length === 0) {
            if (_autoEnabled) {
                _autoEnabled = false;
                props.enabled = false;
            }
            return;
        }

        let isRunning = false;
        for (const toplevel of Hyprland.toplevels.values) {
            if (toplevel.lastIpcObject && Strings.testRegexList(regexes, toplevel.lastIpcObject.class)) {
                isRunning = true;
                break;
            }
        }

        if (_autoEnabled !== isRunning) {
            _autoEnabled = isRunning;
            props.enabled = isRunning;
        }
    }

    // Force Quickshell to continuously track windows in the background
    property var _toplevelsTracker: Hyprland.toplevels.values
    on_ToplevelsTrackerChanged: evaluateAutoEnable()

    Component.onCompleted: evaluateAutoEnable()

    Connections {
        target: GlobalConfig.utilities.gameMode
        function onAutoEnableChanged(): void { root.evaluateAutoEnable(); }
        function onAutoEnableRegexesChanged(): void { root.evaluateAutoEnable(); }
    }

    function setDynamicConfs(): void {
        const gameModeConfig = GlobalConfig.utilities.gameMode;
        let options = {};
        if (gameModeConfig.disableHyprlandAnimations) options["animations:enabled"] = 0;
        if (gameModeConfig.disableHyprlandShadows) options["decoration:shadow:enabled"] = 0;
        if (gameModeConfig.disableHyprlandBlur) options["decoration:blur:enabled"] = 0;
        if (gameModeConfig.disableHyprlandGaps) {
            options["general:gaps_in"] = 0;
            options["general:gaps_out"] = 0;
            options["general:border_size"] = 1;
            options["decoration:rounding"] = 0;
        }
        options["general:allow_tearing"] = 1;
        
        if (gameModeConfig.disableWindowTransparency) {
            options["decoration:active_opacity"] = 1;
            options["decoration:inactive_opacity"] = 1;
            options["decoration:fullscreen_opacity"] = 1;
        }

        Hypr.extras.applyOptions(options);

        if (gameModeConfig.disableWindowTransparency) {
            if (Hypr.usingLua) {
                Hypr.extras.batchMessage([`eval hl.window_rule({ match = { class = ".*" }, opaque = true })`]);
            } else {
                Hypr.extras.batchMessage([`keyword windowrulev2 opaque, class:.*`]);
            }
        }
    }

    onEnabledChanged: {
        if (enabled) {
            setDynamicConfs();
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode enabled"), qsTr("Disabled Hyprland animations, blur, gaps and shadows"), "gamepad");
        } else {
            Hypr.extras.message("reload");
            if (GlobalConfig.utilities.toasts.gameModeChanged)
                Toaster.toast(qsTr("Game mode disabled"), qsTr("Hyprland settings restored"), "gamepad");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: Hypr.options["animations:enabled"] === 0 // qmllint disable missing-property

        reloadableId: "gameMode"
    }

    Connections {
        function onConfigReloaded(): void {
            if (props.enabled)
                root.setDynamicConfs();
        }

        target: Hypr
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "gameMode"
    }
}
