//
//  ChangePasswordViewController.m
//  surespot
//
//  Created by Adam on 12/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ChangePasswordViewController.h"
#import "IdentityController.h"
#import "DDLog.h"
#import "SurespotConstants.h"
#import "UIUtils.h"
#import "LoadingView.h"
#import "FileController.h"
#import "NSData+Gunzip.h"
#import "NSString+Sensitivize.h"
#import "NSData+Base64.h"
#import "NSData+SRB64Additions.h"
#import "EncryptionController.h"
#import "NetworkController.h"
#import "SurespotAppDelegate.h"
#import "BackupIdentityViewController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface ChangePasswordViewController ()
@property (strong, nonatomic) IBOutlet UILabel *label1;
@property (strong, nonatomic) IBOutlet UILabel *label2;
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@property (strong, nonatomic) IBOutlet UIButton *bExecute;
@property (atomic, strong) id progressView;
@property (strong, nonatomic) IBOutlet UITextField *currentPassword;
@property (strong, nonatomic) IBOutlet UITextField *shinyNewPassword;
@property (strong, nonatomic) IBOutlet UITextField *confirmPassword;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (atomic, strong) NSString * name;
@end



@implementation ChangePasswordViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"password", nil)];
    [_bExecute setTitle:NSLocalizedString(@"change_password", nil) forState:UIControlStateNormal];
    [self loadIdentityNames];
    self.navigationController.navigationBar.translucent = NO;
    
    _label1.text = NSLocalizedString(@"warning_password_reset", nil);
    _label1.textColor = [UIColor redColor];
    _label2.text = NSLocalizedString(@"backup_identities_again_password",nil);
    _label2.textColor = [UIColor redColor];
    
    [_currentPassword setPlaceholder: NSLocalizedString(@"current_password",nil)];
    [_shinyNewPassword setPlaceholder: NSLocalizedString(@"new_password",nil)];
    [_confirmPassword setPlaceholder: NSLocalizedString(@"confirm_password",nil)];
    
    _scrollView.contentSize = self.view.frame.size;
    
    [self registerForKeyboardNotifications];
    [_userPicker selectRow:[_identityNames indexOfObject:[[IdentityController sharedInstance] getLoggedInUser]] inComponent:0 animated:YES];
    
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    if (theTextField == self.currentPassword) {
        [_shinyNewPassword becomeFirstResponder];
    }
    else {
        
        if (theTextField == self.shinyNewPassword) {
            [_confirmPassword becomeFirstResponder];
        }
        else {
            if (theTextField == self.confirmPassword) {
                [theTextField resignFirstResponder];
                [self changePassword];
            }
        }
    }
    return YES;
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
    NSInteger  kbHeight = [UIUtils keyboardHeightAdjustedForOrientation: [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size];
    
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbHeight, 0.0);
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbHeight;
    if (!CGRectContainsPoint(aRect, _bExecute.frame.origin) ) {
        [_scrollView setContentOffset:CGPointMake(0.0, (_bExecute.frame.origin.y + _bExecute.frame.size.height + 5) -kbHeight) animated:YES];
    }

 }

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _scrollView.contentInset = contentInsets;
    _scrollView.scrollIndicatorInsets = contentInsets;
}

//- (void)textFieldDidBeginEditing:(UITextField *)textField
//{
//    _activeView = textField;
//}
//
//- (void)textFieldDidEndEditing:(UITextField *)textField
//{
//    _activeView = nil;
//}


-(void) loadIdentityNames {
    _identityNames = [[IdentityController sharedInstance] getIdentityNames];
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



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (IBAction)execute:(id)sender {
    
    [self changePassword];
}

-(void) changePassword {
    NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    NSString * password = self.currentPassword.text;
    NSString * newPassword = self.shinyNewPassword.text;
    NSString * confirmPassword = self.confirmPassword.text;
    
    
    if ([UIUtils stringIsNilOrEmpty:username] || [UIUtils stringIsNilOrEmpty:password] || [UIUtils stringIsNilOrEmpty:newPassword] || [UIUtils stringIsNilOrEmpty:confirmPassword]) {
        return;
    }
    
    if (![confirmPassword isEqualToString:newPassword]) {
        [UIUtils showToastKey:@"passwords_do_not_match" duration:1.5];
        _shinyNewPassword.text = @"";
        _confirmPassword.text = @"";
        [_shinyNewPassword becomeFirstResponder];
        return;
    }
    
    
    [_currentPassword resignFirstResponder];
    [_shinyNewPassword resignFirstResponder];
    [_confirmPassword resignFirstResponder];
    _progressView = [LoadingView showViewKey:@"change_password_progress"];
    
    SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
    if (!identity) {
        [_progressView removeView];
        _progressView = nil;

        [_currentPassword becomeFirstResponder];
        [UIUtils showToastKey:NSLocalizedString(@"could_not_change_password", nil) duration:2];
        return;
    }
    
    NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
    NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
    NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
    NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    
    [[NetworkController sharedInstance] getPasswordTokenForUsername:username
                                                        andPassword:passwordString
                                                       andSignature:signatureString
                                                       successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                           NSString * passwordToken = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                                           NSDictionary * derived = [EncryptionController deriveKeyFromPassword:newPassword];
                                                           NSData * newSaltData = [derived objectForKey:@"salt"];
                                                           NSData * newPasswordData = [derived objectForKey:@"key"];
                                                           NSData * encodedNewPassword = [newPasswordData SR_dataByBase64Encoding];
                                                           NSString * newPasswordString = [newPasswordData SR_stringByBase64Encoding];
                                                           NSData * tokenSignature = [EncryptionController signData1:[NSData dataFromBase64String:passwordToken] data2:encodedNewPassword withPrivateKey:[identity getDsaPrivateKey]];
                                                           NSString * tokenSignatureString = [tokenSignature SR_stringByBase64Encoding];
                                                           
                                                           [[NetworkController sharedInstance] changePasswordForUsername:username
                                                                                                             oldPassword:passwordString
                                                                                                             newPassword:newPasswordString
                                                                                                                 authSig:signatureString
                                                                                                                tokenSig:tokenSignatureString
                                                                                                              keyVersion:[identity latestVersion]
                                                                                                            successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                                                                [[IdentityController sharedInstance] updatePasswordForUsername:username
                                                                                                                                                               currentPassword:password
                                                                                                                                                                   newPassword:newPassword
                                                                                                                                                                       newSalt:[newSaltData SR_stringByBase64Encoding]];
                                                                                                                
                                                                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                                    [_progressView removeView];
                                                                                                                    _progressView = nil;

                                                                                                                    [UIUtils showToastKey:@"password_changed" duration:2];
                                                                                                                    
                                                                                                                    BackupIdentityViewController * bvc = [[BackupIdentityViewController alloc] initWithNibName:@"BackupIdentityView" bundle:nil];
                                                                                                                
                                                                                                                    UINavigationController * nav = self.navigationController;
                                                                                                                    [nav popViewControllerAnimated:NO];
                                                                                                                    [nav pushViewController:bvc animated:YES];
                                                                                                                });
  
                                                                                                            } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                                    [_progressView removeView];
                                                                                                                    _progressView = nil;

                                                                                                                    [_currentPassword becomeFirstResponder];
                                                                                                                    [UIUtils showToastKey:@"could_not_change_password" duration:2];
                                                                                                                });
                                                                                                            }];
                                                           
                                                       } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                           dispatch_async(dispatch_get_main_queue(), ^{
                                                               [_currentPassword becomeFirstResponder];
                                                               [_progressView removeView];
                                                               _progressView = nil;

                                                               [UIUtils showToastKey:@"could_not_change_password" duration:2];
                                                           });
                                                       }];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}




@end
