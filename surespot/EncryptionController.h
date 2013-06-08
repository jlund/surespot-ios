//
//  EncryptionController.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

int const PBKDF_ROUNDS = 1000;
int const BUFFER_SIZE = 1024;
int const AES_KEY_LENGTH = 32;
int const SALT_LENGTH = 16;
int const IV_LENGTH = 16;

@interface EncryptionController : NSObject
+ (unsigned char *) derive:(NSString *)password salt:(unsigned char *)salt;

@end
