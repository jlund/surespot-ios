//
//  ChatController.h
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "SocketIO.h"
#import "ChatDataSource.h"

@interface ChatController : NSObject <SocketIODelegate>
+(ChatController*)sharedInstance;

@property (strong) NSMutableDictionary * dataSources;

- (ChatDataSource *) getDataSourceForFriendname: (NSString *) friendname;
- (void) sendMessage: (NSString *) message toFriendname: (NSString *) friendname;
@end