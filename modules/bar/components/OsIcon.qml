import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: Math.round(GlobalConfig.general.logo.size)
    implicitHeight: Math.round(GlobalConfig.general.logo.size)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const visibilities = Visibilities.getForActive();
            visibilities.launcher = !visibilities.launcher;
        }
    }

    Loader {
        asynchronous: true
        anchors.centerIn: parent
        sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: Math.round(GlobalConfig.general.logo.size)
            implicitHeight: Math.round(GlobalConfig.general.logo.size)
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Math.round(GlobalConfig.general.logo.size)
            colour: Colours.palette.m3tertiary
        }
    }
}
