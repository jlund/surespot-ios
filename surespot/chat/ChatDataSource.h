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

-(ChatDataSource*)initWithUsername:(NSString *) username;
@property (strong) NSMutableArray * messages;
- (void) addMessage:(SurespotMessage *) message;
@property (strong, nonatomic) NSString * username;
-(NSInteger) latestMessageId;
-(NSInteger) latestControlMessageId;
-(void) postRefresh;
@end
