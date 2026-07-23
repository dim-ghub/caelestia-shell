#include "QuickShareCrypto.hpp"
#include <QDebug>
#include <string>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/kdf.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <openssl/ec.h>
#include <openssl/obj_mac.h>
#include "ukey.pb.h"
#include "securemessage.pb.h"

namespace caelestia::services {

static QByteArray hkdfInternal(const EVP_MD* md, const QByteArray& salt, const QByteArray& ikm, const QByteArray& info, size_t outLen) {
    EVP_PKEY_CTX *pctx = EVP_PKEY_CTX_new_id(EVP_PKEY_HKDF, nullptr);
    if (!pctx) return QByteArray();
    if (EVP_PKEY_derive_init(pctx) <= 0) { EVP_PKEY_CTX_free(pctx); return QByteArray(); }
    if (EVP_PKEY_CTX_set_hkdf_md(pctx, md) <= 0) { EVP_PKEY_CTX_free(pctx); return QByteArray(); }
    if (!salt.isEmpty()) {
        if (EVP_PKEY_CTX_set1_hkdf_salt(pctx, reinterpret_cast<const unsigned char*>(salt.constData()), salt.size()) <= 0) {
            EVP_PKEY_CTX_free(pctx); return QByteArray();
        }
    }
    if (EVP_PKEY_CTX_set1_hkdf_key(pctx, reinterpret_cast<const unsigned char*>(ikm.constData()), ikm.size()) <= 0) {
        EVP_PKEY_CTX_free(pctx); return QByteArray();
    }
    if (!info.isEmpty()) {
        if (EVP_PKEY_CTX_add1_hkdf_info(pctx, reinterpret_cast<const unsigned char*>(info.constData()), info.size()) <= 0) {
            EVP_PKEY_CTX_free(pctx); return QByteArray();
        }
    }
    QByteArray out;
    out.resize(outLen);
    size_t out_len = outLen;
    if (EVP_PKEY_derive(pctx, reinterpret_cast<unsigned char*>(out.data()), &out_len) <= 0) {
        EVP_PKEY_CTX_free(pctx); return QByteArray();
    }
    EVP_PKEY_CTX_free(pctx);
    return out;
}

static QByteArray hkdfSha512(const QByteArray& salt, const QByteArray& ikm, const QByteArray& info, size_t outLen) {
    return hkdfInternal(EVP_sha512(), salt, ikm, info, outLen);
}

static QByteArray hkdfSha256(const QByteArray& salt, const QByteArray& ikm, const QByteArray& info, size_t outLen) {
    return hkdfInternal(EVP_sha256(), salt, ikm, info, outLen);
}

QuickShareCrypto::QuickShareCrypto() {
}

QuickShareCrypto::~QuickShareCrypto() {
    if (m_dhKey) {
        EVP_PKEY_free(m_dhKey);
    }
}

void QuickShareCrypto::generateDhKeypair() {
    if (m_dhKey) {
        EVP_PKEY_free(m_dhKey);
        m_dhKey = nullptr;
    }
    EVP_PKEY_CTX *pctx = EVP_PKEY_CTX_new_id(EVP_PKEY_EC, nullptr);
    EVP_PKEY_keygen_init(pctx);
    EVP_PKEY_CTX_set_ec_paramgen_curve_nid(pctx, NID_X9_62_prime256v1);
    EVP_PKEY_keygen(pctx, &m_dhKey);
    EVP_PKEY_CTX_free(pctx);
}

void QuickShareCrypto::deriveKeys(const QByteArray& peerPublicKeyBytes) {
    EVP_PKEY* peerKey = nullptr;
    EC_GROUP* group = EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1);
    if (group) {
        EC_POINT* point = EC_POINT_new(group);
        if (point) {
            if (EC_POINT_oct2point(group, point, reinterpret_cast<const unsigned char*>(peerPublicKeyBytes.constData()), peerPublicKeyBytes.size(), nullptr)) {
                EC_KEY* ecKey = EC_KEY_new();
                EC_KEY_set_group(ecKey, group);
                EC_KEY_set_public_key(ecKey, point);
                peerKey = EVP_PKEY_new();
                EVP_PKEY_assign_EC_KEY(peerKey, ecKey);
            }
            EC_POINT_free(point);
        }
        EC_GROUP_free(group);
    }
    
    QByteArray sharedSecret = extractSharedSecret(peerKey);


    if (peerKey) {
        EVP_PKEY_free(peerKey);
    }

    QByteArray derivedSecret;
    derivedSecret.resize(32);
    unsigned int mdLen = 0;
    EVP_MD_CTX* mdctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(mdctx, EVP_sha256(), nullptr);
    EVP_DigestUpdate(mdctx, sharedSecret.constData(), sharedSecret.size());
    EVP_DigestFinal_ex(mdctx, reinterpret_cast<unsigned char*>(derivedSecret.data()), &mdLen);
    EVP_MD_CTX_free(mdctx);

    QByteArray ukeyInfo = m_clientInitMsgData + m_serverInitMsgData;
    
    QByteArray authString = hkdfSha256("UKEY2 v1 auth", derivedSecret, ukeyInfo, 32);
    QByteArray nextSecret = hkdfSha256("UKEY2 v1 next", derivedSecret, ukeyInfo, 32);

    m_authString = authString;

    
    QByteArray salt1 = QByteArray::fromHex("82AA55A0D397F88346CA1CEE8D3909B95F13FA7DEB1D4AB38376B8256DA85510");
    QByteArray d2dClient = hkdfSha256(salt1, nextSecret, QByteArray("client"), 32);
    QByteArray d2dServer = hkdfSha256(salt1, nextSecret, QByteArray("server"), 32);


    QByteArray salt2 = QByteArray::fromHex("BF9D2A53C63616D75DB0A7165B91C1EF73E537F2427405FA23610A4BE657642E");
    QByteArray clientKey = hkdfSha256(salt2, d2dClient, QByteArray("ENC:2"), 32);
    QByteArray clientHmacKey = hkdfSha256(salt2, d2dClient, QByteArray("SIG:1"), 32);
    QByteArray serverKey = hkdfSha256(salt2, d2dServer, QByteArray("ENC:2"), 32);
    QByteArray serverHmacKey = hkdfSha256(salt2, d2dServer, QByteArray("SIG:1"), 32);

    if (m_isServer) {
        m_encodeKey = serverKey;
        m_hmacEncodeKey = serverHmacKey;
        m_decodeKey = clientKey;
        m_hmacDecodeKey = clientHmacKey;
    } else {
        m_encodeKey = clientKey;
        m_hmacEncodeKey = clientHmacKey;
        m_decodeKey = serverKey;
        m_hmacDecodeKey = serverHmacKey;
    }
}

QString QuickShareCrypto::pinCode() const {
    const int kHashModulo = 9973;
    const int kHashBaseMultiplier = 31;

    int hash = 0;
    int multiplier = 1;
    for (unsigned char byte : m_authString) {
        int signedByte = static_cast<int>(static_cast<signed char>(byte));
        hash = (hash + signedByte * multiplier) % kHashModulo;
        multiplier = (multiplier * kHashBaseMultiplier) % kHashModulo;
    }

    return QString("%1").arg(abs(hash), 4, 10, QChar('0'));
}

QByteArray QuickShareCrypto::extractSharedSecret(EVP_PKEY* peerKey) {
    if (!m_dhKey || !peerKey) return QByteArray();
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(m_dhKey, nullptr);
    EVP_PKEY_derive_init(ctx);
    EVP_PKEY_derive_set_peer(ctx, peerKey);
    size_t secretLen = 0;
    EVP_PKEY_derive(ctx, nullptr, &secretLen);
    QByteArray secret;
    secret.resize(secretLen);
    EVP_PKEY_derive(ctx, (unsigned char*)secret.data(), &secretLen);
    EVP_PKEY_CTX_free(ctx);
    return secret;
}

void QuickShareCrypto::initClient() {
    m_isServer = false;
    m_handshakeComplete = false;
    generateDhKeypair();
}

void QuickShareCrypto::initServer() {
    m_isServer = true;
    m_handshakeComplete = false;
    generateDhKeypair();
}

QByteArray QuickShareCrypto::processClientInit(const QByteArray& data) {
    m_clientInitMsgData = data;
    securegcm::Ukey2Message msg;
    if (!msg.ParseFromArray(data.constData(), data.size())) return QByteArray();
    if (msg.message_type() != securegcm::Ukey2Message::CLIENT_INIT) return QByteArray();

    securegcm::Ukey2ClientInit clientInit;
    if (!clientInit.ParseFromString(msg.message_data())) return QByteArray();
    
    return generateServerInit();
}

QByteArray QuickShareCrypto::processServerInit(const QByteArray& data) {
    m_serverInitMsgData = data;
    securegcm::Ukey2Message msg;
    if (!msg.ParseFromArray(data.constData(), data.size())) return QByteArray();
    if (msg.message_type() != securegcm::Ukey2Message::SERVER_INIT) return QByteArray();

    securegcm::Ukey2ServerInit serverInit;
    if (!serverInit.ParseFromString(msg.message_data())) return QByteArray();

    securemessage::GenericPublicKey genericPubKey;
    if (!genericPubKey.ParseFromString(serverInit.public_key())) return QByteArray();
    if (genericPubKey.type() != securemessage::EC_P256) return QByteArray();

    std::string xRaw = genericPubKey.ec_p256_public_key().x();
    std::string yRaw = genericPubKey.ec_p256_public_key().y();
    if (xRaw.size() == 33 && xRaw[0] == '\0') {
        xRaw.erase(xRaw.begin());
    }
    if (yRaw.size() == 33 && yRaw[0] == '\0') {
        yRaw.erase(yRaw.begin());
    }

    QByteArray peerPublicKeyBytes;
    peerPublicKeyBytes.append(static_cast<char>(0x04));
    peerPublicKeyBytes.append(xRaw.data(), xRaw.size());
    peerPublicKeyBytes.append(yRaw.data(), yRaw.size());

    deriveKeys(peerPublicKeyBytes);
    m_handshakeComplete = true;
    return generateClientFinished();
}

bool QuickShareCrypto::processClientFinished(const QByteArray& data) {
    securegcm::Ukey2Message msg;
    if (!msg.ParseFromArray(data.constData(), data.size())) return false;
    if (msg.message_type() != securegcm::Ukey2Message::CLIENT_FINISH) return false;

    securegcm::Ukey2ClientFinished clientFinished;
    if (!clientFinished.ParseFromString(msg.message_data())) return false;

    securemessage::GenericPublicKey genericPubKey;
    if (!genericPubKey.ParseFromString(clientFinished.public_key())) return false;
    if (genericPubKey.type() != securemessage::EC_P256) return false;
    
    std::string xRaw2 = genericPubKey.ec_p256_public_key().x();
    std::string yRaw2 = genericPubKey.ec_p256_public_key().y();
    if (xRaw2.size() == 33 && xRaw2[0] == '\0') {
        xRaw2.erase(xRaw2.begin());
    }
    if (yRaw2.size() == 33 && yRaw2[0] == '\0') {
        yRaw2.erase(yRaw2.begin());
    }

    QByteArray peerPublicKeyBytes;
    peerPublicKeyBytes.append(static_cast<char>(0x04));
    peerPublicKeyBytes.append(xRaw2.data(), xRaw2.size());
    peerPublicKeyBytes.append(yRaw2.data(), yRaw2.size());

    deriveKeys(peerPublicKeyBytes);
    
    m_handshakeComplete = true;
    return true;
}

QByteArray QuickShareCrypto::generateClientInit() {
    securegcm::Ukey2ClientFinished clientFinished;
    if (m_dhKey) {
        EC_KEY* ecKey = EVP_PKEY_get1_EC_KEY(m_dhKey);
        if (ecKey) {
            const EC_GROUP* group = EC_KEY_get0_group(ecKey);
            const EC_POINT* point = EC_KEY_get0_public_key(ecKey);
            size_t len = EC_POINT_point2oct(group, point, POINT_CONVERSION_UNCOMPRESSED, nullptr, 0, nullptr);
            QByteArray pubKeyBytes(len, '\0');
            EC_POINT_point2oct(group, point, POINT_CONVERSION_UNCOMPRESSED,
                reinterpret_cast<unsigned char*>(pubKeyBytes.data()), len, nullptr);

            QByteArray xRaw = pubKeyBytes.mid(1, 32);
            QByteArray yRaw = pubKeyBytes.mid(33, 32);

            std::string xEncoded;
            if (static_cast<unsigned char>(xRaw[0]) >= 0x80)
                xEncoded += '\0';
            xEncoded.append(xRaw.constData(), 32);

            std::string yEncoded;
            if (static_cast<unsigned char>(yRaw[0]) >= 0x80)
                yEncoded += '\0';
            yEncoded.append(yRaw.constData(), 32);

            securemessage::EcP256PublicKey ecPubKey;
            ecPubKey.set_x(xEncoded);
            ecPubKey.set_y(yEncoded);

            securemessage::GenericPublicKey genericPubKey;
            genericPubKey.set_type(securemessage::EC_P256);
            *genericPubKey.mutable_ec_p256_public_key() = ecPubKey;

            QByteArray serializedGenPubKey;
            serializedGenPubKey.resize(genericPubKey.ByteSizeLong());
            genericPubKey.SerializeToArray(serializedGenPubKey.data(), serializedGenPubKey.size());
            clientFinished.set_public_key(serializedGenPubKey.constData(), serializedGenPubKey.size());
            EC_KEY_free(ecKey);
        }
    }

    std::string clientFinishedData = clientFinished.SerializeAsString();

    securegcm::Ukey2Message finishFrame;
    finishFrame.set_message_type(securegcm::Ukey2Message::CLIENT_FINISH);
    finishFrame.set_message_data(clientFinishedData);

    std::string finishFrameSerialized = finishFrame.SerializeAsString();

    m_clientFinishedMsgData = QByteArray::fromStdString(finishFrameSerialized);

    unsigned char hash[SHA512_DIGEST_LENGTH];
    SHA512(reinterpret_cast<const unsigned char*>(finishFrameSerialized.data()),
           finishFrameSerialized.size(), hash);

    {
        QString hex;
        for (int i = 0; i < SHA512_DIGEST_LENGTH; ++i)
            hex += QString("%1").arg(hash[i], 2, 16, QChar('0'));
    }

    securegcm::Ukey2ClientInit clientInit;
    clientInit.set_version(1);
    QByteArray randData;
    randData.resize(32);
    RAND_bytes((unsigned char*)randData.data(), 32);
    clientInit.set_random(randData.constData(), 32);
    clientInit.set_next_protocol("AES_256_CBC-HMAC_SHA256");

    auto* commit = clientInit.add_cipher_commitments();
    commit->set_handshake_cipher(securegcm::P256_SHA512);
    commit->set_commitment(reinterpret_cast<const char*>(hash), SHA512_DIGEST_LENGTH);

    securegcm::Ukey2Message msg;
    msg.set_message_type(securegcm::Ukey2Message::CLIENT_INIT);
    msg.set_message_data(clientInit.SerializeAsString());

    QByteArray out;
    out.resize(msg.ByteSizeLong());
    msg.SerializeToArray(out.data(), out.size());
    m_clientInitMsgData = out;
    return out;
}

QByteArray QuickShareCrypto::generateServerInit() {
    securegcm::Ukey2ServerInit serverInit;
    serverInit.set_version(1);
    QByteArray randData;
    randData.resize(32);
    RAND_bytes((unsigned char*)randData.data(), 32);
    serverInit.set_random(randData.constData(), 32);
    serverInit.set_handshake_cipher(securegcm::P256_SHA512);

    EVP_PKEY* pkey = m_dhKey;
    if (pkey) {
        EC_KEY* ecKey = EVP_PKEY_get1_EC_KEY(pkey);
        if (ecKey) {
            const EC_GROUP* group = EC_KEY_get0_group(ecKey);
            const EC_POINT* point = EC_KEY_get0_public_key(ecKey);
            size_t len = EC_POINT_point2oct(group, point, POINT_CONVERSION_UNCOMPRESSED, nullptr, 0, nullptr);
            QByteArray pubKeyBytes;
            pubKeyBytes.resize(len);
            EC_POINT_point2oct(group, point, POINT_CONVERSION_UNCOMPRESSED, reinterpret_cast<unsigned char*>(pubKeyBytes.data()), len, nullptr);
            
            QByteArray xRaw = pubKeyBytes.mid(1, 32);
            QByteArray yRaw = pubKeyBytes.mid(33, 32);

            std::string xEncoded;
            if (static_cast<unsigned char>(xRaw[0]) >= 0x80) {
                xEncoded += '\0';
            }
            xEncoded.append(xRaw.constData(), 32);

            std::string yEncoded;
            if (static_cast<unsigned char>(yRaw[0]) >= 0x80) {
                yEncoded += '\0';
            }
            yEncoded.append(yRaw.constData(), 32);

            securemessage::EcP256PublicKey ecPubKey;
            ecPubKey.set_x(xEncoded);
            ecPubKey.set_y(yEncoded);
            
            securemessage::GenericPublicKey genericPubKey;
            genericPubKey.set_type(securemessage::EC_P256);
            *genericPubKey.mutable_ec_p256_public_key() = ecPubKey;
            
            QByteArray serializedGenPubKey;
            serializedGenPubKey.resize(genericPubKey.ByteSizeLong());
            genericPubKey.SerializeToArray(serializedGenPubKey.data(), serializedGenPubKey.size());
            
            serverInit.set_public_key(serializedGenPubKey.constData(), serializedGenPubKey.size());
            EC_KEY_free(ecKey);
        }
    }

    securegcm::Ukey2Message msg;
    msg.set_message_type(securegcm::Ukey2Message::SERVER_INIT);
    msg.set_message_data(serverInit.SerializeAsString());

    QByteArray out;
    out.resize(msg.ByteSizeLong());
    msg.SerializeToArray(out.data(), out.size());
    m_serverInitMsgData = out;
    return out;
}

QByteArray QuickShareCrypto::generateClientFinished() {
    return m_clientFinishedMsgData;
}

QByteArray QuickShareCrypto::encryptPayload(const QByteArray& plaintext) {
    if (!m_handshakeComplete) return plaintext;
    
    QByteArray iv;
    iv.resize(16);
    RAND_bytes((unsigned char*)iv.data(), iv.size());

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), nullptr, (const unsigned char*)m_encodeKey.constData(), (const unsigned char*)iv.constData());
    
    QByteArray ciphertext;
    ciphertext.resize(plaintext.size() + EVP_CIPHER_block_size(EVP_aes_256_cbc()));
    int len1 = 0, len2 = 0;
    EVP_EncryptUpdate(ctx, (unsigned char*)ciphertext.data(), &len1, (const unsigned char*)plaintext.constData(), plaintext.size());
    EVP_EncryptFinal_ex(ctx, (unsigned char*)ciphertext.data() + len1, &len2);
    EVP_CIPHER_CTX_free(ctx);
    ciphertext.resize(len1 + len2);

    QByteArray hmacData = iv + ciphertext;
    QByteArray hmac;
    hmac.resize(32);
    unsigned int hmacLen = 0;
    HMAC(EVP_sha256(), m_hmacEncodeKey.constData(), static_cast<int>(m_hmacEncodeKey.size()),
         reinterpret_cast<const unsigned char*>(hmacData.constData()), hmacData.size(),
         reinterpret_cast<unsigned char*>(hmac.data()), &hmacLen);
    
    return iv + ciphertext + hmac;
}

QByteArray QuickShareCrypto::decryptPayload(const QByteArray& ciphertextBytes) {
    if (!m_handshakeComplete) return ciphertextBytes;
    
    if (ciphertextBytes.size() < 16 + 32) return QByteArray();
    
    QByteArray iv = ciphertextBytes.left(16);
    QByteArray hmac = ciphertextBytes.right(32);
    QByteArray ciphertext = ciphertextBytes.mid(16, ciphertextBytes.size() - 16 - 32);
    
    QByteArray hmacData = iv + ciphertext;
    QByteArray expectedHmac;
    expectedHmac.resize(32);
    unsigned int hmacLen = 0;
    HMAC(EVP_sha256(), m_hmacDecodeKey.constData(), static_cast<int>(m_hmacDecodeKey.size()),
         reinterpret_cast<const unsigned char*>(hmacData.constData()), hmacData.size(),
         reinterpret_cast<unsigned char*>(expectedHmac.data()), &hmacLen);
         
    if (hmac != expectedHmac) {
        return QByteArray();
    }

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    EVP_DecryptInit_ex(ctx, EVP_aes_256_cbc(), nullptr, reinterpret_cast<const unsigned char*>(m_decodeKey.constData()), reinterpret_cast<const unsigned char*>(iv.constData()));
    
    QByteArray plaintext;
    plaintext.resize(ciphertext.size());
    
    int len1 = 0, len2 = 0;
    EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char*>(plaintext.data()), &len1, reinterpret_cast<const unsigned char*>(ciphertext.constData()), ciphertext.size());
    EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char*>(plaintext.data()) + len1, &len2);
    EVP_CIPHER_CTX_free(ctx);
    plaintext.resize(len1 + len2);

    return plaintext;
}

} // namespace caelestia::services
