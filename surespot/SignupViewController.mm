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
#import "UIUtils.h"
#import "DDLog.h"
#import "LoadingView.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface SignupViewController ()
@property (atomic, strong) id progressView;
@end

@implementation SignupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"create", nil)];
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
        self.navigationController.navigationBar.tintColor = [UIUtils surespotBlue];
    }
    _tbUsername.returnKeyType = UIReturnKeyNext;
    _tbPassword.returnKeyType = UIReturnKeyGo;
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
    
    if ([UIUtils stringIsNilOrEmpty:username] || [UIUtils stringIsNilOrEmpty:password]) {
        return;
    }
    
    [_tbPassword resignFirstResponder];
    _progressView = [LoadingView loadingViewInView:self.view textKey:@"create_user_progress"];
    
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(q, ^{
        
        
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
             DDLogVerbose(@"signup response: %d",  [operation.response statusCode]);
             [[IdentityController sharedInstance] createIdentityWithUsername:username andPassword:password andSalt:salt andKeys:keys];
             [self performSegueWithIdentifier: @"signupToMain" sender: nil];
             [_progressView removeView];
             
         }
         failureBlock:^(AFHTTPRequestOperation *operation, NSError *Error) {
             
             DDLogVerbose(@"signup response failure: %@",  Error);
             [UIUtils showToastView:[self view] key:@"could_not_create_user"];
             [_progressView removeView];
         }
         ];
        
    });
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _tbUsername) {
        if (![UIUtils stringIsNilOrEmpty: textField.text]) {
            [_tbPassword becomeFirstResponder];
            [_tbUsername resignFirstResponder];
        }
        return NO;
    }
    else {
        if (textField == _tbPassword) {
            if (![UIUtils stringIsNilOrEmpty: textField.text]) {
                [textField resignFirstResponder];
                [self createIdentity:nil];
                return YES;
            }
        }
    }
    
    
    return NO;
}


@end
