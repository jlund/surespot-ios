//
//  FileController.m
//  surespot
//
//  Created by Adam on 7/22/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "FileController.h"
#import "NSData+Gunzip.h"
#include <zlib.h>
#include "secblock.h"
#import "IdentityController.h"
#import "DDLog.h"
#import "ChatUtils.h"
#import "EncryptionController.h"
#import "NSData+Gunzip.h"

using CryptoPP::SecByteBlock;


NSString * const STATE_DIR = @"state";
NSString * const HOME_FILENAME = @"home";
NSString * const STATE_EXTENSION = @"sss";
NSString * const CHAT_DATA_PREFIX = @"chatdata_";
NSString * const PUBLIC_KEYS_DIR = @"publickeys";
NSString * const IDENTITIES_DIR = @"identities";

NSString * const PUBLIC_KEYS_EXTENSION = @"spk";
NSString * const IDENTITY_EXTENSION = @"ssi";
NSString * const SECRET_EXTENSION = @"sse";
NSString * const SECRETS_DIR = @"secrets";

NSInteger const GZIP_MAGIC_1 = 0x1f;
NSInteger const GZIP_MAGIC_2 = 0x8b;

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@implementation FileController


+ (NSString*) getAppSupportDir {
    NSString *appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
    //If there isn't an App Support Directory yet ...
    if (![[NSFileManager defaultManager] fileExistsAtPath:appSupportDir isDirectory:NULL]) {
        NSError *error = nil;
        //Create one
        if (![[NSFileManager defaultManager] createDirectoryAtPath:appSupportDir withIntermediateDirectories:YES attributes:nil error:&error]) {
            DDLogVerbose(@"%@", error.localizedDescription);
        }
        else {
            // *** OPTIONAL *** Mark the directory as excluded from iCloud backups
            NSURL *url = [NSURL fileURLWithPath:appSupportDir];
            if (![url setResourceValue:[NSNumber numberWithBool:YES]
                                forKey:NSURLIsExcludedFromBackupKey
                                 error:&error])
            {
                DDLogVerbose(@"Error excluding %@ from backup %@", [url lastPathComponent], error.localizedDescription);
            }
            else {
                DDLogVerbose(@"Yay");
            }
        }
    }
    
    return appSupportDir;
}

+(NSString *) getHomeFilename {
    return [self getFilename:HOME_FILENAME];
}

+(NSString *) getChatDataFilenameForSpot: (NSString *) spot {
    return [self getFilename:[CHAT_DATA_PREFIX stringByAppendingString:spot]];
}

+(NSString*)getPublicKeyFilenameForUsername: (NSString *) username version: (NSString *)version {
    NSString * dir = [self getPublicKeyDirectoryForUsername:username];
    return [dir stringByAppendingPathComponent:[version stringByAppendingPathExtension:PUBLIC_KEYS_EXTENSION]];

}
+(NSString*)getPublicKeyDirectoryForUsername: (NSString *) username  {
    NSString * dir = [self getDirectoryForUser:[[IdentityController sharedInstance] getLoggedInUser] ];
    NSString * pkdir = [[dir stringByAppendingPathComponent:PUBLIC_KEYS_DIR] stringByAppendingPathComponent:username];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:pkdir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    
    return pkdir;
}


+(void) wipeDataForUsername: (NSString *) username friendUsername: (NSString *) friendUsername {
    NSError * error;
    if (![[NSFileManager defaultManager] removeItemAtPath:[self getPublicKeyDirectoryForUsername:friendUsername] error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    
    NSString * spot = [ChatUtils getSpotUserA:username userB:friendUsername];
    NSString * messageFile = [self getChatDataFilenameForSpot:spot];
    
    DDLogInfo( @"wiping data for username: %@, friendname: %@, path: %@", username,friendUsername,messageFile);
    //file manager thread safe supposedly
    NSFileManager * fileMgr = [NSFileManager defaultManager];
    BOOL wiped = [fileMgr removeItemAtPath:messageFile error:nil];
    
    DDLogInfo(@"wiped: %@", wiped ? @"YES" : @"NO");
    
}

+(void) wipeIdentityData: (NSString *) username {
    //remove identity file
    NSString * identityFile = [self getIdentityFile:username];
    
    DDLogInfo( @"wiping idenity file for username: %@,  path: %@", username,identityFile);
    //file manager thread safe supposedly
    NSFileManager * fileMgr = [NSFileManager defaultManager];
    BOOL wiped = [fileMgr removeItemAtPath:identityFile error:nil];    
    DDLogInfo(@"wiped: %@", wiped ? @"YES" : @"NO");
    
    //wipe data (chats, keys, etc.)
    NSString * identityDataDir = [self getDirectoryForUser:username];
    
    DDLogInfo( @"wiping data for username: %@,  path: %@", username,identityDataDir);
    wiped = [fileMgr removeItemAtPath:identityDataDir error:nil];
    DDLogInfo(@"wiped: %@", wiped ? @"YES" : @"NO");
}

+(NSString *) getFilename: (NSString *) filename {
    return [self getFilename:filename forUser:[[IdentityController sharedInstance] getLoggedInUser]];
}

+(NSString *) getFilename: (NSString *) filename forUser: (NSString *) user {
    if (user) {
        NSString * dir = [self getDirectoryForUser:user];
        return [dir stringByAppendingPathComponent:[filename stringByAppendingPathExtension:STATE_EXTENSION]];
                
    }
    
    return nil;
}
+(NSString *) getIdentityDir {
    NSString * basedir = [[self getAppSupportDir] stringByAppendingPathComponent:IDENTITIES_DIR];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:basedir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    return basedir;
}

+(NSString *) getSecretsDir {
    NSString * basedir = [[self getAppSupportDir] stringByAppendingPathComponent:SECRETS_DIR];
    NSError * error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:basedir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogError(@"%@", error.localizedDescription);
    }
    return basedir;
}

+(NSString *) getIdentityFile: (NSString *) username {
    NSString * filename = [username stringByAppendingPathExtension:IDENTITY_EXTENSION];
    return [[self getIdentityDir ] stringByAppendingPathComponent:filename];
}


+(NSString *) getSecretsFile: (NSString *) username {
    NSString * filename = [username stringByAppendingPathExtension:SECRET_EXTENSION];
    return [[self getSecretsDir ] stringByAppendingPathComponent:filename];
}

+(NSString *) getDirectoryForUser: (NSString *) user {
    NSString * dir = [[[FileController getAppSupportDir] stringByAppendingPathComponent:STATE_DIR ] stringByAppendingPathComponent:user];
    NSError * error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
        DDLogVerbose(@"%@", error.localizedDescription);
    }
    return  dir;
}

+(NSDictionary *) loadSharedSecretsForUsername: (NSString *) username withPassword: (NSString *) password {
    NSString * filePath = [self getSecretsFile:username];
    
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    
    if (data) {
      
        //NSError* error = nil;
        NSData * secrets = [EncryptionController decryptData: data withPassword:password];
        if (secrets) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:secrets];
        }
    }
    
    return nil;

}

+(void) saveSharedSecrets:(NSDictionary *) sharedSecretsDict forUsername: (NSString *) username withPassword: (NSString *) password{
    NSString * filePath = [self getSecretsFile:username];
    NSData * secretData = [NSKeyedArchiver archivedDataWithRootObject:sharedSecretsDict];

    NSData * encryptedSecretData = [EncryptionController encryptData:secretData withPassword:password];
    [encryptedSecretData writeToFile:filePath atomically:TRUE];
}

+(void) deleteSharedSecretsForUsername: (NSString *) username; {
     NSString * filePath = [self getSecretsFile:username];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
}

+(BOOL) isGzipCompressed: (NSData *) data {
    if (!data ||data.length < 18) {
        return NO;
    }
    else {
        unsigned char * bytes = (unsigned char *)[data bytes];
        return ((bytes[0] == GZIP_MAGIC_1) && (bytes[1] == GZIP_MAGIC_2));
    }
}

+(NSData *) gunzipIfNecessary: (NSData *) identityBytes {
    if ([self isGzipCompressed:identityBytes]) {
        return [identityBytes gzipInflate];
    }
    return identityBytes;
}

@end
