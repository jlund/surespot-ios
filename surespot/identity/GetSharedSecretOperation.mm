//
//  GetPublicKeysOperation.m
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

//
//  GenerateSharedSecretOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "GetSharedSecretOperation.h"
#import "GetPublicKeysOperation.h"
#import "GenerateSharedSecretOperation.h"
#import "IdentityController.h"
#import "NSData+Base64.h"
#import "DDLog.h"

static const int ddLogLevel = LOG_LEVEL_OFF;

@interface GetSharedSecretOperation()
@property (nonatomic) CredentialCachingController * cache;
@property (nonatomic) NSString * ourUsername;
@property (nonatomic) NSString * ourVersion;
@property (nonatomic) NSString * theirUsername;
@property (nonatomic) NSString * theirVersion;
@property (nonatomic, strong) void(^callback)(NSData *);
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end



@implementation GetSharedSecretOperation

-(id) initWithCache: (CredentialCachingController *) cache
        ourUsername: (NSString *) ourUsername
         ourVersion: (NSString *) ourVersion
      theirUsername: (NSString *) theirUsername
       theirVersion: (NSString *) theirVersion
           callback: (CallbackBlock) callback {
    if (self = [super init]) {
        self.cache = cache;
        self.ourUsername = ourUsername;
        self.ourVersion = ourVersion;
        self.theirUsername = theirUsername;
        self.theirVersion = theirVersion;
        self.callback = callback;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    
    
    //see if we have the shared secret cached already
    NSString * sharedSecretKey = [NSString stringWithFormat:@"%@:%@:%@:%@", self.cache.loggedInUsername, self.ourVersion, self.theirUsername, self.theirVersion];
    
    NSData * sharedSecret = [self.cache.sharedSecretsDict objectForKey:sharedSecretKey];
    
    if (sharedSecret) {
        DDLogVerbose(@"using cached secret %@ for %@", [sharedSecret base64EncodedString], sharedSecretKey);
        [self finish:sharedSecret];
    }
    else {
        SurespotIdentity * identity = [self.cache.identities objectForKey:[self.cache loggedInUsername]];
        if (!identity) {
            [self finish:nil];
            return;
        }
        
        //get public keys out of dictionary
        NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", self.theirUsername, self.theirVersion];
        PublicKeys * publicKeys = [self.cache.publicKeysDict objectForKey:publicKeysKey];
        
        if (publicKeys) {
            DDLogVerbose(@"using cached public keys for %@", publicKeysKey);
            
            GenerateSharedSecretOperation * sharedSecretOp = [[GenerateSharedSecretOperation alloc] initWithOurIdentity:identity theirPublicKeys:publicKeys completionCallback:^(NSData * secret) {
                //store shared key in dictionary
                DDLogVerbose(@"caching shared secret %@ for %@", [secret base64EncodedString], sharedSecretKey);
                [self.cache.sharedSecretsDict setObject:secret forKey:sharedSecretKey];
                [self finish:secret];
            }];
            
            [self.cache.secretQueue addOperation:sharedSecretOp];
        }
        else {
            
            //get the public keys we need
            GetPublicKeysOperation * pkOp = [[GetPublicKeysOperation alloc] initWithUsername:self.theirUsername version:self.theirVersion completionCallback:
                                             ^(PublicKeys * keys) {
                                                 if (keys) {
                                                     DDLogVerbose(@"caching public keys for %@", publicKeysKey);
                                                     //store keys in dictionary
                                                     [self.cache.publicKeysDict setObject:keys forKey:publicKeysKey];
                                                     
                                                     GenerateSharedSecretOperation * sharedSecretOp = [[GenerateSharedSecretOperation alloc] initWithOurIdentity:identity theirPublicKeys:keys completionCallback:^(NSData * secret) {
                                                         //store shared key in dictionary
                                                         DDLogVerbose(@"caching shared secret %@ for %@", [secret base64EncodedString], sharedSecretKey);
                                                         [self.cache.sharedSecretsDict setObject:secret forKey:sharedSecretKey];
                                                         [self finish:secret];
                                                     }];
                                                     
                                                     [self.cache.secretQueue addOperation:sharedSecretOp];
                                                 }}];
            
            [self.cache.publicKeyQueue addOperation:pkOp];
        }
    }
}

- (void)finish: (NSData *) secret
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    _callback(secret);
    _callback = nil;
    _cache = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
