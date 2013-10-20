//
//  ChatDataSource.m
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChatDataSource.h"
#import "NetworkController.h"

@implementation ChatDataSource

-(ChatDataSource*)initWithUsername:(NSString *) username{
    //call super init
    self = [super init];
    
    if (self != nil) {
        [self setMessages:[[NSMutableArray alloc] init]];
        _username = username;
        NSLog(@"getting messageData");
        //load message data
        [[NetworkController sharedInstance] getMessageDataForUsername:username andMessageId:0 andControlId:0 successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            NSLog(@"get messageData response: %d",  [response statusCode]);
            
            NSArray * messageStrings =[((NSDictionary *) JSON) objectForKey:@"messages"];
            
            
            //convert messages to SurespotMessage
            for (NSString * messageString in messageStrings) {
                
                [self addMessage:[[SurespotMessage alloc] initWithJSONString:messageString]];
            }
            
            
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadMessages" object:username ];
            
            
            
        } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
            NSLog(@"get messagedata response error: %@",  Error);
            
        }];
        
        
    }
    
    return self;
}


- (void) addMessage:(SurespotMessage *) message {
    [[self messages] addObject:message];
}

@end
