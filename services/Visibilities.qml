pragma Singleton

import Quickshell
import qs.components
import qs.services

Singleton {
    property string launcherInitialSearch: ""
    property string initialSidebarTab: "notifications"

    // Backwards compatibility for custom modules
    property var bars: ({
        get: function(name) {
            for (let i = 0; i < Screens.screens.length; i++) {
                if (Screens.screens[i].name === name) {
                    const comps = ShellState.componentsFor(Screens.screens[i]);
                    if (comps) return comps.bar;
                }
            }
            return null;
        }
    })

    function load(screen: ShellScreen, visibilities: ScreenState): void {
        // Obsolete, ScreenState handles this
    }

    function registerBar(screen: ShellScreen, barWrapper: var): void {
        // Obsolete, ShellState ComponentRef handles this
    }

    function getForActive(): ScreenState {
        return ShellState.forActive();
    }
}
