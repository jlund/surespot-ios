//
//  ChatUtils.h
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"

@interface ChatUtils : NSObject

+ (NSString *) getSpotUserA: (NSString *) userA userB: (NSString *) userB;
+ (NSString *)  getOtherUserWithFrom: (NSString *) from andTo: (NSString *) to;
+ (NSString *) getOtherUserFromSpot: (NSString *) spot andUser: (NSString *) user;

+ (BOOL) isOurMessage: (SurespotMessage *) message;
+ (NSString *) hexFromData: (NSData *) data ;
@end
