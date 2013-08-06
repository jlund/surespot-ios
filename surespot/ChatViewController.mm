//
//  ChatViewController.m
//  surespot
//
//  Created by Adam on 6/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChatViewController.h"
#import "IdentityController.h"
#import "EncryptionController.h"
#import "SocketIOPacket.h"
#import "SurespotIdentity.h"
#import "NSData+Base64.h";

@interface ChatViewController ()

@end

@implementation ChatViewController

@synthesize socketIO;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    self.socketIO = [[SocketIO alloc] initWithDelegate:self];
    self.socketIO.useSecure = YES;
    [self.socketIO connectToHost:@"192.168.10.68" onPort:443];
    
}


- (IBAction)send:(UIButton *)sender {
    NSString* message = self.tfMessage.text;
    NSString * ourLatestVersion = [IdentityController getOurLatestVersion];
    NSString * loggedInUser = [IdentityController getLoggedInUser];
    NSData * iv = [EncryptionController getIv];
    
    [IdentityController getTheirLatestVersionForUsername:loggedInUser callback:^(NSString * version) {
        [EncryptionController symmetricEncryptString: message ourVersion:ourLatestVersion theirUsername:@"wank27" theirVersion:version iv:iv callback:^(NSString * cipherText) {
                        
            NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            
            [dict setObject:@"wank27" forKey:@"to"];
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
        }];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) socketIODidConnect:(SocketIO *)socket {
    NSLog(@"didConnect()");
    // [socketIO sendJSON:dict];
}

- (void) socketIO:(SocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveEvent() >>> data: %@", packet.data);
    
    SocketIOCallback cb = ^(id argsData) {
        NSDictionary *response = argsData;
        // do something with response
        NSLog(@"ack arrived: %@", response);
    };
    //[socketIO sendMessage:@"hello back!" withAcknowledge:cb];
}

- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveMessage() >>> data: %@", packet.data);
    
    SocketIOCallback cb = ^(id argsData) {
        NSDictionary *response = argsData;
        // do something with response
        NSLog(@"ack arrived: %@", response);
    };
    
    //[socketIO sendMessage:@"hello back!" withAcknowledge:cb];
}

- (void)viewDidUnload {
    [self setTfMessage:nil];
    [super viewDidUnload];
}
@end
