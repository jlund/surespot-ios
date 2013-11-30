//
//  GenerateSharedSecretOperation.h
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PublicKeys.h"
#import "SurespotIdentity.h"


@interface GenerateSharedSecretOperation : NSOperation

@property (nonatomic, strong) void(^callback)(NSData *);
@property (nonatomic, strong) NSData * sharedSecret;

-(id) initWithOurPrivateKey: (ECDHPrivateKey *) ourPrivateKey theirPublicKey: (ECDHPublicKey *) theirPublicKey completionCallback:(void(^)(NSData *)) callback;


@end

