//
//  SurespotViewController.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "LoginViewController.h"
#import "EncryptionController.h"
#import "IdentityController.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)login:(id)sender {
    NSString * username = self.textUsername.text;
    NSString * password = self.textPassword.text;
    
    SurespotIdentity * identity = [IdentityController getIdentityWithUsername:username andPassword:@"a_cache_identity"];
    
    
    
    
}
@end
