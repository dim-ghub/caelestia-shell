pragma Singleton

import QtQuick
import Quickshell.Hyprland
import Caelestia.Config

QtObject {
    id: root

    property var items: []

    function reload(): void {
        updateItems();
    }

    function updateItems(): void {
        const windows = [];
        for (const client of Hyprland.toplevels.values) {
            windows.push({
                address: client.address,
                title: client.title || "",
                class: client.lastIpcObject?.class || "",
                workspace: client.workspace?.name || "",
                monitor: client.monitor?.name || "",
                wayland: client.wayland,
                size: client.lastIpcObject?.size || [0, 0],
                at: client.lastIpcObject?.at || [0, 0]
            });
        }
        items = windows;
    }

    function query(search: string): var {
        let results = items;
        if (GlobalConfig.launcher.windowSwitcherActiveWorkspaceOnly) {
            const monitor = Hyprland.focusedMonitor;
            const specialWs = monitor?.lastIpcObject?.specialWorkspace?.name;
            if (specialWs) {
                results = results.filter(w => w.workspace === specialWs);
            } else {
                const activeWs = monitor?.activeWorkspace?.name;
                if (activeWs) {
                    results = results.filter(w => w.workspace === activeWs);
                }
            }
        }
        
        if (!search)
            return results;
        const lower = search.toLowerCase();
        return results.filter(w => w.title.toLowerCase().includes(lower) || w.class.toLowerCase().includes(lower));
    }

    function focusWindow(address: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${address}" })` : `focuswindow address:0x${address}`);
    }

    Component.onCompleted: {
        updateItems();
        Hyprland.toplevels.onValuesChanged.connect(updateItems);
    }
}
