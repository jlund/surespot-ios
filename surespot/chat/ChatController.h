//
//  ChatController.h
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SocketIO.h"
#import "ChatDataSource.h"
#import "HomeDataSource.h"
#import "Friend.h"
#import "FriendDelegate.h"

@interface ChatController : NSObject <SocketIODelegate, FriendDelegate>
+(ChatController*)sharedInstance;

- (HomeDataSource *) getHomeDataSource;
- (ChatDataSource *) getDataSourceForFriendname: (NSString *) friendname;
- (void) sendMessage: (NSString *) message toFriendname: (NSString *) friendname;
- (void) inviteUser: (NSString *) username;
@end