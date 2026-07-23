#pragma once

#include <QObject>
#include <QTcpSocket>
#include "QuickShareCrypto.hpp"
#include "wire_format.pb.h"

namespace caelestia::services {

class QuickShareConnection : public QObject {
    Q_OBJECT

public:
    enum State {
        Disconnected,
        Connecting,
        OfflineFrameExchange,
        Ukey2Handshake,
        PostHandshake,
        PairedKeyExchange,
        ConnectionAccepted,
        Transferring
    };

    explicit QuickShareConnection(QTcpSocket* socket, QObject* parent = nullptr);
    explicit QuickShareConnection(const QString& host, int port, QObject* parent = nullptr);
    ~QuickShareConnection() override;

    void sendFile(const QString& filePath);
    void acceptTransfer();
    void rejectTransfer();
    QString incomingFileName() const { return m_incomingFileName; }
    QString deviceName() const { return m_deviceName; }

signals:
    void stateChanged(State newState);
    void transferRequested(const QString& fileName, qint64 fileSize);
    void pinCodeReady(const QString& pinCode);
    void transferProgress(qint64 bytesSent, qint64 bytesTotal);
    void transferFinished(bool success);

private slots:
    void onReadyRead();
    void onDisconnected();
    void onError(QAbstractSocket::SocketError socketError);

private:
    void handleOfflineFrame(const QByteArray& data);
    void handleUkey2(const QByteArray& data);
    void handlePostHandshake(const QByteArray& data);
    void handleEncryptedFrame(const QByteArray& data);
    void handlePayloadTransfer(const QByteArray& plaintext);

    QByteArray wrapInSecureMessage(const QByteArray& offlineFrameData);
    QByteArray unwrapSecureMessage(const QByteArray& secureMessageData);
    void sendEncryptedSharingFrame(sharing::nearby::V1Frame::FrameType type);
    void sendEncryptedSharingFrame(const sharing::nearby::Frame& frame);
    QByteArray buildPayloadTransferFrame(const QByteArray& sharingFrameData, bool lastChunk, qint64 offset);
    QByteArray buildOfflineFrame(const QByteArray& payloadTransferData);
    void encryptAndSendOfflineFrameBytes(const QByteArray& offlineFrameData);

    QTcpSocket* m_socket;
    State m_state = Disconnected;
    bool m_encryptionEnabled = false;
    int m_sendSeq = 1;
    int m_recvSeq = 1;
    QuickShareCrypto m_crypto;
    QByteArray m_buffer;
    
    QString m_incomingFileName;
    qint64 m_incomingFileSize = 0;
    QString m_deviceName;

    qint64 m_outgoingFilePayloadId = 0;
    QString m_outgoingFilePath;
    qint64 m_outgoingFileSize = 0;

    QMap<qint64, QByteArray> m_payloadBuffers;
    QMap<qint64, qint64> m_payloadTotalSizes;

    QByteArray m_fileBuffer;
    bool m_fileTransferActive = false;
};

} // namespace caelestia::services
