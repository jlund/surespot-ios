//
//  FriendDelegate.h
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol FriendDelegate <NSObject>
-(void) inviteAction:(NSString *) action forUsername:(NSString *) username;
@end
