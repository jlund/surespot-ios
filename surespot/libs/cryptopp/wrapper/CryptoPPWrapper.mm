//
//  CryptoPPWrapper.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//
#import "CryptoPPWrapper.h"


#include <strstream>
#include <iostream>
using std::cout;
using std::cerr;
using std::endl;

#include <string>
using std::string;

#include <stdexcept>
using std::runtime_error;

#include <cstdlib>
using std::exit;

#include "sha.h"
using CryptoPP::SHA256;

#include "pwdbased.h"
using CryptoPP::PKCS5_PBKDF2_HMAC;

#include "eccrypto.h"
using CryptoPP::ECP;
using CryptoPP::ECDH;



@implementation SurespotCrypto : NSObject

-(void) doImport:(NSData *) data {
    CryptoPP::PKCS5_PBKDF2_HMAC<SHA256> kdf;
    CryptoPP::SecByteBlock dBytes(32);
    
    
    
    CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC privateKey;

    
    byte bytes[32];
    
    //CryptoPP::SecByteBlock salt(16);
    byte salt[16] = {0,0,0,0 ,0,0,0,0 ,0,0,0,0, 0,0,0,0};
    
    
   // string password = "b_cache_identity";
    byte bp[]  = { 0,98,0,0};
    byte p[] ={'b'};
    
    kdf.DeriveKey(bytes, 32, 0, p, 1, salt, 16, 1000, 0);
    
    
    
}
@end
