pragma ComponentBehavior: Bound

import "lock"
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.Internal
import qs.services
import "background"

Scope {
    id: root

    required property Lock lock
    readonly property bool enabled: (!GlobalConfig.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying)) && !BadApplePlayer.shouldPlay

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock") {
            lock.lock.locked = true;
            Audio.playLock();
        } else if (action === "unlock") {
            lock.lock.locked = false;
        } else if (typeof action === "string") {
            Hypr.dispatch(Hypr.usingLua && ["dpms off", "dpms on"].includes(action) ? `hl.dsp.dpms({ action = "${action === "dpms off" ? "disable" : "enable"}" })` : action);
        } else {
            let cmd = action.slice();
            if (!GlobalConfig.services.useSystemd && cmd.length > 0 && cmd[0] === "systemctl") {
                cmd[0] = "loginctl";
            }
            Quickshell.execDetached(cmd);
        }
    }

    LogindManager {
        onAboutToSleep: {
            if (GlobalConfig.general.idle.lockBeforeSleep) {
                root.lock.lock.locked = true;
                Audio.playLock();
            }
        }
        onLockRequested: {
            root.lock.lock.locked = true;
            Audio.playLock();
        }
        onUnlockRequested: root.lock.lock.unlock()
    }

    Variants {
        model: GlobalConfig.general.idle.timeouts

        IdleMonitor {
            required property var modelData

            enabled: root.enabled && (modelData.enabled ?? true)
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
