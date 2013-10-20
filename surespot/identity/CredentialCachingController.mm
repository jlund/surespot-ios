//
//  CredentialCachingController.m
//  surespot
//
//  Created by Adam on 8/5/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "CredentialCachingController.h"
#import "GetSharedSecretOperation.h"
#import "EGOCache.h"


@interface CredentialCachingController()
@property (nonatomic, strong) NSOperationQueue * getSecretQueue;
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
        //[sharedInstance.publicKeyQueue setMaxConcurrentOperationCount:1];
        sharedInstance.getSecretQueue = [[NSOperationQueue alloc] init];
        [sharedInstance.getSecretQueue setMaxConcurrentOperationCount:1];
    });
    
    return sharedInstance;
}



-(void) getSharedSecretForOurVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion callback: (CallbackBlock) callback {
    
    NSLog(@"getSharedSecretForOurVersion");
   
    GetSharedSecretOperation * op = [[GetSharedSecretOperation alloc] initWithCache:self ourUsername:self.loggedInUsername ourVersion:ourVersion theirUsername:theirUsername theirVersion:theirVersion callback:callback];
    
    [self.getSecretQueue addOperation:op];
        
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
