#include "QuickShareConnection.hpp"
#include <QDebug>
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QSysInfo>
#include <QMimeDatabase>
#include <QMimeType>
#include <QRandomGenerator>
#include <QtEndian>
#include <openssl/hmac.h>
#include <openssl/rand.h>
#include "offline_wire_formats.pb.h"
#include "securemessage.pb.h"
#include "securegcm.pb.h"
#include "ukey.pb.h"
#include "device_to_device_messages.pb.h"
#include "wire_format.pb.h"

namespace caelestia::services {

static void writeLengthPrefixed(QTcpSocket* socket, const QByteArray& data) {
    uint32_t length = qToBigEndian(static_cast<uint32_t>(data.size()));
    socket->write(reinterpret_cast<const char*>(&length), 4);
    socket->write(data);
}

QuickShareConnection::QuickShareConnection(QTcpSocket* socket, QObject* parent)
    : QObject(parent), m_socket(socket), m_state(OfflineFrameExchange) {
    m_crypto.initServer();
    
    connect(m_socket, &QTcpSocket::readyRead, this, &QuickShareConnection::onReadyRead);
    connect(m_socket, &QTcpSocket::disconnected, this, &QuickShareConnection::onDisconnected);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    connect(m_socket, &QTcpSocket::errorOccurred, this, &QuickShareConnection::onError);
#else
    connect(m_socket, QOverload<QAbstractSocket::SocketError>::of(&QTcpSocket::error), this, &QuickShareConnection::onError);
#endif
}

QuickShareConnection::QuickShareConnection(const QString& host, int port, QObject* parent)
    : QObject(parent), m_socket(new QTcpSocket(this)), m_state(Connecting) {
    m_crypto.initClient();
    
    connect(m_socket, &QTcpSocket::readyRead, this, &QuickShareConnection::onReadyRead);
    connect(m_socket, &QTcpSocket::disconnected, this, &QuickShareConnection::onDisconnected);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    connect(m_socket, &QTcpSocket::errorOccurred, this, &QuickShareConnection::onError);
#else
    connect(m_socket, QOverload<QAbstractSocket::SocketError>::of(&QTcpSocket::error), this, &QuickShareConnection::onError);
#endif

    connect(m_socket, &QTcpSocket::connected, this, [this]() {
        m_state = OfflineFrameExchange;
        emit stateChanged(m_state);
        
        location::nearby::connections::OfflineFrame frame;
        frame.set_version(location::nearby::connections::OfflineFrame::V1);
        auto* v1 = frame.mutable_v1();
        v1->set_type(location::nearby::connections::V1Frame::CONNECTION_REQUEST);
        auto* req = v1->mutable_connection_request();
        req->set_endpoint_id("ABCD");
        QString hostname = QSysInfo::machineHostName();
        if (hostname.isEmpty()) hostname = "CaelestiaClient";
        req->set_endpoint_name(hostname.toStdString());

        QByteArray endpointInfo;
        endpointInfo.append(static_cast<char>(3 << 1)); // Laptop
        for (int i = 0; i < 16; i++) {
            endpointInfo.append(static_cast<char>(QRandomGenerator::global()->generate()));
        }
        QString deviceName = QSysInfo::machineHostName();
        if (deviceName.isEmpty()) deviceName = "CaelestiaClient";
        QByteArray nameBytes = deviceName.toUtf8();
        if (nameBytes.length() > 255) nameBytes.truncate(255);
        endpointInfo.append(static_cast<char>(nameBytes.length()));
        endpointInfo.append(nameBytes);

        req->set_endpoint_info(endpointInfo.constData(), endpointInfo.size());
        QByteArray request;
        request.resize(frame.ByteSizeLong());
        (void)frame.SerializeToArray(request.data(), static_cast<int>(request.size()));
        
        writeLengthPrefixed(m_socket, request);
        
        m_state = Ukey2Handshake;
        writeLengthPrefixed(m_socket, m_crypto.generateClientInit());
    });

    m_socket->connectToHost(host, static_cast<quint16>(port));
}

QuickShareConnection::~QuickShareConnection() {
    if (m_socket->isOpen()) {
        m_socket->close();
    }
}

void QuickShareConnection::sendFile(const QString& filePath) {
    if (m_state != ConnectionAccepted) return;
    
    QFileInfo fileInfo(filePath);
    if (!fileInfo.exists()) {
        qWarning() << "QuickShareConnection: File to send does not exist:" << filePath;
        emit transferFinished(false);
        return;
    }

    m_state = Transferring;
    emit stateChanged(m_state);

    sharing::nearby::Frame frame;
    frame.set_version(sharing::nearby::Frame::V1);
    auto* v1 = frame.mutable_v1();
    v1->set_type(sharing::nearby::V1Frame::INTRODUCTION);
    
    auto* intro = v1->mutable_introduction();
    auto* fileMeta = intro->add_file_metadata();
    fileMeta->set_name(fileInfo.fileName().toStdString());
    
    QMimeDatabase db;
    QMimeType mimeType = db.mimeTypeForFile(fileInfo);
    QString mimeString = mimeType.name();
    if (mimeString.isEmpty()) mimeString = "application/octet-stream";
    
    fileMeta->set_mime_type(mimeString.toStdString());
    
    if (mimeString.startsWith("image/")) {
        fileMeta->set_type(sharing::nearby::FileMetadata::IMAGE);
    } else if (mimeString.startsWith("video/")) {
        fileMeta->set_type(sharing::nearby::FileMetadata::VIDEO);
    } else if (mimeString.startsWith("audio/")) {
        fileMeta->set_type(sharing::nearby::FileMetadata::AUDIO);
    } else {
        fileMeta->set_type(sharing::nearby::FileMetadata::UNKNOWN);
    }
    
    fileMeta->set_size(fileInfo.size());
    
    qint64 filePayloadId = QRandomGenerator::global()->generate64();
    filePayloadId = qAbs(filePayloadId);
    fileMeta->set_payload_id(filePayloadId);
    fileMeta->set_id(filePayloadId);
    
    m_outgoingFilePayloadId = filePayloadId;
    m_outgoingFilePath = filePath;
    m_outgoingFileSize = fileInfo.size();

    sendEncryptedSharingFrame(frame);
}

void QuickShareConnection::sendEncryptedSharingFrame(sharing::nearby::V1Frame::FrameType type) {
    sharing::nearby::Frame frame;
    frame.set_version(sharing::nearby::Frame::V1);
    auto* v1 = frame.mutable_v1();
    v1->set_type(type);

    if (type == sharing::nearby::V1Frame::PAIRED_KEY_RESULT) {
        v1->mutable_paired_key_result()->set_status(sharing::nearby::PairedKeyResultFrame::UNABLE);
    } else if (type == sharing::nearby::V1Frame::PAIRED_KEY_ENCRYPTION) {
        QByteArray secretIdHash(6, 0);
        QByteArray signedData(72, 0);
        RAND_bytes(reinterpret_cast<unsigned char*>(secretIdHash.data()), 6);
        RAND_bytes(reinterpret_cast<unsigned char*>(signedData.data()), 72);
        v1->mutable_paired_key_encryption()->set_secret_id_hash(secretIdHash.constData(), 6);
        v1->mutable_paired_key_encryption()->set_signed_data(signedData.constData(), 72);
    } else if (type == sharing::nearby::V1Frame::RESPONSE) {
        v1->mutable_connection_response()->set_status(sharing::nearby::ConnectionResponseFrame::ACCEPT);
    }

    sendEncryptedSharingFrame(frame);
}

void QuickShareConnection::sendEncryptedSharingFrame(const sharing::nearby::Frame& frame) {
    QByteArray frameData;
    frameData.resize(frame.ByteSizeLong());
    (void)frame.SerializeToArray(frameData.data(), static_cast<int>(frameData.size()));

    qint64 payloadId = QRandomGenerator::global()->generate64();
    qint64 bodySize = frameData.size();

    location::nearby::connections::PayloadTransferFrame ptf1;
    auto* header1 = ptf1.mutable_payload_header();
    header1->set_id(payloadId);
    header1->set_type(location::nearby::connections::PayloadTransferFrame::PayloadHeader::BYTES);
    header1->set_total_size(bodySize);
    header1->set_is_sensitive(false);
    ptf1.set_packet_type(location::nearby::connections::PayloadTransferFrame::DATA);
    auto* chunk1 = ptf1.mutable_payload_chunk();
    chunk1->set_offset(0);
    chunk1->set_flags(0);
    chunk1->set_body(frameData.constData(), frameData.size());

    location::nearby::connections::OfflineFrame offline1;
    offline1.set_version(location::nearby::connections::OfflineFrame::V1);
    auto* v1a = offline1.mutable_v1();
    v1a->set_type(location::nearby::connections::V1Frame::PAYLOAD_TRANSFER);
    *v1a->mutable_payload_transfer() = ptf1;

    QByteArray out1;
    out1.resize(offline1.ByteSizeLong());
    (void)offline1.SerializeToArray(out1.data(), static_cast<int>(out1.size()));
    encryptAndSendOfflineFrameBytes(out1);

    location::nearby::connections::PayloadTransferFrame ptf2;
    auto* header2 = ptf2.mutable_payload_header();
    header2->set_id(payloadId);
    header2->set_type(location::nearby::connections::PayloadTransferFrame::PayloadHeader::BYTES);
    header2->set_total_size(bodySize);
    header2->set_is_sensitive(false);
    ptf2.set_packet_type(location::nearby::connections::PayloadTransferFrame::DATA);
    auto* chunk2 = ptf2.mutable_payload_chunk();
    chunk2->set_offset(bodySize);
    chunk2->set_flags(1);
    chunk2->set_body("");

    location::nearby::connections::OfflineFrame offline2;
    offline2.set_version(location::nearby::connections::OfflineFrame::V1);
    auto* v1b = offline2.mutable_v1();
    v1b->set_type(location::nearby::connections::V1Frame::PAYLOAD_TRANSFER);
    *v1b->mutable_payload_transfer() = ptf2;

    QByteArray out2;
    out2.resize(offline2.ByteSizeLong());
    (void)offline2.SerializeToArray(out2.data(), static_cast<int>(out2.size()));
    encryptAndSendOfflineFrameBytes(out2);
}

QByteArray QuickShareConnection::buildPayloadTransferFrame(const QByteArray& sharingFrameData, bool lastChunk, qint64 offset) {
    location::nearby::connections::PayloadTransferFrame ptf;

    auto* header = ptf.mutable_payload_header();
    header->set_id(QRandomGenerator::global()->generate());
    header->set_type(location::nearby::connections::PayloadTransferFrame::PayloadHeader::BYTES);
    header->set_total_size(sharingFrameData.size());
    header->set_is_sensitive(false);

    ptf.set_packet_type(location::nearby::connections::PayloadTransferFrame::DATA);

    auto* chunk = ptf.mutable_payload_chunk();
    chunk->set_offset(offset);
    chunk->set_flags(lastChunk ? 1 : 0);
    if (!sharingFrameData.isEmpty()) {
        chunk->set_body(sharingFrameData.constData(), sharingFrameData.size());
    }

    QByteArray out;
    out.resize(ptf.ByteSizeLong());
    (void)ptf.SerializeToArray(out.data(), static_cast<int>(out.size()));
    return out;
}

QByteArray QuickShareConnection::buildOfflineFrame(const QByteArray& payloadTransferData) {
    location::nearby::connections::OfflineFrame offlineFrame;
    offlineFrame.set_version(location::nearby::connections::OfflineFrame::V1);
    auto* v1 = offlineFrame.mutable_v1();
    v1->set_type(location::nearby::connections::V1Frame::PAYLOAD_TRANSFER);
    v1->mutable_payload_transfer()->ParseFromArray(payloadTransferData.constData(), payloadTransferData.size());

    QByteArray out;
    out.resize(offlineFrame.ByteSizeLong());
    (void)offlineFrame.SerializeToArray(out.data(), static_cast<int>(out.size()));
    return out;
}

void QuickShareConnection::encryptAndSendOfflineFrameBytes(const QByteArray& offlineFrameData) {
    writeLengthPrefixed(m_socket, wrapInSecureMessage(offlineFrameData));
}

void QuickShareConnection::acceptTransfer() {
    if (m_state != ConnectionAccepted) return;

    sendEncryptedSharingFrame(sharing::nearby::V1Frame::RESPONSE);
    m_state = Transferring;
    emit stateChanged(m_state);
}

void QuickShareConnection::rejectTransfer() {
    if (m_state != ConnectionAccepted) return;
    
    sharing::nearby::Frame frame;
    frame.set_version(sharing::nearby::Frame::V1);
    auto* v1s = frame.mutable_v1();
    v1s->set_type(sharing::nearby::V1Frame::RESPONSE);
    auto* respS = v1s->mutable_connection_response();
    respS->set_status(sharing::nearby::ConnectionResponseFrame::REJECT);
    sendEncryptedSharingFrame(frame);

    emit transferFinished(false);
}

void QuickShareConnection::onReadyRead() {
    m_buffer.append(m_socket->readAll());
    
    while (m_buffer.size() >= 4) {
        uint32_t length;
        memcpy(&length, m_buffer.constData(), 4);
        length = qFromBigEndian(length);
        
        if (static_cast<uint32_t>(m_buffer.size()) < 4 + length) {
            break;
        }
        
        QByteArray frameData = m_buffer.mid(4, length);
        m_buffer.remove(0, 4 + length);
        
        
        switch (m_state) {
            case OfflineFrameExchange:
                handleOfflineFrame(frameData);
                break;
            case Ukey2Handshake:
                handleUkey2(frameData);
                break;
            case PostHandshake:
                handlePostHandshake(frameData);
                break;
            case PairedKeyExchange:
            case ConnectionAccepted:
            case Transferring:
                handleEncryptedFrame(frameData);
                break;
            default:
                break;
        }
    }
}

void QuickShareConnection::handleOfflineFrame(const QByteArray& data) {
    location::nearby::connections::OfflineFrame frame;
    if (!frame.ParseFromArray(data.constData(), static_cast<int>(data.size()))) {
        qWarning() << "QuickShareConnection: Failed to parse initial OfflineFrame";
        return;
    }
    
    if (frame.has_v1() && frame.v1().has_connection_request()) {
        const auto& req = frame.v1().connection_request();
        if (req.has_endpoint_info()) {
            const auto& info = req.endpoint_info();
            if (info.size() >= 18) {
                const auto visibility = (static_cast<unsigned char>(info[0]) >> 3) & 0x01;
                if (visibility == 0) {
                    const int nameLen = static_cast<unsigned char>(info[17]);
                    if (nameLen > 0 && info.size() >= 18 + nameLen) {
                        m_deviceName = QString::fromUtf8(info.data() + 18, nameLen);
                    }
                }
            }
        }
        if (m_deviceName.isEmpty() && req.has_endpoint_name()) {
            m_deviceName = QString::fromUtf8(req.endpoint_name().data(), req.endpoint_name().size());
        }
    }
    
    m_state = Ukey2Handshake;
    emit stateChanged(m_state);
}

void QuickShareConnection::handleUkey2(const QByteArray& data) {
    if (!m_crypto.isHandshakeComplete()) {
        securegcm::Ukey2Message msg;
        if (msg.ParseFromArray(data.constData(), static_cast<int>(data.size()))) {
            if (msg.message_type() == securegcm::Ukey2Message::CLIENT_INIT) {
                QByteArray serverInit = m_crypto.processClientInit(data);
                if (serverInit.isEmpty()) {
                    qWarning() << "QuickShareConnection: m_crypto.processClientInit failed";
                } else {
                    writeLengthPrefixed(m_socket, serverInit);
                }
            } else if (msg.message_type() == securegcm::Ukey2Message::SERVER_INIT) {
                (void)m_crypto.processServerInit(data);
                QByteArray clientFinished = m_crypto.generateClientFinished();
                writeLengthPrefixed(m_socket, clientFinished);
                
                location::nearby::connections::OfflineFrame respFrame;
                respFrame.set_version(location::nearby::connections::OfflineFrame::V1);
                auto* v1 = respFrame.mutable_v1();
                v1->set_type(location::nearby::connections::V1Frame::CONNECTION_RESPONSE);
                auto* resp = v1->mutable_connection_response();
                resp->set_response(location::nearby::connections::ConnectionResponseFrame::ACCEPT);
                resp->mutable_os_info()->set_type(location::nearby::connections::OsInfo::LINUX);
                
                QByteArray responseData;
                responseData.resize(respFrame.ByteSizeLong());
                (void)respFrame.SerializeToArray(responseData.data(), static_cast<int>(responseData.size()));
                
                writeLengthPrefixed(m_socket, responseData);
                m_encryptionEnabled = true;

                m_state = PostHandshake;
                emit stateChanged(m_state);
            } else if (msg.message_type() == securegcm::Ukey2Message::CLIENT_FINISH) {
                if (!m_crypto.processClientFinished(data)) {
                    qWarning() << "QuickShareConnection: m_crypto.processClientFinished failed!";
                } else {
                    m_state = PostHandshake;
                    emit stateChanged(m_state);
                    QString pin = m_crypto.pinCode();
                    emit pinCodeReady(pin);
                }
            }
        } else {
            qWarning() << "QuickShareConnection: Failed to parse Ukey2Message!";
        }
    } else {
        qWarning() << "QuickShareConnection: Received Ukey2 message but handshake is already complete!";
    }
}

void QuickShareConnection::handlePostHandshake(const QByteArray& data) {
    location::nearby::connections::OfflineFrame frame;
    if (!frame.ParseFromArray(data.constData(), static_cast<int>(data.size()))) {
        qWarning() << "QuickShareConnection: Failed to parse plaintext CONNECTION_RESPONSE";
        return;
    }


    if (frame.v1().has_connection_response()) {
    } else {
    }

    // If we are the Server (receiver), we must send our CONNECTION_RESPONSE now.
    // If we are the Client (sender), we already sent it immediately after CLIENT_FINISH.
    if (!m_crypto.isClient()) {
        location::nearby::connections::OfflineFrame respFrame;
        respFrame.set_version(location::nearby::connections::OfflineFrame::V1);
        auto* v1 = respFrame.mutable_v1();
        v1->set_type(location::nearby::connections::V1Frame::CONNECTION_RESPONSE);
        auto* resp = v1->mutable_connection_response();
        resp->set_response(location::nearby::connections::ConnectionResponseFrame::ACCEPT);
        resp->mutable_os_info()->set_type(location::nearby::connections::OsInfo::LINUX);

        QByteArray responseData;
        responseData.resize(respFrame.ByteSizeLong());
        (void)respFrame.SerializeToArray(responseData.data(), static_cast<int>(responseData.size()));
        writeLengthPrefixed(m_socket, responseData);

        m_encryptionEnabled = true;
    }

    sendEncryptedSharingFrame(sharing::nearby::V1Frame::PAIRED_KEY_ENCRYPTION);

    m_state = PairedKeyExchange;
    emit stateChanged(m_state);
}

QByteArray QuickShareConnection::wrapInSecureMessage(const QByteArray& offlineFrameData) {
    securegcm::DeviceToDeviceMessage d2dMsg;
    d2dMsg.set_message(offlineFrameData.constData(), offlineFrameData.size());
    d2dMsg.set_sequence_number(m_sendSeq++);

    QByteArray d2dData;
    d2dData.resize(d2dMsg.ByteSizeLong());
    (void)d2dMsg.SerializeToArray(d2dData.data(), static_cast<int>(d2dData.size()));

    QByteArray iv;
    iv.resize(16);
    RAND_bytes(reinterpret_cast<unsigned char*>(iv.data()), 16);

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), nullptr,
        reinterpret_cast<const unsigned char*>(m_crypto.encodeKey().constData()),
        reinterpret_cast<const unsigned char*>(iv.constData()));

    QByteArray ciphertext;
    ciphertext.resize(d2dData.size() + EVP_CIPHER_block_size(EVP_aes_256_cbc()));
    int len1 = 0, len2 = 0;
    EVP_EncryptUpdate(ctx, reinterpret_cast<unsigned char*>(ciphertext.data()), &len1,
        reinterpret_cast<const unsigned char*>(d2dData.constData()), d2dData.size());
    EVP_EncryptFinal_ex(ctx, reinterpret_cast<unsigned char*>(ciphertext.data()) + len1, &len2);
    EVP_CIPHER_CTX_free(ctx);
    ciphertext.resize(len1 + len2);

    securemessage::Header header;
    header.set_signature_scheme(securemessage::HMAC_SHA256);
    header.set_encryption_scheme(securemessage::AES_256_CBC);
    header.set_iv(iv.constData(), iv.size());

    securegcm::GcmMetadata metadata;
    metadata.set_type(securegcm::DEVICE_TO_DEVICE_MESSAGE);
    metadata.set_version(1);
    QByteArray metadataBytes;
    metadataBytes.resize(metadata.ByteSizeLong());
    (void)metadata.SerializeToArray(metadataBytes.data(), static_cast<int>(metadataBytes.size()));
    header.set_public_metadata(metadataBytes.constData(), metadataBytes.size());

    securemessage::HeaderAndBody headerAndBody;
    *headerAndBody.mutable_header() = header;
    headerAndBody.set_body(ciphertext.constData(), ciphertext.size());

    QByteArray headerAndBodyBytes;
    headerAndBodyBytes.resize(headerAndBody.ByteSizeLong());
    (void)headerAndBody.SerializeToArray(headerAndBodyBytes.data(), static_cast<int>(headerAndBodyBytes.size()));

    unsigned char hmacResult[32];
    unsigned int hmacLen = 0;
    HMAC(EVP_sha256(),
        m_crypto.hmacEncodeKey().constData(), static_cast<int>(m_crypto.hmacEncodeKey().size()),
        reinterpret_cast<const unsigned char*>(headerAndBodyBytes.constData()), headerAndBodyBytes.size(),
        hmacResult, &hmacLen);

    securemessage::SecureMessage secMsg;
    secMsg.set_header_and_body(headerAndBodyBytes.constData(), headerAndBodyBytes.size());
    secMsg.set_signature(hmacResult, hmacLen);

    QByteArray out;
    out.resize(secMsg.ByteSizeLong());
    (void)secMsg.SerializeToArray(out.data(), static_cast<int>(out.size()));
    return out;
}

QByteArray QuickShareConnection::unwrapSecureMessage(const QByteArray& secureMessageData) {
    securemessage::SecureMessage secMsg;
    if (!secMsg.ParseFromArray(secureMessageData.constData(), static_cast<int>(secureMessageData.size()))) {
        qWarning() << "QuickShareConnection: Failed to parse SecureMessage";
        return QByteArray();
    }

    const QByteArray headerAndBodyBytes(secMsg.header_and_body().data(), secMsg.header_and_body().size());

    unsigned char hmacResult[32];
    unsigned int hmacLen = 0;
    HMAC(EVP_sha256(),
        m_crypto.hmacDecodeKey().constData(), static_cast<int>(m_crypto.hmacDecodeKey().size()),
        reinterpret_cast<const unsigned char*>(headerAndBodyBytes.constData()), headerAndBodyBytes.size(),
        hmacResult, &hmacLen);

    if (static_cast<int>(hmacLen) != secMsg.signature().size() ||
        memcmp(hmacResult, secMsg.signature().data(), hmacLen) != 0) {
        qWarning() << "QuickShareConnection: HMAC verification failed";
        return QByteArray();
    }

    securemessage::HeaderAndBody headerAndBody;
    if (!headerAndBody.ParseFromArray(headerAndBodyBytes.constData(), static_cast<int>(headerAndBodyBytes.size()))) {
        qWarning() << "QuickShareConnection: Failed to parse HeaderAndBody";
        return QByteArray();
    }

    const auto& header = headerAndBody.header();
    QByteArray iv(header.iv().data(), header.iv().size());
    QByteArray ciphertext(headerAndBody.body().data(), headerAndBody.body().size());

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    EVP_DecryptInit_ex(ctx, EVP_aes_256_cbc(), nullptr,
        reinterpret_cast<const unsigned char*>(m_crypto.decodeKey().constData()),
        reinterpret_cast<const unsigned char*>(iv.constData()));

    QByteArray plaintext;
    plaintext.resize(ciphertext.size() + EVP_CIPHER_block_size(EVP_aes_256_cbc()));
    int len1 = 0, len2 = 0;
    EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char*>(plaintext.data()), &len1,
        reinterpret_cast<const unsigned char*>(ciphertext.constData()), ciphertext.size());
    EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char*>(plaintext.data()) + len1, &len2);
    EVP_CIPHER_CTX_free(ctx);
    plaintext.resize(len1 + len2);

    securegcm::DeviceToDeviceMessage d2dMsg;
    if (!d2dMsg.ParseFromArray(plaintext.constData(), static_cast<int>(plaintext.size()))) {
        qWarning() << "QuickShareConnection: Failed to parse DeviceToDeviceMessage";
        return QByteArray();
    }

    return QByteArray(d2dMsg.message().data(), d2dMsg.message().size());
}

void QuickShareConnection::handleEncryptedFrame(const QByteArray& data) {
    QByteArray plaintext = unwrapSecureMessage(data);
    if (plaintext.isEmpty()) {
        qWarning() << "QuickShareConnection: Failed to unwrap encrypted frame";
        return;
    }

    location::nearby::connections::OfflineFrame offlineFrame;
    if (!offlineFrame.ParseFromArray(plaintext.constData(), static_cast<int>(plaintext.size()))) {
        qWarning() << "QuickShareConnection: Failed to parse OfflineFrame from decrypted data";
        return;
    }

    const auto& v1 = offlineFrame.v1();
    if (v1.has_payload_transfer()) {
        handlePayloadTransfer(plaintext);
    } else if (v1.type() == location::nearby::connections::V1Frame::KEEP_ALIVE) {
    } else if (v1.type() == location::nearby::connections::V1Frame::DISCONNECTION) {
        if (v1.has_disconnection() && v1.disconnection().has_request_safe_to_disconnect()) {
        }
        emit transferFinished(true);
    } else {
    }
}

void QuickShareConnection::handlePayloadTransfer(const QByteArray& plaintext) {
    location::nearby::connections::OfflineFrame offlineFrame;
    if (!offlineFrame.ParseFromArray(plaintext.constData(), static_cast<int>(plaintext.size()))) return;

    const auto& payloadTransfer = offlineFrame.v1().payload_transfer();
    const auto& payloadHeader = payloadTransfer.payload_header();
    const auto& payloadChunk = payloadTransfer.payload_chunk();

    qint64 payloadId = payloadHeader.id();
    QByteArray chunkBody(payloadChunk.body().data(), payloadChunk.body().size());

    if (payloadHeader.type() == location::nearby::connections::PayloadTransferFrame::PayloadHeader::FILE) {
        if (!m_fileTransferActive) {
            m_fileTransferActive = true;
            m_fileBuffer.clear();
        }

        if (payloadChunk.offset() != m_fileBuffer.size()) {
            return;
        }

        if (!chunkBody.isEmpty()) {
            m_fileBuffer.append(chunkBody);
        }

        emit transferProgress(m_fileBuffer.size(), m_incomingFileSize);

        if ((payloadChunk.flags() & 1) == 1) {
            QString savePath = QDir::homePath() + "/Downloads/" + m_incomingFileName;
            QFile file(savePath);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(m_fileBuffer);
                file.close();
            } else {
                qWarning() << "QuickShareConnection: Failed to save file to" << savePath;
            }
            m_fileTransferActive = false;
            m_fileBuffer.clear();
            emit transferFinished(true);
        }

        return;
    }

    if (!m_payloadBuffers.contains(payloadId)) {
        m_payloadBuffers[payloadId] = QByteArray();
        m_payloadTotalSizes[payloadId] = payloadHeader.total_size();
    }

    if (payloadChunk.offset() != m_payloadBuffers[payloadId].size()) {
        return;
    }

    if (!chunkBody.isEmpty()) {
        m_payloadBuffers[payloadId].append(chunkBody);
    }

    if ((payloadChunk.flags() & 1) == 1) {

        if (!m_payloadBuffers[payloadId].isEmpty()) {
            QByteArray buf = m_payloadBuffers[payloadId];
            QString hex;
            for (int i = 0; i < qMin(buf.size(), 64); ++i)
                hex += QString("%1 ").arg(static_cast<uchar>(buf[i]), 2, 16, QChar('0'));

            sharing::nearby::Frame frame;
            if (frame.ParseFromArray(m_payloadBuffers[payloadId].constData(), m_payloadBuffers[payloadId].size())) {

                switch (frame.v1().type()) {
                    case sharing::nearby::V1Frame::PAIRED_KEY_ENCRYPTION: {
                        sendEncryptedSharingFrame(sharing::nearby::V1Frame::PAIRED_KEY_RESULT);
                        break;
                    }
                    case sharing::nearby::V1Frame::PAIRED_KEY_RESULT: {
                        if (m_state != ConnectionAccepted) {
                            m_state = ConnectionAccepted;
                            emit stateChanged(m_state);
                        }
                        break;
                    }
                    case sharing::nearby::V1Frame::INTRODUCTION: {
                        const auto& intro = frame.v1().introduction();
                        if (intro.file_metadata_size() > 0) {
                            const auto& fileMeta = intro.file_metadata(0);
                            m_incomingFileName = QString::fromStdString(fileMeta.name());
                            m_incomingFileSize = fileMeta.size();
                            emit transferRequested(m_incomingFileName, m_incomingFileSize);
                        }
                        break;
                    }
                    case sharing::nearby::V1Frame::RESPONSE: {
                        const auto& resp = frame.v1().connection_response();
                        if (resp.status() == sharing::nearby::ConnectionResponseFrame::ACCEPT) {
                            if (!m_outgoingFilePath.isEmpty()) {
                                
                                QFile file(m_outgoingFilePath);
                                if (file.open(QIODevice::ReadOnly)) {
                                    qint64 offset = 0;
                                    const qint64 CHUNK_SIZE = 1024 * 1024; // 1MB chunks
                                    
                                    while (!file.atEnd()) {
                                        QByteArray fileData = file.read(CHUNK_SIZE);
                                        
                                        location::nearby::connections::PayloadTransferFrame ptfFile;
                                        auto* headerF = ptfFile.mutable_payload_header();
                                        headerF->set_id(m_outgoingFilePayloadId);
                                        headerF->set_type(location::nearby::connections::PayloadTransferFrame::PayloadHeader::FILE);
                                        headerF->set_total_size(m_outgoingFileSize);
                                        headerF->set_is_sensitive(false);
                                        headerF->set_file_name(QFileInfo(m_outgoingFilePath).fileName().toStdString());
                                        
                                        ptfFile.set_packet_type(location::nearby::connections::PayloadTransferFrame::DATA);
                                        auto* chunkF = ptfFile.mutable_payload_chunk();
                                        chunkF->set_offset(offset);
                                        chunkF->set_flags(0);
                                        chunkF->set_body(fileData.constData(), fileData.size());
                                        
                                        location::nearby::connections::OfflineFrame offlineFile;
                                        offlineFile.set_version(location::nearby::connections::OfflineFrame::V1);
                                        auto* v1F = offlineFile.mutable_v1();
                                        v1F->set_type(location::nearby::connections::V1Frame::PAYLOAD_TRANSFER);
                                        *v1F->mutable_payload_transfer() = ptfFile;
                                        
                                        QByteArray outFile;
                                        outFile.resize(offlineFile.ByteSizeLong());
                                        (void)offlineFile.SerializeToArray(outFile.data(), static_cast<int>(outFile.size()));
                                        encryptAndSendOfflineFrameBytes(outFile);
                                        
                                        offset += fileData.size();
                                        emit transferProgress(offset, m_outgoingFileSize);
                                    }
                                    file.close();
                                    
                                    // Send empty last chunk
                                    location::nearby::connections::PayloadTransferFrame ptfLast;
                                    auto* headerL = ptfLast.mutable_payload_header();
                                    headerL->set_id(m_outgoingFilePayloadId);
                                    headerL->set_type(location::nearby::connections::PayloadTransferFrame::PayloadHeader::FILE);
                                    headerL->set_total_size(m_outgoingFileSize);
                                    headerL->set_is_sensitive(false);
                                    headerL->set_file_name(QFileInfo(m_outgoingFilePath).fileName().toStdString());
                                    
                                    ptfLast.set_packet_type(location::nearby::connections::PayloadTransferFrame::DATA);
                                    auto* chunkL = ptfLast.mutable_payload_chunk();
                                    chunkL->set_offset(m_outgoingFileSize);
                                    chunkL->set_flags(1); // LAST_CHUNK
                                    chunkL->set_body("");
                                    
                                    location::nearby::connections::OfflineFrame offlineLast;
                                    offlineLast.set_version(location::nearby::connections::OfflineFrame::V1);
                                    auto* v1L = offlineLast.mutable_v1();
                                    v1L->set_type(location::nearby::connections::V1Frame::PAYLOAD_TRANSFER);
                                    *v1L->mutable_payload_transfer() = ptfLast;
                                    
                                    QByteArray outLast;
                                    outLast.resize(offlineLast.ByteSizeLong());
                                    (void)offlineLast.SerializeToArray(outLast.data(), static_cast<int>(outLast.size()));
                                    encryptAndSendOfflineFrameBytes(outLast);
                                    
                                    // Send Disconnection
                                    location::nearby::connections::OfflineFrame offlineDisc;
                                    offlineDisc.set_version(location::nearby::connections::OfflineFrame::V1);
                                    auto* v1Disc = offlineDisc.mutable_v1();
                                    v1Disc->set_type(location::nearby::connections::V1Frame::DISCONNECTION);
                                    v1Disc->mutable_disconnection(); // Create empty disconnection frame
                                    
                                    QByteArray discBytes;
                                    discBytes.resize(offlineDisc.ByteSizeLong());
                                    (void)offlineDisc.SerializeToArray(discBytes.data(), static_cast<int>(discBytes.size()));
                                    encryptAndSendOfflineFrameBytes(discBytes);
                                    
                                    emit transferFinished(true);
                                } else {
                                    qWarning() << "QuickShareConnection: Failed to open file to send!";
                                    emit transferFinished(false);
                                }
                            } else {
                            }
                        } else {
                            emit transferFinished(false);
                        }
                        break;
                    }
                    default:
                        break;
                }
            } else {
            }
        }

        m_payloadBuffers.remove(payloadId);
        m_payloadTotalSizes.remove(payloadId);
    }
}

void QuickShareConnection::onDisconnected() {
    m_state = Disconnected;
    emit stateChanged(m_state);
}

void QuickShareConnection::onError(QAbstractSocket::SocketError socketError) {
    Q_UNUSED(socketError);
    qWarning() << "QuickShareConnection error:" << m_socket->errorString();
    emit transferFinished(false);
}

} // namespace caelestia::services
