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
#import "NetworkController.h"
#import "NSData+Base64.h"

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
//    NSString * username = self.textUsername.text;
//    NSString * password = self.textPassword.text;
  
    NSString * username = @"testlocal1";
    NSString * password = @"a_export_identity";
    SurespotIdentity * identity = [IdentityController getIdentityWithUsername:username andPassword:password];
    
   
    
    NSLog(@"loaded salt: %@", [identity salt]);

  //  NSData * saltData = [[identity salt] dataUsingEncoding:NSUTF8StringEncoding];

    NSData * decodedSalt =     [NSData dataFromBase64String: [identity salt]];
    byte * derivedPassword = [EncryptionController deriveKeyUsingPassword:@"a" andSalt: (byte *)[decodedSalt bytes]];
    NSData * passwordData = [NSData dataWithBytes:derivedPassword length:AES_KEY_LENGTH];
    NSData * encodedPassword = [passwordData SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
   // NSData * signatureData = [NSData dataWithBytes:signature length:sizeof(signature)];
    
    NSString * passwordString = [passwordData SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    
    [[NetworkController sharedInstance] loginWithUsername:username andPassword:passwordString andSignature: signatureString];
    
    [self performSegueWithIdentifier: @"loginSegue" sender: nil];
}
@end
