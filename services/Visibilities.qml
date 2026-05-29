pragma Singleton

import Quickshell
import qs.components
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()
    property string launcherInitialSearch: ""
    property var activeDashboard: null
    property bool switchToTerminalOnOpen: false

    function load(screen: ShellScreen, visibilities: DrawerVisibilities): void {
        screens.set(Hypr.monitorFor(screen), visibilities);
    }

    function registerBar(screen: ShellScreen, barWrapper: var): void {
        console.log("Visibilities: registering bar for screen name:", screen.name, "bar:", barWrapper);
        bars.set(screen.name, barWrapper);
        bars = new Map(bars); // Force QML property change notification by changing the Map reference
    }

    function getForActive(): DrawerVisibilities {
        return screens.get(Hypr.focusedMonitor);
    }
}
