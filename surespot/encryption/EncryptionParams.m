//
//  EncryptionParams.m
//  surespot
//
//  Created by Adam on 12/14/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "EncryptionParams.h"

@implementation EncryptionParams
-(id) initWithOurUsername: (NSString *) ourUsername
               ourVersion: (NSString *) ourVersion
            theirUsername: (NSString *) theirUsername
             theirVersion: (NSString *) theirVersion
                       iv: (NSString *) iv {
    self = [super init];
    if (self) {
        self.ourUsername = ourUsername;
        self.ourVersion = ourVersion;
        self.theirUsername = theirUsername;
        self.theirVersion = theirVersion;
        self.iv = iv;
    }    
    
    return self;

}
@end
