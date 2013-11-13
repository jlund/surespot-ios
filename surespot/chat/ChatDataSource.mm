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
#import "IdentityController.h"
#import "FileController.h"
#import "DDLog.h"
#import "UIUtils.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface ChatDataSource()
@property (nonatomic, strong) NSOperationQueue * decryptionQueue;
@property (nonatomic, strong) NSString * loggedInUser;
@property (nonatomic, strong) NSMutableDictionary * controlMessages;
@end

@implementation ChatDataSource

-(ChatDataSource*)initWithUsername:(NSString *) username loggedInUser: (NSString * ) loggedInUser availableId:(NSInteger)availableId availableControlId:( NSInteger) availableControlId {
    
    DDLogInfo(@"username: %@, loggedInUser: %@, availableid: %d, availableControlId: %d", username, loggedInUser, availableId, availableControlId);
    //call super init
    self = [super init];
    
    if (self != nil) {
        _decryptionQueue = [[NSOperationQueue alloc] init];
        _loggedInUser = loggedInUser;
        _username = username;
        _messages = [NSMutableArray new];
        _controlMessages = [NSMutableDictionary new];
        
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
                
                [self addMessage:message refresh:YES];
            }
            
            //[_decryptionQueue waitUntilAllOperationsAreFinished];
            DDLogVerbose(@"loaded %d messages from disk at: %@", [messages count] ,path);
            DDLogInfo( @"latestMEssageid: %d, latestControlId: %d", _latestMessageId ,_latestControlMessageId);
            
            [self postRefresh];
        }
        
        if (availableId > _latestMessageId || availableControlId > _latestControlMessageId) {
            
            DDLogInfo(@"getting messageData latestMessageId: %d, latestControlId: %d", _latestMessageId ,_latestControlMessageId);
            //load message data
            [[NetworkController sharedInstance] getMessageDataForUsername:_username andMessageId:_latestMessageId andControlId:_latestControlMessageId successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                DDLogInfo(@"get messageData response: %d",  [response statusCode]);
                
                NSArray * controlMessageStrings =[((NSDictionary *) JSON) objectForKey:@"controlMessages"];
                
                [self handleControlMessages:controlMessageStrings];
                
                
                
                NSArray * messageStrings =[((NSDictionary *) JSON) objectForKey:@"messages"];
                
                
                //convert messages to SurespotMessage
                for (NSString * messageString in messageStrings) {
                    
                    [self addMessage:[[SurespotMessage alloc] initWithJSONString:messageString] refresh:YES];
                }
                
                //      [_decryptionQueue waitUntilAllOperationsAreFinished];
                
                
                [self postRefresh];
                
                
            } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
                DDLogVerbose(@"get messagedata response error: %@",  Error);
                
            }];
        }
        
        
    }
    
    DDLogInfo(@"init complete");
    
    return self;
}


-(void) addMessage:(SurespotMessage *)message  refresh: (BOOL) refresh {
    @synchronized (_messages)  {
        NSMutableArray * applicableControlMessages  = nil;
        if (message.serverid > 0 && ![UIUtils stringIsNilOrEmpty:message.plainData]) {
            
            // see if we have applicable control messages and apply them if necessary
            NSArray * controlMessages = [_controlMessages allValues];
            applicableControlMessages = [NSMutableArray new];
            
            for (SurespotControlMessage * cm in controlMessages) {
                NSInteger messageId = [cm.moreData  integerValue];
                if (message.serverid == messageId) {
                    [applicableControlMessages addObject:cm];
                }
            }
        }
        
        NSUInteger index = [self.messages indexOfObject:message];
        if (index == NSNotFound) {
            if (!message.plainData) {
                DDLogInfo(@"decrypting message iv: %@", message.iv);
                
                MessageDecryptionOperation * op = [[MessageDecryptionOperation alloc]initWithMessage:message width: 200 completionCallback:^(SurespotMessage  * message){
                    DDLogInfo(@"adding message iv: %@", message.iv);
                    [self.messages addObject:message];
                    
                }];
                [_decryptionQueue addOperation:op];
                
                
            }
            else {
                DDLogInfo(@"adding message iv: %@", message.iv);
                [self.messages addObject:message];
            }
        }
        else {
            DDLogInfo(@"updating message iv: %@", message.iv);
            SurespotMessage * existingMessage = [self.messages objectAtIndex:index];
            if (message.serverid > 0) {
                existingMessage.serverid = message.serverid;
                existingMessage.dateTime = message.dateTime;
            }
        }
        
        if (applicableControlMessages && [applicableControlMessages count] > 0) {
            DDLogInfo(@"retroactively applying control messages to message id %d", message.serverid);
            for (SurespotControlMessage * cm in applicableControlMessages) {
                [self handleControlMessage:cm];
            }
        }
    }
    
    if (message.serverid > _latestMessageId) {
        DDLogVerbose(@"updating latest message id: %d", message.serverid);
        _latestMessageId = message.serverid;
    }
    
    
    if (refresh) {
        if ([_decryptionQueue operationCount] == 0) {
            [self postRefresh];
        }
    }
    
    
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
    
    @synchronized (_messages)  {
        [dict setObject:_messages forKey:@"messages"];
        //[dict setObject:_username  forKey:@"username"];
        [dict setObject:[NSNumber numberWithInteger:_latestControlMessageId] forKey:@"latestControlMessageId"];
        
        
        BOOL saved =[NSKeyedArchiver archiveRootObject:dict toFile:filename];
        
        DDLogVerbose(@"save success?: %@",saved ? @"YES" : @"NO");
    }
    
}

-(void) deleteMessage: (SurespotMessage *) message initiatedByMe: (BOOL) initiatedByMe {
    BOOL myMessage = [[message from] isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]];
    if (initiatedByMe || !myMessage) {
        [self deleteMessageById: message.serverid];
    }
}

-(SurespotMessage *) getMessageById: (NSInteger) serverId {
    @synchronized (_messages) {
        __block SurespotMessage * message;
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid]  == serverId) {
                message = obj;
                *stop = YES;
            }
        }];
        return message;
    }
}

-(void) deleteMessageById: (NSInteger) serverId {
    DDLogInfo(@"serverID: %d", serverId);
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] == serverId) {
                [_messages removeObjectAtIndex:idx];
                [self postRefresh];
                *stop = YES;
            }
        }];
    }
}

-(void) deleteMessageByIv: (NSString *) iv {
    DDLogInfo(@"iv: %@", iv);
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([[obj iv] isEqualToString:iv]) {
                [_messages removeObjectAtIndex:idx];
                [self postRefresh];
                *stop = YES;
            }
        }];
    }
}


-(void) handleMessages: (NSArray *) messages {
    
    SurespotMessage * lastMessage;
    for (id jsonMessage in messages) {
        lastMessage = [[SurespotMessage alloc] initWithJSONString:jsonMessage];
        [self addMessage:lastMessage refresh:YES];
    }
    
}


-(void) handleControlMessages: (NSArray *) controlMessages {
    
    SurespotControlMessage * message;
    
    for (id jsonMessage in controlMessages) {
        
        
        message = [[SurespotControlMessage alloc] initWithJSONString: jsonMessage];
        [self handleControlMessage:message];
        
    }
    
}

-(void) handleControlMessage: (SurespotControlMessage *) message {
    if ([message.type isEqualToString:@"message"]) {
        
        DDLogInfo(@"action: %@, id: %d", message.action, message.controlId );
        
        if  (message.controlId >  self.latestControlMessageId) {
            self.latestControlMessageId = message.controlId;
        }
        BOOL controlFromMe = [[message from] isEqualToString:_loggedInUser];
        
        if ([[message action] isEqualToString:@"delete"]) {
            NSInteger messageId = [[message moreData] integerValue];
            SurespotMessage * dMessage = [self getMessageById: messageId];
            
            if (dMessage) {
                [self deleteMessage:dMessage initiatedByMe:controlFromMe];
            }
        }
        else {
            if ([[message action] isEqualToString:@"deleteAll"]) {
                if (message.moreData) {
                    if (controlFromMe) {
                        [self deleteAllMessagesUTAI:[ message.moreData integerValue] ];
                    }
                    else {
                        [self deleteTheirMessagesUTAI:[ message.moreData integerValue] ];
                    }
                }
            }
        }
    }
    
    @synchronized (_controlMessages) {
        [_controlMessages setObject:message forKey:[NSNumber numberWithInteger: message.controlId  ]];
    }
}

-(void) deleteAllMessagesUTAI: (NSInteger) messageId {
    DDLogInfo(@"UTAI messageID: %d", messageId);
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] <= messageId) {
                DDLogInfo(@"deleting messageID: %d", [obj serverid]);
                [_messages removeObjectAtIndex:idx];
            }
        }];
    }
    
    [self postRefresh];
}

-(void) deleteTheirMessagesUTAI: (NSInteger) messageId {
    
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SurespotMessage * obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] <= messageId && ![[obj getOtherUser] isEqualToString:_loggedInUser]) {
                DDLogInfo(@"deleting messageID: %d", [obj serverid]);
                [_messages removeObjectAtIndex:idx];
            }
        }];
    }
    
    [self postRefresh];
    
}

@end
