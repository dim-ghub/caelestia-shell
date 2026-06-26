import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    property var dockModel: null
    property string selectedClientAddress: ""
    property bool sidebarOpen: false
    property bool isHorizontal: true
    property real currentCenter

    signal detachRequested(mode: string)
}
