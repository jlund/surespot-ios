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

@interface SurespotIdentity : NSObject

-(id) initWithUsername:(NSString *)username andSalt:(NSString *)salt;

- (void) addKeyPairs:(NSString*)version keyPairDH:(DL_Keys_EC<ECP>)keyPairDH keyPairDSA:(DL_Keys_EC<ECP>)keyPairDSA;

@property (nonatomic, retain) NSString* username;
@property (nonatomic, retain) NSString* latestVersion;
@property (nonatomic, retain) NSString* salt;
@property (nonatomic, retain) NSMutableDictionary* keyPairs;


@end
