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

static const int ddLogLevel = LOG_LEVEL_OFF;

@interface LoginViewController ()
@property (atomic, strong) NSArray * identityNames;
@property (atomic, strong) id progressView;
@property (nonatomic, assign) CGFloat delta;
@end

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"login", nil)];
    [self loadIdentityNames];
    [self registerForKeyboardNotifications];
    self.navigationController.navigationBar.translucent = NO;
    _textPassword.returnKeyType = UIReturnKeyGo;
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
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    CGFloat buttonBot =    _bLogin.frame.origin.y + _bLogin.frame.size.height;
    CGFloat viewBot = self.view.frame.size.height;
    
    CGFloat kbHeight = [UIUtils keyboardHeightAdjustedForOrientation:kbSize];
    CGFloat d =  kbHeight - (viewBot - buttonBot);
    
    if (d > 0) {
        _delta = d;
        CGRect frame = self.view.frame;
        frame.origin.y -= d;
        self.view.frame = frame;
    }
    else {
        _delta = 0;
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    if (_delta >0) {
        
        CGRect frame = self.view.frame;
        frame.origin.y += _delta;
        self.view.frame = frame;
    }
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
    _progressView = [LoadingView loadingViewInView:self.view textKey:@"login_progress"];
    
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(q, ^{
        
        
        SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
        
        if (!identity) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIUtils showToastView:_userPicker key: @"login_check_password" ];
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
             
             [[IdentityController sharedInstance] userLoggedInWithIdentity:identity];
             [self performSegueWithIdentifier: @"loginToMainSegue" sender: nil ];
             [_progressView removeView];
             self.navigationItem.rightBarButtonItem.enabled = YES;
         }
         failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
             DDLogVerbose(@"response failure: %@",  Error);
             [UIUtils showToastView:_userPicker key: @"login_try_again_later" duration: 2.0];
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
}


- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{    
    NSUInteger newLength = [textField.text length] + [string length] - range.length;
    return (newLength >= 256) ? NO : YES;
}


@end
