//
//  EncryptionController.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//
#import "EncryptionController.h"
#import "SurespotIdentity.h"
#import "CredentialCachingController.h"
#import "NSData+Base64.h"
#import "DDLog.h"
#import "SurespotConstants.h"
#import "cryptlib.h"
#import "filters.h"

using CryptoPP::BitBucket;
static CryptoPP::AutoSeededRandomPool rng;

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface EncryptionController()
+(ECDSAPPublicKey) serverPublicKey;
@end

@implementation EncryptionController

int const IV_LENGTH = 16;
int const SALT_LENGTH = 16;
int const AES_KEY_LENGTH = 32;
int const PBKDF_ROUNDS = 1000;

+(ECDSAPPublicKey) serverPublicKey {
    static ECDSAPPublicKey serverPublicKey;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        serverPublicKey = [self recreateDsaPublicKey:serverPublicKeyString];
    });
    
    return serverPublicKey;
}


+ (NSData *) encryptIdentity:(NSData *) identityData withPassword:(NSString *) password
{
    int length = [identityData length];
    byte * identityBytes = (byte*)[identityData bytes];
    
    //generate iv
    byte ivBytes[IV_LENGTH];
    rng.GenerateBlock(ivBytes, IV_LENGTH);
    
    //derive password and salt
    NSDictionary * derived =[self deriveKeyFromPassword:password];
    
    //encrypt the identity data
    byte * keyBytes = (byte *)[[derived objectForKey:@"key"] bytes];
    GCM<AES>::Encryption e;
    e.SetKeyWithIV(keyBytes, AES_KEY_LENGTH, ivBytes,IV_LENGTH);
    
    string cipherString;
    
    CryptoPP::AuthenticatedEncryptionFilter ef (e, new StringSink(cipherString));
    ef.Put(identityBytes, length);
    ef.MessageEnd();
    
    
    
    //return the iv salt and encrypted identity data in one buffer
    int returnLength = IV_LENGTH + SALT_LENGTH + cipherString.length();
    NSMutableData * returnData = [[NSMutableData alloc] initWithCapacity: returnLength];
    [returnData appendBytes:ivBytes length:IV_LENGTH];
    [returnData appendData:[derived objectForKey:@"salt"]];
    [returnData appendBytes:cipherString.data() length:cipherString.length()];
    
    
    return returnData;
}

+ (NSData *) decryptIdentity:(NSData *) identityData withPassword:(NSString *) password
{
    // CryptoPP::PKCS5_PBKDF2_HMAC<SHA256> kdf;
    byte * identityBytes = (byte*)[identityData bytes];
    
    int cipherLength = [identityData length] - IV_LENGTH - SALT_LENGTH;
    byte cipherByte[cipherLength];
    byte ivBytes[IV_LENGTH];
    byte saltBytes[SALT_LENGTH];
    // byte * passwordBytes = (byte *) [[password dataUsingEncoding:NSUTF8StringEncoding] bytes];
    memcpy(ivBytes, identityBytes, IV_LENGTH);
    memcpy(saltBytes, identityBytes + IV_LENGTH, SALT_LENGTH);
    memcpy(cipherByte, identityBytes + IV_LENGTH + SALT_LENGTH, cipherLength);
    
    NSData * key = [self deriveKeyUsingPassword: password andSalt:[NSData dataWithBytes:saltBytes length:SALT_LENGTH]];
    
    
    GCM<AES>::Decryption d;
    d.SetKeyWithIV((byte *)[key bytes], AES_KEY_LENGTH, ivBytes,IV_LENGTH);
    
    string jsonIdentity;
    
    
    try {
        CryptoPP::AuthenticatedDecryptionFilter df (d, new StringSink(jsonIdentity));
        df.Put(cipherByte, cipherLength);
        df.MessageEnd();
    }
    catch (CryptoPP::HashVerificationFilter::HashVerificationFailed e) {
        DDLogVerbose(@"error decrypting identity: %@", [NSString stringWithUTF8String: e.GetWhat().data()]);
        return nil;
    }
    
    
    //StringSource s(cipherByte, false, new CryptoPP::Redirector(df));
    
    // bool b =  df.GetLastResult();
    
    DDLogVerbose(@"recovered: %s", jsonIdentity.data());
    
    //convert json to NSDictionary
    
    NSString * jsonNSString =[[NSString alloc] initWithUTF8String:jsonIdentity.data()];
    NSData * jsonData = [jsonNSString dataUsingEncoding:NSUTF8StringEncoding];
    
    return jsonData;
}

+(NSData *) getIv {
    byte* iv = new byte[IV_LENGTH];
    rng.GenerateBlock(iv, IV_LENGTH);
    return [NSData dataWithBytes:iv length:IV_LENGTH];
}

+(NSData *) encryptPlain: (NSString *) plain usingKey: (NSData *) key usingIv: (NSData *) iv {
    GCM<AES>::Encryption e;
    e.SetKeyWithIV((byte *)[key bytes], AES_KEY_LENGTH, (byte *)[iv bytes],IV_LENGTH);
    
    
    string encrypted;
    CryptoPP::AuthenticatedEncryptionFilter ef (e, new StringSink(encrypted));
    
    
    
    ef.Put(reinterpret_cast<const unsigned char *>([plain cStringUsingEncoding:NSUTF8StringEncoding]), [plain lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    ef.MessageEnd();
    
    return [NSData dataWithBytes:encrypted.data() length:encrypted.length()];
}

+(NSString *) decryptCipher: (NSString *) cipher usingKey: (NSData *) key usingIv: (NSData *) iv {
    GCM<AES>::Decryption d;
    UInt8 * keyBytes = (UInt8 *)[key bytes];
    d.SetKeyWithIV(keyBytes, AES_KEY_LENGTH, (byte *)[iv bytes],IV_LENGTH);
    
    
    string decrypted;
    CryptoPP::AuthenticatedDecryptionFilter df (d, new StringSink(decrypted));
    
    NSData * cipherData = [NSData dataFromBase64String:cipher];
    byte * cipherByte = (byte *)[cipherData bytes];
    df.Put(cipherByte, cipherData.length);
    try {
        df.MessageEnd();
    }
    catch (CryptoPP::HashVerificationFilter::HashVerificationFailed e) {
        DDLogError(@"error decrypting, e: %s", e.GetWhat().data());
        return NSLocalizedString(@"message_error_decrypting_message", nil);
    }
    
    
    NSString * plainString =[[NSString alloc] initWithUTF8String:decrypted.data()];
    return plainString;
}

+(NSData *) generateSharedSecret: (ECDHPrivateKey) privateKey publicKey:(ECDHPublicKey) publicKey {
    OID CURVE = secp521r1();
    ECDH < ECP >::Domain dhA( CURVE );
    CryptoPP::SecByteBlock secA(dhA.AgreedValueLength());
    dhA.Agree(secA, privateKey.GetPrivateExponent(), publicKey.GetPublicElement());
    NSData * key = [NSData dataWithBytes:secA.data() length:secA.SizeInBytes()];
    return key;
}

+(NSData *) deriveKeyUsingPassword:(NSString *)password andSalt:(NSData *)salt {
    
    byte * bytes = new byte[AES_KEY_LENGTH];
    NSData * passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    byte * passwordBytes = (byte *) [passwordData bytes];
    
    CryptoPP::PKCS5_PBKDF2_HMAC<SHA256> kdf;
    kdf.DeriveKey(bytes, AES_KEY_LENGTH, 0, passwordBytes, [passwordData length], (byte *)[salt bytes],  SALT_LENGTH, PBKDF_ROUNDS, 0);
    return [NSData dataWithBytes:bytes length:AES_KEY_LENGTH];
}

+ (NSDictionary *) deriveKeyFromPassword: (NSString *) password {
    NSMutableDictionary * derived = [[NSMutableDictionary alloc] initWithCapacity:2];
    CryptoPP::SecByteBlock keyBytes(AES_KEY_LENGTH);
    CryptoPP::SecByteBlock saltBytes(SALT_LENGTH);
    
    rng.GenerateBlock(saltBytes, SALT_LENGTH);
    
    [derived setObject:[NSData dataWithBytes:saltBytes length:SALT_LENGTH] forKey:@"salt"];
    
    CryptoPP::PKCS5_PBKDF2_HMAC<SHA256> kdf;
    NSData * passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    
    kdf.DeriveKey(keyBytes, AES_KEY_LENGTH, 0, (byte *)[passwordData bytes], [passwordData length], saltBytes,  SALT_LENGTH, PBKDF_ROUNDS, 0);
    
    [derived setObject:[NSData dataWithBytes:keyBytes length:AES_KEY_LENGTH] forKey:@"key"];
    return derived;
}


+ (NSData *) decodePublicKey: (NSString *) encodedKey {
    
    //unpem the key
    NSString * afterHeader = [encodedKey substringFromIndex:[encodedKey rangeOfString:@"\n"].location + 1];
    NSString * beforeHeader = [afterHeader substringToIndex: [afterHeader rangeOfString:@"\n" options: NSBackwardsSearch].location ];
    
    return [NSData dataFromBase64String: beforeHeader];
}


+ (ECDHPublicKey) recreateDhPublicKey: (NSString *) encodedKey {
    ECDHPublicKey publicKey;
    NSData * decodedKey = [self decodePublicKey:encodedKey];
    ByteQueue byteQueue;
    byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
    publicKey.Load(byteQueue);
    bool validated = publicKey.Validate(rng, 3);
    
    if (!validated) {
        DDLogWarn(@"public key not validated");
    }
    return publicKey;
}


+ (ECDHPrivateKey) recreateDhPrivateKey:(NSString *) encodedKey {
    
    ECDHPrivateKey privateKey;
    NSData * decodedKey = [NSData dataFromBase64String: encodedKey];
    ByteQueue byteQueue;
    byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
    privateKey.Load(byteQueue);
    privateKey.Validate(rng, 3);
    
    return privateKey;
}

+ (ECDSAPublicKey) recreateDsaPublicKey: (NSString *) encodedKey {
    ECDSAPublicKey publicKey;
    NSData * decodedKey = [self decodePublicKey:encodedKey];
    ByteQueue byteQueue;
    byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
    publicKey.Load(byteQueue);
    bool validated = publicKey.Validate(rng, 3);
    
    if (!validated) {
        DDLogWarn(@"public key not validated");
    }
    
    return publicKey;
}


+ (CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey) recreateDsaPrivateKey:(NSString *) encodedKey {
    
    CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey privateKey;
    NSData * decodedKey = [ NSData dataFromBase64String:encodedKey];
    ByteQueue byteQueue;
    byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
    privateKey.Load(byteQueue);
    
    privateKey.Validate(rng, 3);
    
    return privateKey;
    
}

+ (NSData *) signUsername: (NSString *) username andPassword: (NSData *) password withPrivateKey: (ECDSAPrivateKey) privateKey {
    CryptoPP::ECDSA<ECP, SHA256>::Signer signer(privateKey);
    NSData * usernameData =[username dataUsingEncoding:NSUTF8StringEncoding];
    
    byte * random = new byte[16];
    rng.GenerateBlock(random,16);
    
    NSMutableData *concatData = [NSMutableData dataWithData: usernameData];
    [concatData appendData:password];
    [concatData appendBytes:random length:16];
    int sigLength = signer.MaxSignatureLength();
    
    byte * signature = new byte[sigLength];
    int sigLen = signer.SignMessage(rng, (byte *)[concatData bytes], concatData.length, signature);
    
    byte * buffer = new Byte[1000];
    int put = CryptoPP::DSAConvertSignatureFormat(buffer, 1000, CryptoPP::DSASignatureFormat::DSA_DER, signature, sigLen, CryptoPP::DSASignatureFormat::DSA_P1363);
    
    NSMutableData * sig = [NSMutableData dataWithBytesNoCopy:random  length:16 freeWhenDone:true];
    [sig appendBytes:buffer length:put];
    
    return sig;
}

+(BOOL) verifyPublicKeySignature: (NSData *) signature data: (NSString *) data {
    CryptoPP::ECDSA<ECP, SHA256>::Verifier verifier( [self serverPublicKey]);
    NSMutableData * keyData = [NSMutableData dataWithData:[data dataUsingEncoding:NSUTF8StringEncoding ]];
    byte * buffer = new Byte[verifier.SignatureLength()];
    
    int put = CryptoPP::DSAConvertSignatureFormat(buffer,verifier.SignatureLength(), CryptoPP::DSASignatureFormat::DSA_P1363, reinterpret_cast<unsigned char const* >([signature bytes]), [signature length], CryptoPP::DSASignatureFormat::DSA_DER);
    
    [keyData appendBytes:buffer length:put];
    delete buffer;
    
    bool result = false;
    StringSource ss((byte *)[keyData bytes], [keyData length], true,
                    new CryptoPP::SignatureVerificationFilter(
                                                              verifier,
                                                              new CryptoPP::ArraySink((byte*)&result, sizeof(result)),
                                                              CryptoPP::SignatureVerificationFilter::Flags::PUT_RESULT |
                                                              CryptoPP::SignatureVerificationFilter::Flags::SIGNATURE_AT_END
                                                              ) // SignatureVerificationFilter
                    ); // StringSource}
    return result ? YES : NO;
    
}

+(IdentityKeys *) generateKeyPairs {
    CryptoPP::DL_PrivateKey_EC<ECP>::DL_PrivateKey_EC dhKey;
    
    dhKey.Initialize(rng, secp521r1());
    bool dhvalid = dhKey.Validate(rng, 3);
    
    if (dhvalid) {
        CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey dsaKey;
        
        dsaKey.Initialize( rng, secp521r1());
        bool dsaValid = dsaKey.Validate( rng, 3 );
        
        if (dsaValid) {
            IdentityKeys * ik = [[IdentityKeys alloc] init];
            
            ik.dhPrivKey = dhKey;
            CryptoPP::DL_PublicKey_EC<ECP> dhPubKey;
            dhKey.MakePublicKey(dhPubKey);
            ik.dhPubKey = dhPubKey;
            
            CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey dsaPubKey;
            dsaKey.MakePublicKey(dsaPubKey);
            ik.dsaPubKey = dsaPubKey;
            ik.dsaPrivKey = dsaKey;
            return ik;
        }
    }
    return nil;
}


+(NSString *) encodeDHPrivateKey: (ECDHPrivateKey) dhPrivKey {
    ByteQueue dhPrivByteQueue;
    dhPrivKey.Save(dhPrivByteQueue);
    size_t size = dhPrivByteQueue.TotalBytesRetrievable();
    byte encoded[dhPrivByteQueue.TotalBytesRetrievable()];
    dhPrivByteQueue.Get(encoded, size);
    
    NSData * keyData = [NSData dataWithBytes:encoded length:size];
    return [keyData SR_stringByBase64Encoding];
}

+(NSString *) encodeDHPublicKey: (ECDHPublicKey) dhPubKey {
    
    
    ByteQueue byteQueue;
    
    //hard code the asn.1 oids for the curve we're using to the encoded output...don't know why crypto++ doesn't do this
    //will have to revisit if we ever use any other curves
    byte oidBytes[] = {0x30, 0x81, 0x9B, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23, 0x03, 0x81, 0x86, 0x00};
    byteQueue.Put(oidBytes, 25);
    
    dhPubKey.DEREncodePublicKey(byteQueue);
    
    size_t size = byteQueue.TotalBytesRetrievable();
    
    byte encoded[byteQueue.TotalBytesRetrievable()];
    
    //size_t size =
    byteQueue.Get(encoded, size);
    
    NSData * keyData = [NSData dataWithBytes:encoded length:size];
    
    return [self pemKey:keyData];
}

+(NSString *) encodeDSAPrivateKey: (ECDSAPrivateKey) dsaPrivKey {
    ByteQueue dsaPrivByteQueue;
    dsaPrivKey.Save(dsaPrivByteQueue);
    size_t size = dsaPrivByteQueue.TotalBytesRetrievable();
    byte encoded[dsaPrivByteQueue.TotalBytesRetrievable()];
    dsaPrivByteQueue.Get(encoded, size);
    
    NSData * keyData = [NSData dataWithBytes:encoded length:size];
    return [keyData SR_stringByBase64Encoding];
}

+(NSString *) encodeDSAPublicKey: (ECDSAPublicKey) dsaPubKey {
    ByteQueue byteQueue;
    
    //hard code the asn.1 oids for the curve we're using to the encoded output...don't know why crypto++ doesn't do this
    //will have to revisit if we ever use any other curves
    byte oidBytes[] = {0x30, 0x81, 0x9B, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23, 0x03, 0x81, 0x86, 0x00};
    byteQueue.Put(oidBytes, 25);
    
    dsaPubKey.DEREncodePublicKey(byteQueue);
    
    size_t size = byteQueue.TotalBytesRetrievable();
    
    byte encoded[byteQueue.TotalBytesRetrievable()];
    
    //size_t size =
    byteQueue.Get(encoded, size);
    
    NSData * keyData = [NSData dataWithBytes:encoded length:size];
    
    return [self pemKey:keyData];
    
}


//convert key to pem format
+(NSString *) pemKey: (NSData *) keyBytes {
    NSMutableString * keyString = [[NSMutableString alloc] initWithString:@"-----BEGIN PUBLIC KEY-----\n" ];
    [keyString appendString:[keyBytes base64EncodedStringWithSeparateLines:TRUE]];
    [keyString appendString: @"\n-----END PUBLIC KEY-----"];
    
    return keyString;
    
}

+(void) symmetricEncryptString: (NSString *) plaintext ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion iv: (NSData *) iv callback: (CallbackBlock) callback {
    
    [[CredentialCachingController sharedInstance] getSharedSecretForOurVersion:ourVersion theirUsername:theirUsername theirVersion:theirVersion callback: ^(NSData * secret) {
        NSData * cipherText = [EncryptionController encryptPlain:plaintext usingKey:secret usingIv:iv];
        callback([cipherText SR_stringByBase64Encoding]);
    }];
    
}

+(void) symmetricDecryptString: (NSString *) cipherData ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion iv: (NSString *) iv callback: (CallbackBlock) callback {
    
    [[CredentialCachingController sharedInstance] getSharedSecretForOurVersion:ourVersion theirUsername:theirUsername theirVersion:theirVersion callback: ^(NSData * secret) {
        NSData * ivData = [NSData dataFromBase64String:iv];
        
        NSString * plainText = [EncryptionController decryptCipher:cipherData usingKey:secret usingIv:ivData];
        callback(plainText);
    }];
    
}


@end
