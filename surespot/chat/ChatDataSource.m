//
//  ChatDataSource.m
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChatDataSource.h"

@implementation ChatDataSource

-(ChatDataSource*)init{
    //call super init
    self = [super init];
    
    if (self != nil) {
               [self setMessages:[[NSMutableArray alloc] init]];
    }
    
    return self;
}


- (void) addMessage:(NSDictionary *) message {
     [[self messages] addObject:message];
}

@end
