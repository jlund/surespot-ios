//
//  SurespotIdentity.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "eccrypto.h"
using CryptoPP::ECP;
using CryptoPP::ECDH;
using CryptoPP::DL_Keys_EC;

typedef CryptoPP::DL_PublicKey_EC<ECP> ECDHPublicKey;
typedef CryptoPP::DL_PrivateKey_EC<ECP> ECDHPrivateKey;
typedef CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey ECDSAPPublicKey;
typedef CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey ECDSAPrivateKey;


@interface SurespotIdentity : NSObject

-(id) initWithUsername:(NSString*)username andSalt:(NSString *)salt;

- (void)
    addKeysWithVersion:(NSString*)version
    withDhPrivKey: (CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC) dhPrivKey
    withDhPubKey: (CryptoPP::DL_PublicKey_EC<ECP>) dhPubKey
    withDsaPrivKey: (CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey) dsaPrivKey
    withDsaPubKey: (CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey) dsaPubKey;

@property (atomic, copy) NSString* username;
@property (atomic, copy) NSString* latestVersion;
@property (atomic, copy) NSString* salt;
@property (atomic, strong) NSMutableDictionary* keyPairs;

- (ECDHPublicKey) getDhPublicKey;
- (ECDHPrivateKey) getDhPrivateKey;
- (ECDSAPPublicKey) getDsaPublicKey;
- (ECDSAPrivateKey) getDsaPrivateKey;


@end
