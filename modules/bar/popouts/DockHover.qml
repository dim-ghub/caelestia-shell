import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

RowLayout {
    id: root

    required property PopoutState popouts
    property var model: popouts.dockModel

    property MprisPlayer player: {
        if (!model) return null;
        return Players.list.find(p => p.identity.toLowerCase().includes(model.appClass.toLowerCase()) || (model.id && p.identity.toLowerCase().includes(model.id.toLowerCase().replace(".desktop", "")))) || null;
    }

    spacing: Tokens.spacing.normal

        // Fallback for pinned apps with no active windows
        StyledRect {
            visible: !root.model || !root.model.toplevels || root.model.toplevels.length === 0
            Layout.alignment: Qt.AlignTop
            radius: Tokens.rounding.normal
            color: Colours.tPalette.m3surfaceContainer
            clip: true
            implicitWidth: fallbackLayout.implicitWidth + Tokens.padding.normal * 2
            implicitHeight: fallbackLayout.implicitHeight + Tokens.padding.normal * 2

            ColumnLayout {
                id: fallbackLayout
                anchors.centerIn: parent
                spacing: Tokens.spacing.normal

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.normal

                    IconImage {
                        id: fallbackIcon
                        asynchronous: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: fallbackDetails.implicitHeight
                        source: model ? Icons.getAppIcon(model.iconName, "image-missing") : ""
                    }

                    ColumnLayout {
                        id: fallbackDetails
                        spacing: 0
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: model ? (model.entry ? model.entry.name : model.appClass) : ""
                            font.pointSize: Tokens.font.size.normal
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        Repeater {
            model: root.model ? root.model.toplevels : []

            delegate: StyledRect {
                required property var modelData

                readonly property real windowRatio: (modelData.lastIpcObject && modelData.lastIpcObject.size[0] > 0) ? (modelData.lastIpcObject.size[1] / modelData.lastIpcObject.size[0]) : 0.75
                readonly property real targetWidth: Tokens.sizes.bar.windowPreviewSize
                readonly property real targetHeight: Math.max(50, Math.min(targetWidth * windowRatio, Tokens.sizes.bar.windowPreviewSize * 1.5))

                Layout.alignment: Qt.AlignTop
                radius: Tokens.rounding.normal
                color: Colours.tPalette.m3surfaceContainer
                clip: true
                implicitWidth: cardLayout.implicitWidth + Tokens.padding.normal * 2
                implicitHeight: cardLayout.implicitHeight + Tokens.padding.normal * 2

                ColumnLayout {
                    id: cardLayout
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.normal

                    // Title row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: targetWidth

                        IconImage {
                            asynchronous: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitSize: titleText.implicitHeight
                            source: root.model ? Icons.getAppIcon(root.model.iconName, "image-missing") : ""
                        }

                        StyledText {
                            id: titleText
                            Layout.fillWidth: true
                            text: modelData.title || ""
                            font.pointSize: Tokens.font.size.smaller
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }

                        StyledRect {
                            implicitWidth: winfoIcon.implicitHeight + Tokens.padding.small * 2
                            implicitHeight: winfoIcon.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.small
                            color: Colours.tPalette.m3surfaceVariant

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.small
                                // Set the specific client to be used by the window info popout
                                onClicked: {
                                    root.popouts.selectedClientAddress = modelData.address;
                                    root.popouts.detachRequested("winfo");
                                }
                            }

                            MaterialIcon {
                                id: winfoIcon
                                anchors.centerIn: parent
                                text: "chevron_right"
                                font.pointSize: Tokens.font.size.normal
                            }
                        }

                        StyledRect {
                            implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * 2
                            implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.small
                            color: Colours.tPalette.m3surfaceVariant

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.small
                                onClicked: {
                                    Hypr.dispatch(`closewindow address:0x${modelData.address}`);
                                    root.popouts.hasCurrent = false;
                                }
                            }

                            MaterialIcon {
                                id: closeIcon
                                anchors.centerIn: parent
                                text: "close"
                                font.pointSize: Tokens.font.size.normal
                            }
                        }
                    }

                    // Preview
                    Item {
                        Layout.preferredWidth: targetWidth
                        Layout.preferredHeight: targetHeight

                        StateLayer {
                            radius: Tokens.rounding.small
                            color: "transparent"

                            onClicked: {
                                Hypr.dispatch(`focuswindow address:0x${modelData.address}`);
                                root.popouts.hasCurrent = false;
                            }

                            ClippingWrapperRectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: Tokens.rounding.small

                                ScreencopyView {
                                    captureSource: modelData.wayland || null // qmllint disable unresolved-type
                                    live: visible
                                    constraintSize.width: targetWidth
                                    constraintSize.height: targetHeight
                                }
                            }
                        }
                    }

                    // Media controls
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Tokens.spacing.normal
                        visible: !!root.player

                        Item {
                            implicitWidth: prevIcon.implicitHeight + Tokens.padding.small * 2
                            implicitHeight: prevIcon.implicitHeight + Tokens.padding.small * 2
                            visible: root.player ? root.player.canGoPrevious : false

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.small
                                onClicked: root.player.previous()
                            }

                            MaterialIcon {
                                id: prevIcon
                                anchors.centerIn: parent
                                text: "skip_previous"
                                font.pointSize: Tokens.font.size.large
                            }
                        }

                        Item {
                            implicitWidth: playIcon.implicitHeight + Tokens.padding.small * 2
                            implicitHeight: playIcon.implicitHeight + Tokens.padding.small * 2
                            visible: root.player ? root.player.canTogglePlaying : false

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.small
                                onClicked: root.player.togglePlaying()
                            }

                            MaterialIcon {
                                id: playIcon
                                anchors.centerIn: parent
                                text: (root.player && root.player.isPlaying) ? "pause" : "play_arrow"
                                font.pointSize: Tokens.font.size.large
                            }
                        }

                        Item {
                            implicitWidth: nextIcon.implicitHeight + Tokens.padding.small * 2
                            implicitHeight: nextIcon.implicitHeight + Tokens.padding.small * 2
                            visible: root.player ? root.player.canGoNext : false

                            StateLayer {
                                anchors.fill: parent
                                radius: Tokens.rounding.small
                                onClicked: root.player.next()
                            }

                            MaterialIcon {
                                id: nextIcon
                                anchors.centerIn: parent
                                text: "skip_next"
                                font.pointSize: Tokens.font.size.large
                            }
                        }
                    }
                }
            }
}
}
