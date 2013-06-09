//
//  EncryptionController.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

extern int const IV_LENGTH;
extern int const SALT_LENGTH;
extern int const AES_KEY_LENGTH;


@interface EncryptionController : NSObject

+ (NSData *) decryptIdentity:(NSData *) identityData withPassword:(NSString *) password;
@end
