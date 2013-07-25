//
//  SurespotIdentity.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotIdentity.h"
#import "IdentityKeys.h"


@implementation SurespotIdentity

-(id) initWithUsername:(NSString *)username andSalt:(NSString *)salt {
    if (self = [super init]) {
        self.username = username;
        self.salt = salt;
        self.keyPairs = [[NSMutableDictionary alloc] init];
        return self;
    }
    else {
        return nil;
    }
}

- (NSDictionary *) getKeys {
    return self.keyPairs;
}

- (void)
addKeysWithVersion:(NSString*)version
withDhPrivKey: (CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC) dhPrivKey
withDhPubKey: (CryptoPP::DL_PublicKey_EC<ECP>) dhPubKey
withDsaPrivKey: (CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey) dsaPrivKey
withDsaPubKey: (CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey) dsaPubKey {
    
    if (self.latestVersion == nil) {
        self.latestVersion = version;
    }
    else {
        if ([self.latestVersion compare:version] == NSOrderedAscending) {
            self.latestVersion = version;
        }
    }
    //self.version = version;
    
    IdentityKeys * ik = [[IdentityKeys alloc] init];
    ik.version = version;
    ik.dhPrivKey = dhPrivKey;
    ik.dhPubKey = dhPubKey;
    ik.dsaPrivKey = dsaPrivKey;
    ik.dsaPubKey = dsaPubKey;
    
    [self.keyPairs setValue: ik forKey: version];
}

- (ECDHPublicKey) getDhPublicKey {
    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
    return keys.dhPubKey;
}

- (ECDHPrivateKey) getDhPrivateKey {
    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
    return keys.dhPrivKey;
}

-(ECDSAPPublicKey)getDsaPublicKey {
    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
    return keys.dsaPubKey;
}

- (ECDSAPrivateKey) getDsaPrivateKey {
    IdentityKeys * keys = [self.keyPairs objectForKey:self.latestVersion];
    return keys.dsaPrivKey;
}






@end
