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
#import "UIUtils.h"
#import "LoadingView.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface LoginViewController ()
@property (atomic, strong) NSArray * identityNames;
@property (atomic, strong) id progressView;
@property (nonatomic, assign) CGFloat delta;
@property (nonatomic, assign) CGPoint offset;
@property (strong, nonatomic) IBOutlet UITextField *textPassword;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;

- (IBAction)login:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *bLogin;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UISwitch *storePassword;
@end

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"login", nil)];
    [self loadIdentityNames];
    [self registerForKeyboardNotifications];
    self.navigationController.navigationBar.translucent = NO;
    [self updatePassword:[_identityNames objectAtIndex:[ _userPicker selectedRowInComponent:0]]];

    //  _textPassword.returnKeyType = UIReturnKeyGo;
}

// Call this method somewhere in your view controller setup code.
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
- (void)keyboardWasShown:(NSNotification*)aNotification {
    NSDictionary* info = [aNotification userInfo];
    NSInteger  kbHeight = [UIUtils keyboardHeightAdjustedForOrientation: [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size];
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbHeight, 0.0);
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
    
    NSInteger totalHeight = self.view.frame.size.height;
    NSInteger keyboardTop = totalHeight - kbHeight;
    _offset = _scrollView.contentOffset;
    
    NSInteger loginButtonBottom =(_bLogin.frame.origin.y + _bLogin.frame.size.height);
    NSInteger delta = keyboardTop - loginButtonBottom;
   //  DDLogInfo(@"delta %d loginBottom %d keyboardtop: %d", delta, loginButtonBottom, keyboardTop);
    
    if (delta < 0 ) {
        
        
        CGPoint scrollPoint = CGPointMake(0.0, -delta);
       //  DDLogInfo(@"scrollPoint y: %f", scrollPoint.y);
        [_scrollView setContentOffset:scrollPoint animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
    [_scrollView setContentOffset:_offset animated:YES];
}



- (IBAction)login:(id)sender {
    NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    NSString * password = self.textPassword.text;
    
    if ([UIUtils stringIsNilOrEmpty:password]) {
        return;
    }
    
    DDLogVerbose(@"starting login");
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [_textPassword resignFirstResponder];
    _progressView = [LoadingView loadingViewInView:self.view keyboardHeight:0 textKey:@"login_progress"];
    
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(q, ^{
        
        
        SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
        
        if (!identity) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIUtils showToastKey: @"login_check_password" ];
                [_textPassword becomeFirstResponder];
                _textPassword.text = @"";
                [_progressView removeView];
                self.navigationItem.rightBarButtonItem.enabled = YES;
                
            });
            return;
        }
        
        
        
        
        // DDLogVerbose(@"loaded salt: %@", [identity salt]);
        
        NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
        NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
        NSData * passwordData = [NSData dataWithBytes:[derivedPassword bytes] length:AES_KEY_LENGTH];
        NSData * encodedPassword = [passwordData SR_dataByBase64Encoding];
        
        NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
        NSString * passwordString = [passwordData SR_stringByBase64Encoding];
        NSString * signatureString = [signature SR_stringByBase64Encoding];
        
        [[NetworkController sharedInstance]
         loginWithUsername:username
         andPassword:passwordString
         andSignature: signatureString
         successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
             DDLogVerbose(@"login response: %d",  [response statusCode]);
             
             if (_storePassword.isOn) {
                 [[IdentityController sharedInstance] storePasswordForIdentity:username password:password];
             }
             else {
                 [[IdentityController sharedInstance] clearStoredPasswordForIdentity:username];
             }
             
             [[IdentityController sharedInstance] userLoggedInWithIdentity:identity];
             [self performSegueWithIdentifier: @"loginToMainSegue" sender: nil ];
             _textPassword.text = @"";
             
             [_progressView removeView];
             self.navigationItem.rightBarButtonItem.enabled = YES;
         }
         failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
             DDLogVerbose(@"response failure: %@",  Error);
             
             switch (responseObject.statusCode) {
                 case 401:
                     [UIUtils showToastKey: @"login_check_password"];
                     break;
                 case 403:
                     [UIUtils showToastKey: @"login_update"];
                     break;
                 default:
                     [UIUtils showToastKey: @"login_try_again_later"];
             }
             
             _textPassword.text = @"";
             [_textPassword becomeFirstResponder];
             [_progressView removeView];
             self.navigationItem.rightBarButtonItem.enabled = YES;
             
         }];
    });
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_identityNames count];
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    //set item per row
    return [_identityNames objectAtIndex:row];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self login: nil];
    [textField resignFirstResponder];
    return NO;
}

- (void)viewDidUnload {
    [self setUserPicker:nil];
    [super viewDidUnload];
}

-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
}

-(IBAction) returnToLogin:(UIStoryboardSegue *) segue {
    [self loadIdentityNames];
    [_userPicker reloadAllComponents];
    [self updatePassword:[_identityNames objectAtIndex:[ _userPicker selectedRowInComponent:0]]];
}


- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSUInteger newLength = [textField.text length] + [string length] - range.length;
    return (newLength >= 256) ? NO : YES;
}

-(void) pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    NSString * selectedUser = [_identityNames objectAtIndex:row];
    [self updatePassword:selectedUser];
    
  }

-(void) updatePassword: (NSString *) username {
    DDLogInfo(@"user changed: %@", username);
    NSString * password = [[IdentityController sharedInstance] getStoredPasswordForIdentity:username];
    if (password) {
        _textPassword.text = password;
        [_storePassword setOn:YES animated:NO];
    }
    else {
        _textPassword.text = nil;
        [_storePassword setOn:NO animated:NO];
    }

}

@end
