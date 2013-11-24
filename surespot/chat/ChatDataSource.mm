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
#import "ChatController.h"
#import "SurespotConstants.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface ChatDataSource()
@property (nonatomic, strong) NSOperationQueue * decryptionQueue;
@property (nonatomic, strong) NSString * loggedInUser;
@property (nonatomic, strong) NSMutableDictionary * controlMessages;
@property (atomic, assign) BOOL noEarlierMessages;
@property (atomic, assign) BOOL loadingEarlier;
@end

@implementation ChatDataSource

-(ChatDataSource*)initWithUsername:(NSString *) username loggedInUser: (NSString * ) loggedInUser availableId:(NSInteger)availableId availableControlId:( NSInteger) availableControlId {
    
    DDLogVerbose(@"username: %@, loggedInUser: %@, availableid: %d, availableControlId: %d", username, loggedInUser, availableId, availableControlId);
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
        DDLogInfo(@"looking for chat data at: %@", path);
        id chatData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        if (chatData) {
            DDLogInfo(@"loading chat data from: %@", path);
            
            _latestControlMessageId = [[chatData objectForKey:@"latestControlMessageId"] integerValue];
            messages = [chatData objectForKey:@"messages"];
            
            //convert messages to SurespotMessage
            for (SurespotMessage * message in messages) {
                DDLogVerbose(@"adding message");
                __weak ChatDataSource * weakSelf = self;
                [self addMessage:message refresh:NO callback:^(id result) {
                    if ([weakSelf.decryptionQueue operationCount] == 0) {
                        DDLogInfo(@"loaded %d messages from disk at: %@", [messages count] ,path);
                        [weakSelf postRefresh];
                    }
                }];
                
                //if the message doesn't have a server id, add it to the resend buffer
                if (message.serverid <= 0) {
                    [[ChatController sharedInstance] enqueueResendMessage: message];
                }
                
            }
            
            
            
            
            DDLogVerbose( @"latestMEssageid: %d, latestControlId: %d", _latestMessageId ,_latestControlMessageId);
            
        }
        
        if (availableId > _latestMessageId || availableControlId > _latestControlMessageId) {
            
            DDLogVerbose(@"getting messageData latestMessageId: %d, latestControlId: %d", _latestMessageId ,_latestControlMessageId);
            //load message data
            DDLogInfo(@"startProgress");
            [[NSNotificationCenter defaultCenter] postNotificationName:@"startProgress" object:nil];
            [[NetworkController sharedInstance] getMessageDataForUsername:_username andMessageId:_latestMessageId andControlId:_latestControlMessageId successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                DDLogVerbose(@"get messageData response: %d",  [response statusCode]);
                
                NSArray * controlMessageStrings =[((NSDictionary *) JSON) objectForKey:@"controlMessages"];
                
                [self handleControlMessages:controlMessageStrings];
                
                
                
                NSArray * messageStrings =[((NSDictionary *) JSON) objectForKey:@"messages"];
                
                [self handleMessages:messageStrings];
                
                DDLogInfo(@"stopProgress");
                [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object:nil];
                
                
            } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
                DDLogVerbose(@"get messagedata response error: %@",  Error);
                DDLogInfo(@"stopProgress");
                [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object:nil];
                [UIUtils showToastKey:@"loading_latest_messages_failed"];
                
            }];
        }
        
        
    }
    
    DDLogVerbose(@"init complete");
    
    return self;
}

-(BOOL) addMessage:(SurespotMessage *) message refresh:(BOOL) refresh {
    return [self addMessage:message refresh:refresh callback:nil];
}

-(BOOL) addMessage:(SurespotMessage *)message  refresh: (BOOL) refresh callback: (CallbackBlock) callback {
    BOOL isNew = NO;
    @synchronized (_messages)  {
        NSMutableArray * applicableControlMessages  = nil;
        if (message.serverid > 0 && ![UIUtils stringIsNilOrEmpty:message.plainData]) {
            
            // see if we have applicable control messages and apply them if necessary
            NSArray * controlMessages = [_controlMessages allValues];
            applicableControlMessages = [NSMutableArray new];
            
            for (SurespotControlMessage * cm in controlMessages) {
                NSInteger messageId = [cm.moreData  integerValue];
                if (message.serverid == messageId) {
                    //if we're going to delete the message don't bother adding it
                    if ([cm.action isEqualToString:@"delete"] ) {
                                        DDLogVerbose(@"message going to be deleted, marking message as old");
                        isNew = NO;
                    }
                    [applicableControlMessages addObject:cm];
                }
            }
        }
        
        DDLogVerbose(@"looking for message iv: %@", message.iv);
        NSUInteger index = [self.messages indexOfObject:message];
        if (index == NSNotFound) {
            [self.messages addObject:message];
            if (!message.plainData) {
                BOOL blockRefresh = refresh;
                refresh = false;
                CGSize size = [UIScreen mainScreen ].bounds.size;
                
                DDLogVerbose(@"added, now decrypting message iv: %@, width: %f, height: %f", message.iv, size.width, size.height);
                
                MessageDecryptionOperation * op = [[MessageDecryptionOperation alloc]initWithMessage:message size: size completionCallback:^(SurespotMessage  * message){
                    // DDLogInfo(@"adding message post decryption iv: %@", message.iv);
                    
                    
                    
                    if (blockRefresh) {
                        if ([_decryptionQueue operationCount] == 0) {
                            [self postRefresh];
                        }
                    }
                    
                    if (callback) {
                        callback(nil);
                    }
                    
                    
                }];
                [_decryptionQueue addOperation:op];
                
                
            }
            else {
                DDLogVerbose(@"added message already decrypted iv: %@", message.iv);
                
                if (callback) {
                    callback(nil);
                }
                
            }
            
            if (![ChatUtils isOurMessage:message]) {
                DDLogInfo(@"not our message, marking message as new");

                isNew = YES;
            }
            else {
                isNew = NO;
            }
        }
        else {
            DDLogInfo(@"updating message iv: %@", message.iv);
            SurespotMessage * existingMessage = [self.messages objectAtIndex:index];
            if (message.serverid > 0) {
                existingMessage.serverid = message.serverid;
                existingMessage.dateTime = message.dateTime;
                existingMessage.errorStatus = 0;
            }
        }
        
        if (applicableControlMessages && [applicableControlMessages count] > 0) {
            DDLogVerbose(@"retroactively applying control messages to message id %d", message.serverid);
            for (SurespotControlMessage * cm in applicableControlMessages) {
                [self handleControlMessage:cm];
            }
        }
        
        
    }
    
    if (message.serverid > _latestMessageId) {
        DDLogVerbose(@"updating latest message id: %d", message.serverid);
        _latestMessageId = message.serverid;
    }
    else {
        DDLogVerbose(@"have received before, marking message as old");
        isNew = NO;
    }
    
    if (message.serverid == 1) {
        _noEarlierMessages = YES;
    }
    
    
    
    if (refresh) {
        if ([_decryptionQueue operationCount] == 0) {
            [self postRefresh];
        }
    }
    
    DDLogInfo(@"isNew: %hhd", isNew);
    
    return isNew;
    
    
}

-(void) postRefresh {
    [self sort];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshMessages" object:_username ];
    });
}

-(void) writeToDisk {
    
    
    NSString * spot = [ChatUtils getSpotUserA:_loggedInUser userB:_username];
    NSString * filename =[FileController getChatDataFilenameForSpot: spot];
    DDLogInfo(@"saving chat data to disk,filename: %@, spot: %@", filename, spot);
    NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
    
    [self sort];
    
    @synchronized (_messages)  {
        //only save x messages
        NSInteger count = _messages.count < SAVE_MESSAGE_COUNT ? _messages.count : SAVE_MESSAGE_COUNT;
        
        NSArray * messages = [_messages subarrayWithRange:NSMakeRange([_messages count] - count ,count)];
        [dict setObject:messages forKey:@"messages"];
        [dict setObject:[NSNumber numberWithInteger:_latestControlMessageId] forKey:@"latestControlMessageId"];
        BOOL saved =[NSKeyedArchiver archiveRootObject:dict toFile:filename];
        
        DDLogInfo(@"saved %d messages for user %@, success?: %@",[messages count],_username, saved ? @"YES" : @"NO");
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
    DDLogVerbose(@"serverID: %d", serverId);
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
    DDLogVerbose(@"iv: %@", iv);
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


-(BOOL) handleMessages: (NSArray *) messages {
    __weak ChatDataSource* weakSelf =self;
    SurespotMessage * lastMessage;
    BOOL areNew = NO;
    for (id jsonMessage in messages) {
        lastMessage = [[SurespotMessage alloc] initWithJSONString:jsonMessage];
        BOOL isNew = [self addMessage:lastMessage refresh:NO callback:^(id result) {
            if ([weakSelf.decryptionQueue operationCount] == 0) {
                [weakSelf postRefresh];
            }
        }];
        if (isNew  ) {
            areNew = isNew;
        }
    }
    
    return areNew;
}

-(void) handleEarlierMessages: (NSArray *) messages  callback: (CallbackBlock) callback{
    if ([messages count] == 0) {
        callback([NSNumber numberWithLong:0]);
        _noEarlierMessages = YES;
        return;
    }
    __weak ChatDataSource* weakSelf =self;
    SurespotMessage * lastMessage;
    for (id jsonMessage in messages) {
        lastMessage = [[SurespotMessage alloc] initWithJSONString:jsonMessage];
        DDLogInfo(@"adding earlier message, id: %d", lastMessage.serverid);
        [self addMessage:lastMessage refresh:NO callback:^(id result) {
            if ([weakSelf.decryptionQueue operationCount] == 0) {
                [weakSelf sort];
                DDLogInfo(@"all messages added, calling back");
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    callback([NSNumber numberWithLong:[messages count]]);
                });
            }
            
        }];
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
        
        DDLogVerbose(@"action: %@, id: %d", message.action, message.controlId );
        
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
    DDLogVerbose(@"UTAI messageID: %d", messageId);
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] <= messageId) {
                DDLogVerbose(@"deleting messageID: %d", [obj serverid]);
                [_messages removeObjectAtIndex:idx];
            }
        }];
    }
    
    [self postRefresh];
}

-(void) deleteTheirMessagesUTAI: (NSInteger) messageId {
    
    @synchronized (_messages) {
        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SurespotMessage * obj, NSUInteger idx, BOOL *stop) {
            if([obj serverid] <= messageId && ![[obj from] isEqualToString:_loggedInUser]) {
                DDLogVerbose(@"deleting messageID: %d", [obj serverid]);
                [_messages removeObjectAtIndex:idx];
            }
        }];
    }
    
    [self postRefresh];
    
}

-(void) userDeleted {
    
    [self deleteTheirMessagesUTAI:NSIntegerMax];
}

-(void) sort {
    @synchronized (_messages) {
        DDLogVerbose(@"sorting messages for %@", _username);
        NSArray *sortedArray;
        sortedArray = [_messages sortedArrayUsingComparator:^NSComparisonResult(SurespotMessage * a, SurespotMessage * b) {
            DDLogVerbose(@"comparing a serverid: %d, b serverId: %d", a.serverid, b.serverid);
            if (a.serverid == b.serverid) {return NSOrderedSame;}
            if (a.serverid == 0) {return NSOrderedDescending;}
            if (b.serverid == 0) {return NSOrderedAscending;}
            if (a.serverid < b.serverid) return NSOrderedAscending;
            if (b.serverid < a.serverid) return NSOrderedDescending;
            //  DDLogVerbose(@"returning same");
            return NSOrderedSame;
            
        }];
        _messages = [NSMutableArray arrayWithArray: sortedArray];
    }
}

-(NSInteger) earliestMessageId {
    NSInteger earliestMessageId = NSIntegerMax;
    @synchronized (_messages) {
        for (int i=0;i<_messages.count;i++) {
            NSInteger serverId = [[_messages objectAtIndex:i] serverid];
            if (serverId > 0) {
                earliestMessageId = serverId;
                break;
            }
        }
    }
    return earliestMessageId;
}

-(void) loadEarlierMessagesCallback: (CallbackBlock) callback {
    
    if (_noEarlierMessages) {
        callback([NSNumber numberWithInteger:0]);
        return;
    }
    
    if (!_loadingEarlier) {
        _loadingEarlier = YES;
        
        NSInteger earliestMessageId = [self earliestMessageId];
        if (earliestMessageId == 1) {
            _noEarlierMessages = YES;
            callback([NSNumber numberWithInteger:0]);
            _loadingEarlier = NO;
            return;
        }
        
        if (earliestMessageId == NSIntegerMax ) {
            callback([NSNumber numberWithInteger:NSIntegerMax]);
            _loadingEarlier = NO;
            return;
        }
        
        [[NetworkController sharedInstance] getEarlierMessagesForUsername:_username messageId:earliestMessageId successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            
            NSArray * messages = JSON;
            if (messages.count == 0) {
                _noEarlierMessages = YES;
            }
            
            [self handleEarlierMessages:messages callback:callback];
            _loadingEarlier = NO;
        } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
            callback(nil);
            _loadingEarlier = NO;
            [UIUtils showToastKey:@"loading_earlier_messages_failed"];
        }];
    }
}

//-(BOOL) hasNewMessagesSinceId: (NSInteger) lastViewedId {
//    @synchronized (_messages) {
//        __block BOOL hasNew = NO;
//        [_messages enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SurespotMessage * message, NSUInteger idx, BOOL *stop) {
//            if (![ChatUtils isOurMessage:message]) {
//                if (message.serverid > lastViewedId) {
//                    hasNew = YES;
//                    *stop = YES;
//                }
//                
//                if (message.serverid <= lastViewedId) {
//                    *stop = YES;
//                }
//            }
//        }];
//        return hasNew;
//    }
//}

@end
