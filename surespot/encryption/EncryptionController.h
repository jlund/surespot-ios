//
//  EncryptionController.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IdentityController.h"




#include <strstream>
#include <iostream>
using std::cout;
using std::cerr;
using std::endl;


#include "cryptlib.h"
using CryptoPP::Exception;

#include <string>
using std::string;

#include <stdexcept>
using std::runtime_error;

#include <cstdlib>
using std::exit;

#include "hex.h"

#include "sha.h"
using CryptoPP::SHA256;

#include "pwdbased.h"
using CryptoPP::PKCS5_PBKDF2_HMAC;

#include "secblock.h"
using CryptoPP::SecByteBlock;

#include "oids.h"
using CryptoPP::OID;

// ASN1 is a namespace, not an object
#include "asn.h"
using namespace CryptoPP::ASN1;

#include "osrng.h"
using CryptoPP::AutoSeededRandomPool;
using CryptoPP::AutoSeededX917RNG;


#include "integer.h"
using CryptoPP::Integer;

#include "aes.h"
using CryptoPP::AES;
#include "gcm.h"
using CryptoPP::GCM;

#include "filters.h"
using CryptoPP::StringSink;
using CryptoPP::StringSource;
using CryptoPP::AuthenticatedEncryptionFilter;
using CryptoPP::AuthenticatedDecryptionFilter;
using CryptoPP::Redirector;
using CryptoPP::ByteQueue;

#include "NSData+SRB64Additions.h"

#include "eccrypto.h"
using CryptoPP::ECP;

#include "dsa.h"
#include "IdentityKeys.h"

typedef CryptoPP::DL_PublicKey_EC<ECP> ECDHPublicKey;
typedef CryptoPP::DL_PrivateKey_EC<ECP> ECDHPrivateKey;
typedef CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey ECDSAPrivateKey;
typedef CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey ECDSAPublicKey;

extern int const IV_LENGTH;
extern int const SALT_LENGTH;
extern int const AES_KEY_LENGTH;





@interface EncryptionController : NSObject
+ (CryptoPP::AutoSeededRandomPool *) rng;
+ (NSData *) encryptIdentity:(NSData *) identityData withPassword:(NSString *) password;
+ (NSData *) decryptIdentity:(NSData *) identityData withPassword:(NSString *) password;
+ (ECDHPrivateKey) recreateDhPrivateKey:(NSString *) encodedKey;
+ (ECDSAPrivateKey) recreateDsaPrivateKey:(NSString *) encodedKey;
+ (byte *) deriveKeyUsingPassword: (NSString *) password andSalt: (byte *) salt;
+ (NSDictionary *) deriveKeyFromPassword: (NSString *) password;
+ (NSData *) signUsername: (NSString *) username andPassword: (NSData *) password withPrivateKey: (ECDSAPrivateKey) privateKey;
+ (NSData *) getIv;
+ (NSData *) encryptPlain: (NSString *) plain usingKey: (byte *) key usingIv: (NSData *) iv;
+ (NSData *) generateSharedSecret: (ECDHPrivateKey) privateKey publicKey:(ECDHPublicKey) publicKey;
+ (IdentityKeys *) generateKeyPairs;
+ (NSString *) encodeDHPrivateKey: (ECDHPrivateKey) dhPrivKey;
+ (NSString *) encodeDHPublicKey: (ECDHPublicKey) dhPubKey;
+ (NSString *) encodeDSAPrivateKey: (ECDSAPrivateKey) dsaPrivKey;
+ (NSString *) encodeDSAPublicKey: (ECDSAPublicKey) dsaPubKey;
+ (ECDHPublicKey) recreateDhPublicKey: (NSString *) encodedKey;
+  (ECDSAPublicKey) recreateDsaPublicKey: (NSString *) encodedKey;
+(void) symmetricEncryptString: (NSString *) plaintext ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *)  theirVersion iv: (NSData *) iv callback: (CallbackBlock) callback;
+(void) symmetricDecryptString: (NSString *) cipherData ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion iv: (NSString *) iv callback: (CallbackBlock) callback;
@end
