#include "QuickShareBle.hpp"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDebug>

// --------------------------------------------------------------------------------
// QuickShareBleAdvertisementAdaptor
// --------------------------------------------------------------------------------

QuickShareBleAdvertisementAdaptor::QuickShareBleAdvertisementAdaptor(QObject *parent)
    : QDBusAbstractAdaptor(parent)
{
}

QVariantMap QuickShareBleAdvertisementAdaptor::serviceData() const {
    QVariantMap map;
    const char rawData[] = {
        (char)252, 18, (char)142, 1, 66, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
        (char)191, 45, 91, (char)160, (char)225, (char)216, 117, 36, (char)202, 0
    };
    QByteArray data(rawData, 24);
    map.insert("0000fe2c-0000-1000-8000-00805f9b34fb", QVariant::fromValue(data));
    return map;
}

void QuickShareBleAdvertisementAdaptor::Release() {
    qDebug() << "QuickShareBleAdvertisement released by BlueZ";
}

// --------------------------------------------------------------------------------
// QuickShareBleAdvertiser
// --------------------------------------------------------------------------------

QuickShareBleAdvertiser::QuickShareBleAdvertiser(QObject* parent)
    : QObject(parent), m_objectPath("/org/caelestia/QuickShareBleAdvertisement"), m_isAdvertising(false)
{
    new QuickShareBleAdvertisementAdaptor(this);
    QDBusConnection::systemBus().registerObject(m_objectPath, this);
}

QuickShareBleAdvertiser::~QuickShareBleAdvertiser() {
    stopAdvertising();
    QDBusConnection::systemBus().unregisterObject(m_objectPath);
}

void QuickShareBleAdvertiser::startAdvertising() {
    if (m_isAdvertising) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects");
    
    QDBusConnection::systemBus().callWithCallback(msg, this, SLOT(onGetManagedObjectsFinished(QDBusMessage)));
}

void QuickShareBleAdvertiser::stopAdvertising() {
    if (!m_isAdvertising || m_adapterPath.isEmpty()) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.bluez", m_adapterPath, "org.bluez.LEAdvertisingManager1", "UnregisterAdvertisement");
    msg << QVariant::fromValue(QDBusObjectPath(m_objectPath));
    QDBusConnection::systemBus().call(msg); // sync call is fine here for cleanup
    m_isAdvertising = false;
}

void QuickShareBleAdvertiser::onGetManagedObjectsFinished(const QDBusMessage& reply) {
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "Failed to get managed objects:" << reply.errorMessage();
        return;
    }

    const QDBusArgument arg = reply.arguments().at(0).value<QDBusArgument>();
    QMap<QDBusObjectPath, QMap<QString, QVariantMap>> objects;
    arg >> objects;

    for (auto it = objects.constBegin(); it != objects.constEnd(); ++it) {
        if (it.value().contains("org.bluez.LEAdvertisingManager1")) {
            m_adapterPath = it.key().path();
            break;
        }
    }

    if (m_adapterPath.isEmpty()) {
        qWarning() << "No adapter with LEAdvertisingManager1 found.";
        return;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.bluez", m_adapterPath, "org.bluez.LEAdvertisingManager1", "RegisterAdvertisement");
    msg << QVariant::fromValue(QDBusObjectPath(m_objectPath));
    msg << QVariantMap(); // empty dict

    QDBusConnection::systemBus().callWithCallback(msg, this, SLOT(onRegisterAdvertisementFinished(QDBusMessage)));
}

void QuickShareBleAdvertiser::onRegisterAdvertisementFinished(const QDBusMessage& reply) {
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "Failed to register advertisement:" << reply.errorMessage();
    } else {
        qDebug() << "Successfully registered BLE advertisement.";
        m_isAdvertising = true;
    }
}

// --------------------------------------------------------------------------------
// QuickShareBleScanner
// --------------------------------------------------------------------------------

QuickShareBleScanner::QuickShareBleScanner(QObject* parent)
    : QObject(parent), m_isScanning(false)
{
    QDBusConnection::systemBus().connect(
        "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "InterfacesAdded",
        this, SLOT(onInterfacesAdded(QDBusObjectPath, QMap<QString, QVariantMap>)));
}

QuickShareBleScanner::~QuickShareBleScanner() {
    stopScanning();
}

void QuickShareBleScanner::startScanning() {
    if (m_isScanning) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.bluez", "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects");
    
    QDBusConnection::systemBus().callWithCallback(msg, this, SLOT(onGetManagedObjectsFinished(QDBusMessage)));
}

void QuickShareBleScanner::stopScanning() {
    if (!m_isScanning || m_adapterPath.isEmpty()) return;

    QDBusMessage msg = QDBusMessage::createMethodCall(
        "org.bluez", m_adapterPath, "org.bluez.Adapter1", "StopDiscovery");
    QDBusConnection::systemBus().call(msg);
    m_isScanning = false;
}

void QuickShareBleScanner::onGetManagedObjectsFinished(const QDBusMessage& reply) {
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "Failed to get managed objects for scanner:" << reply.errorMessage();
        return;
    }

    const QDBusArgument arg = reply.arguments().at(0).value<QDBusArgument>();
    QMap<QDBusObjectPath, QMap<QString, QVariantMap>> objects;
    arg >> objects;

    for (auto it = objects.constBegin(); it != objects.constEnd(); ++it) {
        if (it.value().contains("org.bluez.Adapter1")) {
            m_adapterPath = it.key().path();
            break;
        }
    }

    if (m_adapterPath.isEmpty()) {
        qWarning() << "No adapter with org.bluez.Adapter1 found.";
        return;
    }

    QDBusMessage filterMsg = QDBusMessage::createMethodCall(
        "org.bluez", m_adapterPath, "org.bluez.Adapter1", "SetDiscoveryFilter");
    QVariantMap filter;
    filter.insert("UUIDs", QStringList{"0000fe2c-0000-1000-8000-00805f9b34fb"});
    filterMsg << filter;
    QDBusConnection::systemBus().callWithCallback(filterMsg, this, SLOT(onSetDiscoveryFilterFinished(QDBusMessage)));
}

void QuickShareBleScanner::onSetDiscoveryFilterFinished(const QDBusMessage& reply) {
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "Failed to set discovery filter:" << reply.errorMessage();
    }

    QDBusMessage startMsg = QDBusMessage::createMethodCall(
        "org.bluez", m_adapterPath, "org.bluez.Adapter1", "StartDiscovery");
    QDBusConnection::systemBus().callWithCallback(startMsg, this, SLOT(onStartDiscoveryFinished(QDBusMessage)));
}

void QuickShareBleScanner::onStartDiscoveryFinished(const QDBusMessage& reply) {
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qWarning() << "Failed to start discovery:" << reply.errorMessage();
    } else {
        qDebug() << "Started BLE discovery.";
        m_isScanning = true;
    }
}

void QuickShareBleScanner::onInterfacesAdded(const QDBusObjectPath& objectPath, const QMap<QString, QVariantMap>& interfacesAndProperties) {
    if (interfacesAndProperties.contains("org.bluez.Device1")) {
        QVariantMap props = interfacesAndProperties.value("org.bluez.Device1");
        checkDeviceProperties(props);
        
        QDBusConnection::systemBus().connect(
            "org.bluez", objectPath.path(), "org.freedesktop.DBus.Properties", "PropertiesChanged",
            this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    }
}

void QuickShareBleScanner::onPropertiesChanged(const QString& interface, const QVariantMap& changedProperties, const QStringList& invalidatedProperties) {
    Q_UNUSED(invalidatedProperties);
    if (interface == "org.bluez.Device1") {
        checkDeviceProperties(changedProperties);
    }
}

void QuickShareBleScanner::checkDeviceProperties(const QVariantMap& props) {
    if (props.contains("ServiceData")) {
        const QDBusArgument arg = props.value("ServiceData").value<QDBusArgument>();
        QMap<QString, QVariant> serviceData;
        arg >> serviceData;
        
        // Sometimes QDBusArgument converts to QMap<QString, QByteArray> or QVariant
        if (serviceData.contains("0000fe2c-0000-1000-8000-00805f9b34fb")) {
            QByteArray data;
            QVariant val = serviceData.value("0000fe2c-0000-1000-8000-00805f9b34fb");
            if (val.userType() == QMetaType::QByteArray) {
                data = val.toByteArray();
            } else if (val.canConvert<QDBusArgument>()) {
                const QDBusArgument barg = val.value<QDBusArgument>();
                barg >> data;
            }
            
            if (!data.isEmpty()) {
                QDateTime now = QDateTime::currentDateTime();
                if (!m_lastEmit.isValid() || m_lastEmit.msecsTo(now) > 10000) {
                    m_lastEmit = now;
                    QString address = props.value("Address").toString();
                    emit deviceFound(address, data);
                    qDebug() << "QuickShareBleScanner found device:" << address;
                }
            }
        }
    }
}
