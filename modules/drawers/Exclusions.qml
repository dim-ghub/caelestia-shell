pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar
    required property DockWrapper dockWrapper

    ExclusionZone {
        anchors.left: true
        exclusiveZone: {
            const barZone = Config.bar.position === "left" ? root.bar.exclusiveZone : contentItem.Config.border.thickness;
            const dockZone = Config.bar.dock.detached && Config.bar.dock.position === "left" ? root.dockWrapper.exclusiveZone : 0;
            return barZone + dockZone;
        }
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.top: true
        exclusiveZone: {
            const barZone = Config.bar.position === "top" ? root.bar.exclusiveZone : contentItem.Config.border.thickness;
            const dockZone = Config.bar.dock.detached && Config.bar.dock.position === "top" ? root.dockWrapper.exclusiveZone : 0;
            return barZone + dockZone;
        }
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.right: true
        exclusiveZone: {
            const barZone = Config.bar.position === "right" ? root.bar.exclusiveZone : contentItem.Config.border.thickness;
            const dockZone = Config.bar.dock.detached && Config.bar.dock.position === "right" ? root.dockWrapper.exclusiveZone : 0;
            return barZone + dockZone;
        }
        Config.screen: root.screen.name
    }

    ExclusionZone {
        anchors.bottom: true
        exclusiveZone: {
            const barZone = Config.bar.position === "bottom" ? root.bar.exclusiveZone : contentItem.Config.border.thickness;
            const dockZone = Config.bar.dock.detached && Config.bar.dock.position === "bottom" ? root.dockWrapper.exclusiveZone : 0;
            return barZone + dockZone;
        }
        Config.screen: root.screen.name
    }

    component ExclusionZone: StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        Config.screen: root.screen.name
    }
}
