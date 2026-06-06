pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property var popouts
    required property var popoutsWrapper
    readonly property Props props: Props {}

    readonly property bool shouldBeActive: visibilities.sidebar && Config.sidebar.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.leftMargin: Config.bar.position === "right" ? (-implicitWidth - 5) * offsetScale : 0
    anchors.rightMargin: Config.bar.position !== "right" ? (-implicitWidth - 5) * offsetScale : 0
    implicitWidth: {
        const defaultWidth = Tokens.sizes.sidebar.width;
        if (root.visible && popouts && popouts.hasCurrent && (Config.bar.position === "bottom" || Config.bar.position === "top")) {
            // Don't push/merge with dock pop-outs
            if (popouts.currentName === "dockhover" || popouts.currentName === "dockcontext")
                return defaultWidth;
            const naturalWidth = Math.max(defaultWidth, popouts.popoutNaturalWidth);
            if (popoutsWrapper) {
                const extendedWidth = parent.width - popoutsWrapper.normalX;
                return Math.max(naturalWidth, extendedWidth);
            }
            return naturalWidth;
        }
        return defaultWidth;
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: Tokens.padding.large
        anchors.topMargin: {
            if (Config.bar.position === "top") {
                return (root.visible && popouts && popouts.hasCurrent && popouts.currentName !== "dockhover" && popouts.currentName !== "dockcontext") ? 0 : Tokens.padding.large;
            }
            if (Config.bar.position === "bottom") {
                return 0;
            }
            return Tokens.padding.large;
        }
        anchors.bottomMargin: {
            if (Config.bar.position === "bottom") {
                return (root.visible && popouts && popouts.hasCurrent && popouts.currentName !== "dockhover" && popouts.currentName !== "dockcontext") ? 0 : Tokens.padding.large;
            }
            if (Config.bar.position === "top") {
                return Tokens.padding.large;
            }
            return Tokens.padding.large;
        }

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            implicitWidth: root.implicitWidth - Tokens.padding.large * 2
            props: root.props
            visibilities: root.visibilities
            popouts: root.popouts
            popoutsWrapper: root.popoutsWrapper
        }
    }
}
