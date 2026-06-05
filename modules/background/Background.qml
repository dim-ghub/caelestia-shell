pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Variants {
    model: Screens.screens.filter(s => (GlobalConfig.forScreen(s.name)?.background?.enabled ?? GlobalConfig.instance()?.background?.enabled ?? true))

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (contentItem.Config?.background?.wallpaperEnabled ?? true) ? WlrLayer.Background : WlrLayer.Bottom
        color: (contentItem.Config?.background?.wallpaperEnabled ?? true) ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        readonly property var barWrapper: {
            let name = win.screen ? win.screen.name : undefined;
            let bar = name ? Visibilities.bars.get(name) : undefined;
            return bar;
        }
        readonly property int barExclusiveZone: barWrapper ? barWrapper.exclusiveZone : 0

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: (Config?.background?.wallpaperEnabled ?? true)

                sourceComponent: Wallpaper {
                    screen: win.modelData
                }
            }

            BadAppleVideo {
                id: badappleVid
                anchors.fill: parent
                z: 1
                property var screenModel: win.modelData
            }

            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
                z: 2
            }
        }

        Loader {
            id: clockLoader

            asynchronous: true
            active: (Config?.background?.desktopClock?.enabled ?? false)

            readonly property real baseMargin: Tokens.padding.large * 2

            anchors.leftMargin: (Config?.bar?.position === "left" && state.indexOf("left") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin
            anchors.rightMargin: (Config?.bar?.position === "right" && state.indexOf("right") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin
            anchors.topMargin: (Config?.bar?.position === "top" && state.indexOf("top") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin
            anchors.bottomMargin: (Config?.bar?.position === "bottom" && state.indexOf("bottom") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin

            Behavior on anchors.leftMargin { Anim {} }
            Behavior on anchors.rightMargin { Anim {} }
            Behavior on anchors.topMargin { Anim {} }
            Behavior on anchors.bottomMargin { Anim {} }

            state: Config?.background?.desktopClock?.position ?? "bottom-right"
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x
                absY: clockLoader.y
            }
        }

        Loader {
            id: lyricsLoader

            asynchronous: true
            active: (Config?.background?.desktopLyrics?.enabled ?? false)

            readonly property real baseMargin: Tokens.padding.large * 2

            anchors.leftMargin: (Config?.bar?.position === "left" && state.indexOf("left") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin
            anchors.rightMargin: (Config?.bar?.position === "right" && state.indexOf("right") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin
            anchors.topMargin: (Config?.bar?.position === "top" && state.indexOf("top") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin
            anchors.bottomMargin: (Config?.bar?.position === "bottom" && state.indexOf("bottom") !== -1) ? (baseMargin + win.barExclusiveZone) : baseMargin

            Behavior on anchors.leftMargin { Anim {} }
            Behavior on anchors.rightMargin { Anim {} }
            Behavior on anchors.topMargin { Anim {} }
            Behavior on anchors.bottomMargin { Anim {} }

            state: (Config?.background?.desktopLyrics?.position ?? "bottom-center")
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: lyricsLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopLyrics {
                screen: modelData
                wallpaper: behindClock
                absX: lyricsLoader.x
                absY: lyricsLoader.y
            }
        }
    }
}
