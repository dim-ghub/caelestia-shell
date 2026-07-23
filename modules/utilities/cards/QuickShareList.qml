pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

StyledRect {
    id: root

    required property var props
    required property ScreenState screenState

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitWidth: implicitHeight
                implicitHeight: {
                    const h = icon.implicitHeight + Tokens.padding.small * 2;
                    return h - (h % 2);
                }

                radius: Tokens.rounding.full
                color: QuickShare.isEnabled ? Colours.palette.m3secondary : Colours.palette.m3secondaryContainer

                MaterialIcon {
                    id: icon

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 1
                    text: "near_me"
                    color: QuickShare.isEnabled ? Colours.palette.m3onSecondary : Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Quick Share")
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: QuickShare.isEnabled ? (QuickShare.isVisible ? qsTr("Visible to everyone") : qsTr("Hidden")) : qsTr("Disabled")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                    animate: true
                }
            }

            IconButton {
                icon: "send"
                type: IconButton.Filled
                onClicked: {
                    root.props.quickShareDeviceSelectorOpen = true;
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            WrapperMouseArea {
                Layout.fillWidth: true

                cursorShape: Qt.PointingHandCursor
                onClicked: root.props.quickShareListExpanded = !root.props.quickShareListExpanded

                RowLayout {
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: "list"
                        fontStyle: Tokens.font.icon.large
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: qsTr("Recent Transfers")
                        font: Tokens.font.body.medium
                    }

                    IconButton {
                        icon: root.props.quickShareListExpanded ? "unfold_less" : "unfold_more"
                        type: IconButton.Text
                        label.animate: true
                        onClicked: root.props.quickShareListExpanded = !root.props.quickShareListExpanded
                    }
                }
            }

            StyledListView {
                id: list

                model: QuickShare.transferHistory
                
                Layout.fillWidth: true
                Layout.rightMargin: -Tokens.spacing.small
                implicitHeight: (Tokens.font.body.large.pointSize + Tokens.padding.small) * (root.props.quickShareListExpanded ? 10 : 3)
                clip: true
                
                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }

                delegate: RowLayout {
                    required property var modelData
                    required property int index

                    anchors.left: list.contentItem.left
                    anchors.right: list.contentItem.right
                    anchors.rightMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        Layout.rightMargin: Tokens.spacing.extraSmall
                        text: {
                            const date = new Date(modelData.timestamp * 1000);
                            return qsTr("%1 at %2").arg(modelData.fileName).arg(Qt.formatDateTime(date, Qt.locale()));
                        }
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "play_arrow"
                        type: IconButton.Text
                        onClicked: {
                            root.screenState.utilities = false;
                            root.screenState.sidebar = false;
                            Quickshell.execDetached(["xdg-open", modelData.filePath]);
                        }
                    }

                    IconButton {
                        icon: "folder"
                        type: IconButton.Text
                        onClicked: {
                            root.screenState.utilities = false;
                            root.screenState.sidebar = false;
                            
                            const lastSlash = modelData.filePath.lastIndexOf('/');
                            const dir = modelData.filePath.substring(0, lastSlash);
                            Quickshell.execDetached([...GlobalConfig.general.apps.explorer, dir]);
                        }
                    }

                    IconButton {
                        icon: "delete_forever"
                        type: IconButton.Text
                        label.color: Colours.palette.m3error
                        stateLayer.color: Colours.palette.m3error
                        onClicked: {
                            root.props.quickShareConfirmDeletePath = modelData.filePath;
                            root.props.quickShareConfirmDeleteIndex = index;
                        }
                    }
                }

                add: Transition {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                        from: 0
                        to: 1
                    }
                }

                remove: Transition {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                        to: 0
                    }
                }

                displaced: Transition {
                    Anim {
                        type: Anim.DefaultEffects
                        property: "opacity"
                        to: 1
                    }
                    Anim {
                        property: "y"
                    }
                }

                Loader {
                    asynchronous: true
                    anchors.centerIn: parent

                    opacity: list.count === 0 ? 1 : 0
                    active: opacity > 0

                    sourceComponent: ColumnLayout {
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: "history_toggle_off"
                            color: Colours.palette.m3outline
                            fontStyle: Tokens.font.icon.extraLarge

                            opacity: root.props.quickShareListExpanded ? 1 : 0
                            scale: root.props.quickShareListExpanded ? 1 : 0
                            Layout.preferredHeight: root.props.quickShareListExpanded ? implicitHeight : 0

                            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                            Behavior on scale { Anim {} }
                            Behavior on Layout.preferredHeight { Anim {} }
                        }

                        RowLayout {
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: "history_toggle_off"
                                color: Colours.palette.m3outline

                                opacity: !root.props.quickShareListExpanded ? 1 : 0
                                scale: !root.props.quickShareListExpanded ? 1 : 0
                                Layout.preferredWidth: !root.props.quickShareListExpanded ? implicitWidth : 0

                                Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                                Behavior on scale { Anim {} }
                                Behavior on Layout.preferredWidth { Anim {} }
                            }

                            StyledText {
                                text: qsTr("No recent transfers")
                                color: Colours.palette.m3outline
                            }
                        }
                    }

                    Behavior on opacity {
                        Anim { type: Anim.DefaultEffects }
                    }
                }

                Behavior on implicitHeight {
                    Anim {}
                }
            }
        }
    }
}
