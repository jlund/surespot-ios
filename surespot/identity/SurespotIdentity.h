//
//  SurespotIdentity.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "eccrypto.h"
#import "IdentityKeys.h"



@interface SurespotIdentity : NSObject
-(id) initWithDictionary: (NSDictionary *) jsonIdentity validate: (BOOL) validate;
-(id) initWithUsername:(NSString*)username andSalt:(NSString *)salt keys: (IdentityKeys *) keys;

@property (atomic, copy) NSString* username;
@property (atomic, copy) NSString* latestVersion;
@property (atomic, copy) NSString* salt;
//- (ECDHPublicKey) getDhPublicKey;
- (ECDHPrivateKey *) getDhPrivateKeyForVersion: (NSString *) version;
//- (ECDSAPPublicKey) getDsaPublicKey;
- (ECDSAPrivateKey *) getDsaPrivateKey;


@property (atomic, strong) NSMutableDictionary* keyPairs;
@property (atomic, strong) NSMutableDictionary* jsonKeyPairs;
- (void) addKeysWithVersion:(NSString*)version keys: (IdentityKeys *) keys;
-(void) recreateMissingKeys;
@end
