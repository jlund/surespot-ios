//
//  IdentityController.m
//  surespot
//
//  Created by Adam on 6/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//


#import "IdentityController.h"
#import "EncryptionController.h"
#import "FileController.h"
#import "SurespotIdentity.h"
#import "NSData+Gunzip.h"
#include <zlib.h>

@implementation IdentityController

NSString *const CACHE_IDENTITY_ID = @"_cache_identity";
NSString *const EXPORT_IDENTITY_ID = @"_export_identity";

+ (SurespotIdentity *) getIdentityWithUsername:(NSString *) username andPassword:(NSString *) password {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:username ofType:@"ssi"];
    NSData *myData = [NSData dataWithContentsOfFile:filePath];
    
    if (myData) {
        //gunzip the identity data
        //NSError* error = nil;
        NSData* unzipped = [myData gunzippedData];
        
        
        
        
        NSData * identity = [EncryptionController decryptIdentity: unzipped withPassword:password];
        return [self decryptIdentityData:identity withUsername:username andPassword:password];
    }
    
    return nil;
}


+( SurespotIdentity *) decryptIdentityData: (NSData *) identityData withUsername: (NSString *) username andPassword: (NSString *) password {    
    try {
        NSError* error;
        
        NSDictionary* dic = [NSJSONSerialization JSONObjectWithData:identityData options:kNilOptions error:&error];
        
        //convert keys from json
        NSString * username = [dic objectForKey:@"username"];
        NSString * salt = [dic objectForKey:@"salt"];
        NSArray * keys = [dic objectForKey:@"keys"];
        
        SurespotIdentity * si = [[SurespotIdentity alloc] initWithUsername:username andSalt:salt];
        
        //
        for (NSDictionary * key in keys) {
            
            NSString * version = [key objectForKey:@"version"];
        //    NSString * dpubDH = [key objectForKey:@"dhPub"];
            NSString * dprivDH = [key objectForKey:@"dhPriv"];
         //   NSString * dsaPub = [key objectForKey:@"dsaPub"];
            NSString * dsaPriv = [key objectForKey:@"dsaPriv"];
            
            
            
            CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC dhPrivKey = [EncryptionController recreateDhPrivateKey:dprivDH];
            CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey dsaPrivKey = [EncryptionController recreateDsaPrivateKey:dsaPriv];
            CryptoPP::DL_PublicKey_EC<ECP> dhPubKey;
            dhPrivKey.MakePublicKey(dhPubKey);
            
            CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey dsaPubKey;
            dsaPrivKey.MakePublicKey(dsaPubKey);
            //            dsaPubKey.Load(<#CryptoPP::BufferedTransformation &bt#>);
            //    CryptoPP::ECPPoint point;
            
            //    CryptoPP::ECDH<ECP>::Decryptor d;
            
            
            // CryptoPP::DL_PublicKey_EC<CryptoPP::ECPPoint> dhPubKey;
            //  dhPrivKey.MakePublicKey(&key2);
            
            //    CryptoPP::DL_PublicKey_EC<CryptoPP::ECPPoint> dsaPubKey;
            //    dsaPrivKey.MakePublicKey(&dsaPubKey);
            
            
            
            [si addKeysWithVersion:version withDhPrivKey:dhPrivKey withDhPubKey:dhPubKey withDsaPrivKey:dsaPrivKey withDsaPubKey:dsaPubKey];
        }
        
        return si;
        
    } catch (const CryptoPP::Exception& e) {
        // cerr << e.what() << endl;
    }
    return nil;
    
}


+ (void) createIdentityWithUsername: (NSString *) username
                        andPassword: (NSString *) password
                            andSalt: (NSString *) salt
                            andKeys: (IdentityKeys *) keys {
    
    NSString * identityDir = [FileController getAppSupportDir];
    SurespotIdentity * identity = [[SurespotIdentity alloc] initWithUsername:username andSalt:salt];
    [identity addKeysWithVersion:@"1" withDhPrivKey:[keys dhPrivKey] withDhPubKey:[keys dhPubKey] withDsaPrivKey:[keys dsaPrivKey] withDsaPubKey:[keys dsaPubKey] ];
    
    [self saveIdentity:identity toDir:identityDir withPassword:[password stringByAppendingString:CACHE_IDENTITY_ID]];
}

+ (NSString *) saveIdentity: (SurespotIdentity *) identity toDir: (NSString *) identityDir withPassword: (NSString *) password {
    
}

@end
