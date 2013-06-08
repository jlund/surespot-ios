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

@interface PrivateKeyPairs : NSObject

@property (nonatomic, strong) NSString* version;
@property (nonatomic, assign) DL_Keys_EC<ECP> keyPairDH;
@property (nonatomic, assign) DL_Keys_EC<ECP> keyPairDSA;

@end
