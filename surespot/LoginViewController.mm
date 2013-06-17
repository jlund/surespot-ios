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
#import "NSData+SRB64Additions.h"

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
    NSString * password = @"a_cache_identity";
    SurespotIdentity * identity = [IdentityController getIdentityWithUsername:username andPassword:password];
    
    NSLog(@"loaded salt: %@", [identity salt]);

    NSData * saltData = [[identity salt] dataUsingEncoding:NSUTF8StringEncoding];
    NSData * decodedSalt = [saltData base64decode];
    byte * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: (byte *)[decodedSalt bytes]];
    NSData * passwordData = [NSData dataWithBytes:derivedPassword length:sizeof(derivedPassword)];
    
    byte * signature = [EncryptionController signUsername:username andPassword:(byte *)[password  UTF8String] withPrivateKey:[identity getDsaPrivateKey]];
    NSData * signatureData = [NSData dataWithBytes:signature length:sizeof(signature)];
    
    NSString * passwordString = [passwordData SR_stringByBase64Encoding];
    NSString * signatureString = [signatureData SR_stringByBase64Encoding];
    
    [[NetworkController sharedInstance] loginWithUsername:username andPassword:passwordString andSignature: signatureString];
}
@end
