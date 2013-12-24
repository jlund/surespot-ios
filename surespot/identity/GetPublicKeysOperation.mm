//
//  GetPublicKeysOperation.m
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "GetPublicKeysOperation.h"
#import "NetworkController.h"
#import "EncryptionController.h"
#import "IdentityController.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface GetPublicKeysOperation()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * version;
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end




@implementation GetPublicKeysOperation

-(id) initWithUsername: (NSString *) username version: (NSString *) version completionCallback:(void(^)(PublicKeys *))  callback {
    if (self = [super init]) {
        self.callback = callback;
        self.username = username;
        self.version = version;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    
    PublicKeys * keys = [[IdentityController sharedInstance] loadPublicKeysUsername: _username version:  _version];
    if (keys) {
        DDLogInfo(@"Loaded public keys from disk for user: %@, version: %@", _username, _version);
        [self finish:keys];
        return;
    }
    
    [[NetworkController sharedInstance]
     getPublicKeysForUsername: self.username
     andVersion: self.version
     successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
         
         if (JSON) {
             NSString * version = [JSON objectForKey:@"version"];
             if (![_version isEqualToString:version]) {
                 DDLogWarn(@"public key versions do not match");
                 [self finish: nil];
             }
             
             
             DDLogInfo(@"verifying public keys for %@", _username);
             BOOL verified = [[IdentityController sharedInstance  ] verifyPublicKeys: JSON];
             
             if (!verified) {
                 DDLogWarn(@"could not verify public keys!");
                 [self finish: nil];
             }
             else {
                 DDLogInfo(@"public keys verified against server signature");

                 //recreate public keys
                 NSDictionary * jsonKeys = JSON;
                 
                 NSString * spubDH = [jsonKeys objectForKey:@"dhPub"];
                 NSString * spubDSA = [jsonKeys objectForKey:@"dsaPub"];
                 DDLogVerbose(@"get public keys response: %d, key: %@",  [response statusCode], spubDH);
                 
                 ECDHPublicKey * dhPub = [EncryptionController recreateDhPublicKey:spubDH];
                 ECDHPublicKey * dsaPub = [EncryptionController recreateDsaPublicKey:spubDSA];
                 
                 PublicKeys* pk = [[PublicKeys alloc] init];
                 pk.dhPubKey = dhPub;
                 pk.dsaPubKey = dsaPub;
                 pk.version = _version;
                 pk.lastModified = [NSDate date];
                 
                 //save keys to disk
                 [[IdentityController sharedInstance] savePublicKeys: JSON username: _username version:  _version];
                 
                 DDLogVerbose(@"get public keys calling callback");
                 [self finish:pk];
             }
         }
         else {
             [self finish:nil];
         }
         
     } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
         
         DDLogVerbose(@"response failure: %@",  Error);
         [self finish:nil];
         
     }];
    
    
}

- (void)finish: (PublicKeys *) publicKeys
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    _callback(publicKeys);
    _callback = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
