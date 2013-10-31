//
//  ChatUtils.m
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChatUtils.h"
#import "IdentityController.h"

@implementation ChatUtils
+ (NSString *)  getOtherUserWithFrom: (NSString *) from andTo: (NSString *) to {
    return [to isEqualToString:[[IdentityController sharedInstance] getLoggedInUser] ] ? from : to;
}
+ (BOOL) isOurMessage: (SurespotMessage *) message {
    return  [[message from] isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]];
}

+ (NSString *) hexFromData: (NSData *) data {
    NSUInteger dataLength = [data length];
    NSMutableString *string = [NSMutableString stringWithCapacity:dataLength*2];
    const unsigned char *dataBytes = (unsigned char *)[data bytes];
    for (NSInteger idx = 0; idx < dataLength; ++idx) {
        [string appendFormat:@"%02x", dataBytes[idx]];
    }
    return string;
}

@end
