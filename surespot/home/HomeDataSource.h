//
//  HomeDataSource.h
//  surespot
//
//  Created by Adam on 11/2/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Friend.h"

@interface HomeDataSource : NSObject

@property (strong, atomic) NSMutableArray *friends;
@property (atomic, assign) NSInteger latestUserControlId;
@property (strong, nonatomic) NSString * currentChat;

- (void) addFriendInvited: (NSString *) name;
- (void) addFriendInviter: (NSString *) name;
- (void) setFriend: (NSString *) username;
- (void) removeFriend: (Friend *) afriend withRefresh: (BOOL) refresh;
-(Friend *) getFriendByName: (NSString *) name;
-(void) postRefresh;
-(void) setAvailableMessageId: (NSInteger) availableId forFriendname: (NSString *) friendname;
-(void) setAvailableMessageControlId: (NSInteger) availableId forFriendname: (NSString *) friendname;
-(void) writeToDisk ;
-(void) loadFriendsCallback: (void(^)(BOOL success)) callback;
-(BOOL) hasAnyNewMessages;
-(void) setFriendImageUrl: (NSString *) url forFriendname: (NSString *) name version: version iv: iv;
@end
