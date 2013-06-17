//
//  IdentityController.m
//  surespot
//
//  Created by Adam on 6/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//


#import "IdentityController.h"
#import "EncryptionController.h"
#import "NSData+Gunzip.h"
#include <zlib.h>

@implementation IdentityController
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

// http://cocoadev.com/wiki/NSDataCategory
+ (NSData *)gzipInflate:(NSData *) data
{
	if ([data length] == 0) return data;
	
	unsigned full_length = [data length];
	unsigned half_length = [data length] / 2;
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[data bytes];
	strm.avail_in = [data length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
	while (!done)
	{
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = (byte *)[decompressed mutableBytes] + strm.total_out;
		strm.avail_out = [decompressed length] - strm.total_out;
		
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) done = YES;
		else if (status != Z_OK) break;
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
	
	// Set real length.
	if (done)
	{
		[decompressed setLength: strm.total_out];
		return [NSData dataWithData: decompressed];
	}
	else return nil;
}

+ (NSData *)gzipDeflate:(NSData *) data
{
	if ([data length] == 0) return data;
	
	z_stream strm;
	
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in=(Bytef *)[data bytes];
	strm.avail_in = [data length];
	
	// Compresssion Levels:
	//   Z_NO_COMPRESSION
	//   Z_BEST_SPEED
	//   Z_BEST_COMPRESSION
	//   Z_DEFAULT_COMPRESSION
	
	if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
	
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
	
	do {
		
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = (byte *)[compressed mutableBytes] + strm.total_out;
		strm.avail_out = [compressed length] - strm.total_out;
		
		deflate(&strm, Z_FINISH);
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
	[compressed setLength: strm.total_out];
	return [NSData dataWithData:compressed];
}

@end
