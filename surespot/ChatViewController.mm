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

#import "SurespotIdentity.h"

#import "ChatController.h"

@interface ChatViewController ()

@end

@implementation ChatViewController



- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
   
    
    
    //get and set a data source
    [self.tableView setDataSource: [[ChatController sharedInstance] getDataSourceForFriendname: self.friendname]];
    //listen for rolead notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadMessages:) name:@"reloadMessages" object:self.friendname];
}

- (void) send {
    NSString* message = self.tfMessage.text;
    [[ChatController sharedInstance] sendMessage: message toFriendname:[self friendname]];
}

- (void)reloadMessages:(NSNotification *)notification
{
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self send];
    [textField setText:nil];
    return NO;
}

- (void)viewDidUnload {
    [self setTfMessage:nil];
    [self setTableView:nil];
    [super viewDidUnload];
}
@end
