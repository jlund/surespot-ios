//
//  getKeyVersionOperation.m
//  surespot
//
//  Created by Adam on 11/12/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "GetKeyVersionOperation.h"
#import "NetworkController.h"
#import "EncryptionController.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface GetKeyVersionOperation()
@property (nonatomic) CredentialCachingController * cache;
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) CallbackStringBlock callback;
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end




@implementation GetKeyVersionOperation

-(id) initWithCache: (CredentialCachingController *) cache username: (NSString *) username completionCallback: (CallbackStringBlock)  callback {
    

    if (self = [super init]) {
        self.cache = cache;
        self.callback = callback;
        self.username = username;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    NSString * latestVersion = [_cache.latestVersionsDict objectForKey:_username];
    if (!latestVersion) {
        
        [[NetworkController sharedInstance]
         getKeyVersionForUsername: _username
         successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
             NSString * responseObjectS =   [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
             DDLogVerbose(@"caching key version: %@ for username: %@", responseObjectS, _username);
             
             [_cache.latestVersionsDict setObject:responseObjectS forKey:_username];
             [_cache saveLatestVersions];
             [self finish:responseObjectS];
             
         }
         failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
             
             DDLogVerbose(@"response failure: %@",  Error);
             [self finish:nil];
             
         }];
    }
    else {
        DDLogVerbose(@"returning cached key version: %@ for user: %@", latestVersion, _username);
        [self finish: latestVersion];
    }


    
}

- (void)finish: (NSString *) version
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    _callback(version);
    _callback = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
