//
//  ChatDataSource.h
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"

@interface ChatDataSource : NSObject

@property (nonatomic, strong) NSMutableArray * messages;
@property (nonatomic, strong) NSString * username;
@property (nonatomic, assign) NSInteger latestMessageId;
@property (nonatomic, assign) NSInteger latestControlMessageId;

-(ChatDataSource*)initWithUsername:(NSString *) username loggedInUser: (NSString * ) loggedInUser;
-(void) addMessage:(SurespotMessage *) message refresh:(BOOL) refresh;
-(void) postRefresh;

@end
