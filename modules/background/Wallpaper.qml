pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    property string source: Wallpapers.current
    property Item current
    property bool completed
    property var screen: null

    function isVideo(path: string): bool {
        if (!path)
            return false;
        const ext = path.split('.').pop().toLowerCase();
        return ["mp4", "webm", "mkv", "avi", "mov", "wmv", "flv"].includes(ext);
    }

    function isCurrentReady(): bool {
        if (!current)
            return false;
        if (current.playing !== undefined)
            return current.playing;
        if (current.status !== undefined)
            return current.status === Image.Ready;
        return false;
    }

    function createWallpaperObject() {
        if (!source) {
            current = null;
        } else {
            const isVid = isVideo(source);
            const isGif = source.endsWith(".gif");
            const comp = isVid ? videoComp : (isGif ? gifComp : imgComp);
            current = comp.createObject(root, {
                path: source,
                screen: root.screen
            });
        }
    }

    onSourceChanged: createWallpaperObject()

    Component.onCompleted: {
        if (source)
            Qt.callLater(() => {
                createWallpaperObject();
                completed = true;
            });
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

            anchors.fill: parent

            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== img && root.isCurrentReady()
                interval: anim.duration
                onTriggered: img.destroy()
            }
        }
    }

    Component {
        id: gifComp

        CachingAnimatedImage {
            id: gifImg

            anchors.fill: parent

            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== gifImg && root.isCurrentReady()
                interval: anim.duration
                onTriggered: gifImg.destroy()
            }
        }
    }

    Component {
        id: videoComp

        CachingVideo {
            id: video

            anchors.fill: parent
            screen: root.screen

            opacity: 0

            onPlayingChanged: {
                if (playing)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== video && root.isCurrentReady()
                interval: anim.duration
                onTriggered: video.destroy()
            }
        }
    }
}