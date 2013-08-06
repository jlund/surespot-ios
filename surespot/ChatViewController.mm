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
#import "NSData+Base64.h"

@interface ChatViewController ()

@end

@implementation ChatViewController

@synthesize socketIO;

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self setMessages:[[NSMutableArray alloc] init]];
    self.socketIO = [[SocketIO alloc] initWithDelegate:self];
    self.socketIO.useSecure = YES;
    [self.socketIO connectToHost:@"192.168.10.68" onPort:443];
    
}


- (void) send {
    NSString* message = self.tfMessage.text;
    NSString * ourLatestVersion = [IdentityController getOurLatestVersion];
    NSString * loggedInUser = [IdentityController getLoggedInUser];
    NSData * iv = [EncryptionController getIv];
    
    [IdentityController getTheirLatestVersionForUsername:loggedInUser callback:^(NSString * version) {
        [EncryptionController symmetricEncryptString: message ourVersion:ourLatestVersion theirUsername:[self friendname] theirVersion:version iv:iv callback:^(NSString * cipherText) {
            
            NSString * b64iv = [iv base64EncodedStringWithSeparateLines:NO];
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            
            [dict setObject:[self friendname] forKey:@"to"];
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
            
            [dict setObject:message forKey:@"plaindata"];
            [[self messages] addObject:dict];
            [[self tableView] reloadData];
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
            [[self messages] addObject:jsonMessage];
            [[self tableView] reloadData];
        }];
        
        
     
    }
    
    //    SocketIOCallback cb = ^(id argsData) {
    //        NSDictionary *response = argsData;
    //        // do something with response
    //        NSLog(@"ack arrived: %@", response);
    //    };
    //[socketIO sendMessage:@"hello back!" withAcknowledge:cb];
}

- (void) socketIO:(SocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
{
    NSLog(@"didReceiveMessage() >>> data: %@", packet.data);
    
    //    SocketIOCallback cb = ^(id argsData) {
    //        NSDictionary *response = argsData;
    //        // do something with response
    //        NSLog(@"ack arrived: %@", response);
    //    };
    //
    //[socketIO sendMessage:@"hello back!" withAcknowledge:cb];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section
    if (![self messages])
        return 0;
    
    
    return [[self messages] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    
    // Configure the cell...
    //todo change bar black/grey
    NSDictionary * message = [[self messages] objectAtIndex:indexPath.row];
    
    
    
    cell.textLabel.text = [message objectForKey:@"plaindata"];
    
    
    return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self send];
    [textField setText:nil];
    return NO;
}

- (void)viewDidUnload {
    [self setTfMessage:nil];
    [super viewDidUnload];
}
@end
