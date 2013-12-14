//
//  EncryptionParams.h
//  surespot
//
//  Created by Adam on 12/14/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EncryptionParams : NSObject

-(id) initWithOurUsername: (NSString *) ourUsername
               ourVersion: (NSString *) ourversion
            theirUsername: (NSString *) theirUsername
             theirVersion: (NSString *) theirVersion
                       iv: (NSString *) iv;

@property (nonatomic, strong) NSString * ourUsername;
@property (nonatomic, strong) NSString * ourVersion;
@property (nonatomic, strong) NSString * theirUsername;
@property (nonatomic, strong) NSString * theirVersion;
@property (nonatomic, strong) NSString * iv;

@end
