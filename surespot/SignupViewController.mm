//
//  SignupViewController.m
//  surespot
//
//  Created by Adam on 7/22/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SignupViewController.h"
#import "EncryptionController.h"
#import "IdentityController.h"
#import "NetworkController.h"
#import "NSData+Base64.h"

@interface SignupViewController ()

@end

@implementation SignupViewController

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
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setBCreateIdentity:nil];
    [self setTbUsername:nil];
    [self setTbPassword:nil];
    [super viewDidUnload];
}
- (IBAction)createIdentity:(id)sender {
    NSString * username = self.tbUsername.text;
    NSString * password = self.tbPassword.text;
    
    NSDictionary *derived = [EncryptionController deriveKeyFromPassword:password];
    
    NSString * salt = [[derived objectForKey:@"salt" ] SR_stringByBase64Encoding];
    NSString * encPassword = [[derived objectForKey:@"key" ] SR_stringByBase64Encoding];
    
    
    IdentityKeys * keys = [EncryptionController generateKeyPairs];
    
    NSString * encodedDHKey = [EncryptionController encodeDHPublicKey: [keys dhPubKey]];
    NSString * encodedDSAKey = [EncryptionController encodeDSAPublicKey:[keys dsaPubKey]];
    NSString * signature = [[EncryptionController signUsername:username andPassword: [encPassword dataUsingEncoding:NSUTF8StringEncoding] withPrivateKey:keys.dsaPrivKey] SR_stringByBase64Encoding];
    
    [[NetworkController sharedInstance]
     addUser: username
     derivedPassword: encPassword
     dhKey: encodedDHKey
     dsaKey: encodedDSAKey
     signature: signature
     version: @"ios is my bitch"
     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
         NSLog(@"response: %d",  [operation.response statusCode]);
         [IdentityController createIdentityWithUsername:username andPassword:password andSalt:salt andKeys:keys];
         [self performSegueWithIdentifier: @"signupToMain" sender: nil];
         
     }
     failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
         
         //success!1
         //completionBlock(JSON);
         NSLog(@"response failure: %@",  Error);
         
     }
     ];
    
    
    
}


@end
