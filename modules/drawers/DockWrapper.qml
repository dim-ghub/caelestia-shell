pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.modules.bar.components as BarComponents
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BlobGroup blobGroup

    Config.screen: screen.name

    readonly property string position: Config.bar.dock.position
    readonly property bool isHorizontal: position === "top" || position === "bottom"
    readonly property bool disabled: false
    readonly property bool shouldBeVisible: Config.bar.dock.detached && (Config.bar.dock.persistent || isHovered)
    property bool isHovered

    readonly property int exclusiveZone: !disabled && Config.bar.dock.detached ? (isHorizontal ? contentLoader.item?.implicitHeight ?? 0 : contentLoader.item?.implicitWidth ?? 0) : Config.border.thickness

    visible: shouldBeVisible

    readonly property real contentW: contentLoader.item ? contentLoader.item.implicitWidth : 0
    readonly property real contentH: contentLoader.item ? contentLoader.item.implicitHeight : 0

    readonly property int bgPadding: Math.max(Tokens.padding.small, Config.border.thickness)

    implicitWidth: contentW
    implicitHeight: contentH

    BlobRect {
        visible: root.shouldBeVisible
        group: root.blobGroup
        anchors.fill: parent
        anchors.margins: -root.bgPadding
        radius: Tokens.rounding.extraLarge
        deformScale: (0.1 * Config.appearance.deformScale) / 10000
    }

    states: [
        State {
            name: "left"
            when: Config.bar.dock.detached && position === "left"

            AnchorChanges {
                target: root
                anchors.left: parent.left
                anchors.right: undefined
                anchors.top: undefined
                anchors.bottom: undefined
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: undefined
            }
            PropertyChanges {
                target: root
                anchors.leftMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
            }
        },
        State {
            name: "right"
            when: Config.bar.dock.detached && position === "right"

            AnchorChanges {
                target: root
                anchors.left: undefined
                anchors.right: parent.right
                anchors.top: undefined
                anchors.bottom: undefined
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: undefined
            }
            PropertyChanges {
                target: root
                anchors.rightMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
            }
        },
        State {
            name: "top"
            when: Config.bar.dock.detached && position === "top"

            AnchorChanges {
                target: root
                anchors.left: undefined
                anchors.right: undefined
                anchors.top: parent.top
                anchors.bottom: undefined
                anchors.verticalCenter: undefined
                anchors.horizontalCenter: parent.horizontalCenter
            }
            PropertyChanges {
                target: root
                anchors.topMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
            }
        },
        State {
            name: "bottom"
            when: Config.bar.dock.detached && position === "bottom"

            AnchorChanges {
                target: root
                anchors.left: undefined
                anchors.right: undefined
                anchors.top: undefined
                anchors.bottom: parent.bottom
                anchors.verticalCenter: undefined
                anchors.horizontalCenter: parent.horizontalCenter
            }
            PropertyChanges {
                target: root
                anchors.bottomMargin: GlobalConfig.appearance.islands ? Tokens.spacing.extraLarge : 0
            }
        }
    ]

    transitions: []

    BarPopouts.PopoutState {
        id: popoutState

        sidebarOpen: false
        isHorizontal: root.isHorizontal
    }

    Item {
        id: popoutsClip

        z: -1

        anchors.left: root.isHorizontal ? parent.left : undefined
        anchors.right: root.isHorizontal ? parent.right : undefined
        anchors.top: !root.isHorizontal ? parent.top : undefined
        anchors.bottom: !root.isHorizontal ? parent.bottom : undefined

        width: root.isHorizontal ? root.width : popoutsContent.implicitWidth * (1 - popoutOffsetScale)
        height: root.isHorizontal ? popoutsContent.implicitHeight * (1 - popoutOffsetScale) : root.height

        property real popoutOffsetScale: popoutState.hasCurrent ? 0 : 1

        visible: popoutState.hasCurrent

        Behavior on popoutOffsetScale {
            Anim {}
        }

        x: {
            if (!root.isHorizontal) {
                if (root.position === "right")
                    return root.width - popoutsContent.implicitWidth * (1 - popoutOffsetScale);
                return 0;
            }
            const off = popoutState.currentCenter - popoutsContent.nonAnimWidth / 2;
            const diff = root.width - Math.floor(off + popoutsContent.nonAnimWidth);
            if (diff < 0)
                return off + diff;
            return Math.max(off, 0);
        }

        y: {
            if (root.isHorizontal) {
                if (root.position === "bottom")
                    return root.height - popoutsContent.implicitHeight * (1 - popoutOffsetScale);
                return 0;
            }
            const off = popoutState.currentCenter - popoutsContent.nonAnimHeight / 2;
            const diff = root.height - Math.floor(off + popoutsContent.nonAnimHeight);
            if (diff < 0)
                return off + diff;
            return Math.max(off, 0);
        }

        BarPopouts.Wrapper {
            id: popoutsContent

            anchors.leftMargin: root.position === "left" ? (-implicitWidth - 5) * popoutsClip.popoutOffsetScale : 0
            anchors.rightMargin: root.position === "right" ? (-implicitWidth - 5) * popoutsClip.popoutOffsetScale : 0
            anchors.topMargin: root.position === "top" ? (-implicitHeight - 5) * popoutsClip.popoutOffsetScale : 0
            anchors.bottomMargin: root.position === "bottom" ? (-implicitHeight - 5) * popoutsClip.popoutOffsetScale : 0

            states: [
                State {
                    name: "left"
                    when: root.position === "left"

                    AnchorChanges {
                        target: popoutsContent
                        anchors.left: parent.left
                        anchors.right: undefined
                        anchors.top: undefined
                        anchors.bottom: undefined
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: undefined
                    }
                },
                State {
                    name: "right"
                    when: root.position === "right"

                    AnchorChanges {
                        target: popoutsContent
                        anchors.left: undefined
                        anchors.right: parent.right
                        anchors.top: undefined
                        anchors.bottom: undefined
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: undefined
                    }
                },
                State {
                    name: "top"
                    when: root.position === "top"

                    AnchorChanges {
                        target: popoutsContent
                        anchors.left: undefined
                        anchors.right: undefined
                        anchors.top: parent.top
                        anchors.bottom: undefined
                        anchors.verticalCenter: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom"
                    when: root.position === "bottom"

                    AnchorChanges {
                        target: popoutsContent
                        anchors.left: undefined
                        anchors.right: undefined
                        anchors.top: undefined
                        anchors.bottom: parent.bottom
                        anchors.verticalCenter: undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            ]

            offsetScale: popoutsClip.popoutOffsetScale

            screen: root.screen
            visibilities: root.visibilities
        }
    }

    Loader {
        id: contentLoader

        active: root.shouldBeVisible
        sourceComponent: Item {
            implicitWidth: dockItem.implicitWidth
            implicitHeight: dockItem.implicitHeight

            BarComponents.Dock {
                id: dockItem
                bar: null
                popouts: popoutState
            }
        }
    }
}
