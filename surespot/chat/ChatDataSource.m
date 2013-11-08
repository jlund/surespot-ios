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
#import "ChatUtils.h"
#import "FileController.h"
#import "DDLog.h"

static const int ddLogLevel = LOG_LEVEL_OFF;

@interface ChatDataSource()
@property (nonatomic, strong) NSOperationQueue * decryptionQueue;
@property (nonatomic, strong) NSString * loggedInUser;
@end

@implementation ChatDataSource

-(ChatDataSource*)initWithUsername:(NSString *) username loggedInUser: (NSString * ) loggedInUser {
    //call super init
    self = [super init];
    
    if (self != nil) {
        _decryptionQueue = [[NSOperationQueue alloc] init];
        _loggedInUser = loggedInUser;
        _username = username;
         _messages = [NSMutableArray new];
        
        NSArray * messages;
        
        NSString * path =[FileController getChatDataFilenameForSpot:[ChatUtils getSpotUserA:username userB:loggedInUser]];
        DDLogVerbose(@"looking for chat data at: %@", path);
        id chatData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (chatData) {
            DDLogVerbose(@"loading chat data from: %@", path);
           
            _latestControlMessageId = [[chatData objectForKey:@"latestControlMessageId"] integerValue];
            messages = [chatData objectForKey:@"messages"];
            
            //convert messages to SurespotMessage
            for (SurespotMessage * message in messages) {
                
                [self addMessage:message refresh:NO];
            }
            
           // [_decryptionQueue waitUntilAllOperationsAreFinished];
            DDLogVerbose(@"messages completed loading from disk at: %@", path);
//            dispatch_async(dispatch_get_main_queue(), ^{
//                [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshMessages" object:username ];
//            });
        }
        
        
        DDLogVerbose(@"getting messageData latestMessageId: %d, latestControlId: %d", _latestMessageId ,_latestControlMessageId);
        //load message data
        [[NetworkController sharedInstance] getMessageDataForUsername:username andMessageId:_latestMessageId andControlId:_latestControlMessageId successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            DDLogVerbose(@"get messageData response: %d",  [response statusCode]);
            
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
            DDLogVerbose(@"get messagedata response error: %@",  Error);
            
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
        DDLogVerbose(@"adding message iv: %@", message.iv);
        [self.messages addObject:message];
    }
    else {
        DDLogVerbose(@"updating message iv: %@", message.iv);
        SurespotMessage * existingMessage = [self.messages objectAtIndex:index];
        if (message.serverid) {
            existingMessage.serverid = message.serverid;
            existingMessage.dateTime = message.dateTime;
        }
    }
    
    if (message.serverid) {
        NSInteger messageId =[message.serverid integerValue];
        if (messageId > _latestMessageId) {
             DDLogVerbose(@"updating latest message id: %d", messageId);
            _latestMessageId = messageId;
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

-(void) writeToDisk {
    
    
    NSString * spot = [ChatUtils getSpotUserA:_loggedInUser userB:_username];
    NSString * filename =[FileController getChatDataFilenameForSpot: spot];
    DDLogVerbose(@"saving chat data to disk, spot: %@", spot);
    NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
    [dict setObject:_messages forKey:@"messages"];
    //[dict setObject:_username  forKey:@"username"];
    [dict setObject:[NSNumber numberWithInteger:_latestControlMessageId] forKey:@"latestControlMessageId"];
    
    
    BOOL saved =[NSKeyedArchiver archiveRootObject:dict toFile:filename];
    DDLogVerbose(@"save success?: %@",saved ? @"YES" : @"NO");
    
}

@end
