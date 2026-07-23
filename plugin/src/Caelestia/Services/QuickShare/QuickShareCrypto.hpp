#pragma once

#include <QByteArray>
#include <QString>
#include <openssl/evp.h>

namespace caelestia::services {

class QuickShareCrypto {
public:
    QuickShareCrypto();
    ~QuickShareCrypto();

    void initClient();
    void initServer();

    QByteArray processClientInit(const QByteArray& data);
    QByteArray processServerInit(const QByteArray& data);
    bool processClientFinished(const QByteArray& data);
    
    QByteArray generateClientInit();
    QByteArray generateServerInit();
    QByteArray generateClientFinished();

    QByteArray encryptPayload(const QByteArray& plaintext);
    QByteArray decryptPayload(const QByteArray& ciphertext);

    bool isHandshakeComplete() const { return m_handshakeComplete; }
    bool isClient() const { return !m_isServer; }

    QByteArray encodeKey() const { return m_encodeKey; }
    QByteArray decodeKey() const { return m_decodeKey; }
    QByteArray hmacEncodeKey() const { return m_hmacEncodeKey; }
    QByteArray hmacDecodeKey() const { return m_hmacDecodeKey; }

    QString pinCode() const;

private:
    void generateDhKeypair();
    void deriveKeys(const QByteArray& peerPublicKeyBytes);
    QByteArray extractSharedSecret(EVP_PKEY* peerKey);

    bool m_handshakeComplete = false;
    bool m_isServer = false;
    
    EVP_PKEY* m_dhKey = nullptr;

    QByteArray m_clientInitMsgData;
    QByteArray m_serverInitMsgData;
    QByteArray m_clientFinishedMsgData;
    
    QByteArray m_encodeKey;
    QByteArray m_decodeKey;
    QByteArray m_hmacEncodeKey;
    QByteArray m_hmacDecodeKey;
    QByteArray m_authString;
};

} // namespace caelestia::services
