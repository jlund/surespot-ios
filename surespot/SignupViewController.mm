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
@property (nonatomic, strong) NSString * lastCheckedUsername;
@property (nonatomic, assign) NSInteger keyboardHeight;
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
    
    [_tbUsername setRightViewMode: UITextFieldViewModeNever];
    
    _tbPassword.returnKeyType = UIReturnKeyNext;
    _tbPasswordConfirm.returnKeyType = UIReturnKeyGo;
    [self registerForKeyboardNotifications];
    
    if ([[[IdentityController sharedInstance] getIdentityNames] count] == 0) {
        self.navigationItem.hidesBackButton = YES;
    }
    
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
        [UIUtils showToastKey:@"passwords_do_not_match" duration:1.5];
        _tbPassword.text = @"";
        _tbPasswordConfirm.text = @"";
        [_tbPassword becomeFirstResponder];
        return;
    }
    
    [_tbPasswordConfirm resignFirstResponder];
    _progressView = [LoadingView loadingViewInView:self.view keyboardHeight:_keyboardHeight textKey:@"create_user_progress"];
    
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
             
             switch (operation.response.statusCode) {
                 case 429:
                     [UIUtils showToastKey: @"user_creation_throttled"];
                     [_tbUsername becomeFirstResponder];
                     break;
                 case 409:
                     [UIUtils showToastKey: @"username_exists"];
                     [_tbUsername becomeFirstResponder];
                     break;
                 case 403:
                     [UIUtils showToastKey: @"signup_update"];
                     break;
                 default:
                     [UIUtils showToastKey: @"could_not_create_user"];
             }

             self.navigationItem.rightBarButtonItem.enabled = YES;
             [_progressView removeView];
         }
         ];
        
    });
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == _tbUsername) {
        //        if (![UIUtils stringIsNilOrEmpty: textField.text]) {
        //            [_tbPassword becomeFirstResponder];
        //            [_tbUsername resignFirstResponder];
        //        }
        [self checkUsername];
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
        if (newLength == 0) {
            [_tbUsername setRightViewMode:UITextFieldViewModeNever];
            _lastCheckedUsername = nil;
        }
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

-(void) checkUsername {
    NSString * username = self.tbUsername.text;
    
    if ([UIUtils stringIsNilOrEmpty:username]) {
        return;
    }
    
    if ([_lastCheckedUsername isEqualToString: username]) {
        return;
    }
    
    _lastCheckedUsername = username;
    _progressView = [LoadingView loadingViewInView:self.view keyboardHeight:_keyboardHeight textKey:@"user_exists_progress"];
    
    [[NetworkController sharedInstance] userExists:username successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString * response = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
        
        if ([response isEqualToString:@"true"]) {
            [UIUtils showToastKey:@"username_exists"];
            [self setUsernameValidity:NO];
            [_tbUsername becomeFirstResponder];
        }
        else {
            [self setUsernameValidity:YES];
            [_tbPassword becomeFirstResponder];
        }
        [_progressView removeView];
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        [_tbUsername becomeFirstResponder];
        [UIUtils showToastKey:@"user_exists_error"];
    }];
}


-(void) setUsernameValidity: (BOOL) valid {
    [_tbUsername setRightViewMode:UITextFieldViewModeAlways];
    if (valid) {
        _tbUsername.rightView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"btn_check_buttonless_on"] ];
    }
    else {
        _tbUsername.rightView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_delete"] ];
        
    }
    
}

-(void)textFieldDidEndEditing:(UITextField *)textField {
    
    if (textField == _tbUsername) {
        [self checkUsername];
    }
}

//- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *) event
//{
//
//    UITouch *touch = [[event allTouches] anyObject];
//    if ([_tbUsername isFirstResponder] && (_tbUsername != touch.view))
//    {
//        [self checkUsername ];
//    }
////
////    if ([textField2 isFirstResponder] && (textField2 != touch.view))
////    {
////        // textField2 lost focus
////    }
////
////    ...
//}


- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    
    DDLogVerbose(@"keyboardWasShown");
    
    
    NSDictionary* info = [aNotification userInfo];
    CGRect keyboardRect = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    _keyboardHeight = [UIUtils keyboardHeightAdjustedForOrientation:keyboardRect.size];
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    DDLogVerbose(@"keyboardWillBeHidden");
    _keyboardHeight = 0;
}
@end
