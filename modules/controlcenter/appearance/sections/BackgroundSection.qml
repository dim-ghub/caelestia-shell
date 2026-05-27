pragma ComponentBehavior: Bound

import ".."
import "../../components"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

CollapsibleSection {
    id: root

    required property var rootPane

    title: qsTr("Background")
    showBackground: true

    SwitchRow {
        label: qsTr("Background enabled")
        checked: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.backgroundEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Video wallpaper sound")
        checked: rootPane.videoWallpaperSoundEnabled
        enabled: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.videoWallpaperSoundEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Pause on all displays")
        checked: rootPane.videoWallpaperPauseOnAllDisplays
        enabled: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.videoWallpaperPauseOnAllDisplays = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Pause on fullscreen")
        checked: rootPane.videoWallpaperPauseOnFullscreen
        enabled: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.videoWallpaperPauseOnFullscreen = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Pause on tiled")
        checked: rootPane.videoWallpaperPauseOnTiled
        enabled: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.videoWallpaperPauseOnTiled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Mute when media playing")
        checked: rootPane.videoWallpaperMuteOnMedia
        enabled: rootPane.backgroundEnabled
        onToggled: checked => {
            rootPane.videoWallpaperMuteOnMedia = checked;
            rootPane.saveConfig();
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium
        text: qsTr("Shimeji")
        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
    }

    SwitchRow {
        label: qsTr("Shimeji enabled")
        checked: rootPane.shimejiEnabled
        onToggled: checked => {
            rootPane.shimejiEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Shimeji auto hide")
        checked: rootPane.shimejiAutoHide
        onToggled: checked => {
            rootPane.shimejiAutoHide = checked;
            rootPane.saveConfig();
        }
    }

    ConnectedButtonGroup {
        rootItem: root
        rows: Math.ceil(rootPane.monitorNames.length / 3)

        options: rootPane.monitorNames.map(e => ({
            label: qsTr(e),
            propertyName: `shimejiScreen${e}`,
            onToggled: function (_) {
                let addedBack = rootPane.shimejiExcludedScreens.includes(e);
                if (addedBack) {
                    const index = rootPane.shimejiExcludedScreens.indexOf(e);
                    if (index !== -1) {
                        rootPane.shimejiExcludedScreens.splice(index, 1);
                    }
                } else {
                    if (!rootPane.shimejiExcludedScreens.includes(e)) {
                        rootPane.shimejiExcludedScreens.push(e);
                    }
                }
                rootPane.saveConfig();
            },
            state: !Strings.testRegexList(rootPane.shimejiExcludedScreens, e)
        }))
    }

    SliderInput {
        Layout.fillWidth: true

        label: qsTr("Shimeji count")
        value: rootPane.shimejiCount
        from: 1
        to: 50
        suffix: ""
        validator: IntValidator {
            bottom: 1
            top: 50
        }
        formatValueFunction: val => Math.round(val).toString()
        parseValueFunction: text => parseInt(text)

        onValueModified: newValue => {
            rootPane.shimejiCount = newValue;
            rootPane.saveConfig();
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium
        text: qsTr("Desktop Clock")
        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
    }

    SwitchRow {
        label: qsTr("Desktop Clock enabled")
        checked: rootPane.desktopClockEnabled
        onToggled: checked => {
            rootPane.desktopClockEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        id: posContainer

        readonly property var pos: (rootPane.desktopClockPosition || "top-left").split('-')
        readonly property string currentV: pos[0]
        readonly property string currentH: pos[1]

        function updateClockPos(v, h) {
            rootPane.desktopClockPosition = v + "-" + h;
            rootPane.saveConfig();
        }

        contentSpacing: Tokens.spacing.small
        z: 1

        StyledText {
            text: qsTr("Positioning")
            font: Tokens.font.body.builders.large.weight(Font.Medium).build()
        }

        SplitButtonRow {
            label: qsTr("Vertical Position")
            enabled: rootPane.desktopClockEnabled

            menuItems: [
                MenuItem {
                    property string val: "top"

                    text: qsTr("Top")
                    icon: "vertical_align_top"
                },
                MenuItem {
                    property string val: "middle"

                    text: qsTr("Middle")
                    icon: "vertical_align_center"
                },
                MenuItem {
                    property string val: "bottom"

                    text: qsTr("Bottom")
                    icon: "vertical_align_bottom"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === posContainer.currentV)
                        active = menuItems[i];
                }
            }

            onSelected: item => posContainer.updateClockPos(item.val, posContainer.currentH)
        }

        SplitButtonRow {
            label: qsTr("Horizontal Position")
            enabled: rootPane.desktopClockEnabled
            expandedZ: 99

            menuItems: [
                MenuItem {
                    property string val: "left"

                    text: qsTr("Left")
                    icon: "align_horizontal_left"
                },
                MenuItem {
                    property string val: "center"

                    text: qsTr("Center")
                    icon: "align_horizontal_center"
                },
                MenuItem {
                    property string val: "right"

                    text: qsTr("Right")
                    icon: "align_horizontal_right"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === posContainer.currentH)
                        active = menuItems[i];
                }
            }

            onSelected: item => posContainer.updateClockPos(posContainer.currentV, item.val)
        }
    }

    SwitchRow {
        label: qsTr("Invert colors")
        checked: rootPane.desktopClockInvertColors
        onToggled: checked => {
            rootPane.desktopClockInvertColors = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Shadow")
            font: Tokens.font.body.builders.large.weight(Font.Medium).build()
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.desktopClockShadowEnabled
            onToggled: checked => {
                rootPane.desktopClockShadowEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.medium

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Opacity")
                value: rootPane.desktopClockShadowOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockShadowOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.medium

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Blur")
                value: rootPane.desktopClockShadowBlur * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockShadowBlur = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Background")
            font: Tokens.font.body.builders.large.weight(Font.Medium).build()
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.desktopClockBackgroundEnabled
            onToggled: checked => {
                rootPane.desktopClockBackgroundEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Blur enabled")
            checked: rootPane.desktopClockBackgroundBlur
            onToggled: checked => {
                rootPane.desktopClockBackgroundBlur = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.medium

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Opacity")
                value: rootPane.desktopClockBackgroundOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopClockBackgroundOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.medium
        text: qsTr("Visualiser")
        font: Tokens.font.body.builders.large.weight(Font.Medium).build()
    }

    SwitchRow {
        label: qsTr("Visualiser enabled")
        checked: rootPane.visualiserEnabled
        onToggled: checked => {
            rootPane.visualiserEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Visualiser auto hide")
        checked: rootPane.visualiserAutoHide
        onToggled: checked => {
            rootPane.visualiserAutoHide = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.medium

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Visualiser rounding")
            value: rootPane.visualiserRounding
            from: 0
            to: 10
            stepSize: 1
            validator: IntValidator {
                bottom: 0
                top: 10
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.visualiserRounding = Math.round(newValue);
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.medium

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Visualiser spacing")
            value: rootPane.visualiserSpacing
            from: 0
            to: 2
            validator: DoubleValidator {
                bottom: 0
                top: 2
            }

            onValueModified: newValue => {
                rootPane.visualiserSpacing = newValue;
                rootPane.saveConfig();
            }
        }
    }


    StyledText {
        Layout.topMargin: Tokens.spacing.normal
        text: qsTr("Desktop Lyrics")
        font.pointSize: Tokens.font.body.large.pointSize
        font.weight: 500
    }

    SwitchRow {
        label: qsTr("Desktop Lyrics enabled")
        checked: rootPane.desktopLyricsEnabled
        onToggled: checked => {
            rootPane.desktopLyricsEnabled = checked;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Auto-hide")
        checked: rootPane.desktopLyricsAutoHide
        enabled: rootPane.desktopLyricsEnabled
        onToggled: checked => {
            rootPane.desktopLyricsAutoHide = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        id: lyricsPosContainer

        readonly property var pos: (rootPane.desktopLyricsPosition || "bottom-center").split('-')
        readonly property string currentV: pos[0]
        readonly property string currentH: pos[1]

        function updateLyricsPos(v, h) {
            rootPane.desktopLyricsPosition = v + "-" + h;
            rootPane.saveConfig();
        }

        contentSpacing: Tokens.spacing.small
        z: 1

        StyledText {
            text: qsTr("Positioning")
            font.pointSize: Tokens.font.body.large.pointSize
            font.weight: 500
        }

        SplitButtonRow {
            label: qsTr("Vertical Position")
            enabled: rootPane.desktopLyricsEnabled

            menuItems: [
                MenuItem {
                    property string val: "top"

                    text: qsTr("Top")
                    icon: "vertical_align_top"
                },
                MenuItem {
                    property string val: "middle"

                    text: qsTr("Middle")
                    icon: "vertical_align_center"
                },
                MenuItem {
                    property string val: "bottom"

                    text: qsTr("Bottom")
                    icon: "vertical_align_bottom"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === lyricsPosContainer.currentV)
                        active = menuItems[i];
                }
            }

            onSelected: item => lyricsPosContainer.updateLyricsPos(item.val, lyricsPosContainer.currentH)
        }

        SplitButtonRow {
            label: qsTr("Horizontal Position")
            enabled: rootPane.desktopLyricsEnabled
            expandedZ: 99

            menuItems: [
                MenuItem {
                    property string val: "left"

                    text: qsTr("Left")
                    icon: "align_horizontal_left"
                },
                MenuItem {
                    property string val: "center"

                    text: qsTr("Center")
                    icon: "align_horizontal_center"
                },
                MenuItem {
                    property string val: "right"

                    text: qsTr("Right")
                    icon: "align_horizontal_right"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === lyricsPosContainer.currentH)
                        active = menuItems[i];
                }
            }

            onSelected: item => lyricsPosContainer.updateLyricsPos(lyricsPosContainer.currentV, item.val)
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Text Alignment")
            font.pointSize: Tokens.font.body.large.pointSize
            font.weight: 500
        }

        SplitButtonRow {
            label: qsTr("Alignment")
            enabled: rootPane.desktopLyricsEnabled

            menuItems: [
                MenuItem {
                    property int val: 0

                    text: qsTr("Left")
                    icon: "format_align_left"
                },
                MenuItem {
                    property int val: 1

                    text: qsTr("Center")
                    icon: "format_align_center"
                },
                MenuItem {
                    property int val: 2

                    text: qsTr("Right")
                    icon: "format_align_right"
                }
            ]

            Component.onCompleted: {
                for (let i = 0; i < menuItems.length; i++) {
                    if (menuItems[i].val === rootPane.desktopLyricsAlignment)
                        active = menuItems[i];
                }
            }

            onSelected: item => {
                rootPane.desktopLyricsAlignment = item.val;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Scale")
            value: rootPane.desktopLyricsScale * 100
            from: 50
            to: 200
            suffix: "%"
            validator: IntValidator {
                bottom: 50
                top: 200
            }
            formatValueFunction: val => Math.round(val).toString()
            parseValueFunction: text => parseInt(text)

            onValueModified: newValue => {
                rootPane.desktopLyricsScale = newValue / 100;
                rootPane.saveConfig();
            }
        }
    }

    SwitchRow {
        label: qsTr("Invert colors")
        checked: rootPane.desktopLyricsInvertColors
        onToggled: checked => {
            rootPane.desktopLyricsInvertColors = checked;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Shadow")
            font.pointSize: Tokens.font.body.large.pointSize
            font.weight: 500
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.desktopLyricsShadowEnabled
            onToggled: checked => {
                rootPane.desktopLyricsShadowEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.normal

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Opacity")
                value: rootPane.desktopLyricsShadowOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopLyricsShadowOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.normal

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Blur")
                value: rootPane.desktopLyricsShadowBlur * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopLyricsShadowBlur = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }

    SectionContainer {
        contentSpacing: Tokens.spacing.small

        StyledText {
            text: qsTr("Background")
            font.pointSize: Tokens.font.body.large.pointSize
            font.weight: 500
        }

        SwitchRow {
            label: qsTr("Enabled")
            checked: rootPane.desktopLyricsBackgroundEnabled
            onToggled: checked => {
                rootPane.desktopLyricsBackgroundEnabled = checked;
                rootPane.saveConfig();
            }
        }

        SwitchRow {
            label: qsTr("Blur enabled")
            checked: rootPane.desktopLyricsBackgroundBlur
            onToggled: checked => {
                rootPane.desktopLyricsBackgroundBlur = checked;
                rootPane.saveConfig();
            }
        }

        SectionContainer {
            contentSpacing: Tokens.spacing.normal

            SliderInput {
                Layout.fillWidth: true

                label: qsTr("Opacity")
                value: rootPane.desktopLyricsBackgroundOpacity * 100
                from: 0
                to: 100
                suffix: "%"
                validator: IntValidator {
                    bottom: 0
                    top: 100
                }
                formatValueFunction: val => Math.round(val).toString()
                parseValueFunction: text => parseInt(text)

                onValueModified: newValue => {
                    rootPane.desktopLyricsBackgroundOpacity = newValue / 100;
                    rootPane.saveConfig();
                }
            }
        }
    }
}
