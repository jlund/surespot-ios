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
@property (nonatomic, assign) ECDHPrivateKey* ourPrivateKey;
@property (nonatomic, assign) ECDHPublicKey* theirPublicKey;
@end


@implementation GenerateSharedSecretOperation

-(id) initWithOurPrivateKey: (ECDHPrivateKey *) ourPrivateKey theirPublicKey: (ECDHPublicKey *) theirPublicKey completionCallback:(void(^)(NSData *)) callback {
    if (self = [super init]) {
        self.callback = callback;
        self.ourPrivateKey = ourPrivateKey;
        self.theirPublicKey = theirPublicKey;
    }
    return self;
}

-(void) main {
    @autoreleasepool {
        
        //generate shared secret and store it in cache
        NSData * sharedSecret = [EncryptionController generateSharedSecret:_ourPrivateKey  publicKey:_theirPublicKey];
        self.callback(sharedSecret);
    }
}



@end
