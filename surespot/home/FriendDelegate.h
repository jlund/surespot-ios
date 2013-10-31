//
//  FriendDelegate.h
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#define INVITE_ACTION_BLOCK 0;
#define INVITE_ACTION_IGNORE 1;
#define INVITE_ACTION_ACCEPT 2;

@protocol FriendDelegate <NSObject>
-(void) inviteAction:(NSInteger) action forUsername:(NSString *) username;
@end
