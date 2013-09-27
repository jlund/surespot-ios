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


@implementation ChatController
@synthesize socketIO;

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
        self.socketIO.useSecure = NO;
        [self.socketIO connectToHost:@"127.0.0.1" onPort:8080];
        self.dataSources = [[NSMutableDictionary alloc] init];
        self.tableViews = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}



- (void) socketIODidConnect:(SocketIO *)socket {
    NSLog(@"didConnect()");
    // [socketIO sendJSON:dict];
}

- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveEvent() >>> data: %@", packet.data);
    NSDictionary * jsonData = [NSJSONSerialization JSONObjectWithData:[packet.data dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    
    
    NSString * name = [jsonData objectForKey:@"name"];
    if (![name isEqual:@"message"]) {
        return;
    }
    
    NSMutableDictionary * jsonMessage = [NSJSONSerialization JSONObjectWithData:[[jsonData objectForKey:@"args"][0]dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    NSString * from = [jsonMessage objectForKey:@"from"];
    if (![from isEqual:[IdentityController getLoggedInUser]]) {
        //decrypt
        [EncryptionController symmetricDecryptString:[jsonMessage objectForKey:@"data"] ourVersion:[jsonMessage objectForKey:@"toVersion"] theirUsername:from theirVersion:[jsonMessage objectForKey:@"fromVersion"] iv:[jsonMessage objectForKey:@"iv"] callback:^(NSString * plaintext){
            
            [jsonMessage setObject:plaintext forKey:@"plaindata"];
            
            //get the datasource for this message and add the message
            ChatDataSource * dataSource = [self getDataSourceForFriendname: from];
            [dataSource addMessage: jsonMessage];
            
            //get the key out so it is the same object so event is received
            NSArray * keys = [self.dataSources allKeys];
            for (NSString * key in keys) {
                
                if ([key isEqual: from]) {
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadMessages" object:key ];
                    break;
                    
                }
            }
            //use if we have issues http://www.cocoanetics.com/2010/05/nsnotifications-and-background-threads/
            
            //            NSNotification *note = [NSNotification notificationWithName:@"reloadMessages"  object:from];
            //            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject: note waitUntilDone:NO];
            //             }];
            
            
        }];
    }
}

- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveMessage() >>> data: %@", packet.data);
}

- (id) getDataSourceForFriendname: (NSString *) friendname {
    ChatDataSource * dataSource = [self.dataSources objectForKey:friendname];
    if (dataSource == nil) {
        dataSource = [[ChatDataSource alloc] init];
        [self.dataSources setObject: dataSource forKey: friendname];           }
    return dataSource;
}

- (void) sendMessage: (NSString *) message toFriendname: (NSString *) friendname
{
    NSString * ourLatestVersion = [IdentityController getOurLatestVersion];
    NSString * loggedInUser = [IdentityController getLoggedInUser];
    NSData * iv = [EncryptionController getIv];
    
    [IdentityController getTheirLatestVersionForUsername:loggedInUser callback:^(NSString * version) {
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
            
            
            [socketIO sendMessage: jsonString];
            
            //cache the plain data locally
            [dict setObject:message forKey:@"plaindata"];
            
            ChatDataSource * dataSource = [self getDataSourceForFriendname: friendname];
            [dataSource addMessage: dict];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"reloadMessages" object:friendname ];
            
        }];
    }];
    
}

@end
