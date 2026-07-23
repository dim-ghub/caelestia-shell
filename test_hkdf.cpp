#include <iostream>
#include <openssl/evp.h>
#include <openssl/kdf.h>
#include <vector>

std::vector<unsigned char> hkdfSha256(const std::string& salt, const std::string& ikm, const std::string& info) {
    EVP_PKEY_CTX *pctx = EVP_PKEY_CTX_new_id(EVP_PKEY_HKDF, nullptr);
    EVP_PKEY_derive_init(pctx);
    EVP_PKEY_CTX_set_hkdf_md(pctx, EVP_sha256());
    EVP_PKEY_CTX_set1_hkdf_salt(pctx, salt.data(), salt.size());
    EVP_PKEY_CTX_set1_hkdf_key(pctx, ikm.data(), ikm.size());
    EVP_PKEY_CTX_add1_hkdf_info(pctx, info.data(), info.size());
    std::vector<unsigned char> out(32);
    size_t out_len = 32;
    EVP_PKEY_derive(pctx, out.data(), &out_len);
    EVP_PKEY_CTX_free(pctx);
    return out;
}

std::vector<unsigned char> hexToBytes(const std::string& hex) {
    std::vector<unsigned char> bytes;
    for (size_t i = 0; i < hex.length(); i += 2) {
        std::string byteString = hex.substr(i, 2);
        unsigned char byte = (unsigned char) strtol(byteString.c_str(), NULL, 16);
        bytes.push_back(byte);
    }
    return bytes;
}

void printHex(const std::vector<unsigned char>& data) {
    for (unsigned char b : data) {
        printf("%02x", b);
    }
    printf("\n");
}

int main() {
    std::string ikm = "test_ikm_test_ikm_test_ikm_test_"; // 32 bytes
    std::string info = "ENC:2";
    
    // Case 1: salt is string "SecureMessage"
    std::string salt1 = "SecureMessage";
    auto key1 = hkdfSha256(salt1, ikm, info);
    std::cout << "Salt string: "; printHex(key1);
    
    // Case 2: salt is fromHex("BF9D2A...")
    auto saltBytes = hexToBytes("BF9D2A53C63616D75DB0A7165B91C1EF73E537F2427405FA23610A4BE657642E");
    std::string salt2(saltBytes.begin(), saltBytes.end());
    auto key2 = hkdfSha256(salt2, ikm, info);
    std::cout << "Salt hash:   "; printHex(key2);
    
    return 0;
}
