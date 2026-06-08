import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Props props
    required property DrawerVisibilities visibilities

    property var popouts

    readonly property bool isBarHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property bool showPopoutSeparator: isBarHorizontal && root.visibilities.sidebar && popouts && popouts.hasCurrent && popouts.currentName !== "dockhover" && popouts.currentName !== "dockcontext" && popouts.currentName !== "activewindow"

    GridLayout {
        id: layout

        anchors.fill: parent
        columns: 1
        rowSpacing: Tokens.spacing.medium

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.row: isBarHorizontal ? 1 : 0

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            NotifDock {
                props: root.props
                visibilities: root.visibilities
            }
        }

        // Utilities Separator
        StyledRect {
            Layout.row: Config.bar.position === "bottom" ? 0 : (Config.bar.position === "top" ? 2 : 1)
            Layout.topMargin: Config.bar.position === "bottom" ? 0 : (Tokens.padding.large - layout.rowSpacing)
            Layout.bottomMargin: Config.bar.position === "bottom" ? (Tokens.padding.large - layout.rowSpacing) : 0
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }

        // Popout Separator
        StyledRect {
            visible: showPopoutSeparator
            Layout.row: Config.bar.position === "bottom" ? 2 : 0
            Layout.topMargin: Config.bar.position === "top" ? 6 : (Tokens.padding.large - layout.rowSpacing)
            Layout.bottomMargin: Config.bar.position === "top" ? (Tokens.padding.large - layout.rowSpacing) : 6
            Layout.fillWidth: true
            implicitHeight: 1

            color: Colours.tPalette.m3outlineVariant
        }
    }
}
