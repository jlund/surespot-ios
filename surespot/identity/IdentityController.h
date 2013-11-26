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
#import "PublicKeys.h"
#import "SurespotConstants.h"


@interface IdentityController : NSObject
+(IdentityController*)sharedInstance;


- ( SurespotIdentity *) getIdentityWithUsername:(NSString *) username andPassword:(NSString *) password;
-( SurespotIdentity *) decodeIdentityData: (NSData *) identityData withUsername: (NSString *) username andPassword: (NSString *) password;

- (void) createIdentityWithUsername: (NSString *) username andPassword: (NSString *) password andSalt: (NSString *) salt andKeys: (IdentityKeys *) keys;
-(NSArray *) getIdentityNames;
- (void) userLoggedInWithIdentity: (SurespotIdentity *) identity;
- (NSString *) getLoggedInUser;
- (SurespotIdentity *) loggedInIdentity;
- (NSString *) getOurLatestVersion;
- (void) getTheirLatestVersionForUsername: (NSString *) username callback:(CallbackStringBlock) callback;

-(BOOL) verifyPublicKeys: (NSDictionary *) keys;
-(PublicKeys *) loadPublicKeysUsername: (NSString * ) username version: (NSString *) version;
-(void) savePublicKeys: (NSDictionary * ) keys username: (NSString *)username version: (NSString *)version;
-(void) updateLatestVersionForUsername: (NSString *) username version: (NSString * ) version;
-(void) logout;
@end
