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

@interface IdentityKeys : NSObject

@property (nonatomic, strong) NSString* version;
@property (nonatomic, assign) CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC dhPrivKey;
@property (nonatomic, assign) CryptoPP::DL_PublicKey_EC<ECP> dhPubKey;
@property (nonatomic, assign) CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey dsaPrivKey;
@property (nonatomic, assign) CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey dsaPubKey;

@end
