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
#import "SurespotMessage.h"
#import "SurespotControlMessage.h"
#import "MessageProcessor.h"
#import "NetworkController.h"
#import "ChatUtils.h"
#import "StateController.h"

@interface ChatController()
@property (strong, atomic) SocketIO * socketIO;
@property (strong, atomic) NSMutableDictionary * chatDataSources;
@property (strong, atomic) HomeDataSource * homeDataSource;
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
        
        
        ////   self.socketIO.useSecure = YES;
        //   [self.socketIO connectToHost:@"server.surespot.me" onPort:443];
        
       // _homeDataSource = [[HomeDataSource alloc] init];
        _chatDataSources = [[NSMutableDictionary alloc] init];
        
        //open active chats
        
        
        //listen for invited
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(friendInvited:) name:@"friendInvited" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(friendInvite:) name:@"friendInvite" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(friendDelete:) name:@"friendDelete" object:nil];
        
        
        [self connect];
    }
    
    return self;
}

-(void) disconnect {
    if (_socketIO) {
        NSLog(@"disconnecting socket");
        [_socketIO disconnect ];
    }
}

-(void) pause: (NSNotification *)  notification{
    NSLog(@"chatcontroller pause");
    [self disconnect];
    [self saveState];
}

-(void) connect {
    if (_socketIO) {
        NSLog(@"connecting socket");
        //  if (![_socketIO isConnected] && ![_socketIO isConnecting]) {
        self.socketIO.useSecure = NO;
        [self.socketIO connectToHost:@"192.168.10.68" onPort:8080];
    }
    //  }
    
}

-(void) resume: (NSNotification *) notification {
    NSLog(@"chatcontroller resume");
    [self connect];
}



- (void) socketIODidConnect:(SocketIO *)socket {
    NSLog(@"didConnect()");
    // [[NSNotificationCenter defaultCenter] postNotificationName:@"socketConnected" object:nil ];
    [self getData];
}

- (void) socketIODidDisconnect:(SocketIO *)socket disconnectedWithError:(NSError *)error {

    NSLog(@"didDisconnectWithError       %@", error);
    
    if (error ) {
        //start reconnect cycle
    }
}

- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveEvent() >>> data: %@", packet.data);
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
    NSLog(@"didReceiveMessage() >>> data: %@", packet.data);
}

- (ChatDataSource *) getDataSourceForFriendname: (NSString *) friendname {
    ChatDataSource * dataSource = [self.chatDataSources objectForKey:friendname];
    if (dataSource == nil) {
        dataSource = [[ChatDataSource alloc] initWithUsername:friendname loggedInUser:[[IdentityController sharedInstance] getLoggedInUser]] ;
        [self.chatDataSources setObject: dataSource forKey: friendname];
    }
    return dataSource;
}


-(void) getData {
    
    [self getLatestData];
    
}

-(void) saveState {
    if (_homeDataSource) {
        [_homeDataSource writeToDisk];
    }
    
    if (_chatDataSources) {
        for (id key in _chatDataSources) {
            [[_chatDataSources objectForKey:key] writeToDisk];
        }
    }
}

-(void) getLatestData {
    NSLog(@"getLatestData");
    
    NSMutableArray * messageIds = [[NSMutableArray alloc] init];
    
    //build message id list for open chats
    for (id username in [_chatDataSources allKeys]) {
        ChatDataSource * chatDataSource = [_chatDataSources objectForKey:username];
        NSString * spot = [ChatUtils getSpotUserA: [[IdentityController sharedInstance] getLoggedInUser] userB: username];
        
        NSLog(@"getting message and control data for spot: %@",spot );
        NSMutableDictionary * messageId = [[NSMutableDictionary alloc] init];
        [messageId setObject: username forKey:@"username"];
        [messageId setObject: [NSNumber numberWithInteger: [chatDataSource latestMessageId]] forKey:@"messageid"];
        [messageId setObject: [NSNumber numberWithInteger:[chatDataSource latestControlMessageId]] forKey:@"controlmessageid"];
        
        [messageIds addObject:messageId];
    }
    
    
    [[NetworkController sharedInstance] getLatestDataSinceUserControlId:_homeDataSource.latestUserControlId spotIds:messageIds successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        
        
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
            //  [self handleControlMessages: userControlMessages forUsername: [[IdentityController sharedInstance] getLoggedInUser]];
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
    if (message.length == 0) return;
    
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
    ChatDataSource * dataSource = [self.chatDataSources objectForKey:otherUser];
    if (dataSource) {
        //  [[MessageProcessor sharedInstance] decryptMessage:message completionCallback:^(SurespotMessage * message){
        
        
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [dataSource addMessage: message refresh:YES];
        });
        
        
        
        
        // }];
        
    }
}

-(void) handleMessages: (NSArray *) messages forUsername: (NSString *) username {
    ChatDataSource * cds = [_chatDataSources objectForKey:username];
    if (!cds) {
        NSLog(@"no chat data source for %@", username);
        return;
    }
    
    SurespotMessage * lastMessage;
    for (id jsonMessage in messages) {        lastMessage = [[SurespotMessage alloc] initWithJSONString:jsonMessage];
        
        [cds addMessage:lastMessage refresh:NO];
    }
    
    [cds postRefresh];
}

-(void) handleControlMessages: (NSArray *) controlMessages forUsername: (NSString *) username {
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
    
    if (message) {
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
                    afriend.lastReceivedUserControlId = message.controlId;
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
            
        }
    }
}

-(void) handleUserControlMessage: (SurespotControlMessage *) message {
    NSString * user;
    if ([message.action isEqualToString:@"revoke"]) {
        
    }
    else {
        if ([message.action isEqualToString:@"invited"]) {
            user = message.data;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"friendInvited" object:user ];
        }
        else {
            if ([message.action isEqualToString:@"added"]) {
                
            }
            else {
                if ([message.action isEqualToString:@"invite"]) {
                    user = message.data;
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"friendInvite" object:user ];
                }
                else {
                    if ([message.action isEqualToString:@"ignore"]) {
                        
                    }
                    else {
                        if ([message.action isEqualToString:@"delete"]) {
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"friendDelete" object:message ];
                            
                        }
                    }
                }
            }
        }
    }
}

-(void) inviteAction:(NSString *) action forUsername:(NSString *)username{
    NSLog(@"Invite action: %@, for username: %@", action, username);
    
    [[NetworkController sharedInstance]
     respondToInviteName:username action:action
     
     
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         
         Friend * afriend = [_homeDataSource getFriendByName:username];
         [afriend setInviter:NO];
         
         if ([action isEqualToString:@"accept"]) {
             //set new to true
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
    if ([username isEqualToString:loggedInUser]) {
        //todo tell user they can't invite themselves
        return;
    }
    
    [[NetworkController sharedInstance]
     inviteFriend:username
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         NSLog(@"invite friend response: %d",  [operation.response statusCode]);
         Friend * afriend = [[Friend alloc] init];
         afriend.name = username         ;
         afriend.flags = 2;
         
         [_homeDataSource addFriend:afriend withRefresh:YES];
     }
     failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
         
         NSLog(@"response failure: %@",  Error);
         
     }];
}

- (void)friendInvited:(NSNotification *)notification
{
    NSLog(@"friendInvited");
    NSString * username = notification.object;
    
    Friend * theFriend = [_homeDataSource getFriendByName:username];
    if (!theFriend) {
        theFriend = [[Friend alloc] init];
        theFriend.name = username;
        
    }
    
    [theFriend setInvited:YES];
    [_homeDataSource postRefresh];
}

- (void)friendInvite:(NSNotification *)notification
{
    NSLog(@"friendInvite");
    NSString * username = notification.object;
    
    Friend * theFriend = [_homeDataSource getFriendByName:username];
    
    if (!theFriend) {
        theFriend = [[Friend alloc] init];
        theFriend.name = username;
        [_homeDataSource addFriend:theFriend withRefresh:NO];
    }
    
    [theFriend setInviter:YES];
    
    //todo sort
    [_homeDataSource postRefresh];
    
    
}


- (void)friendDelete:(NSNotification *)notification
{
    NSLog(@"friendDelete");
    SurespotControlMessage * message = notification.object;
    
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
    [self disconnect];
    [self saveState];
    [_chatDataSources removeAllObjects];
  //  _homeDataSource.currentChat = nil;
    _homeDataSource = nil;
    
   
}

@end
