pragma Singleton
import QtQuick
import Caelestia.Config
import Caelestia.Services

QtObject {
    id: root

    property bool isEnabled: QuickShareService.isEnabled
    property bool isVisible: QuickShareService.isVisible
    property var nearbyDevices: QuickShareService.nearbyDevices
    property var transferHistory: QuickShareService.transferHistory

    property var currentNotification: null
    property string currentDeviceName: ""
    property string currentFileName: ""
    property string currentPinCode: ""

    function setEnabled(enabled: bool) {
        QuickShareService.isEnabled = enabled
    }

    function setVisible(visible: bool) {
        QuickShareService.isVisible = visible
    }

    function sendFile(deviceId: string, filePath: string) {
        QuickShareService.sendFile(deviceId, filePath)
    }

    function acceptIncomingTransfer() {
        QuickShareService.acceptIncomingTransfer()
    }

    function rejectIncomingTransfer() {
        QuickShareService.rejectIncomingTransfer()
    }

    function clearHistory() {
        QuickShareService.clearHistory()
    }

    function removeHistoryEntry(index: int) {
        QuickShareService.removeHistoryEntry(index)
    }

    // Connect to C++ signals
    Component.onCompleted: {
        QuickShareService.incomingTransferRequested.connect(function(deviceName, fileName, fileSize) {
            console.log("Quick Share: Incoming transfer from " + deviceName + " - " + fileName)
            root.currentDeviceName = deviceName
            root.currentFileName = fileName
            let body = qsTr("%1 wants to share %2").arg(deviceName).arg(fileName)
            if (root.currentPinCode)
                body += qsTr("\nPIN: %1").arg(root.currentPinCode)
            root.currentNotification = Notifs.addCustomNotification(
                qsTr("Incoming file"),
                body,
                "",
                [
                    { text: qsTr("Decline"), invoke: function() { QuickShareService.rejectIncomingTransfer(); } },
                    { text: qsTr("Accept"), invoke: function() { QuickShareService.acceptIncomingTransfer(); } }
                ],
                true
            );
        })
        QuickShareService.incomingTransferPinReady.connect(function(pinCode) {
            root.currentPinCode = pinCode
            if (root.currentNotification) {
                root.currentNotification.body = qsTr("%1 wants to share %2\nPIN: %3").arg(root.currentDeviceName).arg(root.currentFileName).arg(pinCode)
            }
        })
        QuickShareService.transferFinished.connect(function(deviceId, success) {
            if (root.currentNotification) {
                root.currentNotification.close();
                root.currentNotification = null;
            }
            root.currentDeviceName = ""
            root.currentFileName = ""
            root.currentPinCode = ""
        })

        if (GlobalConfig.services.quickShareAutoStart) {
            root.setEnabled(true);
            root.setVisible(true);
        }
    }
}
