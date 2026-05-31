pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

GridLayout {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset

    readonly property bool isWorkspace: true // Flag for finding workspace children
    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    // Unanimated prop for others to use as reference
    readonly property int size: isHorizontal ? (implicitWidth + (hasWindows ? Tokens.padding.small : 0)) : (implicitHeight + (hasWindows ? Tokens.padding.small : 0))

    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows

    columns: isHorizontal ? -1 : 1
    rows: isHorizontal ? 1 : -1
    flow: isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom

    Layout.alignment: isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
    Layout.preferredWidth: isHorizontal ? size : -1
    Layout.preferredHeight: isHorizontal ? -1 : size

    columnSpacing: 0
    rowSpacing: 0

    Loader {
        id: indicator

        Layout.alignment: isHorizontal ? (Qt.AlignVCenter | Qt.AlignLeft) : (Qt.AlignHCenter | Qt.AlignTop)
        Layout.preferredWidth: isHorizontal ? (Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2) : -1
        Layout.preferredHeight: isHorizontal ? -1 : (Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2)
        Layout.leftMargin: 0

        asynchronous: true

        sourceComponent: Config.bar.workspaces.useIcon ? iconComponent : textComponent
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                const ws = Hypr.workspaces.values.find(w => w.id === root.ws);
                const wsName = !ws || ws.name == root.ws ? root.ws : ws.name[0];
                let displayName = wsName.toString();
                if (Config.bar.workspaces.capitalisation.toLowerCase() === "upper") {
                    displayName = displayName.toUpperCase();
                } else if (Config.bar.workspaces.capitalisation.toLowerCase() === "lower") {
                    displayName = displayName.toLowerCase();
                }
                const label = Config.bar.workspaces.label || displayName;
                const occupiedLabel = Config.bar.workspaces.occupiedLabel || label;
                const activeLabel = Config.bar.workspaces.activeLabel || (root.isOccupied ? occupiedLabel : label);
                return root.activeWsId === root.ws ? activeLabel : root.isOccupied ? occupiedLabel : label;
            }
            color: Config.bar.workspaces.occupiedBg || root.isOccupied || root.activeWsId === root.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
            verticalAlignment: Qt.AlignVCenter
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            text: root.activeWsId === root.ws ? "check_box" : "check_box_outline_blank"
            color: Config.bar.workspaces.occupiedBg || root.isOccupied || root.activeWsId === root.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
            horizontalAlignment: StyledText.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
        }
    }

    Loader {
        id: windows

        asynchronous: true

        Layout.alignment: isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
        Layout.fillWidth: isHorizontal && enabled
        Layout.fillHeight: !isHorizontal && enabled
        Layout.topMargin: isHorizontal ? 0 : -Tokens.sizes.bar.innerWidth / 10
        Layout.leftMargin: isHorizontal ? -Tokens.sizes.bar.innerWidth / 10 : 0

        visible: active
        active: root.hasWindows

        sourceComponent: isHorizontal ? rowComponent : columnComponent
    }

    Component {
        id: columnComponent
        Column {
            spacing: 0

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: {
                        const ws = root.ws;
                        const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === ws);
                        const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                MaterialIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    Component {
        id: rowComponent
        Row {
            spacing: 0

            add: Transition {
                Anim {
                    properties: "scale"
                    from: 0
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
            }

            move: Transition {
                Anim {
                    properties: "scale"
                    to: 1
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    properties: "x,y"
                }
            }

            Repeater {
                model: ScriptModel {
                    values: {
                        const ws = root.ws;
                        const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === ws);
                        const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                MaterialIcon {
                    required property var modelData

                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    Behavior on Layout.preferredHeight {
        enabled: !isHorizontal
        Anim {}
    }

    Behavior on Layout.preferredWidth {
        enabled: isHorizontal
        Anim {}
    }
}
