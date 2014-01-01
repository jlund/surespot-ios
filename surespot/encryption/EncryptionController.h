//
//  EncryptionController.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IdentityController.h"
#import "SurespotConstants.h"



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
extern int const PBKDF_ROUNDS;

@interface EncryptionController : NSObject
+ (NSData *) encryptData:(NSData *) data withPassword:(NSString *) password;
+ (NSData *) decryptData:(NSData *) data withPassword:(NSString *) password;

+ (NSData *) encryptIdentity:(NSData *) data withPassword:(NSString *) password;
+ (NSData *) decryptIdentity:(NSData *) data withPassword:(NSString *) password;
+ (ECDHPrivateKey *) recreateDhPrivateKey:(NSString *) encodedKey validate: (BOOL) validate;
+ (ECDSAPrivateKey *) recreateDsaPrivateKey:(NSString *) encodedKey validate: (BOOL) validate;
+ (NSData *) deriveKeyUsingPassword: (NSString *) password andSalt: (NSData *) salt;
+ (NSDictionary *) deriveKeyFromPassword: (NSString *) password;
+ (NSData *) signUsername: (NSString *) username andPassword: (NSData *) password withPrivateKey: (ECDSAPrivateKey *) privateKey;
+ (NSData *) signData1: (NSData *) data1 data2: (NSData *) data2 withPrivateKey: (ECDSAPrivateKey *) privateKey;
+ (NSData *) getIv;
+ (NSData *) encryptPlain: (NSString *) plain usingKey: (NSData *) key usingIv: (NSData *) iv;
+ (NSData *) generateSharedSecret: (ECDHPrivateKey *) privateKey publicKey:(ECDHPublicKey *) publicKey;
+ (IdentityKeys *) generateKeyPairs;
+ (NSString *) encodeDHPrivateKey: (ECDHPrivateKey *) dhPrivKey;
+ (NSString *) encodeDHPublicKey: (ECDHPublicKey *) dhPubKey;
+ (NSString *) encodeDSAPrivateKey: (ECDSAPrivateKey *) dsaPrivKey;
+ (NSString *) encodeDSAPublicKey: (ECDSAPublicKey *) dsaPubKey;
+ (ECDHPublicKey *) recreateDhPublicKey: (NSString *) encodedKey;
+  (ECDSAPublicKey *) recreateDsaPublicKey: (NSString *) encodedKey;
+(void) symmetricEncryptString: (NSString *) plaintext ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *)  theirVersion iv: (NSData *) iv callback: (CallbackBlock) callback;
+(void) symmetricDecryptString: (NSString *) cipherData ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion iv: (NSString *) iv callback: (CallbackBlock) callback;

+(BOOL) verifyPublicKeySignature: (NSData *) signature data: (NSData *) data;
+(void) symmetricEncryptData: (NSData *) data ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion iv: (NSData *) iv callback: (CallbackBlock) callback;
+(NSData *) symmetricDecryptData: (NSData *) cipherData key: (NSData *) key iv: (NSString *) iv;
+(ECDHPublicKey *) createPublicDHFromPrivKey: (ECDHPrivateKey *) privateKey;
+(ECDSAPublicKey *) createPublicDSAFromPrivKey: (ECDSAPrivateKey *) privateKey;
+(NSData *) encodeDSAPublicKeyData: (ECDSAPublicKey *) dsaPubKey;
+(NSData *) encodeDHPublicKeyData: (ECDHPublicKey *) dhPubKey;
+(NSString *) md5: (NSData *) data;
+(NSString *)hashedValueForAccountName:(NSString*)userAccountName;
@end
