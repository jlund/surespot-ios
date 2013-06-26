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

        SurespotIdentity * identity1 = [IdentityController getIdentityWithUsername:@"testlocal1" andPassword:@"a_export_identity"];
    SurespotIdentity * identity2 = [IdentityController getIdentityWithUsername:@"testlocal10" andPassword:@"a_export_identity"];
    
    NSData * iv = [EncryptionController getIv];
    NSData * sharedSec = [EncryptionController generateSharedSecret:[identity1 getDhPrivateKey] publicKey:[identity2 getDhPublicKey]];
    NSData * encData = [EncryptionController encryptPlain:message usingKey:(byte*)[sharedSec bytes] usingIv:iv];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    [dict setObject:@"tl4" forKey:@"to"];
    [dict setObject:@"testlocal1" forKey:@"from"];
    [dict setObject:@"1" forKey:@"toVersion"];
    [dict setObject:@"2" forKey:@"fromVersion"];
    [dict setObject:@"tl4" forKey:@"iv"];
    [dict setObject:@"tl4" forKey:@"data"];
    [dict setObject:@"text/plain" forKey:@"mimeType"];
    [dict setObject:[NSNumber  numberWithBool:TRUE] forKey:@"shareable"];

    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [socketIO sendMessage: jsonString];
    
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
