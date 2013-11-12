//
//  GenerateSharedSecretOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "GenerateSharedSecretOperation.h"
#import "EncryptionController.h"
#import "DDLog.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface GenerateSharedSecretOperation()
@property (nonatomic, strong) SurespotIdentity * ourIdentity;
@property (nonatomic, strong) PublicKeys * theirPublicKeys;
@end


@implementation GenerateSharedSecretOperation

-(id) initWithOurIdentity: (SurespotIdentity *) ourIdentity theirPublicKeys: (PublicKeys *) theirPublicKeys  completionCallback:(void(^)(NSData *))  callback {
    if (self = [super init]) {
        self.callback = callback;
        self.ourIdentity = ourIdentity;
        self.theirPublicKeys = theirPublicKeys;
    }
    return self;
}

-(void) main {
    @autoreleasepool {
        DDLogInfo(@"getting pub key");
        ECDHPublicKey pubKey = [self.theirPublicKeys dhPubKey];
        
        //generate shared secret and store it in cache
        NSData * sharedSecret = [EncryptionController generateSharedSecret:[self.ourIdentity getDhPrivateKey] publicKey:pubKey];
        
        self.callback(sharedSecret);
    }
}



@end
