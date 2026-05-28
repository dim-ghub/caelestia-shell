pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property Item wallpaper
    required property real absX
    required property real absY

    property real lyricsScale: Config.background.desktopLyrics.scale
    readonly property bool bgEnabled: Config.background.desktopLyrics.background.enabled
    readonly property bool blurEnabled: bgEnabled && Config.background.desktopLyrics.background.blur && !GameMode.enabled
    readonly property bool invertColors: Config.background.desktopLyrics.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    readonly property string sansFont: GlobalConfig.appearance.font.body.family || "Sans Serif"
    readonly property int alignment: Config.background.desktopLyrics.alignment
    readonly property bool autoHide: Config.background.desktopLyrics.autoHide
    readonly property bool allWindowsFloating: Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true
    readonly property bool shouldHide: autoHide && !allWindowsFloating

    readonly property bool hasLyrics: Lyrics.hasLyrics
    readonly property int currentLyricIndex: Lyrics.indexForTime(currentTrackPosition)
    readonly property bool isCurrentActive: currentLyricIndex >= 0

    property var player: Players.active
    property string displayedLyric: ""
    property string previousLyricText: ""
    property string nextLyricText: ""
    property real currentTrackPosition: 0

    // Reactive binding for position updates
    Binding {
        target: root
        property: "currentTrackPosition"
        when: root.player
        value: root.player?.position ?? 0
    }

    // Reactive track binding - updates when active player changes
    // or when the active player's track metadata changes
    Connections {
        id: playerConnections
        target: root.player

        function onTrackTitleChanged() {
            const p = Players.active;
            if (p)
                Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        }

        function onTrackArtistChanged() {
            const p = Players.active;
            if (p)
                Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        }

        function onTrackAlbumChanged() {
            const p = Players.active;
            if (p)
                Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        }

        function onLengthChanged() {
            const p = Players.active;
            if (p)
                Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        }

        function onIdentityChanged() {
            const p = Players.active;
            if (p)
                Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        }
    }

    // Initial track setup when player becomes available
    Component.onCompleted: {
        const p = Players.active;
        if (p)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
    }

    // Dynamic Spacing Math
    property real lyricSpacing: Tokens.spacing.large * root.lyricsScale
    property real targetCenterY: lyricsContainer.height > 0 ? (lyricsContainer.height - lyricContainer.height) / 2 : 0
    property real targetPrevY: targetCenterY - prevLyricItem.height - lyricSpacing
    property real targetNextY: targetCenterY + lyricContainer.height + lyricSpacing
    property real startNextY: targetNextY + nextLyricItem.height + lyricSpacing

    onCurrentLyricIndexChanged: {
        if (currentLyricIndex >= 0) {
            displayedLyric = (Lyrics.lyrics[currentLyricIndex] ?? "").replace(/\u00A0/g, " ");
            previousLyricText = currentLyricIndex > 0 ? (Lyrics.lyrics[currentLyricIndex - 1] ?? "").replace(/\u00A0/g, " ") : "";
            nextLyricText = currentLyricIndex < Lyrics.lyrics.length - 1 ? (Lyrics.lyrics[currentLyricIndex + 1] ?? "").replace(/\u00A0/g, " ") : "";

            lyricSlide.running = true;
        } else {
            displayedLyric = "";
            previousLyricText = "";
            nextLyricText = "";
        }
    }

    SequentialAnimation {
        id: lyricSlide

        PropertyAction {
            target: prevLyricItem
            property: "y"
            value: root.targetCenterY
        }
        PropertyAction {
            target: lyricContainer
            property: "y"
            value: root.targetNextY
        }
        PropertyAction {
            target: nextLyricItem
            property: "y"
            value: root.startNextY
        }
        ParallelAnimation {
            NumberAnimation {
                target: prevLyricItem
                property: "y"
                to: root.targetPrevY
                duration: Tokens.anim.durations.normal
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lyricContainer
                property: "y"
                to: root.targetCenterY
                duration: Tokens.anim.durations.normal
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: nextLyricItem
                property: "y"
                to: root.targetNextY
                duration: Tokens.anim.durations.normal
                easing.type: Easing.OutCubic
            }
        }
    }

    Timer {
        running: Players.active?.isPlaying ?? false
        interval: GlobalConfig.dashboard.mediaUpdateInterval || 500
        triggeredOnStart: true
        repeat: true
        onTriggered: {
            if (Players.active) {
                currentTrackPosition = Players.active.position;
            }
        }
    }

    implicitWidth: 350 * root.lyricsScale
    implicitHeight: 180 * root.lyricsScale

    opacity: (root.hasLyrics && !root.shouldHide) ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        Anim {}
    }

    Item {
        id: lyricsContainer

        anchors.fill: parent
        // Removed clip: true from here so the shadow doesn't get cut off

        layer.enabled: Config.background.desktopLyrics.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: Config.background.desktopLyrics.shadow.opacity
            shadowBlur: Config.background.desktopLyrics.shadow.blur
        }

        Loader {
            id: blurLoader
            asynchronous: true
            anchors.fill: parent
            active: root.blurEnabled

            sourceComponent: MultiEffect {
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                }
                maskSource: backgroundPlate
                maskEnabled: true
                blurEnabled: true
                blur: 1
                blurMax: 64
                autoPaddingEnabled: false
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.large * root.lyricsScale
            opacity: Config.background.desktopLyrics.background.opacity
            color: Colours.palette.m3surface

            layer.enabled: root.blurEnabled
        }

        // --- NEW INNER CONTAINER FOR FADE MASK ---
        Item {
            id: fadeContainer
            anchors.fill: parent
            clip: true

            layer.enabled: true
            layer.effect: ShaderEffect {
                required property Item source

                // Tweak this value to make the fade taller or shorter
                property real fadeMargin: 0.25

                fragmentShader: Quickshell.shellPath("assets/shaders/fade.frag.qsb")
            }

            // --- Previous Lyric ---
            Item {
                id: prevLyricItem

                width: parent.width
                height: prevLyricLabel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.isCurrentActive

                StyledText {
                    id: prevLyricLabel

                    anchors.fill: parent
                    text: root.previousLyricText
                    font.family: root.sansFont
                    font.pointSize: Tokens.font.body.medium.pointSize * root.lyricsScale
                    color: root.safeSecondary
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                    horizontalAlignment: {
                        switch (root.alignment) {
                        case 0:
                            return Text.AlignLeft;
                        case 2:
                            return Text.AlignRight;
                        default:
                            return Text.AlignHCenter;
                        }
                    }
                }
            }

            // --- Current Lyric ---
            Item {
                id: lyricContainer

                width: parent.width
                height: currentLyricLabel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.isCurrentActive

                MultiEffect {
                    id: lyricGlow

                    anchors.fill: currentLyricLabel
                    source: currentLyricLabel
                    scale: currentLyricLabel.scale
                    enabled: root.isCurrentActive

                    blurEnabled: true
                    blur: 0.4

                    shadowEnabled: true
                    shadowColor: Colours.palette.m3primary
                    shadowOpacity: 0.5
                    shadowBlur: 0.6
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0

                    autoPaddingEnabled: true
                }

                StyledText {
                    id: currentLyricLabel

                    width: parent.width
                    text: root.displayedLyric
                    font.family: root.sansFont
                    font.pointSize: Tokens.font.body.large.pointSize * 1.3 * root.lyricsScale
                    font.weight: Font.Bold
                    color: Colours.palette.m3primary
                    wrapMode: Text.WordWrap
                    horizontalAlignment: {
                        switch (root.alignment) {
                        case 0:
                            return Text.AlignLeft;
                        case 2:
                            return Text.AlignRight;
                        default:
                            return Text.AlignHCenter;
                        }
                    }

                    Behavior on color {
                        CAnim {
                            duration: Tokens.anim.durations.small
                        }
                    }
                }
            }

            Item {
                id: nextLyricItem

                width: parent.width
                height: nextLyricLabel.implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.isCurrentActive

                StyledText {
                    id: nextLyricLabel

                    anchors.fill: parent
                    text: root.nextLyricText
                    font.family: root.sansFont
                    font.pointSize: Tokens.font.body.medium.pointSize * root.lyricsScale
                    color: root.safeSecondary
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                    horizontalAlignment: {
                        switch (root.alignment) {
                        case 0:
                            return Text.AlignLeft;
                        case 2:
                            return Text.AlignRight;
                        default:
                            return Text.AlignHCenter;
                        }
                    }
                }
            }
        }
    }

    Behavior on lyricsScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
