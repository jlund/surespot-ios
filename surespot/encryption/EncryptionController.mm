//
//  EncryptionController.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//
#import "EncryptionController.h"
#import "SurespotIdentity.h"

int const IV_LENGTH = 16;
int const SALT_LENGTH = 16;
int const AES_KEY_LENGTH = 32;



#include <strstream>
#include <iostream>
using std::cout;
using std::cerr;
using std::endl;



#include "cryptlib.h"
using CryptoPP::Exception;

#include <string>
using std::string;

#include <stdexcept>
using std::runtime_error;

#include <cstdlib>
using std::exit;

#include "hex.h"

#include "sha.h"
using CryptoPP::SHA256;

#include "pwdbased.h"
using CryptoPP::PKCS5_PBKDF2_HMAC;

#include "eccrypto.h"
using CryptoPP::ECP;
using CryptoPP::ECDH;

#include "secblock.h"
using CryptoPP::SecByteBlock;

#include "oids.h"
using CryptoPP::OID;

// ASN1 is a namespace, not an object
#include "asn.h"
using namespace CryptoPP::ASN1;

#include "osrng.h"
using CryptoPP::AutoSeededRandomPool;
using CryptoPP::AutoSeededX917RNG;


#include "integer.h"
using CryptoPP::Integer;

#include "aes.h"
using CryptoPP::AES;
#include "gcm.h"
using CryptoPP::GCM;

#include "filters.h"
using CryptoPP::StringSink;
using CryptoPP::StringSource;
using CryptoPP::AuthenticatedEncryptionFilter;
using CryptoPP::AuthenticatedDecryptionFilter;
using CryptoPP::Redirector;
using CryptoPP::ByteQueue;

#include "NSData+SRB64Additions.h"

@implementation EncryptionController

+ (NSData *) decryptIdentity:(NSData *) identityData withPassword:(NSString *) password
{
    CryptoPP::PKCS5_PBKDF2_HMAC<SHA256> kdf;
    CryptoPP::SecByteBlock dBytes(32);
    byte * identityBytes = (byte*)[identityData bytes];
    
    int cipherLength = [identityData length] - IV_LENGTH - SALT_LENGTH;
    byte cipherByte[cipherLength];
    byte ivBytes[IV_LENGTH];
    byte saltBytes[SALT_LENGTH];
    byte * passwordBytes = (byte *) [[password dataUsingEncoding:NSUTF8StringEncoding] bytes];
    memcpy(ivBytes, identityBytes, IV_LENGTH);
    memcpy(saltBytes, identityBytes + IV_LENGTH, SALT_LENGTH);
    memcpy(cipherByte, identityBytes + IV_LENGTH + SALT_LENGTH, cipherLength);
    
    CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC privateKey;
    //
    //
    byte bytes[AES_KEY_LENGTH];
      
    kdf.DeriveKey(bytes, AES_KEY_LENGTH, 0, passwordBytes, [password length], saltBytes, 16, 1000, 0);
    
    try {
        
        GCM<AES>::Decryption d;
        d.SetKeyWithIV(bytes, 32, ivBytes,16);
        
        string jsonIdentity;
        
        CryptoPP::AuthenticatedDecryptionFilter df (d, new StringSink(jsonIdentity));
        df.Put(cipherByte, cipherLength);
        df.MessageEnd();
        
        
        //StringSource s(cipherByte, false, new CryptoPP::Redirector(df));
        
        bool b =  df.GetLastResult();
        
        cout << "Recovered " << jsonIdentity << endl;
        
        //convert json to NSDictionary
        NSError* error;
        NSString * jsonNSString =[[NSString alloc] initWithUTF8String:jsonIdentity.data()];
        NSData * jsonData = [jsonNSString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
        
        //convert keys from json
        NSString * username = [dic objectForKey:@"username"];
        NSString * salt = [dic objectForKey:@"salt"];
        NSArray * keys = [dic objectForKey:@"keys"];
        
        SurespotIdentity * si = [[SurespotIdentity alloc] initWithUsername:username andSalt:salt];
        
        //
        for (NSDictionary * key in keys) {
            
            NSString * version = [key objectForKey:@"version"];            
            NSString * dpubDH = [key objectForKey:@"dhPub"];
            NSString * dprivDH = [key objectForKey:@"dhPriv"];
            NSString * dsaPub = [key objectForKey:@"dsaPub"];
            NSString * dsaPriv = [key objectForKey:@"dsaPriv"];
            
            
            NSData * dhPrivData = [dprivDH dataUsingEncoding:NSUTF8StringEncoding];
            
            CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC privateKey;
            NSData * decodedKey = [dhPrivData base64decode];
            ByteQueue byteQueue;
            byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
            privateKey.Load(byteQueue);
            
            CryptoPP::Integer exp =privateKey.GetPrivateExponent();
            std::ostrstream oss;
            oss << std::ios::hex << exp;
            
            string s(oss.str());
            NSLog(@"pk: %s", s.c_str());
           // [si addKeyPairs:<#(NSString *)#> keyPairDH:<#(DL_Keys_EC<CryptoPP::ECP>)#> keyPairDSA:<#(DL_Keys_EC<CryptoPP::ECP>)#>]
        }
        
    } catch (const CryptoPP::Exception& e) {
        cerr << e.what() << endl;
    }
}


-(void) doECDH {
    
    OID CURVE = secp521r1();
    AutoSeededRandomPool rng;
    
    ECDH < ECP >::Domain dhA( CURVE );//, dhB( CURVE );
    
    CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC privateKey;
    
    //generate key pair
    SecByteBlock privA(dhA.PrivateKeyLength()), pubA(dhA.PublicKeyLength());
    
    //output keys
    //output key
    unsigned int ppkLength = dhA.PrivateKeyLength();
    unsigned int pkLength = dhA.PublicKeyLength();
    
    /*
     dhA.GenerateKeyPair(rng, privA, pubA);
     
     //recreate the private exponent from the generated buffer
     Integer privX = Integer(privA, ppkLength);
     
     //convert private exponent to hex string
     std::ostrstream oss;
     oss << std::hex  << privX << endl;
     string privateKeyHexString(oss.str());
     cout << "(generated private key): " << privateKeyHexString << endl;
     
     //convert encoded point buffer to hex stringh
     CryptoPP::HexEncoder hexEncoder;
     hexEncoder.Put(pubA, pkLength);
     hexEncoder.MessageEnd();
     byte generatedPublic[pkLength*2];
     hexEncoder.Get(generatedPublic, pkLength*2);
     cout << "(generated public key): " << std::hex << generatedPublic << endl;
     
     
     //convert recreated exponent back to buffer
     byte recreatedPriv[ppkLength];
     privX.Encode(recreatedPriv, ppkLength);
     */
    
    string localPrivKey = "015994ba5fb3beab44bd24c0e6f61b35f6404b3aa1cb261057c3fc17a6844b786761a03ea9aa6546638d0288b3237241e884f24d00ef7f0b23a0d10f4f528d74258e";
    
    string localPubKey = "0401444E87911CFD2C2A6FF2E31FB85D77ED83210D1466B09C82644DE9B9B9B03E53706784878533A1BF23B480606366BAD9AB46ED77D7A5D091F444DF9653FB35044D01C7DF492CEDD8CFC132129BD4063BA0EC8E2BF2240A8C13E1684DA48FCAF57324B687DA01D108B14F01C5F69BA4D28AD6E52EAAF259FC496230C7CE241D866526D4";
    
    string remotePubKey = "04018f55e6c93f203dc6813110173a5fb1043876747e402e4023793da32ca9f880c15996ed505b9462e517bd52cc2343eb05f3897499c2cdd1881291a066534631ead200069ab28a6e44bd4d6efc1ad93472ec528063a75b11ba519677da9c3351dc848a59a00adb66fa472676774d1e4f5240dbf0f9bdfe831ac9deefa51e8e76e896be19";
    
    // generate public point buffer from public hex string
    
    CryptoPP::HexDecoder hexDecoder;
    
    hexDecoder.Put((byte *) remotePubKey.data(), remotePubKey.size());
    hexDecoder.MessageEnd();
    byte recreatedPublic[pkLength];
    hexDecoder.Get(recreatedPublic, pkLength);
    
    
    //recreate private key
    byte recreatedPrivate[ppkLength];
    hexDecoder.Initialize();
    hexDecoder.Put((byte *) localPrivKey.data(), localPrivKey.size());
    hexDecoder.MessageEnd();
    hexDecoder.Get(recreatedPrivate, ppkLength);
    
    //output what it thinks the points are
    /*  ECP::Point p;
     CryptoPP::DL_PublicKey_EC<ECP>::DL_PublicKey_EC publicKey;
     publicKey.AccessGroupParameters().Initialize(CURVE);
     
     
     publicKey.GetGroupParameters().GetCurve().DecodePoint(
     p,
     recreatedPublic, publicKey.GetGroupParameters().GetCurve().EncodedPointSize());
     */
    //cout << "(px): " << std::hex << p.x << endl;
    //  cout << "(py): " << std::hex << p.y << endl;
    
    // publicKey.SetPublicElement(p);
    
    
    
    SecByteBlock sharedA(dhA.AgreedValueLength())    , sharedB(dhA.AgreedValueLength()),sharedC(dhA.AgreedValueLength()),
    sharedD(dhA.AgreedValueLength());
    
    if(!dhA.Agree(sharedA, recreatedPrivate, recreatedPublic))
        throw runtime_error("Failed to reach shared secret (A)");
    
    /* if(!dhA.Agree(sharedB, privA, pubA))
     throw runtime_error("Failed to reach shared secret (B)");
     if(!dhA.Agree(sharedC, recreatedPriv, recreatedPublic))
     throw runtime_error("Failed to reach shared secret (C)");
     
     if(!dhA.Agree(sharedD, recreatedPriv, pubA))
     throw runtime_error("Failed to reach shared secret (D)");*/
    
    Integer ssa, ib, ic, idd;
    
    //make sure the secrets all match
    ssa.Decode(sharedA.BytePtr(), sharedA.SizeInBytes());
    cout << "(shared key): " << std::hex << ssa << endl;
    
    /* ib.Decode(sharedB.BytePtr(), sharedB.SizeInBytes());
     cout << "(genPgenPP): " << std::hex << ib << endl;
     
     ic.Decode(sharedC.BytePtr(), sharedC.SizeInBytes());
     cout << "(decPdecPP): " << std::hex << ssa << endl;
     
     idd.Decode(sharedD.BytePtr(), sharedD.SizeInBytes());
     cout << "(genPdecPP): " << std::hex << ib << endl;*/
    
}

@end
