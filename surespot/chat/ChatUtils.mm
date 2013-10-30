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

@end
