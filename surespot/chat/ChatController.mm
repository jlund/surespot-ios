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
#import "SurespotConstants.h"
#import "FileController.h"
#import "CredentialCachingController.h"
#import "SurespotErrorMessage.h"
#import "Reachability.h"
#import "SDWebImageManager.h"

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
        
        //listen for network changes so we can reconnect
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:kReachabilityChangedNotification
                                                   object:nil];
        
        Reachability * reach = [Reachability reachabilityForInternetConnection];
        [reach startNotifier];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAutoinvitesNotification:) name:@"autoinvides" object:nil];
    }
    
    return self;
}

-(void)reachabilityChanged:(NSNotification*)note
{
    Reachability * reach = [note object];
    
    if([reach isReachable])
    {
        DDLogInfo(@"wifi: %hhd, wwan, %hhd",[  reach isReachableViaWiFi], [reach isReachableViaWWAN]);
        //if we're now on wifi, disconnect and reconnect
        if ([reach isReachableViaWiFi]) {
            [self disconnect];
            [self reconnect];
        }
        
    }
    else
    {
        DDLogInfo( @"Notification Says Unreachable");
    }
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
        self.socketIO.useSecure = serverSecure;
        [self.socketIO connectToHost:serverBaseIPAddress onPort:serverPort];
        
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
    DDLogInfo(@"error %@", error);
    id internalError = [error.userInfo objectForKey:NSLocalizedDescriptionKey];
    if ([internalError isMemberOfClass:[NSError class]])  {
        DDLogInfo(@"internal error %@", internalError);
        if ( [internalError code] == 403) {
            DDLogInfo(@"socket unauthorized");
            [[NetworkController sharedInstance] setUnauthorized];
            return;
        }
    }
    [self reconnect];
    
}

- (void) socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error {
    
    DDLogInfo(@"didDisconnectWithError %@", error);
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
            
            //mark voice message to play automatically if tab is open
            if (![ChatUtils isOurMessage: message] && [message.mimeType isEqualToString:MIME_TYPE_M4A] && [[message getOtherUser] isEqualToString:[self getCurrentChat]]) {
                message.playVoice = YES;
            }
            
            [self handleMessage:message];
            [self checkAndSendNextMessage:message];
        }
        else {
            if ([name isEqualToString:@"messageError"]) {
                SurespotErrorMessage * message = [[SurespotErrorMessage alloc] initWithDictionary:[jsonData objectForKey:@"args"][0]];
                
                [self handleErrorMessage:message];
            }
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
            
            Friend  * afriend = [_homeDataSource getFriendByName:friendname];
            if (afriend && [afriend isDeleted]) {
                [dataSource userDeleted];
            }
            
            
            
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
    [self startProgress];
    
    //if we have no friends and have never received a user control message
    //load friends and latest ids
    if ([_homeDataSource.friends count] ==0 && _homeDataSource.latestUserControlId == 0) {
        
        [_homeDataSource loadFriendsCallback:^(BOOL success) {
            if (success) {
                //not gonna be much data if we don't have any friends
                if ([_homeDataSource.friends count] > 0 || _homeDataSource.latestUserControlId > 0) {
                    [self getLatestData];
                }
                else {
                    [self handleAutoinvites];
                    [self stopProgress];
                }
            }
            else {
                [self stopProgress];
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
    
    //move messages from send queue to resend queue
    [_resendBuffer addObjectsFromArray:_sendBuffer];
    [_sendBuffer removeAllObjects];
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
    
    
    DDLogVerbose(@"before network call");
    
    
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
        
        //handle autoinvites
        [self handleAutoinvites];
        
        [self stopProgress];
        [_homeDataSource postRefresh];
    } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
        [self stopProgress];
        [UIUtils showToastKey:@"loading_latest_messages_failed"];
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
    
    Friend * afriend = [_homeDataSource getFriendByName:friendname];
    if ([afriend isDeleted]) return;
    
    DDLogVerbose(@"message: %@", message);
    
    NSString * ourLatestVersion = [[IdentityController sharedInstance] getOurLatestVersion];
    NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
    NSData * iv = [EncryptionController getIv];
    
    NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:friendname forKey:@"to"];
    [dict setObject:loggedInUser forKey:@"from"];
    [dict setObject:ourLatestVersion forKey:@"fromVersion"];
    [dict setObject:b64iv forKey:@"iv"];
    [dict setObject:@"text/plain" forKey:@"mimeType"];
    //  [dict setObject:[NSNumber  numberWithBool:FALSE] forKey:@"shareable"];
    
    SurespotMessage * sm =[[SurespotMessage alloc] initWithDictionary: dict];
    
    //cache the plain data locally
    sm.plainData = message;
    [UIUtils setTextMessageHeights:sm size:[UIScreen mainScreen].bounds.size];
    
    ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
    [dataSource addMessage: sm refresh:NO];
    [dataSource postRefresh];
    
    
    //todo execute in background
    [[IdentityController sharedInstance] getTheirLatestVersionForUsername:[sm to] callback:^(NSString * version) {
        
        if (version) {
            
            [EncryptionController symmetricEncryptString: [sm plainData] ourVersion:[sm fromVersion] theirUsername:[sm to] theirVersion:version iv:iv callback:^(NSString * cipherText) {
                
                if (cipherText) {
                    sm.toVersion = version;
                    sm.data = cipherText;
                    [self enqueueMessage:sm];
                    [self sendMessages];
                    [dataSource postRefresh];
                    
                }
                else {
                    //todo retry later
                    //                            [self enqueueResendMessage:message];
                    //for now mark as errored
                    DDLogInfo(@"could not encrypt message, setting error status to 500");
                    sm.errorStatus = 500;
                    [dataSource postRefresh];
                }
            }];
        }
        else {
            //todo retry later
            //  [self enqueueResendMessage:message];
            DDLogInfo(@"could not get latest version, setting error status to 500");
            sm.errorStatus = 500;
            [dataSource postRefresh];
            
        }
    }];
    
}

-(void) enqueueMessage: (SurespotMessage * ) message {
    DDLogInfo(@"enqueing message %@", message);
    [_sendBuffer addObject:message];
}


-(void) enqueueResendMessage: (SurespotMessage * ) message {
    if (![_resendBuffer containsObject:message]) {
        DDLogInfo(@"enqueing resend message %@", message);
        [_resendBuffer addObject:message];
    }
}


-(void) sendMessageOnSocket: (NSString *) jsonMessage {
    [_socketIO sendMessage: jsonMessage];
}

-(void) sendMessages {
    NSMutableArray * sendBuffer = _sendBuffer;
    _sendBuffer = [NSMutableArray new];
    [sendBuffer enumerateObjectsUsingBlock:^(SurespotMessage * message, NSUInteger idx, BOOL *stop) {
        
        
        if (_socketIO) {
            DDLogInfo(@"sending message %@", message);
            [self enqueueResendMessage:message];
            [_socketIO sendMessage:[message toJsonString]];
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
        
        
        if ([obj readyToSend]) {
            //see if we have plain text, re-encrypt and send
            NSString * otherUser = [obj getOtherUser];
            NSInteger lastMessageId = 0;
            ChatDataSource * cds = [_chatDataSources objectForKey:otherUser];
            if (cds) {
                lastMessageId = [cds latestMessageId];
            }
            else {
                Friend * afriend = [_homeDataSource getFriendByName:otherUser];
                if (afriend) {
                    lastMessageId =  afriend.lastReceivedMessageId;
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
        DDLogInfo(@"sending resend messages %@", jsonString);
        [self sendMessageOnSocket:jsonString];
    }
}

-(void) handleErrorMessage: (SurespotErrorMessage *) errorMessage {
    __block SurespotMessage * foundMessage = nil;
    
    [_resendBuffer enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(SurespotMessage * message, NSUInteger idx, BOOL *stop) {
        if([errorMessage.data isEqualToString: message.iv]) {
            foundMessage = message;
            *stop = YES;
        }
    }];
    
    if (foundMessage ) {
        [_resendBuffer removeObject:foundMessage];
        foundMessage.errorStatus = errorMessage.status;
        ChatDataSource * cds = [self getDataSourceForFriendname:[foundMessage getOtherUser]];
        if (cds) {
            [cds postRefresh];
        }
    }
    
}


-(void) handleMessage: (SurespotMessage *) message {
    NSString * otherUser = [message getOtherUser];
    BOOL isNew = YES;
    ChatDataSource * cds = [self getDataSourceForFriendname:otherUser];
    if (cds) {
        isNew = [cds addMessage: message refresh:YES];
    }
    
    DDLogInfo(@"isnew: %hhd", isNew);
    
    //update ids
    Friend * afriend = [_homeDataSource getFriendByName:otherUser];
    if (afriend && message.serverid > 0) {
        afriend.availableMessageId = message.serverid;
        
        if (cds) {
            afriend.lastReceivedMessageId = message.serverid;
            
            if ([_homeDataSource.currentChat isEqualToString: otherUser]) {
                afriend.hasNewMessages = NO;
            }
            else {
                afriend.hasNewMessages = isNew;
            }
        }
        else {
            
            if (![_homeDataSource.currentChat isEqualToString: otherUser] ) {
                afriend.hasNewMessages = isNew;
            }
        }
        
        
        
        [_homeDataSource postRefresh];
    }
    
    DDLogInfo(@"hasNewMessages: %hhd", afriend.hasNewMessages);
    
    //if we have new message let anyone who cares know
    if (afriend.hasNewMessages) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"newMessage" object: message];
        
    }
}

-(void) handleMessages: (NSArray *) messages forUsername: (NSString *) username {
    if (messages && [messages count ] > 0) {
        ChatDataSource * cds = nil;
        BOOL isNew = YES;
        @synchronized (_chatDataSources) {
            cds = [_chatDataSources objectForKey:username];
        }
        
        isNew = [cds handleMessages: messages];
        
        Friend * afriend = [_homeDataSource getFriendByName:username];
        if (afriend) {
            
            SurespotMessage * message = [[SurespotMessage alloc] initWithJSONString:[messages objectAtIndex:[messages count ] -1]];
            
            if  (message.serverid > 0) {
                
                afriend.availableMessageId = message.serverid;
                
                if (cds) {
                    afriend.lastReceivedMessageId = message.serverid;
                    
                    if ([_homeDataSource.currentChat isEqualToString: username]) {
                        afriend.hasNewMessages = NO;
                    }
                    else {
                        afriend.hasNewMessages = isNew;
                    }
                }
                else {
                    
                    if (![_homeDataSource.currentChat isEqualToString: username] ) {
                        afriend.hasNewMessages = isNew;
                    }
                }
                
                [_homeDataSource postRefresh];
            }
        }
        
        [cds postRefresh];
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
        [[IdentityController sharedInstance] updateLatestVersionForUsername: message.data version: message.moreData];
    }
    else {
        if ([message.action isEqualToString:@"invited"]) {
            user = message.data;
            [_homeDataSource addFriendInvited:user];
        }
        else {
            if ([message.action isEqualToString:@"added"]) {
                [self friendAdded:[message data] acceptedBy: [message moreData]];
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
                        else {
                            if ([message.action isEqualToString:@"friendImage"]) {
                                [self handleFriendImage: message ];
                                
                            }
                        }
                        
                    }
                }
            }
        }
    }
}

-(void) inviteAction:(NSString *) action forUsername:(NSString *)username{
    DDLogVerbose(@"Invite action: %@, for username: %@", action, username);
    [self startProgress];
    [[NetworkController sharedInstance]  respondToInviteName:username action:action
     
     
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
                                                            else {
                                                                [_homeDataSource postRefresh];
                                                            }
                                                        }
                                                    }
                                                    [self stopProgress];
                                                }
     
                                                failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
                                                    DDLogError(@"error responding to invite: %@", Error);
                                                    if ([operation.response statusCode] != 404) {
                                                        
                                                        [UIUtils showToastKey:@"could_not_respond_to_invite"];
                                                    }
                                                    else {
                                                        [_homeDataSource postRefresh];
                                                    }
                                                    [self stopProgress];
                                                }];
    
}


- (void) inviteUser: (NSString *) username {
    NSString * loggedInUser = [[IdentityController sharedInstance] getLoggedInUser];
    if ([UIUtils stringIsNilOrEmpty:username] || [username isEqualToString:loggedInUser]) {
        return;
    }
    
    [self startProgress];
    [[NetworkController sharedInstance]
     inviteFriend:username
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         DDLogVerbose(@"invite friend response: %d",  [operation.response statusCode]);
         
         [_homeDataSource addFriendInvited:username];
         [self stopProgress];
     }
     failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
         
         DDLogVerbose(@"response failure: %@",  Error);
         
         switch (operation.response.statusCode) {
             case 404:
                 [UIUtils showToastKey: @"user_does_not_exist"];
                 break;
             case 409:
                 [UIUtils showToastKey: @"you_are_already_friends"];
                 break;
             case 403:
                 [UIUtils showToastKey: @"already_invited"];
                 break;
             default:
                 [UIUtils showToastKey:@"could_not_invite"];
         }
         
         [self stopProgress];
     }];
    
}



- (void)friendAdded:(NSString *) username acceptedBy:(NSString *) byUsername
{
    DDLogInfo(@"friendAdded: %@, by: %@",username, byUsername);
    [_homeDataSource setFriend: username];
    
    //if i'm not the accepter fire a notification saying such
    if (![byUsername isEqualToString:[[IdentityController sharedInstance] getLoggedInUser]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"inviteAccepted" object:byUsername];
        });
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
    
    [_homeDataSource postRefresh];
}

-(void) handleDeleteUser: (NSString *) deleted deleter: (NSString *) deleter {
    DDLogVerbose(@"entered");
    
    
    Friend * theFriend = [_homeDataSource getFriendByName:deleted];
    
    if (theFriend) {
        NSString * username = [[IdentityController sharedInstance] getLoggedInUser];
        BOOL iDeleted = [deleter isEqualToString:username];
        NSArray * data = [NSArray arrayWithObjects:theFriend.name, [NSNumber numberWithBool: iDeleted], nil];
        
        
        if (iDeleted) {
            //get latest version
            [[CredentialCachingController sharedInstance] getLatestVersionForUsername:deleted callback:^(NSString *version) {
                
                //fire this first so tab closes and saves data before we delete all the data
                [[NSNotificationCenter defaultCenter] postNotificationName:@"deleteFriend" object: data];
                
                
                [_homeDataSource removeFriend:theFriend withRefresh:YES];
                
                //wipe user state
                [FileController wipeDataForUsername:username friendUsername:deleted];
                
                //clear cached user data
                [[CredentialCachingController sharedInstance] clearUserData: deleted];
                
                
                //clear http cache
                NSInteger maxVersion = [version integerValue];
                for (NSInteger i=1;i<=maxVersion;i++) {
                    NSURLRequest * request = [[NetworkController sharedInstance] buildPublicKeyRequestForUsername:deleted version: [@(i) stringValue]];
                    [[NetworkController sharedInstance] deleteFromCache: request];
                }
            }];
        }
        else {
            [theFriend setDeleted];
            
            ChatDataSource * cds = [_chatDataSources objectForKey:deleter];
            if (cds) {
                [cds  userDeleted];
            }
            
            //fire this last because the friend needs to be deleted to update controls
            [[NSNotificationCenter defaultCenter] postNotificationName:@"deleteFriend" object: data];
        }
        
    }
}

- (void)handleFriendImage: (SurespotControlMessage *) message  {
    Friend * theFriend = [_homeDataSource getFriendByName:message.data];
    
    if (theFriend) {
        [self setFriendImageUrl:[message.moreData objectForKey:@"url"] forFriendname: message.data version:[message.moreData objectForKey:@"version"] iv:[message.moreData objectForKey:@"iv"]];
    }
    
    
}

- (void) setCurrentChat: (NSString *) username {
    [_homeDataSource setCurrentChat: username];
    
    //here is where we would set message read stuff
    
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
        
        [self startProgress];
        
        [[NetworkController sharedInstance] deleteFriend:friendname successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
            [self handleDeleteUser:friendname deleter:username];
            [self stopProgress];
        } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
            [UIUtils showToastKey:@"could_not_delete_friend"];
            [self stopProgress];
        }];
    }
}

-(void) deleteMessage: (SurespotMessage *) message {
    if (message) {
        ChatDataSource * cds = [_chatDataSources objectForKey:[message getOtherUser]];
        if (cds) {
            if (message.serverid > 0) {
                
                [self startProgress];
                [[NetworkController sharedInstance] deleteMessageName:[message getOtherUser] serverId:[message serverid] successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                    [cds deleteMessage: message initiatedByMe: YES];
                    [self stopProgress];
                } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                    
                    
                    //if it's 404, delete it locally as it's not on the server
                    if ([operation.response statusCode] == 404) {
                        [cds deleteMessage: message initiatedByMe: YES];
                    }
                    else {
                        [UIUtils showToastKey:@"could_not_delete_message"];
                    }
                    [self stopProgress];
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
        lastMessageId = [afriend lastReceivedMessageId];
    }
    [self startProgress];
    [[NetworkController sharedInstance] deleteMessagesUTAI:lastMessageId name:afriend.name successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        [cds deleteAllMessagesUTAI:lastMessageId];
        [self stopProgress];
        
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        [UIUtils showToastKey:@"could_not_delete_messages"];
        [self stopProgress];
    }];
    
    
}


-(void) loadEarlierMessagesForUsername: username callback: (CallbackBlock) callback {
    ChatDataSource * cds = [self getDataSourceForFriendname:username];
    [cds loadEarlierMessagesCallback:callback];
    
}

-(void) startProgress {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"startProgress" object: nil];
}

-(void) stopProgress {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"stopProgress" object: nil];
}

-(void) toggleMessageShareable: (SurespotMessage *) message {
    if (message) {
        ChatDataSource * cds = [_chatDataSources objectForKey:[message getOtherUser]];
        if (cds) {
            if (message.serverid > 0) {
                
                [self startProgress];
                [[NetworkController sharedInstance] setMessageShareable:[message getOtherUser] serverId:[message serverid] shareable:!message.shareable successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                    [cds setMessageId: message.serverid shareable: [[[NSString alloc] initWithData: responseObject encoding:NSUTF8StringEncoding] isEqualToString:@"shareable"] ? YES : NO];
                    [self stopProgress];
                } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                    [UIUtils showToastKey:@"could_not_set_message_lock_state"];
                    [self stopProgress];
                }];
                
            }
        }
    }
}

-(void) resendFileMessage: (SurespotMessage *) resendMessage {
    
    //make a copy of the message
    SurespotMessage * message = [resendMessage copyWithZone:nil];
    
    if ([[message data] hasPrefix:@"dataKey_"]) {
        
        DDLogInfo(@"resending data %@ to server", message.data);
        NSData * data = [[[SDWebImageManager sharedManager] imageCache] diskImageDataBySearchingAllPathsForKey:message.data];
        if (data) {
            resendMessage.errorStatus = 0;
            ChatDataSource * cds = [self getDataSourceForFriendname:[message getOtherUser]];
            [cds postRefresh];
            [self startProgress];
            [[NetworkController sharedInstance] postFileStreamData: data
                                                        ourVersion:[message getOurVersion]
                                                     theirUsername:[message getOtherUser]
                                                      theirVersion:[message getTheirVersion]
                                                            fileid:message.iv
                                                          mimeType:message.mimeType
                                                      successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                                                          
                                                          NSInteger serverid = [[JSON objectForKey:@"id"] integerValue];
                                                          NSString * url = [JSON objectForKey:@"url"];
                                                          
                                                          DDLogInfo(@"uploaded data %@ to server successfully, server id: %d, url: %@", message.iv, serverid, url);
                                                          
                                                          
                                                          message.serverid = serverid;
                                                          message.data = url;
                                                          
                                                          [cds addMessage:message refresh:YES];
                                                          
                                                          [self stopProgress];
                                                          
                                                      } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
                                                          DDLogInfo(@"resend data %@ to server failed, statuscode: %d", message.data, responseObject.statusCode);
                                                          if (responseObject.statusCode == 402) {
                                                              resendMessage.errorStatus = 402;
                                                          }
                                                          else {
                                                              resendMessage.errorStatus = 500;
                                                          }
                                                          
                                                          [self stopProgress];
                                                          [cds postRefresh];
                                                      }];
        }
    }
}

-(void) handleAutoinvitesNotification: (NSNotification *) notification {
    [self handleAutoinvites];
}

-(void) handleAutoinvites {
    
    NSMutableArray * autoinvites  = [NSMutableArray arrayWithArray: [[NSUserDefaults standardUserDefaults] stringArrayForKey: @"autoinvites"]];
    if ([autoinvites count] > 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"autoinvites"];
        NSMutableString * exists = [NSMutableString new];
        for (NSString * username in autoinvites) {
            if (![_homeDataSource getFriendByName:username]) {
                [self inviteUser:username];
            }
            else {
                [exists appendString: [username stringByAppendingString:@" "]];
            }
        }
        
        if ([exists length] > 0) {
            [UIUtils showToastKey:[NSString stringWithFormat: NSLocalizedString(@"autoinvite_user_exists", nil), exists] duration:2];
        }
        
    }
}

-(void) setFriendImageUrl: (NSString *) url forFriendname: (NSString *) name version: version iv: iv {
    [_homeDataSource setFriendImageUrl:url forFriendname:name version:version iv:iv];
}

@end
