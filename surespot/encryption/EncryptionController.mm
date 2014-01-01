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
#import <CommonCrypto/CommonDigest.h>

using CryptoPP::BitBucket;
static CryptoPP::AutoSeededRandomPool randomRng(true, 32);

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface EncryptionController()
+(ECDSAPublicKey *) serverPublicKey;
@end

@implementation EncryptionController

int const IV_LENGTH = 16;
int const SALT_LENGTH = 16;
int const AES_KEY_LENGTH = 32;
int const PBKDF_ROUNDS_LEGACY = 1000;
int const PBKDF_ROUNDS = 20000;

+(ECDSAPublicKey *) serverPublicKey {
    static ECDSAPublicKey * serverPublicKey;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        serverPublicKey = [self recreateDsaPublicKey:serverPublicKeyString];
    });
    
    return serverPublicKey;
}

+ (NSData *) encryptIdentity:(NSData *) data withPassword:(NSString *) password {
    return [self encryptData:data withPassword:password andRounds:PBKDF_ROUNDS_LEGACY];
}

+ (NSData *) decryptIdentity:(NSData *) data withPassword:(NSString *) password {
    return [self decryptData:data withPassword:password andRounds:PBKDF_ROUNDS_LEGACY];
}

+ (NSData *) encryptData:(NSData *) data withPassword:(NSString *) password {
    return [self encryptData:data withPassword:password andRounds:PBKDF_ROUNDS];
}

+ (NSData *) decryptData:(NSData *) data withPassword:(NSString *) password  {
    return [self decryptData:data withPassword:password andRounds:PBKDF_ROUNDS];
}


+ (NSData *) encryptData:(NSData *) data withPassword:(NSString *) password andRounds: (NSInteger) rounds
{
    int length = [data length];
    byte * identityBytes = (byte*)[data bytes];
    
    //generate iv
    byte ivBytes[IV_LENGTH];
    randomRng.GenerateBlock(ivBytes, IV_LENGTH);
    
    //derive password and salt
    NSDictionary * derived =[self deriveKeyFromPassword:password andRounds: rounds];
    
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

+ (NSData *) decryptData:(NSData *) data withPassword:(NSString *) password andRounds: (NSInteger) rounds
{
    
    byte * identityBytes = (byte*)[data bytes];
    
    int cipherLength = [data length] - IV_LENGTH - SALT_LENGTH;
    byte cipherByte[cipherLength];
    byte ivBytes[IV_LENGTH];
    byte saltBytes[SALT_LENGTH];
    
    memcpy(ivBytes, identityBytes, IV_LENGTH);
    memcpy(saltBytes, identityBytes + IV_LENGTH, SALT_LENGTH);
    memcpy(cipherByte, identityBytes + IV_LENGTH + SALT_LENGTH, cipherLength);
    
    NSData * key = [self deriveKeyUsingPassword: password andSalt:[NSData dataWithBytes:saltBytes length:SALT_LENGTH] andRounds:rounds];
    
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
    
    DDLogVerbose(@"recovered: %s", jsonIdentity.data());
    NSData * jsonData = [NSData dataWithBytes:jsonIdentity.data() length:jsonIdentity.length()];
    return jsonData;
}


+(NSData *) getIv {
    byte* iv = new byte[IV_LENGTH];
    randomRng.GenerateBlock(iv, IV_LENGTH);
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

+(NSData *) encryptData: (NSData *) data usingKey: (NSData *) key usingIv: (NSData *) iv {
    GCM<AES>::Encryption e;
    e.SetKeyWithIV((byte *)[key bytes], AES_KEY_LENGTH, (byte *)[iv bytes],IV_LENGTH);
    
    
    string encrypted;
    CryptoPP::AuthenticatedEncryptionFilter ef (e, new StringSink(encrypted));
    
    
    ef.Put(reinterpret_cast<const unsigned char *>([data bytes]), [data length]);
    ef.MessageEnd();
    
    return [NSData dataWithBytes:encrypted.data() length:encrypted.length()];
}

+(NSString *) decryptCipher: (NSString *) cipher usingKey: (NSData *) key usingIv: (NSData *) iv {
    NSData * cipherData = [NSData dataFromBase64String:cipher];
    NSData * decryptedData = [self decryptData:cipherData usingKey:key usingIv:iv];
    NSString * plainString =[[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
    
    if (plainString == nil) {
        return NSLocalizedString(@"message_error_decrypting_message", nil);
    }
    return plainString;
}

+(NSData *) decryptData: (NSData *) data usingKey: (NSData *) key usingIv: (NSData *) iv {
    GCM<AES>::Decryption d;
    UInt8 * keyBytes = (UInt8 *)[key bytes];
    d.SetKeyWithIV(keyBytes, AES_KEY_LENGTH, (byte *)[iv bytes],IV_LENGTH);
    
    
    string decrypted;
    CryptoPP::AuthenticatedDecryptionFilter df (d, new StringSink(decrypted));
    
    byte * cipherByte = (byte *)[data bytes];
    df.Put(cipherByte, data.length);
    try {
        df.MessageEnd();
    }
    catch (CryptoPP::HashVerificationFilter::HashVerificationFailed e) {
        DDLogError(@"error decrypting, e: %s", e.GetWhat().data());
        return nil;
    }
    
    
    return [NSData dataWithBytes:decrypted.data() length:decrypted.length()];
    
}

+(NSData *) generateSharedSecret: (ECDHPrivateKey *) privateKey publicKey:(ECDHPublicKey *) publicKey {
    OID CURVE = secp521r1();
    ECDH < ECP >::Domain dhA( CURVE );
    CryptoPP::SecByteBlock secA(dhA.AgreedValueLength());
    dhA.Agree(secA, privateKey->GetPrivateExponent(), publicKey->GetPublicElement());
    NSData * key = [NSData dataWithBytes:secA.data() length:secA.SizeInBytes()];
    return key;
}

+(NSData *) deriveKeyUsingPassword:(NSString *)password andSalt:(NSData *)salt {
    return [self deriveKeyUsingPassword:password andSalt:salt andRounds:PBKDF_ROUNDS_LEGACY];
}

+(NSData *) deriveKeyUsingPassword:(NSString *)password andSalt:(NSData *)salt andRounds: (NSInteger) rounds {
    
    byte * bytes = new byte[AES_KEY_LENGTH];
    NSData * passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    byte * passwordBytes = (byte *) [passwordData bytes];
    
    CryptoPP::PKCS5_PBKDF2_HMAC<SHA256> kdf;
    kdf.DeriveKey(bytes, AES_KEY_LENGTH, 0, passwordBytes, [passwordData length], (byte *)[salt bytes],  SALT_LENGTH, rounds, 0);
    return [NSData dataWithBytes:bytes length:AES_KEY_LENGTH];
}

+ (NSDictionary *) deriveKeyFromPassword: (NSString *) password {
    return [self deriveKeyFromPassword:password andRounds:PBKDF_ROUNDS_LEGACY];
}

+ (NSDictionary *) deriveKeyFromPassword: (NSString *) password andRounds: (NSInteger) rounds {
    
    
    NSMutableDictionary * derived = [[NSMutableDictionary alloc] initWithCapacity:2];
    CryptoPP::SecByteBlock keyBytes(AES_KEY_LENGTH);
    CryptoPP::SecByteBlock saltBytes(SALT_LENGTH);
    
    randomRng.GenerateBlock(saltBytes, SALT_LENGTH);
    
    [derived setObject:[NSData dataWithBytes:saltBytes length:SALT_LENGTH] forKey:@"salt"];
    
    CryptoPP::PKCS5_PBKDF2_HMAC<SHA256> kdf;
    NSData * passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    
    kdf.DeriveKey(keyBytes, AES_KEY_LENGTH, 0, (byte *)[passwordData bytes], [passwordData length], saltBytes,  SALT_LENGTH, rounds, 0);
    
    [derived setObject:[NSData dataWithBytes:keyBytes length:AES_KEY_LENGTH] forKey:@"key"];
    return derived;
}


+ (NSData *) decodePublicKey: (NSString *) encodedKey {
    
    //unpem the key
    NSString * afterHeader = [encodedKey substringFromIndex:[encodedKey rangeOfString:@"\n"].location + 1];
    NSString * beforeHeader = [afterHeader substringToIndex: [afterHeader rangeOfString:@"\n" options: NSBackwardsSearch].location ];
    
    return [NSData dataFromBase64String: beforeHeader];
}


+ (ECDHPublicKey *) recreateDhPublicKey: (NSString *) encodedKey {
    ECDHPublicKey * publicKey = new ECDHPublicKey();
    NSData * decodedKey = [self decodePublicKey:encodedKey];
    ByteQueue byteQueue;
    byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
    publicKey->Load(byteQueue);
    bool validated = publicKey->Validate(randomRng, 3);
    
    if (!validated) {
        DDLogWarn(@"dh public key not validated");
    }
    return publicKey;
}


+ (ECDHPrivateKey *) recreateDhPrivateKey:(NSString *) encodedKey validate: (BOOL) validate {
    DDLogInfo(@"validate: %hhd", validate);
    if (encodedKey) {
        ECDHPrivateKey * privateKey = new ECDHPrivateKey();
        NSData * decodedKey = [NSData dataFromBase64String: encodedKey];
        ByteQueue byteQueue;
        byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
        DDLogInfo(@"loading key start");
        privateKey->Load(byteQueue);
        
        if (validate) {
            if (!privateKey->Validate(randomRng, 3)) {
                DDLogWarn(@"dh private key failed validation");
                return nil;
            }
        }
        
        return privateKey;
    }
    return nil;
}

+ (ECDSAPublicKey *) recreateDsaPublicKey: (NSString *) encodedKey {
    ECDSAPublicKey * publicKey = new ECDSAPublicKey();
    NSData * decodedKey = [self decodePublicKey:encodedKey];
    ByteQueue byteQueue;
    byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
    publicKey->Load(byteQueue);
    bool validated = publicKey->Validate(randomRng, 3);
    
    if (!validated) {
        DDLogWarn(@"dsa public key not validated");
    }
    
    return publicKey;
}


+ (ECDSAPrivateKey *) recreateDsaPrivateKey:(NSString *) encodedKey validate: (BOOL) validate {
    DDLogInfo(@"validate: %hhd", validate);
    ECDSAPrivateKey * privateKey = new ECDSAPrivateKey();
    NSData * decodedKey = [ NSData dataFromBase64String:encodedKey];
    ByteQueue byteQueue;
    byteQueue.Put((byte *) [decodedKey bytes], [decodedKey length]);
    DDLogInfo(@"loading key start");
    privateKey->Load(byteQueue);
    
    if (validate) {
        if (!privateKey->Validate(randomRng, 3)) {
            DDLogWarn(@"dsa private key failed validation");
            return nil;
        }
    }
    
    DDLogInfo(@"loading key end");
    return privateKey;
}

+ (NSData *) signUsername: (NSString *) username andPassword: (NSData *) password withPrivateKey: (ECDSAPrivateKey *) privateKey {
    CryptoPP::ECDSA<ECP, SHA256>::Signer signer(*privateKey);
    NSData * usernameData =[username dataUsingEncoding:NSUTF8StringEncoding];
    return [self signData1:usernameData data2:password withPrivateKey:privateKey];
}

+ (NSData *) signData1: (NSData *) data1 data2: (NSData *) data2 withPrivateKey: (ECDSAPrivateKey *) privateKey {
    CryptoPP::ECDSA<ECP, SHA256>::Signer signer(*privateKey);
    
    byte * random = new byte[16];
    randomRng.GenerateBlock(random,16);
    
    NSMutableData *concatData = [NSMutableData dataWithData: data1];
    [concatData appendData:data2];
    [concatData appendBytes:random length:16];
    int sigLength = signer.MaxSignatureLength();
    
    byte * signature = new byte[sigLength];
    int sigLen = signer.SignMessage(randomRng, (byte *)[concatData bytes], concatData.length, signature);
    
    byte * buffer = new Byte[1000];
    int put = CryptoPP::DSAConvertSignatureFormat(buffer, 1000, CryptoPP::DSASignatureFormat::DSA_DER, signature, sigLen, CryptoPP::DSASignatureFormat::DSA_P1363);
    
    NSMutableData * sig = [NSMutableData dataWithBytesNoCopy:random  length:16 freeWhenDone:true];
    [sig appendBytes:buffer length:put];
    
    return sig;
}

+(BOOL) verifyPublicKeySignature: (NSData *) signature data: (NSString *) data {
    CryptoPP::ECDSA<ECP, SHA256>::Verifier verifier(*[self serverPublicKey]);
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
    ECDHPrivateKey * dhKey = new ECDHPrivateKey();
    
    dhKey->Initialize(randomRng, secp521r1());
    bool dhvalid = dhKey->Validate(randomRng, 3);
    
    if (dhvalid) {
        CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PrivateKey * dsaKey = new ECDSAPrivateKey();
        
        dsaKey->Initialize( randomRng, secp521r1());
        bool dsaValid = dsaKey->Validate( randomRng, 3 );
        
        if (dsaValid) {
            IdentityKeys * ik = [[IdentityKeys alloc] init];
            ik.version = @"1";
            
            ik.dhPrivKey = dhKey;
            ECDHPublicKey * dhPubKey = new ECDHPublicKey();
            dhKey->MakePublicKey(*dhPubKey);
            ik.dhPubKey = dhPubKey;
            
            CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey * dsaPubKey = new ECDHPublicKey();
            dsaKey->MakePublicKey(*dsaPubKey);
            ik.dsaPubKey = dsaPubKey;
            ik.dsaPrivKey = dsaKey;
            return ik;
        }
    }
    return nil;
}


+(NSString *) encodeDHPrivateKey: (ECDHPrivateKey *) dhPrivKey {
    ByteQueue dhPrivByteQueue;
    dhPrivKey->Save(dhPrivByteQueue);
    size_t size = dhPrivByteQueue.TotalBytesRetrievable();
    byte encoded[dhPrivByteQueue.TotalBytesRetrievable()];
    dhPrivByteQueue.Get(encoded, size);
    
    NSData * keyData = [NSData dataWithBytes:encoded length:size];
    return [keyData SR_stringByBase64Encoding];
}

+(NSString *) encodeDHPublicKey: (ECDHPublicKey *) dhPubKey {
     return [self pemKey:[self encodeDHPublicKeyData:dhPubKey]];
}

+(NSData *) encodeDHPublicKeyData: (ECDHPublicKey *) dhPubKey {
    
    
    ByteQueue byteQueue;
    
    //hard code the asn.1 oids for the curve we're using to the encoded output...don't know why crypto++ doesn't do this
    //will have to revisit if we ever use any other curves
    byte oidBytes[] = {0x30, 0x81, 0x9B, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23, 0x03, 0x81, 0x86, 0x00};
    byteQueue.Put(oidBytes, 25);
    
    dhPubKey->DEREncodePublicKey(byteQueue);
    
    size_t size = byteQueue.TotalBytesRetrievable();
    
    byte encoded[byteQueue.TotalBytesRetrievable()];
    
    //size_t size =
    byteQueue.Get(encoded, size);
    
    return [NSData dataWithBytes:encoded length:size];
    

}

+(NSString *) encodeDSAPrivateKey: (ECDSAPrivateKey *) dsaPrivKey {
    ByteQueue dsaPrivByteQueue;
    dsaPrivKey->Save(dsaPrivByteQueue);
    size_t size = dsaPrivByteQueue.TotalBytesRetrievable();
    byte encoded[dsaPrivByteQueue.TotalBytesRetrievable()];
    dsaPrivByteQueue.Get(encoded, size);
    
    NSData * keyData = [NSData dataWithBytes:encoded length:size];
    return [keyData SR_stringByBase64Encoding];
}

+(NSData *) encodeDSAPublicKeyData: (ECDSAPublicKey *) dsaPubKey {
    ByteQueue byteQueue;
    
    //hard code the asn.1 oids for the curve we're using to the encoded output...don't know why crypto++ doesn't do this
    //will have to revisit if we ever use any other curves
    byte oidBytes[] = {0x30, 0x81, 0x9B, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23, 0x03, 0x81, 0x86, 0x00};
    byteQueue.Put(oidBytes, 25);
    
    dsaPubKey->DEREncodePublicKey(byteQueue);
    
    size_t size = byteQueue.TotalBytesRetrievable();
    
    byte encoded[byteQueue.TotalBytesRetrievable()];
    
    //size_t size =
    byteQueue.Get(encoded, size);
    
    return [NSData dataWithBytes:encoded length:size];
  
}

+(NSString *) encodeDSAPublicKey: (ECDSAPublicKey *) dsaPubKey {
    return [self pemKey:[self encodeDSAPublicKeyData:dsaPubKey]];
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
        if (secret) {
            NSData * cipherText = [EncryptionController encryptPlain:plaintext usingKey:secret usingIv:iv];
            callback([cipherText SR_stringByBase64Encoding]);
        }
        else {
            callback(nil);
        }
    }];
    
}

+(void) symmetricEncryptData: (NSData *) data ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion iv: (NSData *) iv callback: (CallbackBlock) callback {
    
    [[CredentialCachingController sharedInstance] getSharedSecretForOurVersion:ourVersion theirUsername:theirUsername theirVersion:theirVersion callback: ^(NSData * secret) {
        if (secret) {
            NSData * cipherData = [EncryptionController encryptData:data usingKey:secret usingIv:iv];
            callback(cipherData);
        }
        else {
            callback(nil);
        }
    }];
    
}

+(void) symmetricDecryptString: (NSString *) cipherData ourVersion: (NSString *) ourVersion theirUsername: (NSString *) theirUsername theirVersion: (NSString *) theirVersion iv: (NSString *) iv callback: (CallbackBlock) callback {
    
    [[CredentialCachingController sharedInstance] getSharedSecretForOurVersion:ourVersion theirUsername:theirUsername theirVersion:theirVersion callback: ^(NSData * secret) {
        if (secret) {
            NSData * ivData = [NSData dataFromBase64String:iv];
            NSString * plainText = [EncryptionController decryptCipher:cipherData usingKey:secret usingIv:ivData];
            callback(plainText);
        }
        else {
            callback(nil);
        }
    }];
    
}

+(NSData *) symmetricDecryptData: (NSData *) cipherData key: (NSData *) key iv: (NSString *) iv {
    
    
    if (key) {
        NSData * ivData = [NSData dataFromBase64String:iv];
        return [self decryptData:cipherData usingKey:key usingIv:ivData];
    }
    
    return nil;
    
}


+(ECDHPublicKey *) createPublicDHFromPrivKey: (ECDHPrivateKey *) privateKey {
    ECDHPublicKey * dhPubKey = new ECDHPublicKey();
    privateKey->MakePublicKey(*dhPubKey);
    return dhPubKey;
}

+(ECDSAPublicKey *) createPublicDSAFromPrivKey: (ECDSAPrivateKey *) privateKey {
    CryptoPP::ECDSA<ECP, CryptoPP::SHA256>::PublicKey * dsaPubKey = new ECDSAPublicKey();
    privateKey->MakePublicKey(*dsaPubKey);
    return dsaPubKey;
}


+(NSString *) md5: (NSData *) data {
    uint8_t digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, data.length, digest);
    
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

+(NSString *)hashedValueForAccountName:(NSString*)userAccountName
{
    const int HASH_SIZE = 32;
    unsigned char hashedChars[HASH_SIZE];
    const char *accountName = [userAccountName UTF8String];
    size_t accountNameLen = strlen(accountName);
    
    // Confirm that the length of the user name is small enough
    // to be recast when calling the hash function.
    if (accountNameLen > UINT32_MAX) {
        NSLog(@"Account name too long to hash: %@", userAccountName);
        return nil;
    }
    CC_SHA256(accountName, (CC_LONG)accountNameLen, hashedChars);
    
    // Convert the array of bytes into a string showing its hex representation.
    NSMutableString *userAccountHash = [[NSMutableString alloc] init];
    for (int i = 0; i < HASH_SIZE; i++) {
        // Add a dash every four bytes, for readability.
        if (i != 0 && i%4 == 0) {
            [userAccountHash appendString:@"-"];
        }
        [userAccountHash appendFormat:@"%02x", hashedChars[i]];
    }
    
    return userAccountHash;
}
@end
