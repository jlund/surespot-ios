//
//  PrivateKeyPairs.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "eccrypto.h"

using CryptoPP::ECP;
using CryptoPP::ECDH;
using CryptoPP::DL_Keys_EC;

typedef CryptoPP::DL_PublicKey_EC<CryptoPP::ECP> ECDHPublicKey;
typedef CryptoPP::DL_PrivateKey_EC<ECP> ECDHPrivateKey;
typedef CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey ECDSAPublicKey;
typedef CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey ECDSAPrivateKey;

@interface IdentityKeys : NSObject

@property (nonatomic, strong) NSString* version;
@property (nonatomic, assign) ECDHPrivateKey * dhPrivKey;
@property (nonatomic, assign) ECDHPublicKey * dhPubKey;
@property (nonatomic, assign) ECDSAPrivateKey * dsaPrivKey;
@property (nonatomic, assign) ECDSAPublicKey * dsaPubKey;

@end
