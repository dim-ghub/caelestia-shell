pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property PopoutState popouts
    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal

    width: Math.max(300, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    spacing: Tokens.spacing.medium

    StyledText {
        Layout.topMargin: Tokens.padding.medium
        Layout.leftMargin: Tokens.padding.small
        text: qsTr("Battery")
        font.weight: 500
    }

    StyledRect {
        Layout.fillWidth: true
        implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true

        ColumnLayout {
            id: cardLayout

            width: parent.width - Tokens.padding.medium * 2
            x: Tokens.padding.medium
            y: Tokens.padding.medium
            spacing: Tokens.spacing.large

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.large

                Item {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 110
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: nub
                        width: 24
                        height: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        color: Colours.palette.m3primary
                        radius: Tokens.rounding.small
                        
                        Rectangle {
                            width: parent.width
                            height: parent.radius
                            anchors.bottom: parent.bottom
                            color: parent.color
                        }
                    }

                    Item {
                        id: batteryBody
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right

                        Rectangle {
                            id: liquidMask
                            anchors.fill: parent
                            radius: Tokens.rounding.medium
                            visible: false
                        }

                        Item {
                            id: liquidUnclipped
                            anchors.fill: parent
                            visible: false

                            Item {
                                id: liquidContainer
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                
                                height: parent.height * (UPower.displayDevice.isLaptopBattery ? UPower.displayDevice.percentage : 0)
                                
                                Behavior on height {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 15
                                    color: Colours.palette.m3primary
                                }

                                Item {
                                    anchors.fill: parent
                                    visible: !UPower.onBattery
                                    
                                    Rectangle {
                                        width: 140; height: 140
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: -(height / 2) + 12
                                        
                                        color: Colours.palette.m3primary
                                        radius: 60
                                        
                                        RotationAnimation on rotation {
                                            loops: Animation.Infinite
                                            from: 0; to: 360
                                            duration: 5000
                                        }
                                    }
                                }
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: liquidUnclipped
                            maskEnabled: true
                            maskSource: liquidMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: Colours.palette.m3primary
                            border.width: 3
                            radius: Tokens.rounding.medium
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "bolt"
                            visible: !UPower.onBattery
                            color: Colours.palette.m3onPrimary
                            fontStyle: Tokens.font.icon.large
                            z: 1
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: UPower.displayDevice.isLaptopBattery ? qsTr("%1%").arg(Math.round(UPower.displayDevice.percentage * 100)) : qsTr("N/A")
                        font.pointSize: 28
                        font.weight: 600
                    }

                    StyledText {
                        function formatSeconds(s: int, fallback: string): string {
                            const day = Math.floor(s / 86400);
                            const hr = Math.floor(s / 3600) % 60;
                            const min = Math.floor(s / 60) % 60;

                            let comps = [];
                            if (day > 0) comps.push(`${day}d`);
                            if (hr > 0) comps.push(`${hr}h`);
                            if (min > 0) comps.push(`${min}m`);

                            return comps.join(" ") || fallback;
                        }

                        text: UPower.displayDevice.isLaptopBattery ? qsTr("~ %1").arg(UPower.onBattery ? formatSeconds(UPower.displayDevice.timeToEmpty, "Calculating...") : formatSeconds(UPower.displayDevice.timeToFull, "Fully charged!")) : qsTr("No battery detected")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    }
                }
            }

            Loader {
                asynchronous: true
                Layout.fillWidth: true

                active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

                sourceComponent: StyledRect {
                    implicitWidth: child.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: child.implicitHeight + Tokens.padding.small * 2

                    color: Colours.palette.m3error
                    radius: Tokens.rounding.large

                    Column {
                        id: child
                        anchors.centerIn: parent

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "warning"
                                color: Colours.palette.m3onError
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Degraded: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                                color: Colours.palette.m3onError
                                font: Tokens.font.mono.builders.medium.weight(Font.Medium).build()
                            }
                        }
                    }
                }
            }

            StyledRect {
                id: profiles

                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true

                property string current: {
                    const p = PowerProfiles.profile;
                    if (p === PowerProfile.PowerSaver)
                        return saver.icon;
                    if (p === PowerProfile.Performance)
                        return perf.icon;
                    return balance.icon;
                }

                implicitHeight: Math.max(saver.implicitHeight, balance.implicitHeight, perf.implicitHeight) + Tokens.padding.small

                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.full

                StyledRect {
                    id: indicator

                    color: Colours.palette.m3primary
                    radius: Tokens.rounding.full
                    state: profiles.current

                    states: [
                        State {
                            name: saver.icon

                            Fill {
                                item: saver
                            }
                        },
                        State {
                            name: balance.icon

                            Fill {
                                item: balance
                            }
                        },
                        State {
                            name: perf.icon

                            Fill {
                                item: perf
                            }
                        }
                    ]

                    transitions: Transition {
                        AnchorAnim {}
                    }
                }

                Profile {
                    id: saver

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.extraSmall

                    profile: PowerProfile.PowerSaver
                    icon: "energy_savings_leaf"
                }

                Profile {
                    id: balance

                    anchors.centerIn: parent

                    profile: PowerProfile.Balanced
                    icon: "balance"
                }

                Profile {
                    id: perf

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.padding.extraSmall

                    profile: PowerProfile.Performance
                    icon: "rocket_launch"
                }
            }
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        required property string icon
        required property int profile

        implicitWidth: icon.implicitHeight + Tokens.padding.small
        implicitHeight: icon.implicitHeight + Tokens.padding.small

        StateLayer {
            radius: Tokens.rounding.full
            color: profiles.current === parent.icon ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: PowerProfiles.profile = parent.profile
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent

            text: parent.icon
            fontStyle: Tokens.font.icon.large
            color: profiles.current === text ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
            fill: profiles.current === text ? 1 : 0

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}
