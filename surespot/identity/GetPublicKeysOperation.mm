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

#import "GetPublicKeysOperation.h"
#import "NetworkController.h"
#import "EncryptionController.h"
#import "DDLog.h"

static const int ddLogLevel = LOG_LEVEL_OFF;

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
    
    [[NetworkController sharedInstance]
     getPublicKeysForUsername: self.username
     andVersion: self.version
     successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
         
         

         //recreate public keys
         //todo verify
         NSDictionary * jsonKeys = JSON;
         
         NSString * spubDH = [jsonKeys objectForKey:@"dhPub"];
         NSString * spubDSA = [jsonKeys objectForKey:@"dsaPub"];
         DDLogVerbose(@"get public keys response: %d, key: %@",  [response statusCode], spubDH);
         
         ECDHPublicKey dhPub = [EncryptionController recreateDhPublicKey:spubDH];
         ECDHPublicKey dsaPub = [EncryptionController recreateDsaPublicKey:spubDSA];
         
         PublicKeys* pk = [[PublicKeys alloc] init];
         pk.dhPubKey = dhPub;
         pk.dsaPubKey = dsaPub;
         
         DDLogVerbose(@"get public keys calling callback");
         [self finish:pk];
         
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
