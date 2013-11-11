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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pause:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resume:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        _chatDataSources = [[NSMutableDictionary alloc] init];
        [self connect];
    }
    
    return self;
}

-(void) disconnect {
    if (_socketIO) {
        DDLogVerbose(@"disconnecting socket");
        [_socketIO disconnect ];
    }
}

-(void) pause: (NSNotification *)  notification{
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

-(void) resume: (NSNotification *) notification {
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
        DDLogInfo(@ "attempting reconnect in: %d" , timerInterval);
        _reconnectTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:self selector:@selector(reconnectTimerFired:) userInfo:nil repeats:NO];
    }
    else {
        DDLogInfo(@"reconnect retries exhausted, giving up");
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
        [self handleControlMessage: message usingChatDataSource:nil];
    }
    else {
        
        if ([name isEqualToString:@"message"]) {
            SurespotMessage * message = [[SurespotMessage alloc] initWithJSONString:[jsonData objectForKey:@"args"][0]];
            
            [self handleMessage:message];
        }
    }
    
    
}

- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
{
    DDLogVerbose(@"didReceiveMessage() >>> data: %@", packet.data);
}

- (ChatDataSource *) createDataSourceForFriendname: (NSString *) friendname availableId:(NSInteger)availableId {
    @synchronized (_chatDataSources) {
        ChatDataSource * dataSource = [self.chatDataSources objectForKey:friendname];
        if (dataSource == nil) {
            dataSource = [[ChatDataSource alloc] initWithUsername:friendname loggedInUser:[[IdentityController sharedInstance] getLoggedInUser] availableId: availableId] ;
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
            [messageId setObject: [NSNumber numberWithInt:-1] forKey:@"controlmessageid"];
            //[NSNumber numberWithInteger:[chatDataSource latestControlMessageId]];
            [messageIds addObject:messageId];
        }
    }
    
    [[NetworkController sharedInstance] getLatestDataSinceUserControlId: _homeDataSource.latestUserControlId spotIds:messageIds successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        
        
        NSArray * conversationIds = [JSON objectForKey:@"conversationIds"];
        if (conversationIds) {
            for (id convoId in conversationIds) {
                NSString * spot = [convoId objectForKey:@"conversation"];
                NSInteger availableId = [[convoId objectForKey:@"id"] integerValue];
                NSString * user = [ChatUtils getOtherUserFromSpot:spot andUser:[[IdentityController sharedInstance] getLoggedInUser]];
                
                [_homeDataSource setAvailableMessageId:availableId forFriendname: user];
                //                ChatDataSource * chatDataSource = [self getDataSourceForFriendname: user];
                //                if (chatDataSource) {
                //                    [chatDataSource setAvailableId: availableId];
                //                }
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
            [self handleControlMessages: userControlMessages forUsername: [[IdentityController sharedInstance] getLoggedInUser]];
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
    
    NSString * ourLatestVersion = [[IdentityController sharedInstance] getOurLatestVersion];
    NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
    NSData * iv = [EncryptionController getIv];
    
    [[IdentityController sharedInstance] getTheirLatestVersionForUsername:friendname callback:^(NSString * version) {
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
            
            
            NSError *error;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            
            [_socketIO sendMessage: jsonString];
            
            //cache the plain data locally
            [dict setObject:message forKey:@"plaindata"];
            
            ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
            [dataSource addMessage: [[SurespotMessage alloc] initWithDictionary: dict] refresh:YES];
        }];
    }];
    
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
    if (afriend && message.serverid) {
        afriend.availableMessageId = [message.serverid integerValue];
    }
}

-(void) handleMessages: (NSArray *) messages forUsername: (NSString *) username {
    @synchronized (_chatDataSources) {
        ChatDataSource * cds = [_chatDataSources objectForKey:username];
        if (!cds) {
            DDLogVerbose(@"no chat data source for %@", username);
            return;
        }
        
        SurespotMessage * lastMessage;
        for (id jsonMessage in messages) {
            lastMessage = [[SurespotMessage alloc] initWithJSONString:jsonMessage];
            [cds addMessage:lastMessage refresh:YES];
        }
    }
}

-(void) handleControlMessages: (NSArray *) controlMessages forUsername: (NSString *) username {
    @synchronized (_chatDataSources) {
        ChatDataSource * cds = [_chatDataSources objectForKey:username];
        
        BOOL userActivity = NO;
        BOOL messageActivity = NO;
        SurespotControlMessage * message;
        
        for (id jsonMessage in controlMessages) {
            
            
            message = [[SurespotControlMessage alloc] initWithJSONString: jsonMessage];
            [self handleControlMessage:message usingChatDataSource: cds];
            
            if ([[message type] isEqualToString:@"user"]) {
                userActivity = YES;
            }
            else {
                if ([[message type] isEqualToString:@"message"]) {
                    messageActivity = YES;
                }
            }
        }
        
        if (messageActivity || userActivity) {
            Friend * afriend = [_homeDataSource getFriendByName:username];
            
            if (afriend) {
                if (messageActivity) {
                    if (cds) {
                        afriend.lastReceivedMessageControlId = message.controlId;
                    }
                    
                    
                    afriend.availableMessageControlId = message.controlId;
                }
                
                
                
                if (userActivity) {
                }
                
                [_homeDataSource postRefresh];
            }
            
        }
    }
}

-(void) handleControlMessage: (SurespotControlMessage *) message usingChatDataSource: cds {
    
    if ([message.type isEqualToString:@"user"]) {
        [self handleUserControlMessage: message];
    }
    else {
        if ([message.type isEqualToString:@"message"]) {
            NSString * otherUser = [ChatUtils getOtherUserFromSpot:message.data andUser:[[IdentityController sharedInstance] getLoggedInUser]];
            Friend * thefriend = [_homeDataSource getFriendByName:otherUser];
            
            if (!cds) {
                cds = [_chatDataSources objectForKey:otherUser];
                
            }
            
            if (cds) {
                BOOL controlFromMe = [[message from] isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]];
                
                if ([[message action] isEqualToString:@"delete"]) {
                    NSInteger messageId = [[message moreData] integerValue];
                    SurespotMessage * dMessage = [cds getMessageById: messageId];
                    
                    if (dMessage) {
                        [cds deleteMessage:dMessage initiatedByMe:controlFromMe];
                    }
                }
            }
        }
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
    DDLogInfo(@"friendAdded");
    [_homeDataSource setFriend: username];
    ChatDataSource * cds = [self getDataSourceForFriendname:username];
    if (cds) {
        //set deleted
    }
}

-(void) friendIgnore: (NSString * ) name {
    DDLogInfo(@"entered");
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
    
    //todo sort
    [_homeDataSource postRefresh];
    
    
}


- (void)friendDelete: (SurespotControlMessage *) message
{
    DDLogInfo(@"entered");
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
    DDLogInfo(@"entered");
    
    Friend * theFriend = [_homeDataSource getFriendByName:deleted];
    if (theFriend) {
        
        NSString * username = [[IdentityController sharedInstance] getLoggedInUser];
        BOOL iDeleted = [deleter isEqualToString:username];
        if (iDeleted) {
            
            [_homeDataSource removeFriend:theFriend withRefresh:YES];
        }
        else {
            [theFriend setDeleted:YES];
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
    [self connect];
    _homeDataSource = [[HomeDataSource alloc] init];
}

-(void) logout {
    [self pause:nil];
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
            if (message.serverid) {
                
                
                [[NetworkController sharedInstance] deleteMessageName:[message getOtherUser] serverId:[[message serverid] integerValue] successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                    [cds deleteMessage: message initiatedByMe: YES];
                } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                    //todo notify user
                }];
                
            }
            else {
                [cds deleteMessageByIv: [message iv] ];
            }
        }
    }
}


@end
