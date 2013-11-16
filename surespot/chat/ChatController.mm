//
//  ChatController.m
//  surespot
//
//  Created by Adam on 8/6/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChatController.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "SocketIOPacket.h"
#import "NSData+Base64.h"
#import "SurespotControlMessage.h"
#import "MessageProcessor.h"
#import "NetworkController.h"
#import "ChatUtils.h"
#import "StateController.h"
#import "DDLog.h"
#import "UIUtils.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

static const int MAX_CONNECTION_RETRIES = 16;



@interface ChatController()
@property (strong, atomic) SocketIO * socketIO;
@property (strong, atomic) NSMutableDictionary * chatDataSources;
@property (strong, atomic) HomeDataSource * homeDataSource;
@property (assign, atomic) NSInteger connectionRetries;
@property (strong, atomic) NSTimer * reconnectTimer;
@property (strong, nonatomic) NSMutableArray * sendBuffer;
@property (strong, nonatomic) NSMutableArray * resendBuffer;

@end

@implementation ChatController


+(ChatController*)sharedInstance
{
    static ChatController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(ChatController*)init
{
    //call super init
    self = [super init];
    
    
    
    if (self != nil) {
        
        self.socketIO = [[SocketIO alloc] initWithDelegate:self];
        _chatDataSources = [NSMutableDictionary new];
        _sendBuffer = [NSMutableArray new];
        _resendBuffer = [NSMutableArray new];
    }
    
    return self;
}

-(void) disconnect {
    if (_socketIO) {
        DDLogVerbose(@"disconnecting socket");
        [_socketIO disconnect ];
    }
}

-(void) pause {
    DDLogVerbose(@"chatcontroller pause");
    [self disconnect];
    [self saveState];
    if (_reconnectTimer) {
        [_reconnectTimer invalidate];
        _connectionRetries = 0;
    }
}

-(void) connect {
    if (_socketIO) {
        DDLogVerbose(@"connecting socket");
        self.socketIO.useSecure = NO;
        [self.socketIO connectToHost:@"192.168.10.68" onPort:8080];
    }
}

-(void) resume {
    DDLogVerbose(@"chatcontroller resume");
    [self connect];
}



- (void) socketIODidConnect:(SocketIO *)socket {
    DDLogVerbose(@"didConnect()");
    // [[NSNotificationCenter defaultCenter] postNotificationName:@"socketConnected" object:nil ];
    _connectionRetries = 0;
    if (_reconnectTimer) {
        [_reconnectTimer invalidate];
    }
    
    //send unsent messages
    [self resendMessages];
    [self getData];
    
}

- (void) socketIO:(SocketIO *)socket onError:(NSError *)error {
    DDLogVerbose(@"error %@", error);
    [self reconnect];
}

- (void) socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error {
    
    DDLogVerbose(@"didDisconnectWithError %@", error);
    if (error) {
        [self connect];
        
    }
    
}

-(void) reconnect {
    //start reconnect cycle
    if (_connectionRetries < MAX_CONNECTION_RETRIES) {
        if (_reconnectTimer) {
            [_reconnectTimer invalidate];
        }
        
        //exponential backoff
        NSInteger timerInterval = pow(2,_connectionRetries++);
        DDLogVerbose(@ "attempting reconnect in: %d" , timerInterval);
        _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(reconnectTimerFired:) userInfo:nil repeats:NO];
    }
    else {
        DDLogVerbose(@"reconnect retries exhausted, giving up");
    }
}

-(void) reconnectTimerFired: (NSTimer *) timer {
    [self connect];
}

- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
    DDLogVerbose(@"didReceiveEvent() >>> data: %@", packet.data);
    NSDictionary * jsonData = [NSJSONSerialization JSONObjectWithData:[packet.data dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    
    
    NSString * name = [jsonData objectForKey:@"name"];
    
    if ([name isEqualToString:@"control"]) {
        
        SurespotControlMessage * message = [[SurespotControlMessage alloc] initWithJSONString:[jsonData objectForKey:@"args"][0]];
        [self handleControlMessage: message];
    }
    else {
        
        if ([name isEqualToString:@"message"]) {
            SurespotMessage * message = [[SurespotMessage alloc] initWithJSONString:[jsonData objectForKey:@"args"][0]];
            
            [self handleMessage:message];
            [self checkAndSendNextMessage:message];
        }
    }
    
    
}

- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
{
    DDLogVerbose(@"didReceiveMessage() >>> data: %@", packet.data);
}

- (ChatDataSource *) createDataSourceForFriendname: (NSString *) friendname availableId:(NSInteger)availableId availableControlId: (NSInteger) availableControlId {
    @synchronized (_chatDataSources) {
        ChatDataSource * dataSource = [self.chatDataSources objectForKey:friendname];
        if (dataSource == nil) {
            dataSource = [[ChatDataSource alloc] initWithUsername:friendname loggedInUser:[[IdentityController sharedInstance] getLoggedInUser] availableId: availableId availableControlId:availableControlId] ;
            [self.chatDataSources setObject: dataSource forKey: friendname];
        }
        return dataSource;
    }
    
}

- (ChatDataSource *) getDataSourceForFriendname: (NSString *) friendname {
    @synchronized (_chatDataSources) {
        return [self.chatDataSources objectForKey:friendname];
    }
}

-(void) destroyDataSourceForFriendname: (NSString *) friendname {
    @synchronized (_chatDataSources) {
        id cds = [_chatDataSources objectForKey:friendname];
        
        if (cds) {
            [cds writeToDisk];
            [_chatDataSources removeObjectForKey:friendname];
        }
    }
}


-(void) getData {
    
    
    //if we have no friends and have never received a user control message
    //load friends and latest ids
    if ([_homeDataSource.friends count] ==0 && _homeDataSource.latestUserControlId == 0) {
        
        [_homeDataSource loadFriendsCallback:^(BOOL success) {
            if (success) {
                //not gonna be much data if we don't have any friends
                if ([_homeDataSource.friends count] > 0 || _homeDataSource.latestUserControlId > 0) {
                    [self getLatestData];
                }
            }
            
        }];
    }
    else {
        [self getLatestData];
    }
    
}

-(void) saveState {
    if (_homeDataSource) {
        [_homeDataSource writeToDisk];
    }
    
    if (_chatDataSources) {
        @synchronized (_chatDataSources) {
            for (id key in _chatDataSources) {
                [[_chatDataSources objectForKey:key] writeToDisk];
            }
        }
    }
}

-(void) getLatestData {
    DDLogVerbose(@"getLatestData, chatDatasources count: %d", [_chatDataSources count]);
    
    NSMutableArray * messageIds = [[NSMutableArray alloc] init];
    
    //build message id list for open chats
    @synchronized (_chatDataSources) {
        for (id username in [_chatDataSources allKeys]) {
            ChatDataSource * chatDataSource = [self getDataSourceForFriendname: username];
            NSString * spot = [ChatUtils getSpotUserA: [[IdentityController sharedInstance] getLoggedInUser] userB: username];
            
            DDLogVerbose(@"getting message and control data for spot: %@",spot );
            NSMutableDictionary * messageId = [[NSMutableDictionary alloc] init];
            [messageId setObject: username forKey:@"username"];
            [messageId setObject: [NSNumber numberWithInteger: [chatDataSource latestMessageId]] forKey:@"messageid"];
            [messageId setObject: [NSNumber numberWithInteger:[chatDataSource latestControlMessageId]] forKey:@"controlmessageid"];
            [messageIds addObject:messageId];
        }
    }
    
    [[NetworkController sharedInstance] getLatestDataSinceUserControlId: _homeDataSource.latestUserControlId spotIds:messageIds successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        
        DDLogVerbose(@"network call complete");
        
        NSArray * conversationIds = [JSON objectForKey:@"conversationIds"];
        if (conversationIds) {
            for (id convoId in conversationIds) {
                NSString * spot = [convoId objectForKey:@"conversation"];
                NSInteger availableId = [[convoId objectForKey:@"id"] integerValue];
                NSString * user = [ChatUtils getOtherUserFromSpot:spot andUser:[[IdentityController sharedInstance] getLoggedInUser]];
                
                [_homeDataSource setAvailableMessageId:availableId forFriendname: user];
            }
        }
        
        NSArray * controlIds = [JSON objectForKey:@"controlIds"];
        if (controlIds) {
            for (id controlId in controlIds) {
                NSString * spot = [controlId objectForKey:@"conversation"];
                NSInteger availableId = [[controlId objectForKey:@"id"] integerValue];
                NSString * user = [ChatUtils getOtherUserFromSpot:spot andUser:[[IdentityController sharedInstance] getLoggedInUser]];
                
                [_homeDataSource setAvailableMessageControlId:availableId forFriendname: user];
            }
        }
        
        NSArray * userControlMessages = [JSON objectForKey:@"userControlMessages"];
        if (userControlMessages ) {
            [self handleUserControlMessages: userControlMessages];
        }
        
        //update message data
        NSArray * messageDatas = [JSON objectForKey:@"messageData"];
        //     if (messageDatas) {
        for (NSDictionary * messageData in messageDatas) {
            
            
            NSString * friendname = [messageData objectForKey:@"username"];
            NSArray * controlMessages = [messageData objectForKey:@"controlMessages"];
            if (controlMessages) {
                [self handleControlMessages:controlMessages forUsername:friendname ];
            }
            
            NSArray * messages = [messageData objectForKey:@"messages"];
            if (messages) {
                
                [self handleMessages: messages forUsername:friendname];
            }
        }
        //    }
        
    } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
    }];
}


- (HomeDataSource *) getHomeDataSource {
    
    if (_homeDataSource == nil) {
        self.homeDataSource = [[HomeDataSource alloc] init];
    }
    return _homeDataSource;
}


- (void) sendMessage: (NSString *) message toFriendname: (NSString *) friendname
{
    if ([UIUtils stringIsNilOrEmpty:friendname]) return;
    
    DDLogVerbose(@"message: %@", message);
    
    NSString * ourLatestVersion = [[IdentityController sharedInstance] getOurLatestVersion];
    NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
    NSData * iv = [EncryptionController getIv];
    
    [[IdentityController sharedInstance] getTheirLatestVersionForUsername:friendname callback:^(NSString * version) {
        
        if (version) {
            
            [EncryptionController symmetricEncryptString: message ourVersion:ourLatestVersion theirUsername:friendname theirVersion:version iv:iv callback:^(NSString * cipherText) {
                
                NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                
                [dict setObject:friendname forKey:@"to"];
                [dict setObject:loggedInUser forKey:@"from"];
                [dict setObject:version forKey:@"toVersion"];
                [dict setObject:ourLatestVersion forKey:@"fromVersion"];
                [dict setObject:b64iv forKey:@"iv"];
                [dict setObject:cipherText forKey:@"data"];
                [dict setObject:@"text/plain" forKey:@"mimeType"];
                [dict setObject:[NSNumber  numberWithBool:FALSE] forKey:@"shareable"];
                
                SurespotMessage * sm =[[SurespotMessage alloc] initWithDictionary: dict];
                
                [self enqueueMessage:sm];
                [self sendMessages];
                //cache the plain data locally
                sm.plainData = message;
                [UIUtils setMessageHeights:sm size:[UIScreen mainScreen].bounds.size];
                
                ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
                [dataSource addMessage: sm refresh:YES];
            }];
        }
        else {
            //todo tell user we can't send
        }
    }];
    
}

-(void) enqueueMessage: (SurespotMessage * ) message {
    
    [_sendBuffer addObject:message];
}


-(void) enqueueResendMessage: (SurespotMessage * ) message {
    if (![_resendBuffer containsObject:message]) {
        [_resendBuffer addObject:message];
    }
}


-(void) sendMessageOnSocket: (NSString *) jsonMessage {
    [_socketIO sendMessage: jsonMessage];
}

-(void) sendMessages {
    NSMutableArray * sendBuffer = _sendBuffer;
    _sendBuffer = [NSMutableArray new];

    [sendBuffer enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {        
        [_resendBuffer addObject:obj];
        
        if (_socketIO) {
            [_socketIO sendMessage:[obj toJsonString]];
        }
    }];
}

-(void ) checkAndSendNextMessage: (SurespotMessage *) message {
    [self sendMessages];
    [_resendBuffer removeObject:message];
}

-(void) resendMessages {
    NSMutableArray * resendBuffer = _resendBuffer;
    _resendBuffer = [NSMutableArray new];
    NSMutableArray * jsonMessageList = [NSMutableArray new];
    [resendBuffer enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        if ([obj serverid] <= 0) {
            NSString * otherUser = [obj getOtherUser];
            NSInteger lastMessageId = 0;
            ChatDataSource * cds = [_chatDataSources objectForKey:otherUser];
            if (cds) {
                lastMessageId = [cds latestMessageId];
            }
            else {
                Friend * afriend = [_homeDataSource getFriendByName:otherUser];
                if (afriend) {
                    lastMessageId =  afriend.lastViewedMessageId;
                }
            }
            
            [obj setResendId:lastMessageId];
            [_resendBuffer addObject:obj];
            [jsonMessageList addObject:[obj toNSDictionary]];
        }
    }];
    
    if ([jsonMessageList count]>0) {
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonMessageList options:0 error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        [self sendMessageOnSocket:jsonString];
    }
}


-(void) handleMessage: (SurespotMessage *) message {
    NSString * otherUser = [message getOtherUser];
    ChatDataSource * dataSource = [self getDataSourceForFriendname:otherUser];
    if (dataSource) {
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [dataSource addMessage: message refresh:YES];
        });
        
    }
    
    //update available id
    Friend * afriend = [_homeDataSource getFriendByName:otherUser];
    if (afriend && message.serverid > 0) {
        afriend.availableMessageId = message.serverid;
    }
}

-(void) handleMessages: (NSArray *) messages forUsername: (NSString *) username {
    if (messages && [messages count ] > 0) {
        ChatDataSource * cds = nil;
        
        @synchronized (_chatDataSources) {
            cds = [_chatDataSources objectForKey:username];
        }
        if (cds) {
            [cds handleMessages: messages];
        }
        
        Friend * thefriend = [_homeDataSource getFriendByName:username];
        if (thefriend) {
            
            SurespotMessage * m = [[SurespotMessage alloc] initWithJSONString:[messages objectAtIndex:[messages count ] -1]];
            NSInteger messageId = m.serverid;
            
            thefriend.availableMessageId = messageId;
            if ([_homeDataSource.currentChat isEqualToString: username]) {
                thefriend.lastViewedMessageId = messageId;
            }
        }
    }
}
-(void) handleControlMessage: (SurespotControlMessage *) message {
    
    if ([message.type isEqualToString:@"user"]) {
        [self handleUserControlMessage: message];
    }
    else {
        if ([message.type isEqualToString:@"message"]) {
            NSString * otherUser = [ChatUtils getOtherUserFromSpot:message.data andUser:[[IdentityController sharedInstance] getLoggedInUser]];
            ChatDataSource * cds = [_chatDataSources objectForKey:otherUser];
            
            
            if (cds) {
                [cds handleControlMessage:message];
            }
            
            
            Friend * thefriend = [_homeDataSource getFriendByName:otherUser];
            if (thefriend) {
                
                NSInteger messageId = message.controlId;
                
                thefriend.availableMessageControlId = messageId;
            }
        }
    }
}

-(void) handleControlMessages: (NSArray *) controlMessages forUsername: (NSString *) username {
    if (controlMessages && [controlMessages count] > 0) {
        ChatDataSource * cds = nil;
        @synchronized (_chatDataSources) {
            cds = [_chatDataSources objectForKey:username];
        }
        
        if (cds) {
            [cds handleControlMessages:controlMessages];
        }
    }
}

-(void) handleUserControlMessages: (NSArray *) controlMessages {
    for (id jsonMessage in controlMessages) {
        
        
        SurespotControlMessage * message = [[SurespotControlMessage alloc] initWithJSONString: jsonMessage];
        [self handleUserControlMessage:message];
    }
}

-(void) handleUserControlMessage: (SurespotControlMessage *) message {
    if (message.controlId > _homeDataSource.latestUserControlId) {
        _homeDataSource.latestUserControlId = message.controlId;
    }
    NSString * user;
    if ([message.action isEqualToString:@"revoke"]) {
        
    }
    else {
        if ([message.action isEqualToString:@"invited"]) {
            user = message.data;
            [_homeDataSource addFriendInvited:user];
        }
        else {
            if ([message.action isEqualToString:@"added"]) {
                [self friendAdded:[message data]];
            }
            else {
                if ([message.action isEqualToString:@"invite"]) {
                    user = message.data;
                    [_homeDataSource addFriendInviter: user ];
                }
                else {
                    if ([message.action isEqualToString:@"ignore"]) {
                        [self friendIgnore: message.data];
                    }
                    else {
                        if ([message.action isEqualToString:@"delete"]) {
                            [self friendDelete: message ];
                            
                        }
                    }
                }
            }
        }
    }
}

-(void) inviteAction:(NSString *) action forUsername:(NSString *)username{
    DDLogVerbose(@"Invite action: %@, for username: %@", action, username);
    
    [[NetworkController sharedInstance]
     respondToInviteName:username action:action
     
     
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         
         Friend * afriend = [_homeDataSource getFriendByName:username];
         [afriend setInviter:NO];
         
         if ([action isEqualToString:@"accept"]) {
             [_homeDataSource setFriend: username] ;
         }
         else {
             if ([action isEqualToString:@"block"]||[action isEqualToString:@"ignore"]) {
                 if (![afriend isDeleted]) {
                     [_homeDataSource removeFriend:afriend withRefresh:YES];
                 }
             }
         }
     }
     
     failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
         //TODO notify user
    }];
    
}


- (void) inviteUser: (NSString *) username {
    NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
    if ([UIUtils stringIsNilOrEmpty:username] || [username isEqualToString:loggedInUser]) {
        //todo tell user they can't invite themselves
        return;
    }
    
    [[NetworkController sharedInstance]
     inviteFriend:username
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         DDLogVerbose(@"invite friend response: %d",  [operation.response statusCode]);
         
         [_homeDataSource addFriendInvited:username];
     }
     failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
         
         DDLogVerbose(@"response failure: %@",  Error);
         
     }];
}



- (void)friendAdded:(NSString *) username
{
    DDLogVerbose(@"friendAdded");
    [_homeDataSource setFriend: username];
    ChatDataSource * cds = [self getDataSourceForFriendname:username];
    if (cds) {
        //set deleted
    }
}

-(void) friendIgnore: (NSString * ) name {
    DDLogVerbose(@"entered");
    Friend * afriend = [_homeDataSource getFriendByName:name];
    
    if (afriend) {
        if (![afriend isDeleted]) {
            [_homeDataSource removeFriend:afriend withRefresh:NO];
        }
        else {
            [afriend setInvited:NO];
            [afriend setInviter:NO];
        }
        
    }
    
    [_homeDataSource postRefresh];
    
    
}


- (void)friendDelete: (SurespotControlMessage *) message
{
    DDLogVerbose(@"entered");
    Friend * afriend = [_homeDataSource getFriendByName:[message data]];
    
    if (afriend) {
        if ([afriend isInvited] || [afriend isInviter]) {
            if (![afriend isDeleted]) {
                [_homeDataSource removeFriend:afriend withRefresh:NO];
            }
            else {
                [afriend setInvited:NO];
                [afriend setInviter:NO];
            }
        }
        else {
            [self handleDeleteUser: [message data] deleter:[message moreData]];
        }
    }
    
    //todo sort
    [_homeDataSource postRefresh];
    
    
}

-(void) handleDeleteUser: (NSString *) deleted deleter: (NSString *) deleter {
    DDLogVerbose(@"entered");
    
    Friend * theFriend = [_homeDataSource getFriendByName:deleted];
    if (theFriend) {
        
        NSString * username = [[IdentityController sharedInstance] getLoggedInUser];
        BOOL iDeleted = [deleter isEqualToString:username];
        if (iDeleted) {
            
            [_homeDataSource removeFriend:theFriend withRefresh:YES];
        }
        else {
            [theFriend setDeleted];
        }
    }
}

- (void) setCurrentChat: (NSString *) username {
    [_homeDataSource setCurrentChat: username];
    
    
}

-(NSString *) getCurrentChat {
    return [_homeDataSource currentChat];
}


-(void) login {
    // [self connect];
    _homeDataSource = [[HomeDataSource alloc] init];
}

-(void) logout {
    [self pause];
    @synchronized (_chatDataSources) {
        [_chatDataSources removeAllObjects];
    }
    //  _homeDataSource.currentChat = nil;
    _homeDataSource = nil;
    
    
    
    
}

- (void) deleteFriend: (Friend *) thefriend {
    if (thefriend) {
        NSString * username = [[IdentityController sharedInstance] getLoggedInUser];
        NSString * friendname = thefriend.name;
        
        [[NetworkController sharedInstance] deleteFriend:friendname successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self handleDeleteUser:friendname deleter:username];
        } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
            //todo tell user
        }];
    }
}

-(void) deleteMessage: (SurespotMessage *) message {
    if (message) {
        ChatDataSource * cds = [_chatDataSources objectForKey:[message getOtherUser]];
        if (cds) {
            if (message.serverid > 0) {
                
                
                [[NetworkController sharedInstance] deleteMessageName:[message getOtherUser] serverId:[message serverid] successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                    [cds deleteMessage: message initiatedByMe: YES];
                } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                    
                    
                    //if it's 404, delete it locally as it's not on the server
                    if ([operation.response statusCode] == 404) {
                        [cds deleteMessage: message initiatedByMe: YES];
                    }
                    else {
                        //todo notify user
                    }
                }];
                
            }
            else {
                [cds deleteMessageByIv: [message iv] ];
            }
        }
    }
}


- (void) deleteMessagesForFriend: (Friend  *) afriend {
    ChatDataSource * cds = [self getDataSourceForFriendname:afriend.name];
    
    int lastMessageId = 0;
    if (cds) {
        lastMessageId = [cds latestMessageId];
    }
    else {
        lastMessageId = [afriend lastViewedMessageId];
    }
    
    [[NetworkController sharedInstance] deleteMessagesUTAI:lastMessageId name:afriend.name successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (cds) {
            [cds deleteAllMessagesUTAI:lastMessageId];
        }
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        //todo tell user
    }];
    
    
}

@end
