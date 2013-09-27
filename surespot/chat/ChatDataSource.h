//
//  ChatDataSource.h
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChatDataSource : NSObject
@property (strong) NSMutableArray * messages;
- (void) addMessage:(NSDictionary *) message;
@end
