#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QDBusInterface>

namespace caelestia::services {

struct QuickShareDevice {
    QString id;
    QString name;
    QString endpointId;
    QString address;
    int port;
};

class QuickShareDiscovery : public QObject {
    Q_OBJECT

public:
    explicit QuickShareDiscovery(QObject* parent = nullptr);
    ~QuickShareDiscovery() override;

    void startDiscovery();
    void stopDiscovery();
    
    void advertise(const QString& deviceName, int port);
    void stopAdvertising();

signals:
    void deviceFound(const QuickShareDevice& device);
    void deviceLost(const QString& deviceId);

private slots:
    void onItemNew(int interface, int protocol, const QString& name, const QString& type, const QString& domain, uint flags);
    void onItemRemove(int interface, int protocol, const QString& name, const QString& type, const QString& domain, uint flags);
    void onServiceResolved(const QDBusMessage& msg);
    
private:
    QDBusInterface* m_serverBrowser;
    QDBusInterface* m_entryGroup;
    bool m_isDiscovering = false;
    bool m_isAdvertising = false;
};

} // namespace caelestia::services
