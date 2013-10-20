//
//  CredentialCachingController.m
//  surespot
//
//  Created by Adam on 8/5/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "CredentialCachingController.h"
#import "GenerateSharedSecretOperation.h"
#import "GetPublicKeysOperation.h"
#import "EGOCache.h"

@interface CredentialCachingController()
@property (nonatomic, retain) NSMutableDictionary * sharedSecretsDict;
@property (nonatomic, retain) NSMutableDictionary * publicKeysDict;
@property (nonatomic, retain) NSMutableDictionary * identitiesDict;
@property (nonatomic, strong) NSOperationQueue * secretQueue;
@property (nonatomic, strong) NSOperationQueue * publicKeyQueue;
@end

@implementation CredentialCachingController

+(CredentialCachingController*)sharedInstance
{
    static CredentialCachingController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.identities = [[NSMutableDictionary alloc] init];
        sharedInstance.sharedSecretsDict = [[NSMutableDictionary alloc] init];
        sharedInstance.publicKeysDict = [[NSMutableDictionary alloc] init];
        sharedInstance.secretQueue = [[NSOperationQueue alloc] init];
        //   [sharedInstance.secretQueue setMaxConcurrentOperationCount:1];
        sharedInstance.publicKeyQueue = [[NSOperationQueue alloc] init];
        [sharedInstance.publicKeyQueue setMaxConcurrentOperationCount:1];
    });
    
    return sharedInstance;
}



-(void) getSharedSecretForOurVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion callback: (CallbackBlock) callback {
    
    NSLog(@"getSharedSecretForOurVersion");
    
    //see if we have the shared secret cached already
    NSString * sharedSecretKey = [NSString stringWithFormat:@"%@:%@:%@:%@", self.loggedInUsername, ourVersion, theirUsername, theirVersion];
    
    NSData * sharedSecret = [self.sharedSecretsDict objectForKey:sharedSecretKey];
    
    if (sharedSecret) {
        NSLog(@"using cached secret for %@", sharedSecretKey);
        callback(sharedSecret);
    }
    else {
        SurespotIdentity * identity = [self.identities objectForKey:[self loggedInUsername]];
        if (!identity) {
            callback(nil);
            return;
        }
        
        //get public keys out of dictionary
        NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", theirUsername, theirVersion];
        PublicKeys * publicKeys = [self.publicKeysDict objectForKey:publicKeysKey];
        
        if (publicKeys) {
            NSLog(@"using cached public keys for %@", publicKeysKey);
            
            GenerateSharedSecretOperation * sharedSecretOp = [[GenerateSharedSecretOperation alloc] initWithOurIdentity:identity theirPublicKeys:publicKeys completionCallback:^(NSData * secret) {
                //store shared key in dictionary
                NSLog(@"caching shared secretfor %@", sharedSecretKey);
                [self.sharedSecretsDict setObject:secret forKey:sharedSecretKey];
                callback(secret);
            }];
            
            [self.secretQueue addOperation:sharedSecretOp];
        }
        else {
            
            //get the public keys we need
            GetPublicKeysOperation * pkOp = [[GetPublicKeysOperation alloc] initWithUsername:theirUsername version:theirVersion completionCallback:
                                             ^(PublicKeys * keys) {
                                                 if (keys) {
                                                     NSLog(@"caching public keys for %@", publicKeysKey);
                                                     //store keys in dictionary
                                                     [self.publicKeysDict setObject:keys forKey:publicKeysKey];
                                                     
                                                     GenerateSharedSecretOperation * sharedSecretOp = [[GenerateSharedSecretOperation alloc] initWithOurIdentity:identity theirPublicKeys:keys completionCallback:^(NSData * secret) {
                                                         //store shared key in dictionary
                                                         NSLog(@"caching shared secretfor %@", sharedSecretKey);
                                                         [self.sharedSecretsDict setObject:secret forKey:sharedSecretKey];
                                                         callback(secret);
                                                     }];
                                                     
                                                     [self.secretQueue addOperation:sharedSecretOp];
                                                 }}];
            
            [self.publicKeyQueue addOperation:pkOp];
        }
        
    }
    
    
    
    
    
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
