pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    signal networkSelected(ap: Nmcli.AccessPoint)

    title: qsTr("Network")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            running: root.visible && Nmcli.wifiEnabled
            repeat: true
            triggeredOnStart: true
            interval: GlobalConfig.nexus.networkRescanInterval
            onTriggered: Nmcli.rescanWifi()
        }

        Timer {
            id: wifiScanDelay

            interval: 100
            onTriggered: Nmcli.rescanWifi()
        }

        Connections {
            function onWifiEnabledChanged(): void {
                if (Nmcli.wifiEnabled)
                    wifiScanDelay.start();
            }

            target: Nmcli
        }

        Loader {
            Layout.fillWidth: true
            active: Nmcli.hasAvailableEthernet
            visible: active
            asynchronous: true

            sourceComponent: EthernetSection {
                nState: root.nState
                cappedWidth: root.cappedWidth
            }
        }

        ToggleRow {
            Layout.topMargin: Nmcli.hasAvailableEthernet ? Tokens.spacing.large : 0
            first: true
            text: qsTr("Wi-Fi")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: Nmcli.wifiEnabled
            onToggled: Nmcli.enableWifi(checked)
        }

        ItemList {
            id: networkList

            showList: Nmcli.wifiEnabled
            placeholderIcon: Nmcli.wifiEnabled ? "wifi_find" : "signal_wifi_off"
            placeholderText: Nmcli.wifiEnabled ? qsTr("No networks found") : qsTr("Wi-Fi disabled")
            extraHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0 // Inline so it isn't affected by anim
            list.anchors.top: scanningIndicator.bottom

            model: ScriptModel {
                values: {
                    const connecting = Nmcli.connectingSsid();
                    // Lower rank sorts higher in the list
                    const rank = n => n.active ? 0 : n.ssid === connecting ? 1 : Nmcli.hasSavedProfile(n.ssid) ? 2 : 3;
                    return [...Nmcli.networks].sort((a, b) => rank(a) - rank(b) || b.strength - a.strength);
                }
            }

            delegate: StateLayer {
                id: network

                required property Nmcli.AccessPoint modelData
                property bool currentSelected
                property real textOpacity: disabled ? 0.5 : 1

                disabled: currentSelected || Nmcli.connectingSsid() === modelData.ssid

                anchors.left: networkList.list.contentItem.left
                anchors.right: networkList.list.contentItem.right
                implicitHeight: networkLayout.implicitHeight + networkLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                anchors.fill: undefined

                onClicked: {
                    if (!modelData.active) {
                        NetworkConnection.handleConnect(modelData);
                        currentSelected = true;
                        root.networkSelected(modelData);
                    } else {
                        // Active network: open its detail/settings sub-page.
                        root.nState.selectedNetworkSsid = modelData.ssid;
                        root.nState.openSubPage(3);
                    }
                }

                Behavior on textOpacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                Connections {
                    function onActiveChanged(): void {
                        if (network.modelData.active)
                            network.currentSelected = false;
                    }

                    target: network.modelData
                }

                Connections {
                    function onNetworkSelected(ap: Nmcli.AccessPoint): void {
                        if (ap !== network.modelData)
                            network.currentSelected = false;
                    }

                    target: root
                }

                RowLayout {
                    id: networkLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: Icons.getNetworkIcon(network.modelData.strength)
                        color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                        opacity: network.textOpacity
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: network.textOpacity

                        StyledText {
                            Layout.fillWidth: true
                            text: network.modelData.ssid
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Security: %1%2").arg(network.modelData.security).arg(network.modelData.active ? qsTr(" • Connected") : Nmcli.hasSavedProfile(network.modelData.ssid) ? qsTr(" • Saved") : "")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    AnimLoader {
                        sourceComp: Nmcli.connectingSsid() === network.modelData.ssid ? loadingComp : iconComp

                        Component {
                            id: iconComp

                            MaterialIcon {
                                text: network.modelData.active ? "settings" : "lock"
                                color: network.modelData.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                fontStyle: Tokens.font.icon.medium
                                opacity: network.textOpacity
                            }
                        }

                        Component {
                            id: loadingComp

                            LoadingIndicator {
                                implicitSize: Math.round(Tokens.font.icon.medium.pointSize * 1.3)
                            }
                        }
                    }
                }
            }

            StyledProgressBar {
                id: scanningIndicator

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                implicitHeight: Nmcli.scanning ? Tokens.rounding.extraSmall : 0
                indeterminate: true

                Behavior on implicitHeight {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: addNetworkLayout.implicitHeight + addNetworkLayout.anchors.margins * 2
            last: true

            StateLayer {
                onClicked: root.nState.openSubPage(2) // Add network sub-page
            }

            RowLayout {
                id: addNetworkLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased

                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "add"
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Add network")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }

        // ---- VPN -------------------------------------------------------------
        ToggleRow {
            Layout.topMargin: Tokens.spacing.large
            Layout.fillWidth: true
            first: true
            text: qsTr("VPN")
            font: Tokens.font.body.medium
            horizontalPadding: Tokens.padding.largeIncreased
            checked: VPN.connected
            // Connectable as long as there's a provider and we're not mid-switch.
            disabled: VPN.connecting || VPN.disconnecting || VPN.providers.length === 0
            onToggled: VPN.toggle()

            Timer {
                running: root.visible
                repeat: true
                triggeredOnStart: true
                interval: 5000
                onTriggered: {
                    VPN.checkStatus();
                    if (VPN.connected)
                        VPN.refreshStats();
                }
            }
        }

        ItemList {
            id: providerList

            showList: true
            placeholderIcon: "add_circle"
            placeholderText: qsTr("No VPN providers configured")

            model: ScriptModel {
                values: [...VPN.providers]
            }

            delegate: Item {
                id: provider

                required property var modelData // QML types are annoying (causes null errors on destruction if typed correctly)
                readonly property bool isSelected: modelData.providerId === VPN.selectedProvider
                readonly property bool isConnected: isSelected && VPN.connected

                anchors.left: providerList.list.contentItem.left
                anchors.right: providerList.list.contentItem.right
                implicitHeight: providerLayout.implicitHeight + providerLayout.anchors.margins * 2

                StateLayer {
                    disabled: provider.isSelected
                    radius: Tokens.rounding.extraSmall
                    onClicked: {
                        if (!provider.isSelected)
                            VPN.setActiveProvider(provider.modelData.index);
                    }
                }

                RowLayout {
                    id: providerLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledRect {
                        implicitWidth: implicitHeight
                        implicitHeight: providerIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: provider.isConnected ? Colours.palette.m3primaryContainer : provider.isSelected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHighest

                        MaterialIcon {
                            id: providerIcon

                            anchors.centerIn: parent
                            text: provider.isConnected || provider.isSelected ? "vpn_key" : "vpn_key_off"
                            fill: provider.isConnected ? 1 : 0
                            color: provider.isConnected ? Colours.palette.m3onPrimaryContainer : provider.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.medium
                            animate: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: provider.modelData.displayName
                            font: Tokens.font.body.medium
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (!provider.isSelected)
                                    return qsTr("Tap to select");
                                if (VPN.connecting)
                                    return qsTr("Connecting...");
                                if (VPN.disconnecting)
                                    return qsTr("Disconnecting...");
                                switch (VPN.status.state) {
                                case "connected":
                                    return qsTr("Connected");
                                case "needs-auth":
                                    return VPN.status.reason || qsTr("Authentication required");
                                case "error":
                                    return VPN.status.reason || qsTr("An error occurred");
                                default:
                                    return qsTr("Selected");
                                }
                            }
                            color: {
                                if (!provider.isSelected)
                                    return Colours.palette.m3onSurfaceVariant;
                                switch (VPN.status.state) {
                                case "connected":
                                    return Colours.palette.m3primary;
                                case "needs-auth":
                                case "error":
                                    return Colours.palette.m3error;
                                default:
                                    return Colours.palette.m3secondary;
                                }
                            }
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                            animate: true
                        }
                    }

                    Item {
                        Layout.rightMargin: Tokens.spacing.small
                        opacity: provider.isConnected && root?.cappedWidth > Tokens.sizes.nexus.networkShowVpnDetailWidth ? 1 : 0
                        visible: opacity > 0

                        implicitWidth: provider.isConnected && root?.cappedWidth > Tokens.sizes.nexus.networkShowVpnDetailWidth ? providerDetailRow.implicitWidth : 0
                        implicitHeight: providerDetailRow.implicitHeight

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        RowLayout {
                            id: providerDetailRow

                            anchors.right: parent.right
                            spacing: Tokens.spacing.large

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: qsTr("Interface")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: provider.modelData.iface
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            ColumnLayout {
                                spacing: 0

                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: qsTr("Current Ping")
                                    color: Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignRight
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignRight
                                    spacing: Tokens.spacing.small

                                    StyledRect {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitWidth: Math.round(Tokens.font.body.small.pointSize * 0.7)
                                        implicitHeight: implicitWidth
                                        radius: Tokens.rounding.full
                                        color: VPN.pingMs <= 80 ? Colours.palette.m3primary : VPN.pingMs <= 150 ? Colours.palette.m3tertiary : Colours.palette.m3error
                                    }

                                    StyledText {
                                        text: qsTr("%1 ms").arg(VPN.pingMs)
                                        color: Colours.palette.m3outline
                                        font: Tokens.font.label.small
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    IconButton {
                        implicitWidth: implicitHeight + (Tokens.padding.large - padding) * 2
                        type: IconButton.Tonal
                        isRound: true
                        icon: "edit"
                        onClicked: {
                            root.nState.editingVpnIndex = provider.modelData.index;
                            root.nState.openSubPage(4); // Add/edit provider sub-page
                        }
                    }
                }
            }
        }

        // Add provider
        ConnectedRect {
            Layout.fillWidth: true
            last: true
            implicitHeight: manageLayout.implicitHeight + manageLayout.anchors.margins * 2

            StateLayer {
                onClicked: {
                    root.nState.editingVpnIndex = -1;
                    root.nState.openSubPage(4); // Add/edit provider sub-page
                }
            }

            RowLayout {
                id: manageLayout

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: "add"
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Add provider")
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }
    }
}
