//
//  ChatDataSource.m
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChatDataSource.h"
#import "NetworkController.h"
#import "MessageProcessor.h"
#import "MessageDecryptionOperation.h"

@interface ChatDataSource()
@property (nonatomic, strong) NSOperationQueue * decryptionQueue;

@end

@implementation ChatDataSource

-(ChatDataSource*)initWithUsername:(NSString *) username {
    //call super init
    self = [super init];
    
    if (self != nil) {
        _decryptionQueue = [[NSOperationQueue alloc] init];
        
        
        [self setMessages:[[NSMutableArray alloc] init]];
        
        _username = username;
        NSLog(@"getting messageData");
        //load message data
        [[NetworkController sharedInstance] getMessageDataForUsername:username andMessageId:0 andControlId:0 successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            NSLog(@"get messageData response: %d",  [response statusCode]);
            
            NSArray * messageStrings =[((NSDictionary *) JSON) objectForKey:@"messages"];
            
            
            //convert messages to SurespotMessage
            for (NSString * messageString in messageStrings) {
                
                [self addMessage:[[SurespotMessage alloc] initWithJSONString:messageString] refresh:NO];
            }
            
            [_decryptionQueue waitUntilAllOperationsAreFinished];
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshMessages" object:username ];
            });
            
            
            
        } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
            NSLog(@"get messagedata response error: %@",  Error);
            
        }];
        
        
    }
    
    return self;
}


- (void) addMessage:(SurespotMessage *) message refresh: (BOOL) refresh {

    
    //decrypt and compute height
    if (!message.plainData) {
        
        MessageDecryptionOperation * op = [[MessageDecryptionOperation alloc]initWithMessage:message width: 200 completionCallback:^(SurespotMessage  * message){
            
            [self addMessageInternal: message refresh:refresh];
        }];
        [_decryptionQueue addOperation:op];
        
        
    }
    else {
        [self addMessageInternal:message refresh:refresh];
    }
    
}

-(void) addMessageInternal:(SurespotMessage *)message  refresh: (BOOL) refresh {
    NSUInteger index = [self.messages indexOfObject:message];
    if (index == NSNotFound) {
        NSLog(@"adding message iv: %@", message.iv);
        [self.messages addObject:message];
    }
    else {
        NSLog(@"updating message iv: %@", message.iv);
        SurespotMessage * existingMessage = [self.messages objectAtIndex:index];
        if (message.serverid) {
            existingMessage.serverid = message.serverid;
            existingMessage.dateTime = message.dateTime;
        }
    }
    
    if (refresh) {
        [self postRefresh];
    }
    
}

-(NSInteger) latestMessageId {
    NSInteger maxId = 0;
    for (SurespotMessage * message in _messages) {
        NSInteger idValue =[message.serverid integerValue];
        if (idValue > maxId) {
            maxId = idValue;
        }
    }
    
    return maxId;
}

-(NSInteger) latestControlMessageId {
    return 0;
}

-(void) postRefresh {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshMessages" object:_username ];
    });
}

@end
