pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Caelestia.Services
Item {
    Component.onCompleted: {
        console.log("SessionManager:", SessionManager);
        Qt.quit();
    }
}
