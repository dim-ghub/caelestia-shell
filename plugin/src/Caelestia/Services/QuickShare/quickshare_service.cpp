#include <QTimer>
#include "quickshare_service.hpp"
#include <QDebug>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QSysInfo>

namespace caelestia::services {

QuickShareService::QuickShareService(QObject* parent)
    : QObject(parent), m_discovery(new QuickShareDiscovery(this)), m_server(new QTcpServer(this)) {
    
    connect(m_discovery, &QuickShareDiscovery::deviceFound, this, &QuickShareService::onDeviceFound);
    connect(m_discovery, &QuickShareDiscovery::deviceLost, this, &QuickShareService::onDeviceLost);
    
    connect(m_server, &QTcpServer::newConnection, this, &QuickShareService::onNewConnection);
    
    loadHistory();
}

QuickShareService::~QuickShareService() {
    saveHistory();
}

bool QuickShareService::isEnabled() const {
    return m_isEnabled;
}

void QuickShareService::setEnabled(bool enabled) {
    if (m_isEnabled == enabled) return;
    m_isEnabled = enabled;
    emit isEnabledChanged();
    
    if (m_isEnabled) {
        m_discovery->startDiscovery();
        if (!m_server->isListening()) {
            m_server->listen(QHostAddress::Any, 0); // Bind to any available port
        }
    } else {
        m_discovery->stopDiscovery();
        m_server->close();
        setVisible(false);
    }
}

bool QuickShareService::isVisible() const {
    return m_isVisible;
}

void QuickShareService::setVisible(bool visible) {
    if (m_isVisible == visible) return;
    m_isVisible = visible;
    emit isVisibleChanged();
    
    if (m_isVisible && m_isEnabled) {
        m_discovery->advertise(QSysInfo::machineHostName(), m_server->serverPort());
    } else {
        m_discovery->stopAdvertising();
    }
}

QVariantList QuickShareService::nearbyDevices() const {
    QVariantList list;
    for (const auto& dev : m_devices) {
        QVariantMap map;
        map["id"] = dev.id;
        map["name"] = dev.name;
        map["address"] = dev.address;
        list.append(map);
    }
    return list;
}

QVariantList QuickShareService::transferHistory() const {
    return m_transferHistory;
}

void QuickShareService::sendFile(const QString& deviceId, const QString& filePath) {
    auto it = std::find_if(m_devices.begin(), m_devices.end(), [&](const QuickShareDevice& d){ return d.id == deviceId; });
    if (it == m_devices.end()) return;
    
    QuickShareConnection* conn = new QuickShareConnection(it->address, it->port, this);
    m_activeConnections.insert(deviceId, conn);
    
    connect(conn, &QuickShareConnection::transferProgress, this, [this, deviceId](qint64 sent, qint64 total) {
        emit transferProgress(deviceId, sent, total);
    });
    
    connect(conn, &QuickShareConnection::transferFinished, this, [this, deviceId, filePath](bool success) {
        emit transferFinished(deviceId, success);
        
        if (success) {
            QVariantMap entry;
            entry["fileName"] = QFileInfo(filePath).fileName();
            entry["filePath"] = filePath;
            entry["timestamp"] = QDateTime::currentDateTime().toSecsSinceEpoch();
            entry["direction"] = "sent";
            entry["deviceName"] = deviceId;
            m_transferHistory.prepend(entry);
            emit transferHistoryChanged();
            saveHistory();
        }
        
        if (m_activeConnections.contains(deviceId)) {
            QuickShareConnection* c = m_activeConnections.take(deviceId);
            QTimer::singleShot(2000, c, &QObject::deleteLater);
        }
    });
    
    // We send file once handshake completes
    connect(conn, &QuickShareConnection::stateChanged, this, [conn, filePath](QuickShareConnection::State state) {
        if (state == QuickShareConnection::ConnectionAccepted) {
            conn->sendFile(filePath);
        }
    });
}

void QuickShareService::acceptIncomingTransfer() {
    if (m_pendingIncomingConnection) {
        m_pendingIncomingConnection->acceptTransfer();
    }
}

void QuickShareService::rejectIncomingTransfer() {
    if (m_pendingIncomingConnection) {
        m_pendingIncomingConnection->rejectTransfer();
        m_pendingIncomingConnection->deleteLater();
        m_pendingIncomingConnection = nullptr;
        emit transferFinished("incoming", false);
    }
}

void QuickShareService::clearHistory() {
    m_transferHistory.clear();
    emit transferHistoryChanged();
    saveHistory();
}

void QuickShareService::onDeviceFound(const QuickShareDevice& device) {
    if (device.name == QSysInfo::machineHostName()) return;
    
    auto it = std::find_if(m_devices.begin(), m_devices.end(), [&](const QuickShareDevice& d){ return d.id == device.id; });
    if (it == m_devices.end()) {
        m_devices.append(device);
        emit nearbyDevicesChanged();
    }
}

void QuickShareService::onDeviceLost(const QString& deviceId) {
    auto it = std::find_if(m_devices.begin(), m_devices.end(), [&](const QuickShareDevice& d){ return d.id == deviceId; });
    if (it != m_devices.end()) {
        m_devices.erase(it);
        emit nearbyDevicesChanged();
    }
}

void QuickShareService::onNewConnection() {
    QTcpSocket* socket = m_server->nextPendingConnection();
    if (!socket) return;
    
    QuickShareConnection* conn = new QuickShareConnection(socket, this);
    m_pendingIncomingConnection = conn;
    
    connect(conn, &QuickShareConnection::transferRequested, this, [this, conn](const QString& fileName, qint64 fileSize) {
        emit incomingTransferRequested(conn->deviceName().isEmpty() ? "Nearby Device" : conn->deviceName(), fileName, fileSize);
    });

    connect(conn, &QuickShareConnection::pinCodeReady, this, [this](const QString& pinCode) {
        emit incomingTransferPinReady(pinCode);
    });
    
    connect(conn, &QuickShareConnection::transferFinished, this, [this](bool success) {
        if (success && m_pendingIncomingConnection) {
            QVariantMap entry;
            QString fileName = m_pendingIncomingConnection->incomingFileName();
            entry["fileName"] = fileName;
            entry["filePath"] = QDir::homePath() + "/Downloads/" + fileName;
            entry["timestamp"] = QDateTime::currentDateTime().toSecsSinceEpoch();
            entry["direction"] = "received";
            entry["deviceName"] = m_pendingIncomingConnection->deviceName().isEmpty() ? "Nearby Device" : m_pendingIncomingConnection->deviceName();
            m_transferHistory.prepend(entry);
            emit transferHistoryChanged();
            saveHistory();
        }
        
        emit transferFinished("incoming", success);

        if (m_pendingIncomingConnection) {
            m_pendingIncomingConnection->deleteLater();
            m_pendingIncomingConnection = nullptr;
        }
    });
}

void QuickShareService::removeHistoryEntry(int index) {
    if (index >= 0 && index < m_transferHistory.size()) {
        m_transferHistory.removeAt(index);
        emit transferHistoryChanged();
        saveHistory();
    }
}


void QuickShareService::loadHistory() {
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/quickshare_history.json";
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
        if (doc.isArray()) {
            m_transferHistory = doc.array().toVariantList();
        }
    }
}

void QuickShareService::saveHistory() {
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/quickshare_history.json";
    QFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        QJsonArray arr = QJsonArray::fromVariantList(m_transferHistory);
        QJsonDocument doc(arr);
        file.write(doc.toJson());
    }
}

} // namespace caelestia::services
