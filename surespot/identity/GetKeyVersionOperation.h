//
//  GetPublicKeysOperation.h
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IdentityController.h"
#import "CredentialCachingController.h"

@interface GetKeyVersionOperation : NSOperation

-(id) initWithCache: (CredentialCachingController *) cache username: (NSString *) username completionCallback: (CallbackStringBlock)  callback;
@end
