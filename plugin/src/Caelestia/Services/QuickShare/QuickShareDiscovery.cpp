#include "QuickShareDiscovery.hpp"

#include <QDBusConnection>
#include <QDBusMetaType>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDebug>
#include <QHostInfo>
#include <QRandomGenerator>

namespace caelestia::services {

QuickShareDiscovery::QuickShareDiscovery(QObject* parent)
    : QObject(parent), m_serverBrowser(nullptr), m_entryGroup(nullptr) {
    qDBusRegisterMetaType<QList<QByteArray>>();
}

QuickShareDiscovery::~QuickShareDiscovery() {
    stopDiscovery();
    stopAdvertising();
}

void QuickShareDiscovery::startDiscovery() {
    if (m_isDiscovering) return;

    QDBusInterface avahiServer(
        "org.freedesktop.Avahi",
        "/",
        "org.freedesktop.Avahi.Server",
        QDBusConnection::systemBus());

    if (!avahiServer.isValid()) {
        qWarning() << "QuickShareDiscovery: Failed to connect to Avahi server";
        return;
    }

    QDBusReply<QDBusObjectPath> browserPath = avahiServer.call("ServiceBrowserNew",
        -1, // AVAHI_IF_UNSPEC
        -1, // AVAHI_PROTO_UNSPEC
        "_FC9F5ED42C8A._tcp",
        "local",
        (uint)0); // flags

    if (!browserPath.isValid()) {
        qWarning() << "QuickShareDiscovery: Failed to create ServiceBrowser:" << browserPath.error().message();
        return;
    }

    m_serverBrowser = new QDBusInterface(
        "org.freedesktop.Avahi",
        browserPath.value().path(),
        "org.freedesktop.Avahi.ServiceBrowser",
        QDBusConnection::systemBus(),
        this);

    QDBusConnection::systemBus().connect(
        "org.freedesktop.Avahi",
        browserPath.value().path(),
        "org.freedesktop.Avahi.ServiceBrowser",
        "ItemNew",
        this,
        SLOT(onItemNew(int, int, const QString&, const QString&, const QString&, uint)));

    QDBusConnection::systemBus().connect(
        "org.freedesktop.Avahi",
        browserPath.value().path(),
        "org.freedesktop.Avahi.ServiceBrowser",
        "ItemRemove",
        this,
        SLOT(onItemRemove(int, int, const QString&, const QString&, const QString&, uint)));

    m_isDiscovering = true;
}

void QuickShareDiscovery::stopDiscovery() {
    if (!m_isDiscovering) return;
    
    if (m_serverBrowser) {
        m_serverBrowser->call("Free");
        m_serverBrowser->deleteLater();
        m_serverBrowser = nullptr;
    }
    
    m_isDiscovering = false;
}

void QuickShareDiscovery::advertise(const QString& deviceName, int port) {
    if (m_isAdvertising) return;

    QDBusInterface avahiServer(
        "org.freedesktop.Avahi",
        "/",
        "org.freedesktop.Avahi.Server",
        QDBusConnection::systemBus());

    if (!avahiServer.isValid()) return;

    QDBusReply<QDBusObjectPath> groupPath = avahiServer.call("EntryGroupNew");
    if (!groupPath.isValid()) return;

    m_entryGroup = new QDBusInterface(
        "org.freedesktop.Avahi",
        groupPath.value().path(),
        "org.freedesktop.Avahi.EntryGroup",
        QDBusConnection::systemBus(),
        this);

    QByteArray endpointId;
    for (int i = 0; i < 4; i++) {
        endpointId.append(static_cast<char>(QRandomGenerator::global()->generate()));
    }

    QByteArray nameB;
    nameB.append(static_cast<char>(0x23)); // pcp
    nameB.append(endpointId);
    nameB.append(static_cast<char>(0xFC)); // service_id
    nameB.append(static_cast<char>(0x9F));
    nameB.append(static_cast<char>(0x5E));
    nameB.append(static_cast<char>(0x00)); // unknown bytes
    nameB.append(static_cast<char>(0x00));
    QString serviceName = QString::fromLatin1(nameB.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));

    QByteArray recordBytes;
    char deviceType = 3; // laptop
    recordBytes.append(static_cast<char>(deviceType << 1));

    for (int i = 0; i < 16; i++) {
        recordBytes.append(static_cast<char>(QRandomGenerator::global()->generate()));
    }

    QByteArray dNameBytes = deviceName.toUtf8();
    if (dNameBytes.length() > 255) {
        dNameBytes.truncate(255);
    }
    recordBytes.append(static_cast<char>(dNameBytes.length()));
    recordBytes.append(dNameBytes);

    QString endpointInfo = QString::fromLatin1(recordBytes.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));

    QList<QByteArray> txtRecord;
    txtRecord.append("n=" + endpointInfo.toUtf8());

    QDBusMessage reply = m_entryGroup->call("AddService",
        -1, // AVAHI_IF_UNSPEC
        -1, // AVAHI_PROTO_UNSPEC
        (uint)0,  // flags
        serviceName,
        "_FC9F5ED42C8A._tcp",
        "local",
        "", // host
        QVariant::fromValue<quint16>(port),
        QVariant::fromValue(txtRecord));
        
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "QuickShareDiscovery: AddService failed:" << reply.errorMessage();
        return;
    }

    QDBusMessage commitReply = m_entryGroup->call("Commit");
    if (commitReply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "QuickShareDiscovery: Commit failed:" << commitReply.errorMessage();
    }
    m_isAdvertising = true;
}

void QuickShareDiscovery::stopAdvertising() {
    if (!m_isAdvertising) return;
    
    if (m_entryGroup) {
        m_entryGroup->call("Reset");
        m_entryGroup->call("Free");
        m_entryGroup->deleteLater();
        m_entryGroup = nullptr;
    }
    
    m_isAdvertising = false;
}

void QuickShareDiscovery::onItemNew(int interface, int protocol, const QString& name, const QString& type, const QString& domain, uint flags) {
    Q_UNUSED(flags);
    
    QDBusInterface avahiServer(
        "org.freedesktop.Avahi",
        "/",
        "org.freedesktop.Avahi.Server",
        QDBusConnection::systemBus());

    QDBusReply<QDBusObjectPath> reply = avahiServer.call("ServiceResolverNew",
        interface, protocol, name, type, domain, -1, (uint)0);
        
    if (reply.isValid()) {
        QString path = reply.value().path();
        QDBusConnection::systemBus().connect(
            "org.freedesktop.Avahi",
            path,
            "org.freedesktop.Avahi.ServiceResolver",
            "Found",
            this,
            SLOT(onServiceResolved(QDBusMessage)));
    }
}

void QuickShareDiscovery::onServiceResolved(const QDBusMessage& msg) {
    QList<QVariant> args = msg.arguments();
    if (args.size() >= 10) {
        QuickShareDevice device;
        device.id = args[2].toString();
        device.name = device.id; // fallback
        
        QList<QByteArray> txtRecords;
        if (args[9].userType() == qMetaTypeId<QDBusArgument>()) {
            txtRecords = qdbus_cast<QList<QByteArray>>(args[9].value<QDBusArgument>());
        }
        
        for (const QByteArray& txt : txtRecords) {
            if (txt.startsWith("n=")) {
                QByteArray b64 = txt.mid(2);
                QByteArray decoded = QByteArray::fromBase64(b64, QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
                if (decoded.isEmpty()) decoded = QByteArray::fromBase64(b64, QByteArray::Base64UrlEncoding);
                if (decoded.isEmpty()) decoded = QByteArray::fromBase64(b64);
                
                if (decoded.length() >= 18) {
                    int nameLen = static_cast<unsigned char>(decoded[17]);
                    if (decoded.length() >= 18 + nameLen) {
                        device.name = QString::fromUtf8(decoded.mid(18, nameLen));
                    }
                }
            }
        }
        
        
        device.address = args[7].toString();
        
        // args[8] is quint16 port
        if (args[8].userType() == QMetaType::UShort) {
            device.port = args[8].value<quint16>();
        } else {
            device.port = args[8].toUInt();
        }
        
        emit deviceFound(device);
    }
}

void QuickShareDiscovery::onItemRemove(int interface, int protocol, const QString& name, const QString& type, const QString& domain, uint flags) {
    Q_UNUSED(interface);
    Q_UNUSED(protocol);
    Q_UNUSED(type);
    Q_UNUSED(domain);
    Q_UNUSED(flags);
    
    emit deviceLost(name);
}

} // namespace caelestia::services
