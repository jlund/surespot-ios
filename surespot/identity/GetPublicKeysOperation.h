//
//  GetPublicKeysOperation.h
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PublicKeys.h"

@interface GetPublicKeysOperation : NSOperation
@property (nonatomic, strong) void(^callback)(PublicKeys *);
-(id) initWithUsername: (NSString *) username version: (NSString *) version completionCallback:(void(^)(PublicKeys *))  callback;
@end
