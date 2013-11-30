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

@property (atomic, strong) NSMutableDictionary* keyPairs;
@property (atomic, strong) NSMutableDictionary* jsonKeyPairs;

@end

@implementation SurespotIdentity


-(id) initWithDictionary: (NSDictionary *) jsonIdentity {
    if (self = [super init]) {
        try {
            self.keyPairs = [[NSMutableDictionary alloc] init];
            self.jsonKeyPairs = [[NSMutableDictionary alloc] init];
            _username = [jsonIdentity objectForKey:@"username"];
            _salt = [jsonIdentity objectForKey:@"salt"];
            NSArray * keys = [jsonIdentity objectForKey:@"keys"];
            for (NSDictionary * key in keys) {
                
                NSString * version = [key objectForKey:@"version"];
                [self addJSONKeysWithVersion:version jsonKeys:key];
            
            }
            
            //re-generate latest keys
            [self getDhPrivateKeyForVersion:_latestVersion];
            [self getDsaPrivateKey];
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

- (NSDictionary *) getKeys {
    return self.keyPairs;
}


- (void) addJSONKeysWithVersion:(NSString*)version jsonKeys: (NSDictionary *) jsonKeys {
    
    if (self.latestVersion == nil) {
        self.latestVersion = version;
    }
    else {
        if ([self.latestVersion integerValue] < [version integerValue]) {
            self.latestVersion = version;
        }
    }
    
    [self.jsonKeyPairs setValue: jsonKeys forKey: version];
}

//- (ECDHPublicKey) getDhPublicKey {
//    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
//    return keys.dhPubKey;
//}

- (ECDHPrivateKey *) getDhPrivateKeyForVersion: (NSString *) version {
    IdentityKeys * keys = [self.keyPairs objectForKey:version];
    if (!keys) {
        keys = [[IdentityKeys alloc] init];
        keys.version = version;
        [self.keyPairs setValue: keys forKey: version];        
    }
    
    ECDHPrivateKey * privateKey = keys.dhPrivKey;
    
    if (!privateKey) {
        //     DDLogInfo(@"recreating keys for username: %@, version: %@ start", _username, version);
        NSString * dprivDH = [[_jsonKeyPairs objectForKey:version ] objectForKey:@"dhPriv"];
        ECDHPrivateKey * dhPrivKey = [EncryptionController recreateDhPrivateKey:dprivDH];
        CryptoPP::DL_PublicKey_EC<ECP> * dhPubKey = new ECDHPublicKey();
        dhPrivKey->MakePublicKey(*dhPubKey);
        
        keys.dhPrivKey = dhPrivKey;
        keys.dhPubKey = dhPubKey;
        
        privateKey = dhPrivKey;
        
    }
    return privateKey;
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
    
    ECDSAPrivateKey * privateKey = keys.dsaPrivKey;
    
    if (!privateKey) {
        //     DDLogInfo(@"recreating keys for username: %@, version: %@ start", _username, version);
        NSString * dprivDSA = [[_jsonKeyPairs objectForKey:self.latestVersion ] objectForKey:@"dsaPriv"];
        ECDSAPrivateKey * dsaPrivKey = [EncryptionController recreateDsaPrivateKey:dprivDSA];
        CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey * dsaPubKey = new ECDSAPublicKey();
        dsaPrivKey->MakePublicKey(*dsaPubKey);
 
        keys.dsaPrivKey = dsaPrivKey;
        keys.dsaPubKey = dsaPubKey;
        
        privateKey = dsaPrivKey;
        
    }
    return privateKey;
}







@end
