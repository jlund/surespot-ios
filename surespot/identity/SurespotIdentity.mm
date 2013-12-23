//
//  SurespotIdentity.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotIdentity.h"
#import "EncryptionController.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface SurespotIdentity()


@end

@implementation SurespotIdentity


-(id) initWithDictionary: (NSDictionary *) jsonIdentity validate:(BOOL) validate {
    if (self = [super init]) {
        try {
            self.keyPairs = [[NSMutableDictionary alloc] init];
            self.jsonKeyPairs = [[NSMutableDictionary alloc] init];
            _username = [jsonIdentity objectForKey:@"username"];
            _salt = [jsonIdentity objectForKey:@"salt"];
            
            //store the json keys
            NSArray * keys = [jsonIdentity objectForKey:@"keys"];
            for (NSMutableDictionary * key in keys) {
                
                NSString * version = [key objectForKey:@"version"];
                [self addJSONKeysWithVersion:version jsonKeys:key];
            }
            
            if (!validate) {
                //not validating so just re-generate latest keys without validation
                [self getDhPrivateKeyForVersion:_latestVersion];
                [self getDsaPrivateKey];
            }
            else {
                //iterate through all keys and re-generate with validation
                for (NSInteger i=1;i<=[self.latestVersion integerValue];i++) {
                    NSString * version =[@(i) stringValue];
                    
                    //if we have a concrete key encode and save that
                    IdentityKeys * keys = [[IdentityKeys alloc] init];
                    keys.version = version;
                    
                    if (![self recreateDhKeys:keys forVersion:version validate:YES]) {
                        return nil;
                    }
                    if (![self recreateDsaKeys:keys forVersion:version validate:YES]) {
                        return nil;
                    }
                    
                    [self.keyPairs setValue: keys forKey: version];
                    
                }
            }
            
            return self;
            
        } catch (const CryptoPP::Exception& e) {
            // cerr << e.what() << endl;
        }
    }
    return nil;
    
}


-(id) initWithUsername:(NSString*)username andSalt:(NSString *)salt keys: (IdentityKeys *) keys {
    if (self = [super init]) {
        self.username = username;
        self.salt = salt;
        self.latestVersion = keys.version;
        self.keyPairs = [[NSMutableDictionary alloc] init];
        self.jsonKeyPairs = [[NSMutableDictionary alloc] init];
        [self.keyPairs setObject:keys forKey:keys.version];
        return self;
    }
    else {
        return nil;
    }
}


- (void) addJSONKeysWithVersion:(NSString*)version jsonKeys: (NSMutableDictionary *) jsonKeys {
    
    if (self.latestVersion == nil) {
        self.latestVersion = version;
    }
    else {
        if ([self.latestVersion integerValue] < [version integerValue]) {
            self.latestVersion = version;
        }
    }
    
    //make sure version matches
    [jsonKeys setObject:version forKey:@"version"];
    [self.jsonKeyPairs setObject:jsonKeys forKey: version];
}

- (void) addKeysWithVersion:(NSString*)version keys: (IdentityKeys *) keys {
    
    if (self.latestVersion == nil) {
        self.latestVersion = version;
    }
    else {
        if ([self.latestVersion integerValue] < [version integerValue]) {
            self.latestVersion = version;
        }
    }
    
    //make sure version matches
    keys.version = version;
    [self.keyPairs setObject:keys forKey: version];
}

//- (ECDHPublicKey) getDhPublicKey {
//    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
//    return keys.dhPubKey;
//}

- (ECDHPrivateKey *) getDhPrivateKeyForVersion: (NSString *) version  {
    IdentityKeys * keys = [self.keyPairs objectForKey:version];
    if (!keys) {
        keys = [[IdentityKeys alloc] init];
        keys.version = version;
        [self.keyPairs setValue: keys forKey: version];
    }
    
    if (!keys.dhPrivKey) {
        [self recreateDhKeys: keys forVersion:version validate:NO];
    }
    return keys.dhPrivKey;
}

-(BOOL) recreateDhKeys: (IdentityKeys *) keys forVersion: (NSString *) version validate: (BOOL) validate {
    DDLogInfo(@"recreating dh keys for username: %@, version: %@ start", _username, version);
    NSString * dprivDH = [[_jsonKeyPairs objectForKey:version ] objectForKey:@"dhPriv"];
    ECDHPrivateKey * privateKey = [EncryptionController recreateDhPrivateKey:dprivDH validate:validate];
    if (!privateKey) {
        return NO;
    }
    
    keys.dhPrivKey = privateKey;
    keys.dhPubKey = [EncryptionController createPublicDHFromPrivKey:privateKey];
    
    return YES;
}

//-(ECDSAPPublicKey)getDsaPublicKey {
//    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
//    return keys.dsaPubKey;
//}

- (ECDSAPrivateKey *) getDsaPrivateKey {
    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
    if (!keys) {
        keys = [[IdentityKeys alloc] init];
        keys.version = self.latestVersion;
        [self.keyPairs setValue: keys forKey: self.latestVersion];
        
    }
    
    if (!keys.dsaPrivKey) {
        [self recreateDsaKeys:keys forVersion:self.latestVersion validate:NO];
    }
    
    return keys.dsaPrivKey;
}

-(BOOL) recreateDsaKeys: (IdentityKeys *) keys forVersion: (NSString *) version validate: (BOOL) validate {
    DDLogInfo(@"recreating dsa keys for username: %@, version: %@ start", _username, version);
    NSString * dprivDsa = [[_jsonKeyPairs objectForKey:version ] objectForKey:@"dsaPriv"];
    ECDSAPrivateKey * dsaPrivKey =  [EncryptionController recreateDsaPrivateKey:dprivDsa validate:validate];
    
    if (!dsaPrivKey) {
        return NO;
    }
    
    keys.dsaPrivKey = dsaPrivKey;
    keys.dsaPubKey = [EncryptionController createPublicDSAFromPrivKey:dsaPrivKey];
    
    return YES;
}

//used for key validation
-(void) recreateMissingKeys {
    //iterate through all keys and re-generate with validation
    for (NSInteger i=1;i<[self.latestVersion integerValue];i++) {
        NSString * version =[@(i) stringValue];
        
        //if we have a concrete key encode and save that
        IdentityKeys * keys = [[IdentityKeys alloc] init];
        keys.version = version;
        
        [self recreateDhKeys:keys forVersion:version validate:NO];
        [self recreateDsaKeys:keys forVersion:version validate:NO];        
        [self.keyPairs setValue: keys forKey: version];
    }
}



@end
