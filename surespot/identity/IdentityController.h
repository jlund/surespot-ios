//
//  IdentityController.h
//  surespot
//
//  Created by Adam on 6/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotIdentity.h"

@interface IdentityController : NSObject
+ (SurespotIdentity *) getIdentityWithUsername:(NSString *) username andPassword:(NSString *) password;
+( SurespotIdentity *) decryptIdentityData: (NSData *) identityData withUsername: (NSString *) username andPassword: (NSString *) password;

+ (NSData *)gzipDeflate:(NSData *) data;
+ (NSData *)gzipInflate:(NSData *) data;
@end
