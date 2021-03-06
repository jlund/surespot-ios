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
-( SurespotIdentity *) decodeIdentityData: (NSData *) identityData withUsername: (NSString *) username andPassword: (NSString *) password validate: (BOOL) validate ;

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
-(NSString *) getStoredPasswordForIdentity: (NSString *) username;
-(void) storePasswordForIdentity: (NSString *) username password: (NSString *) password;
-(void) clearStoredPasswordForIdentity: (NSString *) username;
- (NSString * ) identityNameFromFile: (NSString *) file;
-(void) importIdentityData: (NSData *) identityData username: (NSString *) username password: (NSString *) password callback: (CallbackBlock) callback;
-(void) exportIdentityDataForUsername: (NSString *) username password: (NSString *) password callback: (CallbackErrorBlock) callback;
-(void) rollKeysForUsername: (NSString *) username
                   password: (NSString *) password
                 keyVersion: (NSString *)  keyVersion
                       keys: (IdentityKeys *) keys;
-(void) setExpectedKeyVersionForUsername: (NSString *) username version: (NSString *) version;
-(void) removeExpectedKeyVersionForUsername: (NSString *) username;
-(void) deleteIdentityUsername: (NSString *) username;
-(void) updatePasswordForUsername: (NSString *) username currentPassword: (NSString *) currentPassword newPassword: (NSString *) newPassword newSalt: (NSString *) newSalt;
-(NSInteger) getIdentityCount;
@end

