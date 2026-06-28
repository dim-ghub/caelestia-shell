pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Hyprland
import qs.services
import Caelestia.Config

Singleton {
    id: root

    property var settings: GlobalConfig.services
    property int lastPipX: -1
    property int lastPipY: -1
    property double lastPipMoveTime: 0
    property string tempPipPosition: ""
    property string lastPipMonitor: ""

    Timer {
        id: updateDebouncer
        interval: 100 // Wait for Wayland exclusive zone & QML bindings to settle
        running: false
        repeat: false
        onTriggered: root.checkPip()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "openwindow" || n === "windowtitle" || n === "changefloatingmode" || n === "activewindow" || n === "configreloaded" || n === "workspace" || n === "focusedmon") {
                updateDebouncer.restart();
            }
        }
    }

    Instantiator {
        model: Hyprland.monitors.values
        Connections {
            target: modelData
            function onLastIpcObjectChanged(): void {
                updateDebouncer.restart();
            }
        }
    }

    Connections {
        target: GlobalConfig.services
        function onPipPositionChanged(): void {
            root.tempPipPosition = ""; // Reset temporary override on explicit setting change
            root.checkPip();
        }
        function onPipFollowFocusChanged(): void {
            root.checkPip();
        }
        function onPipPausedChanged(): void {
            if (!GlobalConfig.services.pipPaused) {
                root.checkPip();
            }
        }
    }

    Connections {
        target: GlobalConfig.bar
        function onPositionChanged(): void {
            updateDebouncer.restart();
        }
    }

    Connections {
        target: GlobalConfig.border
        function onThicknessChanged(): void {
            updateDebouncer.restart();
        }
    }

    function checkPip(): void {
        if (GlobalConfig.services.pipPaused) return;

        const toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            const t = toplevels[i];
            if (t && t.title && t.title.match(/Picture[- ]in[- ][Pp]icture/)) {
                root.movePip(t);
            }
        }
    }

    function movePip(t: HyprlandToplevel): void {
        if (GlobalConfig.services.pipPaused) return;

        if (Hyprland.activeToplevel && Hyprland.activeToplevel.address === t.address) {
            return; // Pause auto-alignment while the user is interacting with the window!
        }

        let monitor = t.workspace?.monitor || Hyprland.focusedMonitor;
        const addr = "address:0x" + t.address;

        if (GlobalConfig.services.pipFollowFocus) {
            monitor = Hyprland.focusedMonitor;
        }

        if (!monitor) return;

        if (root.lastPipMonitor !== monitor.name) {
            root.tempPipPosition = "";
            root.lastPipMonitor = monitor.name;
        }

        const transform = monitor.lastIpcObject?.transform || 0;
        const isVertical = (transform % 2 !== 0);

        const rawWidth = monitor.width;
        const rawHeight = monitor.height;

        const monitor_width = (isVertical ? rawHeight : rawWidth) / monitor.scale;
        const monitor_height = (isVertical ? rawWidth : rawHeight) / monitor.scale;

        const sizeX = (t.lastIpcObject && t.lastIpcObject.size && t.lastIpcObject.size[0]) ? t.lastIpcObject.size[0] : 0;
        const sizeY = (t.lastIpcObject && t.lastIpcObject.size && t.lastIpcObject.size[1]) ? t.lastIpcObject.size[1] : 0;

        const currentX = (t.lastIpcObject && t.lastIpcObject.at && t.lastIpcObject.at[0]) ? t.lastIpcObject.at[0] : 0;
        const currentY = (t.lastIpcObject && t.lastIpcObject.at && t.lastIpcObject.at[1]) ? t.lastIpcObject.at[1] : 0;

        if (root.lastPipX !== -1 && root.lastPipY !== -1 && (Date.now() - root.lastPipMoveTime > 1000)) {
            const diffX = Math.abs(currentX - root.lastPipX);
            const diffY = Math.abs(currentY - root.lastPipY);

            if (diffX > 100 || diffY > 100) {
                const relX = currentX - monitor.x;
                const relY = currentY - monitor.y;

                const centerX = relX + sizeX / 2;
                const centerY = relY + sizeY / 2;

                let newPos = "";
                if (centerY < monitor_height / 3) newPos += "top";
                else if (centerY > monitor_height * 2 / 3) newPos += "bottom";
                else newPos += "middle";

                if (centerX < monitor_width / 3) newPos += " left";
                else if (centerX > monitor_width * 2 / 3) newPos += " right";
                else newPos += " center";

                root.tempPipPosition = newPos.trim();
            }
        }

        const baseSize = Math.min(monitor_width, monitor_height) / 4;
        const effectiveSizeY = sizeY > 0 ? sizeY : baseSize;
        const effectiveSizeX = sizeX > 0 ? sizeX : (effectiveSizeY * 16 / 9);

        const scale_factor = baseSize / effectiveSizeY;
        const target_width = effectiveSizeX * scale_factor;
        const target_height = effectiveSizeY * scale_factor;

        const x_resize = Math.floor(Math.max(200, target_width));
        const y_resize = Math.floor(Math.max(150, target_height));

        const offset = Math.min(monitor_width, monitor_height) * 0.03;

        const bPos = GlobalConfig.bar.position;

        let res_left = 0;
        let res_top = 0;
        let res_right = 0;
        let res_bottom = 0;

        let barSize = 42;
        if (typeof Tokens !== "undefined" && typeof GlobalConfig !== "undefined") {
            const padding = Math.max(GlobalConfig.appearance.padding.small, GlobalConfig.border.thickness);
            barSize = Tokens.forScreen(monitor.name).sizes.bar.innerWidth + padding * 2;
        }

        if (bPos === "left") res_left += barSize;
        else if (bPos === "right") res_right += barSize;
        else if (bPos === "top") res_top += barSize;
        else if (bPos === "bottom") res_bottom += barSize;

        const avail_w = monitor_width - res_left - res_right - x_resize;
        const avail_h = monitor_height - res_top - res_bottom - y_resize;

        let base_x = monitor.x + res_left;
        let base_y = monitor.y + res_top;

        const pos = root.tempPipPosition || GlobalConfig.services.pipPosition || "";

        if (pos.includes("center")) {
            base_x += avail_w / 2;
        } else if (pos.includes("right")) {
            base_x += avail_w - offset;
        } else {
            base_x += offset; // left
        }

        if (pos.includes("middle")) {
            base_y += avail_h / 2;
        } else if (pos.includes("bottom")) {
            base_y += avail_h - offset;
        } else {
            base_y += offset; // top
        }

        const move_x = Math.floor(base_x);
        const move_y = Math.floor(base_y);

        root.lastPipX = move_x;
        root.lastPipY = move_y;
        root.lastPipMoveTime = Date.now();

        if (Hypr.usingLua) {
            Hypr.dispatch(`hl.dsp.window.resize({ x = ${x_resize}, y = ${y_resize}, window = "${addr}" })`);
            Hypr.dispatch(`hl.dsp.window.move({ x = ${move_x}, y = ${move_y}, relative = false, window = "${addr}" })`);
            Hypr.dispatch(`hl.dsp.window.set_prop({ prop = "keep_aspect_ratio", value = "true", window = "${addr}" })`);
        } else {
            Hypr.dispatch(`resizewindowpixel exact ${x_resize} ${y_resize},${addr}`);
            Hypr.dispatch(`movewindowpixel exact ${move_x} ${move_y},${addr}`);
            Hypr.dispatch(`setprop ${addr} keep_aspect_ratio true`);
        }
    }
}
