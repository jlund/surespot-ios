//
//  FileController.h
//  surespot
//
//  Created by Adam on 7/22/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const IDENTITY_EXTENSION;

@interface FileController : NSObject
+(NSString *) getHomeFilename;
+(NSString *) getChatDataFilenameForSpot: (NSString *) spot;
+ (NSString*) getAppSupportDir;
+(void) wipeDataForUsername: (NSString *) username friendUsername: (NSString *) friendUsername;
+(NSString*)getPublicKeyFilenameForUsername: (NSString *) username version: (NSString *)version;
+(void) wipeIdentityData: (NSString *) username;
+(NSString *) getIdentityDir;
+(NSString *) getIdentityFile: (NSString *) username;
+(void) saveSharedSecrets:(NSDictionary *) sharedSecretsDict forUsername: (NSString *) username withPassword: (NSString *) password;
+(NSDictionary *) loadSharedSecretsForUsername: (NSString *) username withPassword: (NSString *) password;
+(void) deleteSharedSecretsForUsername:  (NSString *)username;
+(NSData *) gunzipIfNecessary: (NSData *) identityBytes;
@end
