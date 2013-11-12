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
#import "SurespotMessage.h"

@interface ChatController : NSObject <SocketIODelegate, FriendDelegate>
+(ChatController*)sharedInstance;
- (HomeDataSource *) getHomeDataSource;
- (ChatDataSource *) createDataSourceForFriendname: (NSString *) friendname availableId: (NSInteger) availableId availableControlId: (NSInteger) availableControlId;
- (ChatDataSource *) getDataSourceForFriendname: (NSString *) friendname;
-(void) destroyDataSourceForFriendname: (NSString *) friendname;

- (void) sendMessage: (NSString *) message toFriendname: (NSString *) friendname;
- (void) inviteUser: (NSString *) username;
- (void) setCurrentChat: (NSString *) username;
- (NSString *) getCurrentChat;
- (void) login;
- (void) logout;
- (void) deleteFriend: (Friend *) thefriend;
-(void) deleteMessage: (SurespotMessage *) message;
-(void) pause;
-(void) resume;
@end