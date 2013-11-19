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
    _tbPassword.returnKeyType = UIReturnKeyNext;
    _tbPasswordConfirm.returnKeyType = UIReturnKeyGo;
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
    NSString * confirmPassword = self.tbPasswordConfirm.text;
    
    
    if ([UIUtils stringIsNilOrEmpty:username] || [UIUtils stringIsNilOrEmpty:password] || [UIUtils stringIsNilOrEmpty:confirmPassword]) {
        return;
    }
    
    if (![confirmPassword isEqualToString:password]) {
        [UIUtils showToastView:self.view key:@"passwords_do_not_match" duration:1.5];
        _tbPassword.text = @"";
        _tbPasswordConfirm.text = @"";
        [_tbPassword becomeFirstResponder];
        return;
    }
    
    [_tbPasswordConfirm resignFirstResponder];
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
                [_tbPasswordConfirm becomeFirstResponder];
                [textField resignFirstResponder];
                return NO;
            }
        }
        else {
            if (textField == _tbPasswordConfirm) {
                [textField resignFirstResponder];
                [self createIdentity:nil];
                return YES;
                
            }
        }
    }
    
    
    return NO;
}

- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (textField == _tbUsername) {
        NSCharacterSet *alphaSet = [NSCharacterSet alphanumericCharacterSet];
        NSString * newString = [string stringByTrimmingCharactersInSet:alphaSet];
        if (![newString isEqualToString:@""]) {
            return NO;
        }
        
        NSUInteger newLength = [textField.text length] + [newString length] - range.length;
        return (newLength >= 20) ? NO : YES;
    }
    else {
        if ((textField == _tbPassword) || (textField == _tbPasswordConfirm)) {
            NSUInteger newLength = [textField.text length] + [string length] - range.length;
            return (newLength >= 256) ? NO : YES;
        }
    }
    
    return YES;
}


@end
