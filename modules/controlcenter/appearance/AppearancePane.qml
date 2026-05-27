pragma ComponentBehavior: Bound

import ".."
import "../components"
import "./sections"
import "../../launcher/services"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property Session session

    property real animDurationsScale: GlobalConfig.appearance.anim.durations.scale ?? 1
    property string fontFamilyMaterial: Config.appearance.font.icon.family ?? "Material Symbols Rounded"
    property string fontFamilyMono: Config.appearance.font.mono.family ?? "CaskaydiaCove NF"
    property string fontFamilySans: Config.appearance.font.body.family ?? "Rubik"
    property real fontSizeScale: Config.appearance.font.scale ?? 1
    property real paddingScale: Config.appearance.padding.scale ?? 1
    property real roundingScale: Config.appearance.rounding.scale ?? 1
    property real spacingScale: Config.appearance.spacing.scale ?? 1
    property bool transparencyEnabled: GlobalConfig.appearance.transparency.enabled ?? false
    property real transparencyBase: GlobalConfig.appearance.transparency.base ?? 0.85
    property real transparencyLayers: GlobalConfig.appearance.transparency.layers ?? 0.4
    property real borderRounding: Config.border.rounding ?? 1
    property real borderThickness: Config.border.thickness ?? 1

    property bool desktopClockEnabled: Config.background.desktopClock.enabled ?? false
    property real desktopClockScale: Config.background.desktopClock.scale ?? 1
    property string desktopClockPosition: Config.background.desktopClock.position ?? "bottom-right"
    property bool desktopClockShadowEnabled: Config.background.desktopClock.shadow.enabled ?? true
    property real desktopClockShadowOpacity: Config.background.desktopClock.shadow.opacity ?? 0.7
    property real desktopClockShadowBlur: Config.background.desktopClock.shadow.blur ?? 0.4
    property bool desktopClockBackgroundEnabled: Config.background.desktopClock.background.enabled ?? false
    property real desktopClockBackgroundOpacity: Config.background.desktopClock.background.opacity ?? 0.7
    property bool desktopClockBackgroundBlur: Config.background.desktopClock.background.blur ?? false
    property bool desktopClockInvertColors: Config.background.desktopClock.invertColors ?? false
    property bool backgroundEnabled: Config.background.enabled ?? true
    property bool shimejiEnabled: GlobalConfig.shimeji.enabled ?? false
    property bool shimejiAutoHide: GlobalConfig.shimeji.autoHide ?? true
    property list<string> shimejiExcludedScreens: GlobalConfig.shimeji.excludedScreens ?? []
    property int shimejiCount: GlobalConfig.shimeji.count ?? 1
    property var shimejiScreenCounts: (GlobalConfig.shimeji.screenCounts || {})
    property list<string> monitorNames: Hypr.monitorNames()
    property bool wallpaperEnabled: Config.background.wallpaperEnabled ?? true
    property bool videoWallpaperPaused: Config.background.videoWallpaperPaused ?? false
    property bool videoWallpaperSoundEnabled: Config.background.videoWallpaperSoundEnabled ?? false
    property bool videoWallpaperPauseOnAllDisplays: Config.background.videoWallpaperPauseOnAllDisplays ?? false
    property bool videoWallpaperPauseOnFullscreen: Config.background.videoWallpaperPauseOnFullscreen ?? false
    property bool videoWallpaperPauseOnTiled: Config.background.videoWallpaperPauseOnTiled ?? false
    property bool videoWallpaperMuteOnMedia: Config.background.videoWallpaperMuteOnMedia ?? false
    property bool visualiserEnabled: Config.background.visualiser.enabled ?? false
    property bool visualiserAutoHide: Config.background.visualiser.autoHide ?? true
    property real visualiserRounding: Config.background.visualiser.rounding ?? 1
    property real visualiserSpacing: Config.background.visualiser.spacing ?? 1
    property bool desktopLyricsEnabled: Config.background.desktopLyrics.enabled ?? false
    property real desktopLyricsScale: Config.background.desktopLyrics.scale ?? 1
    property string desktopLyricsPosition: Config.background.desktopLyrics.position ?? "bottom-center"
    property int desktopLyricsAlignment: Config.background.desktopLyrics.alignment ?? 1
    property bool desktopLyricsInvertColors: Config.background.desktopLyrics.invertColors ?? false
    property bool desktopLyricsShadowEnabled: Config.background.desktopLyrics.shadow.enabled ?? true
    property real desktopLyricsShadowOpacity: Config.background.desktopLyrics.shadow.opacity ?? 0.7
    property real desktopLyricsShadowBlur: Config.background.desktopLyrics.shadow.blur ?? 0.4
    property bool desktopLyricsBackgroundEnabled: Config.background.desktopLyrics.background.enabled ?? false
    property real desktopLyricsBackgroundOpacity: Config.background.desktopLyrics.background.opacity ?? 0.7
    property bool desktopLyricsBackgroundBlur: Config.background.desktopLyrics.background.blur ?? false
    property bool desktopLyricsAutoHide: Config.background.desktopLyrics.autoHide ?? true

    function saveConfig() {
        GlobalConfig.appearance.anim.durations.scale = root.animDurationsScale;

        GlobalConfig.appearance.font.icon.family = root.fontFamilyMaterial;
        GlobalConfig.appearance.font.mono.family = root.fontFamilyMono;
        GlobalConfig.appearance.font.body.family = root.fontFamilySans;
        GlobalConfig.appearance.font.headline.family = root.fontFamilySans;
        GlobalConfig.appearance.font.title.family = root.fontFamilySans;
        GlobalConfig.appearance.font.label.family = root.fontFamilySans;
        GlobalConfig.appearance.font.scale = root.fontSizeScale;

        GlobalConfig.appearance.padding.scale = root.paddingScale;
        GlobalConfig.appearance.rounding.scale = root.roundingScale;
        GlobalConfig.appearance.spacing.scale = root.spacingScale;

        GlobalConfig.appearance.transparency.enabled = root.transparencyEnabled;
        GlobalConfig.appearance.transparency.base = root.transparencyBase;
        GlobalConfig.appearance.transparency.layers = root.transparencyLayers;

        GlobalConfig.background.desktopClock.enabled = root.desktopClockEnabled;
        GlobalConfig.background.enabled = root.backgroundEnabled;
        GlobalConfig.shimeji.enabled = root.shimejiEnabled;
        GlobalConfig.shimeji.autoHide = root.shimejiAutoHide;
        GlobalConfig.shimeji.excludedScreens = root.shimejiExcludedScreens;
        GlobalConfig.shimeji.count = root.shimejiCount;
        GlobalConfig.shimeji.screenCounts = root.shimejiScreenCounts;
        GlobalConfig.shimeji.path = GlobalConfig.shimeji.path;
        GlobalConfig.background.desktopClock.scale = root.desktopClockScale;
        GlobalConfig.background.desktopClock.position = root.desktopClockPosition;
        GlobalConfig.background.desktopClock.shadow.enabled = root.desktopClockShadowEnabled;
        GlobalConfig.background.desktopClock.shadow.opacity = root.desktopClockShadowOpacity;
        GlobalConfig.background.desktopClock.shadow.blur = root.desktopClockShadowBlur;
        GlobalConfig.background.desktopClock.background.enabled = root.desktopClockBackgroundEnabled;
        GlobalConfig.background.desktopClock.background.opacity = root.desktopClockBackgroundOpacity;
        GlobalConfig.background.desktopClock.background.blur = root.desktopClockBackgroundBlur;
        GlobalConfig.background.desktopClock.invertColors = root.desktopClockInvertColors;

        GlobalConfig.background.wallpaperEnabled = root.wallpaperEnabled;
        GlobalConfig.background.videoWallpaperPaused = root.videoWallpaperPaused;
        GlobalConfig.background.videoWallpaperSoundEnabled = root.videoWallpaperSoundEnabled;
        GlobalConfig.background.videoWallpaperPauseOnAllDisplays = root.videoWallpaperPauseOnAllDisplays;
        GlobalConfig.background.videoWallpaperPauseOnFullscreen = root.videoWallpaperPauseOnFullscreen;
        GlobalConfig.background.videoWallpaperPauseOnTiled = root.videoWallpaperPauseOnTiled;
        GlobalConfig.background.videoWallpaperMuteOnMedia = root.videoWallpaperMuteOnMedia;

        GlobalConfig.background.visualiser.enabled = root.visualiserEnabled;
        GlobalConfig.background.visualiser.autoHide = root.visualiserAutoHide;
        GlobalConfig.background.visualiser.rounding = root.visualiserRounding;
        GlobalConfig.background.visualiser.spacing = root.visualiserSpacing;

        GlobalConfig.background.desktopLyrics.enabled = root.desktopLyricsEnabled;
        GlobalConfig.background.desktopLyrics.scale = root.desktopLyricsScale;
        GlobalConfig.background.desktopLyrics.position = root.desktopLyricsPosition;
        GlobalConfig.background.desktopLyrics.alignment = root.desktopLyricsAlignment;
        GlobalConfig.background.desktopLyrics.invertColors = root.desktopLyricsInvertColors;
        GlobalConfig.background.desktopLyrics.shadow.enabled = root.desktopLyricsShadowEnabled;
        GlobalConfig.background.desktopLyrics.shadow.opacity = root.desktopLyricsShadowOpacity;
        GlobalConfig.background.desktopLyrics.shadow.blur = root.desktopLyricsShadowBlur;
        GlobalConfig.background.desktopLyrics.background.enabled = root.desktopLyricsBackgroundEnabled;
        GlobalConfig.background.desktopLyrics.background.opacity = root.desktopLyricsBackgroundOpacity;
        GlobalConfig.background.desktopLyrics.background.blur = root.desktopLyricsBackgroundBlur;
        GlobalConfig.background.desktopLyrics.autoHide = root.desktopLyricsAutoHide;

        GlobalConfig.border.rounding = root.borderRounding;
        GlobalConfig.border.thickness = root.borderThickness;
    }

    anchors.fill: parent

    Component {
        id: appearanceRightContentComponent

        Item {
            id: rightAppearanceFlickable

            ColumnLayout {
                id: contentLayout

                anchors.fill: parent
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: Tokens.spacing.medium
                    text: qsTr("Wallpaper")
                    font: Tokens.font.body.builders.large.size(28).weight(Font.DemiBold).build()
                }

                Loader {
                    id: wallpaperLoader

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.bottomMargin: -Tokens.padding.extraLargeIncreased

                    asynchronous: true
                    active: {
                        const isActive = root.session.activeIndex === 3;
                        const isAdjacent = Math.abs(root.session.activeIndex - 3) === 1;
                        const splitLayout = root.children[0];
                        const loader = splitLayout && splitLayout.rightLoader ? splitLayout.rightLoader : null;
                        const shouldActivate = loader && loader.item !== null && (isActive || isAdjacent);
                        return shouldActivate;
                    }

                    onStatusChanged: {
                        if (status === Loader.Error) {
                            console.error(lc, "Wallpaper loader error!");
                        }
                    }

                    sourceComponent: WallpaperGrid {
                        session: root.session
                    }
                }
            }
        }
    }

    SplitPaneLayout {
        anchors.fill: parent

        leftContent: Component {
            StyledFlickable {
                id: sidebarFlickable

                readonly property var rootPane: root

                flickableDirection: Flickable.VerticalFlick
                contentHeight: sidebarLayout.height

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: sidebarFlickable
                }

                ColumnLayout {
                    id: sidebarLayout

                    readonly property var rootPane: sidebarFlickable.rootPane
                    readonly property bool allSectionsExpanded: themeModeSection.expanded && colorVariantSection.expanded && colorSchemeSection.expanded && animationsSection.expanded && fontsSection.expanded && scalesSection.expanded && transparencySection.expanded && borderSection.expanded && backgroundSection.expanded

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.small

                    RowLayout {
                        spacing: Tokens.spacing.medium

                        StyledText {
                            text: qsTr("Appearance")
                            font: Tokens.font.body.builders.large.weight(Font.Medium).build()
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        IconButton {
                            icon: sidebarLayout.allSectionsExpanded ? "unfold_less" : "unfold_more"
                            type: IconButton.Text
                            label.animate: true
                            onClicked: {
                                const shouldExpand = !sidebarLayout.allSectionsExpanded;
                                themeModeSection.expanded = shouldExpand;
                                colorVariantSection.expanded = shouldExpand;
                                colorSchemeSection.expanded = shouldExpand;
                                animationsSection.expanded = shouldExpand;
                                fontsSection.expanded = shouldExpand;
                                scalesSection.expanded = shouldExpand;
                                transparencySection.expanded = shouldExpand;
                                borderSection.expanded = shouldExpand;
                                backgroundSection.expanded = shouldExpand;
                            }
                        }
                    }

                    ThemeModeSection {
                        id: themeModeSection
                    }

                    ColorVariantSection {
                        id: colorVariantSection
                    }

                    ColorSchemeSection {
                        id: colorSchemeSection
                    }

                    AnimationsSection {
                        id: animationsSection

                        rootPane: sidebarFlickable.rootPane
                    }

                    FontsSection {
                        id: fontsSection

                        rootPane: sidebarFlickable.rootPane
                    }

                    ScalesSection {
                        id: scalesSection

                        rootPane: sidebarFlickable.rootPane
                    }

                    TransparencySection {
                        id: transparencySection

                        rootPane: sidebarFlickable.rootPane
                    }

                    BorderSection {
                        id: borderSection

                        rootPane: sidebarFlickable.rootPane
                    }

                    BackgroundSection {
                        id: backgroundSection

                        rootPane: sidebarFlickable.rootPane
                    }
                }
            }
        }

        rightContent: appearanceRightContentComponent
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.controlcenter.appearance"
        defaultLogLevel: LoggingCategory.Info
    }
}
