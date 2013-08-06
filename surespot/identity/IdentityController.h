//
//  IdentityController.h
//  surespot
//
//  Created by Adam on 6/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotIdentity.h"
#import "IdentityKeys.h"

typedef void (^CallbackBlock) (id  result);
typedef void (^CallbackStringBlock) (NSString * result);
typedef void (^CallbackDictionaryBlock) (NSDictionary * result);


@interface IdentityController : NSObject



+ (SurespotIdentity *) getIdentityWithUsername:(NSString *) username andPassword:(NSString *) password;
+( SurespotIdentity *) decodeIdentityData: (NSData *) identityData withUsername: (NSString *) username andPassword: (NSString *) password;

+ (void) createIdentityWithUsername: (NSString *) username andPassword: (NSString *) password andSalt: (NSString *) salt andKeys: (IdentityKeys *) keys;
+ (NSArray *) getIdentityNames;
+ (void) userLoggedInWithIdentity: (SurespotIdentity *) identity;
+ (NSString *) loggedInUser;
+ (NSString *) getLoggedInUser;
+ (SurespotIdentity *) loggedInIdentity;
+ (NSString *) getOurLatestVersion;
+ (void) getTheirLatestVersionForUsername: (NSString *) username callback:(CallbackStringBlock) callback;
+(void) getPublicKeysForUsername: (NSString *) username andVersion: (NSString *) version callback: (CallbackBlock) callback ;



@end
