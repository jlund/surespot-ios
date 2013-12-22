//
//  CredentialCachingController.m
//  surespot
//
//  Created by Adam on 8/5/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "CredentialCachingController.h"
#import "GetSharedSecretOperation.h"
#import "GetKeyVersionOperation.h"
#import "NetworkController.h"
#import "FileController.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface CredentialCachingController()
@property (nonatomic, strong) NSOperationQueue * keyVersionQueue;
@property (nonatomic, strong) NSOperationQueue * getSecretQueue;

@end

@implementation CredentialCachingController

+(CredentialCachingController*)sharedInstance
{
    static CredentialCachingController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.sharedSecretsDict = [[NSMutableDictionary alloc] init];
        sharedInstance.publicKeysDict = [[NSMutableDictionary alloc] init];
        sharedInstance.latestVersionsDict = [[NSMutableDictionary alloc] init];
        sharedInstance.genSecretQueue = [[NSOperationQueue alloc] init];
        sharedInstance.publicKeyQueue = [[NSOperationQueue alloc] init];
        sharedInstance.getSecretQueue = [[NSOperationQueue alloc] init];
        [sharedInstance.getSecretQueue setMaxConcurrentOperationCount:1];
        sharedInstance.keyVersionQueue = [NSOperationQueue new];
        [sharedInstance.keyVersionQueue setMaxConcurrentOperationCount:1];
    });
    
    return sharedInstance;
}



-(void) getSharedSecretForOurVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion callback: (CallbackBlock) callback {
    
    DDLogVerbose(@"getSharedSecretForOurVersion, queue size: %d", [_getSecretQueue operationCount] );
    
    GetSharedSecretOperation * op = [[GetSharedSecretOperation alloc] initWithCache:self ourVersion:ourVersion theirUsername:theirUsername theirVersion:theirVersion callback:callback];
    
    [self.getSecretQueue addOperation:op];
    
}

-(void) loginIdentity: (SurespotIdentity *) identity {
    self.loggedInIdentity = identity;
    
    //load encrypted shared secrets from disk if we have a password in the keychain
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:identity.username];
    if (password) {
        NSDictionary * secrets  =  [FileController loadSharedSecretsForUsername: identity.username withPassword:password];
        _sharedSecretsDict = [NSMutableDictionary  dictionaryWithDictionary:secrets];
        DDLogInfo(@"loaded %d encrypted secrets from disk", [_sharedSecretsDict count]);
    }
    
    _latestVersionsDict = [NSMutableDictionary dictionaryWithDictionary:[FileController loadLatestVersionsForUsername:identity.username]];
    DDLogInfo(@"loaded %d latest versions from disk", [_latestVersionsDict count]);
    

    
    //add all the public keys for this identity to the cache
    for (IdentityKeys * keys in [identity.keyPairs allValues]) {
        NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", identity.username,  keys.version];
        PublicKeys * publicKeys = [[PublicKeys alloc] init];
        
        //make new copy of public keys
        
        publicKeys.dhPubKey = [EncryptionController createPublicDHFromPrivKey:keys.dhPrivKey];
        publicKeys.dsaPubKey = [EncryptionController createPublicDSAFromPrivKey:keys.dsaPrivKey];
        [_publicKeysDict setObject:publicKeys forKey:publicKeysKey];
    }
}


-(void) logout {
    [_sharedSecretsDict removeAllObjects];
    [_publicKeysDict removeAllObjects];
    [_latestVersionsDict removeAllObjects];
    _loggedInIdentity = nil;
}

-(void) saveSharedSecrets {
    //save encrypted shared secrets to disk if we have a password in the keychain for this user
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:_loggedInIdentity.username];
    if (password) {
        [FileController saveSharedSecrets: _sharedSecretsDict forUsername: _loggedInIdentity.username withPassword:password];
        DDLogInfo(@"saved %d encrypted secrets to disk", [_sharedSecretsDict count]);
    }
    
}

-(void) saveLatestVersions {
    
    [FileController saveLatestVersions: _latestVersionsDict forUsername: _loggedInIdentity.username];
    DDLogInfo(@"saved %d latest versions to disk", [_latestVersionsDict count]);
    
    
}

-(void) clearUserData: (NSString *) friendname {
    [_latestVersionsDict removeObjectForKey:friendname];
    
    //    NSString * sharedSecretKey = [NSString stringWithFormat:@"%@:%@:%@",self.ourVersion, self.theirUsername, self.theirVersion];
    //      NSString * publicKeysKey = [NSString stringWithFormat:@"%@:%@", self.theirUsername, self.theirVersion];
    
    NSMutableArray * keysToRemove = [NSMutableArray new];
    //iterate through shared secret keys and delete those that match the passed in user
    for (NSString * key in [_sharedSecretsDict allKeys]) {
        NSArray * keyComponents = [key componentsSeparatedByString:@":"];
        if ([[keyComponents objectAtIndex:1] isEqualToString:friendname] ) {
            DDLogInfo(@"removing shared secret for: %@", key);
            [keysToRemove addObject:key];
        }
    }
    
    [_sharedSecretsDict removeObjectsForKeys:keysToRemove];
    
    keysToRemove = [NSMutableArray new];
    //iterate through public keys and delete those that match the passed in user
    for (NSString * key in [_publicKeysDict allKeys]) {
        NSArray * keyComponents = [key componentsSeparatedByString:@":"];
        if ([[keyComponents objectAtIndex:0] isEqualToString:friendname] ) {
            DDLogInfo(@"removing public key for: %@", key);
            [keysToRemove addObject:key];
        }
    }
    
    [_publicKeysDict removeObjectsForKeys:keysToRemove];
    
    [self saveSharedSecrets];
    [self saveLatestVersions];
    
}


-(void) clearIdentityData:(NSString *) username {
    if ([username isEqualToString:_loggedInIdentity.username]) {
        DDLogInfo(@"purging cached identity data from RAM for: %@",  username);
        [_sharedSecretsDict removeAllObjects];
        [_publicKeysDict removeAllObjects];
        [_latestVersionsDict removeAllObjects];
    }
    
    //wipe data from disk
    [FileController deleteDataForUsername:username];
    
}

- (void) getLatestVersionForUsername: (NSString *) username callback:(CallbackStringBlock) callback {
    DDLogVerbose(@"getLatestVersionForUsername, queue size: %d", [_keyVersionQueue operationCount] );
    
    GetKeyVersionOperation * op = [[GetKeyVersionOperation alloc] initWithCache:self username:username completionCallback: callback];
    [self.getSecretQueue addOperation:op];
    
    
}

-(void) updateLatestVersionForUsername: (NSString *) username version: (NSString * ) version {
    if (username && version) {
        NSString * latestVersion = [_latestVersionsDict objectForKey:username];
        if (!latestVersion || [version integerValue] > [latestVersion integerValue]) {
            DDLogInfo(@"updating latest key version to %@ for %@", version, username);
            [_latestVersionsDict setObject:version forKey:username];
            [self saveLatestVersions];
        }
    }
}


-(void) cacheSharedSecret: secret forKey: sharedSecretKey {
    [_sharedSecretsDict setObject:secret forKey:sharedSecretKey];
    [self saveSharedSecrets];
}


@end
