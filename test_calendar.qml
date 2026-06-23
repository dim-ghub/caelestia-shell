pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Caelestia.Config
import "components"
import "modules/dashboard/dash"

Window {
    width: 400
    height: 400
    visible: true

    DashboardState {
        id: stateMock
    }

    Calendar {
        dashState: stateMock
        anchors.centerIn: parent
        width: 300
    }
}
