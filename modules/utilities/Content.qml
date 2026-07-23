pragma ComponentBehavior: Bound

import "cards"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property var props
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property matrix4x4 deformMatrix

    readonly property bool mediaActive: Config.utilities.cards.recorder || true // quickShare always active
    readonly property int enabledCards: (idleInhibit.active ? 1 : 0) + (mediaActive ? 1 : 0) + (toggles.active ? 1 : 0)
    
    // Calculate nonAnimHeight
    // For mediaLoader, we take the nonAnimHeight of the active SwipeView page, or its implicitHeight, plus the indicator height
    readonly property real nonAnimHeight: {
        let h = 0;
        if (idleInhibit.active) h += (idleInhibit.item as IdleInhibit)?.nonAnimHeight ?? 0;
        if (toggles.active) h += (toggles.item as Toggles)?.implicitHeight ?? 0;
        if (mediaActive && mediaLoader.item) {
            h += mediaLoader.item.nonAnimHeight;
        }
        h += layout.spacing * Math.max(0, enabledCards - 1);
        return h;
    }

    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.medium

        Loader {
            id: idleInhibit

            Layout.fillWidth: true
            active: Config.utilities.cards.keepAwake
            visible: active

            sourceComponent: IdleInhibit {
                objectName: "utilitiesKeepAwake"
            }
        }

        Loader {
            id: mediaLoader

            Layout.fillWidth: true
            active: root.mediaActive
            visible: active
            z: 1

            sourceComponent: ColumnLayout {
                id: mediaLayout
                spacing: Tokens.spacing.small

                property int currentIndex: 0
                property bool animEnabled: false
                
                onCurrentIndexChanged: {
                    animEnabled = true;
                    animDisableTimer.restart();
                }

                Timer {
                    id: animDisableTimer
                    interval: 400
                    onTriggered: mediaLayout.animEnabled = false
                }

                property real nonAnimHeight: {
                    const swipeItem = mediaFlickable.currentItem ? mediaFlickable.currentItem.item : null;
                    const itemHeight = swipeItem ? (swipeItem.nonAnimHeight ?? swipeItem.implicitHeight) : 0;
                    return itemHeight + (indicatorRow.visible ? indicatorRow.implicitHeight + spacing : 0);
                }
                
                Behavior on nonAnimHeight {
                    enabled: mediaLayout.animEnabled
                    Anim {}
                }

                Flickable {
                    id: mediaFlickable
                    Layout.fillWidth: true
                    clip: true
                    interactive: mediaRepeater.count > 1

                    readonly property Item currentItem: {
                        mediaRepeater.count;
                        mediaRepeater.dummy;
                        return mediaRepeater.itemAt(mediaLayout.currentIndex);
                    }

                    flickableDirection: Flickable.HorizontalFlick

                    implicitHeight: currentItem ? currentItem.implicitHeight : 0

                    contentX: currentItem ? currentItem.x : 0
                    contentWidth: mediaRow.implicitWidth
                    contentHeight: mediaRow.implicitHeight

                    onContentXChanged: {
                        if (!moving || !currentItem)
                            return;

                        const x = contentX - currentItem.x;
                        if (x > currentItem.width / 2)
                            mediaLayout.currentIndex = Math.min(mediaLayout.currentIndex + 1, mediaRepeater.count - 1);
                        else if (x < -currentItem.width / 2)
                            mediaLayout.currentIndex = Math.max(mediaLayout.currentIndex - 1, 0);
                    }

                    onDragEnded: {
                        if (!currentItem)
                            return;

                        const x = contentX - currentItem.x;
                        if (x > currentItem.width / 10)
                            mediaLayout.currentIndex = Math.min(mediaLayout.currentIndex + 1, mediaRepeater.count - 1);
                        else if (x < -currentItem.width / 10)
                            mediaLayout.currentIndex = Math.max(mediaLayout.currentIndex - 1, 0);
                        else
                            contentX = Qt.binding(() => currentItem ? currentItem.x : 0);
                    }

                    Row {
                        id: mediaRow
                        spacing: Tokens.spacing.medium

                        Repeater {
                            id: mediaRepeater
                            
                            property int dummy: 0
                            onItemAdded: dummy++
                            model: {
                                const pages = [];
                                if (Config.utilities.cards.recorder) pages.push("record");
                                pages.push("quickShare");
                                return pages;
                            }

                            Loader {
                                required property int index
                                required property string modelData
                                active: true
                                sourceComponent: modelData === "record" ? recordComp : quickShareComp
                                
                                width: mediaFlickable.width
                            }
                        }
                    }

                    Behavior on contentX {
                        Anim {}
                    }

                    Behavior on implicitHeight {
                        enabled: mediaLayout.animEnabled
                        Anim {}
                    }
                }

                Item {
                    id: indicatorRow
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: bgRow.implicitWidth
                    implicitHeight: bgRow.implicitHeight
                    visible: mediaRepeater.count > 1

                    Row {
                        id: bgRow
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: mediaRepeater.count

                            StyledRect {
                                required property int index
                                width: Tokens.spacing.medium
                                height: Tokens.spacing.small
                                radius: Tokens.rounding.full
                                color: Colours.palette.m3surfaceVariant
                            }
                        }
                    }

                    StyledRect {
                        width: Tokens.spacing.medium
                        height: Tokens.spacing.small
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        x: mediaLayout.currentIndex * (Tokens.spacing.medium + Tokens.spacing.small)
                        
                        Behavior on x { Anim { type: Anim.DefaultEffects } }
                    }
                }
            }
        }

        Loader {
            id: toggles

            Layout.fillWidth: true
            active: Config.utilities.cards.quickToggles
            visible: active

            sourceComponent: Toggles {
                objectName: "utilitiesQuickToggles"

                screenState: root.screenState
                popouts: root.popouts
            }
        }
    }

    Component {
        id: recordComp
        Record {
            objectName: "utilitiesScreenRecorder"
            props: root.props
            screenState: root.screenState
        }
    }

    Component {
        id: quickShareComp
        QuickShareList {
            objectName: "utilitiesQuickShare"
            props: root.props
            screenState: root.screenState
        }
    }

    RecordingDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }

    QuickShareDeleteModal {
        props: root.props
        deformMatrix: root.deformMatrix
    }

    QuickShareDeviceSelector {
        props: root.props
        deformMatrix: root.deformMatrix
    }
}
