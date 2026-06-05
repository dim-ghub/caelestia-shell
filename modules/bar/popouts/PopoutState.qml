import QtQuick

QtObject {
    id: state

    property string currentName
    property bool hasCurrent
    property var dockModel
    property string selectedClientAddress

    signal detachRequested(mode: string)
}
