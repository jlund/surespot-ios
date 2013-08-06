//
//  CredentialCachingController.m
//  surespot
//
//  Created by Adam on 8/5/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "CredentialCachingController.h"


@implementation CredentialCachingController

+(CredentialCachingController*)sharedInstance
{
    static CredentialCachingController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.identities = [[NSMutableDictionary alloc] init];
    });
    
    return sharedInstance;
}

-(void) getSharedSecretForOurVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion callback: (CallbackBlock) callback {
    //TODO cache, for now generate it from keys
    
    //get private key
    SurespotIdentity * identity = [self getIdentityWithUsername: self.loggedInUsername];
    
    //get public key
    [IdentityController getPublicKeysForUsername:theirUsername andVersion:theirVersion callback: ^(PublicKeys * publicKeys) {
        if (publicKeys != nil) {
            
            
            ECDHPublicKey pubKey = [publicKeys dhPubKey];
            
            callback([EncryptionController generateSharedSecret:[identity getDhPrivateKey] publicKey:pubKey]);
        }
        else {
            callback(nil);
        }
        
    }];
    
    
    
}

//todo cahe cookie
-(void) loginIdentity: (SurespotIdentity *) identity {
    self.loggedInUsername = [identity username];
    
    
    [self.identities setObject:identity forKey:self.loggedInUsername];
}

-(SurespotIdentity *) getIdentityWithUsername: (NSString *) username {
    return [self.identities objectForKey:username];
}
@end
