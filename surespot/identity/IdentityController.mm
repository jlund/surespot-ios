//
//  IdentityController.m
//  surespot
//
//  Created by Adam on 6/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//


#import "IdentityController.h"
#import "EncryptionController.h"
#import "NetworkController.h"
#import "FileController.h"
#import "SurespotIdentity.h"
#import "NSData+Gunzip.h"
#import "PublicKeys.h"
#include <zlib.h>
#import "CredentialCachingController.h"
#import "ChatController.h"
#import "DDLog.h"
#import "NSData+Base64.h"
#import "KeychainItemWrapper.h"
#import <Security/Security.h>
#import "UIUtils.h"
#import "NSString+Sensitivize.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface IdentityController()
@property (nonatomic, strong) SurespotIdentity * loggedInIdentity;
@property (nonatomic, strong) NSMutableDictionary * keychainWrappers;
@property (nonatomic, strong) NSMutableDictionary * identities;
@property (nonatomic, strong) NSMutableDictionary * expectedVersions;
@end

@implementation IdentityController
+(IdentityController*)sharedInstance
{
    static IdentityController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.keychainWrappers = [NSMutableDictionary new];
        sharedInstance.identities = [NSMutableDictionary new];
        sharedInstance.expectedVersions = [NSMutableDictionary new];
    });
    
    return sharedInstance;
}

NSString *const CACHE_IDENTITY_ID = @"_cache_identity";
NSString *const EXPORT_IDENTITY_ID = @"_export_identity";



- (SurespotIdentity *) getIdentityWithUsername:(NSString *) username andPassword:(NSString *) password {
    
    SurespotIdentity * identity = [_identities objectForKey:username];
    if (!identity) {
        identity = [self loadIdentityUsername: (NSString *) username password:password];
        
    }
    return identity;
    
}

-(SurespotIdentity *) loadIdentityUsername: (NSString * ) username password: (NSString *) password {
    
    NSString *filePath = [FileController getIdentityFile:username];
    
    NSData *myData = [NSData dataWithContentsOfFile:filePath];
    
    if (myData) {
        //gunzip the identity data
        //NSError* error = nil;
        NSData* unzipped = [myData gzipInflate];
        NSData * identity = [EncryptionController decryptIdentity: unzipped withPassword:[password stringByAppendingString:CACHE_IDENTITY_ID]];
        if (identity) {
            return [self decodeIdentityData:identity withUsername:username andPassword:password validate: NO];
        }
    }
    
    return nil;
}

-(NSData *) encryptIdentity: (SurespotIdentity *) identity withPassword:(NSString *)password {
    NSMutableDictionary * dic = [NSMutableDictionary dictionaryWithObjectsAndKeys: [identity username] ,@"username", [identity salt], @"salt" ,nil];
    
    
    
    NSDictionary * identityKeys = [identity keyPairs];
    NSMutableArray * encodedKeys = [[NSMutableArray alloc] init];
    for (NSInteger i=1;i<=[identity.latestVersion integerValue];i++) {
        NSString * version =[@(i) stringValue];
        
        //if we have a concrete key encode and save that
        IdentityKeys *versionedKeys = [identityKeys objectForKey:version];
        if (versionedKeys) {
            DDLogInfo(@"saving concrete key for version %@", version);
            NSDictionary *jsonKeys = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [versionedKeys version] ,@"version",
                                      [EncryptionController encodeDHPrivateKey: [versionedKeys dhPrivKey]], @"dhPriv" ,
                                      [EncryptionController encodeDHPublicKey: [versionedKeys dhPubKey]], @"dhPub" ,
                                      [EncryptionController encodeDSAPrivateKey: [versionedKeys dsaPrivKey]], @"dsaPriv" ,
                                      [EncryptionController encodeDSAPublicKey: [versionedKeys dsaPubKey]], @"dsaPub" ,
                                      nil];
            
            [encodedKeys addObject:jsonKeys];
        }
        //otherwise use json
        else {
            DDLogInfo(@"saving json key for version %@", version);
            [encodedKeys addObject:[[identity jsonKeyPairs] objectForKey:version]];
        }
    }
    
    [dic setObject:encodedKeys forKey:@"keys"];
    NSError * error;
    NSData * jsonIdentity = [NSJSONSerialization dataWithJSONObject:dic options:kNilOptions error:&error];
    return [EncryptionController encryptIdentity:jsonIdentity withPassword:password];
    
}

-( SurespotIdentity *) decodeIdentityData: (NSData *) identityData withUsername: (NSString *) username andPassword: (NSString *) password validate: (BOOL) validate {
    
    NSError* error;
    
    NSDictionary* dic = [NSJSONSerialization JSONObjectWithData:identityData options:NSJSONReadingMutableContainers error:&error];
    return [[SurespotIdentity alloc] initWithDictionary: dic validate: validate];
}

-(void) setLoggedInUserIdentity: (SurespotIdentity *) identity {
    @synchronized (self) {
        self.loggedInIdentity = identity;
        [[ChatController sharedInstance] login];
        [[CredentialCachingController sharedInstance] loginIdentity:identity];
    }
}

- (void) createIdentityWithUsername: (NSString *) username
                        andPassword: (NSString *) password
                            andSalt: (NSString *) salt
                            andKeys: (IdentityKeys *) keys {
    
    
    SurespotIdentity * identity = [[SurespotIdentity alloc] initWithUsername:username andSalt:salt keys:keys];
    
    [self saveIdentity:identity  withPassword:[password stringByAppendingString:CACHE_IDENTITY_ID]];
    [self setLoggedInUserIdentity:identity];
}



- (NSString *) saveIdentity: (SurespotIdentity *) identity withPassword: (NSString *) password {
    NSString * filePath = [FileController getIdentityFile:identity.username];
    NSData * encryptedCompressedIdentityData = [[self encryptIdentity:identity withPassword:password] gzipDeflate];
    BOOL written = [encryptedCompressedIdentityData writeToFile:filePath atomically:TRUE];
    return written ? filePath : nil;
}

- (NSArray *) getIdentityNames {
    NSString * identityDir = [FileController getIdentityDir];
    NSArray * dirfiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:identityDir error:NULL];
    NSMutableArray * identityNames = [[NSMutableArray alloc] init];
    NSString * file;
    for (file in dirfiles) {
        [identityNames addObject:[self identityNameFromFile:file]];
    }
    return identityNames;
}

- (NSString * ) identityNameFromFile: (NSString *) file {
    if ([[file pathExtension] isEqualToString:IDENTITY_EXTENSION]) {
        return[[file stringByDeletingPathExtension] caseSensitivize];
    }
    
    return nil;
}

- (void) userLoggedInWithIdentity: (SurespotIdentity *) identity {
    [self setLoggedInUserIdentity:identity];
}



- (NSString *) getLoggedInUser {
    return [[self getLoggedInIdentity] username];
}


- (SurespotIdentity *) getLoggedInIdentity {
    @synchronized (self) { return self.loggedInIdentity; }
}

-(void) logout {
    @synchronized (self) {
        self.loggedInIdentity = nil;
        [[CredentialCachingController sharedInstance] logout];
    }
}

- (NSString *) getOurLatestVersion {
    return [[self getLoggedInIdentity] latestVersion];
}

- (void) getTheirLatestVersionForUsername: (NSString *) username callback:(CallbackStringBlock) callback {
    DDLogVerbose(@"getTheirLatestVersionForUsername");
    [[CredentialCachingController sharedInstance] getLatestVersionForUsername: username callback: callback];
}

-(BOOL) verifyPublicKeys: (NSDictionary *) keys {
    
    BOOL dhVerify = [EncryptionController
                     verifyPublicKeySignature: [NSData dataFromBase64String:[keys objectForKey:@"dhPubSig"]]
                     data:[keys objectForKey:@"dhPub"]];
    
    if (!dhVerify) {
        return NO;
    }
    
    BOOL dsaVerify = [EncryptionController
                      verifyPublicKeySignature: [NSData dataFromBase64String:[keys objectForKey:@"dsaPubSig"]]
                      data:[keys objectForKey:@"dsaPub"]];
    
    if (!dsaVerify) {
        return NO;
    }
    
    return YES;
}

-(PublicKeys *) loadPublicKeysUsername: (NSString * ) username version: (NSString *) version {
    NSString * filename =[FileController getPublicKeyFilenameForUsername: username version: version];
    NSDictionary * keys = [NSKeyedUnarchiver unarchiveObjectWithFile:filename];
    if (keys) {
        ECDHPublicKey * dhPub = [EncryptionController recreateDhPublicKey:[keys objectForKey:@"dhPub"]];
        ECDHPublicKey * dsaPub = [EncryptionController recreateDsaPublicKey:[keys objectForKey:@"dsaPub"]];
        
        PublicKeys* pk = [[PublicKeys alloc] init];
        pk.dhPubKey = dhPub;
        pk.dsaPubKey = dsaPub;
        pk.version = version;
        
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];        
        NSDate *date = [attributes fileModificationDate];
    
        pk.lastModified = date;
        DDLogInfo(@"loaded public keys for username: %@, version: %@ from filename: %@", username,version,filename);
        return pk;
    }
    
    return nil;
}

-(void) savePublicKeys: (NSDictionary * ) keys username: (NSString *)username version: (NSString *)version{
    NSString * filename =[FileController getPublicKeyFilenameForUsername: username version: version];
    BOOL saved =[NSKeyedArchiver archiveRootObject:keys toFile:filename];
    DDLogInfo(@"saved public keys for username: %@, version: %@ to filename: %@  with success: %@", username,version,filename, saved?@"YES":@"NO");
}

//we don't want to delete ourselves if we're in the process of generating new keys
-(void) setExpectedKeyVersionForUsername: (NSString *) username version: (NSString *) version {
    [_expectedVersions setObject:version forKey:username];
}

-(void) updateLatestVersionForUsername: (NSString *) username version: (NSString * ) version {
    // see if we are the user that's been revoked
    // if we have the latest version locally, if we don't then this user has
    // been revoked from a different device
    // and should not be used on this device anymore
    if ([username isEqualToString:[self getLoggedInUser]] && [version integerValue] > [[self getOurLatestVersion] integerValue] && ![[_expectedVersions objectForKey:username] isEqualToString:version]) {
        DDLogInfo(@"user key revoked, deleting data and logging out. username: %@", username);
        [self deleteIdentityUsername:username];
    }
    else {
        [[CredentialCachingController sharedInstance] updateLatestVersionForUsername: username version: version];
    }
}

-(void) deleteIdentityUsername: (NSString *) username {
    //make sure we wipe the identity file first so it doesn't show when we return to login screen
    [FileController wipeIdentityData: username];
    [[NetworkController sharedInstance] setUnauthorized];
    
    [[CredentialCachingController sharedInstance] clearIdentityData:username];
    
    //remove password from keychain
    [self clearStoredPasswordForIdentity:username];
    
    //then wipe the messages saved by logging out
    [FileController wipeIdentityData: username];
}

-(NSString *) getStoredPasswordForIdentity: (NSString *) username {
    KeychainItemWrapper * wrapper = [_keychainWrappers objectForKey:username];
    if (!wrapper) {
        wrapper = [[KeychainItemWrapper alloc] initWithIdentifier:username accessGroup:nil];
        [_keychainWrappers setObject:wrapper forKey:username];
    }
    
    NSString * password = [wrapper objectForKey:(__bridge id)kSecValueData];
    if ([UIUtils stringIsNilOrEmpty:password]) {
        return nil;
    }
    
    return password;
}

-(void) storePasswordForIdentity: (NSString *) username password: (NSString *) password {
    //save password in keychain
    KeychainItemWrapper * wrapper = [_keychainWrappers objectForKey:username];
    if (!wrapper) {
        wrapper = [[KeychainItemWrapper alloc] initWithIdentifier:username accessGroup:nil];
        [_keychainWrappers setObject:wrapper forKey:username];
    }
    
    [wrapper setObject:password forKey:(__bridge id)kSecValueData];
    
}

-(void) clearStoredPasswordForIdentity: (NSString *) username {
    KeychainItemWrapper * wrapper = [_keychainWrappers objectForKey:username];
    if (!wrapper) {
        wrapper = [[KeychainItemWrapper alloc] initWithIdentifier:username accessGroup:nil];
    }
    [wrapper resetKeychainItem];
    [_keychainWrappers removeObjectForKey:username];
    
    //remove secrets from disk
    [FileController deleteDataForUsername:username];
}

-(void) importIdentityData: (NSData *) identityData username: (NSString *) username password: (NSString *) password callback: (CallbackBlock) callback {
    NSData * decryptedIdentity = [EncryptionController decryptIdentity: identityData withPassword:[password stringByAppendingString:EXPORT_IDENTITY_ID]];
    if (!decryptedIdentity) {
        callback([NSString stringWithFormat:NSLocalizedString(@"could_not_restore_identity_name", nil), username]);
        return;
    }
    
    //get the identity without validating to validate with server where we only need the latest ids
    SurespotIdentity * identity = [self decodeIdentityData:decryptedIdentity withUsername:username andPassword:password validate:NO];
    if (!identity) {
        callback([NSString stringWithFormat:NSLocalizedString(@"could_not_restore_identity_name", nil), username]);
        return;
    }
    
    NSData * saltBytes = [NSData dataFromBase64String:identity.salt];
    NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt:saltBytes];
    NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
    NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    
    
    
    [[NetworkController sharedInstance] validateUsername:username
                                                password:passwordString
                                               signature:signatureString
                                            successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                //regenerate the identity with full validation for saving
                                                SurespotIdentity * validatedIdentity = [self decodeIdentityData:decryptedIdentity withUsername:username andPassword:password validate:YES];
                                                [self saveIdentity:validatedIdentity withPassword:[password stringByAppendingString:CACHE_IDENTITY_ID]];
                                                callback(nil);
                                                
                                            } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                switch (operation.response.statusCode) {
                                                    case 403:
                                                        callback(NSLocalizedString(@"incorrect_password_or_key", nil));
                                                        break;
                                                    case 404:
                                                        callback(NSLocalizedString(@"no_such_user", nil));
                                                        break;
                                                    default:
                                                        callback([NSString stringWithFormat:NSLocalizedString(@"could_not_restore_identity_name", nil), username]);
                                                        break;
                                                }
                                            }];
}

-(void) exportIdentityDataForUsername: (NSString *) username password: (NSString *) password callback: (CallbackErrorBlock) callback {
    SurespotIdentity * identity = [self getIdentityWithUsername:username andPassword:password];
    if (!identity) {
        callback(NSLocalizedString(@"could_not_backup_identity_to_google_drive", nil), nil);
        return;
    }
    
    NSData * saltBytes = [NSData dataFromBase64String:identity.salt];
    NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt:saltBytes];
    NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
    NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    
    
    
    [[NetworkController sharedInstance] validateUsername:username password:passwordString signature:signatureString successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        callback(nil, [self encryptIdentity:identity withPassword:[password stringByAppendingString:EXPORT_IDENTITY_ID]]);
        
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        switch (operation.response.statusCode) {
            case 403:
            case 404:
                callback(NSLocalizedString(@"incorrect_password_or_key", nil), nil);
                break;
            default:
                callback([NSString stringWithFormat:NSLocalizedString(@"could_not_backup_identity_to_google_drive", nil), username], nil);
                break;
        }
    }];
}

-(void) removeExpectedKeyVersionForUsername: (NSString *) username {
    [_expectedVersions removeObjectForKey:username];
}

-(void) rollKeysForUsername: (NSString *) username
                   password: (NSString *) password
                 keyVersion: (NSString *)  keyVersion
                       keys: (IdentityKeys *) keys {
    
    SurespotIdentity * identity = [self getIdentityWithUsername:username andPassword:password];
    [identity addKeysWithVersion:keyVersion keys:keys];
    [self saveIdentity:identity withPassword:[password stringByAppendingString:CACHE_IDENTITY_ID]];
    
    if ([username isEqualToString:[self getLoggedInUser]]) {
        _loggedInIdentity = identity;
        [[CredentialCachingController sharedInstance] loginIdentity: identity];
    }
    
    [self removeExpectedKeyVersionForUsername:username];
}

-(void) updatePasswordForUsername: (NSString *) username currentPassword: (NSString *) currentPassword newPassword: (NSString *) newPassword newSalt: (NSString *) newSalt {
    SurespotIdentity * identity = [self getIdentityWithUsername:username andPassword:currentPassword];
    identity.salt = newSalt;
    [self saveIdentity:identity withPassword:[newPassword stringByAppendingString:CACHE_IDENTITY_ID]];
    if ([self getStoredPasswordForIdentity:username]) {
        [self storePasswordForIdentity:username password:newPassword];
    }
}

@end
