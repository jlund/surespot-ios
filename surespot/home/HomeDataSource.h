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
- (void) addFriend: (Friend *) afriend withRefresh: (BOOL) refresh;
- (void) removeFriend: (Friend *) afriend withRefresh: (BOOL) refresh;
-(Friend *) getFriendByName: (NSString *) name;
-(void) postRefresh;
@end
