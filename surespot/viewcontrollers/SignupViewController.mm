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
#import "RestoreIdentityViewController.h"
#import "HelpViewController.h"
#import "SwipeViewController.h"
#import "LoginViewController.h"
#import "BackupIdentityViewController.h"
#import "AboutViewController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface SignupViewController ()
@property (atomic, strong) id progressView;
@property (nonatomic, strong) NSString * lastCheckedUsername;
@property (nonatomic, assign) CGFloat delta;
@property (nonatomic, assign) CGPoint offset;
@property (nonatomic, assign) NSInteger keyboardHeight;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UILabel *helpLabel;
@property (strong, readwrite, nonatomic) REMenu *menu;
@property (nonatomic, strong) UIPopoverController * popover;
@end

@implementation SignupViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"create", nil)];
    
    NSString * usernamesCaseSensitive =    NSLocalizedString(@"usernames_case_sensitive", nil);
    NSString * pwWarning = NSLocalizedString(@"warning_password_reset", nil);
    
    NSString * labelText = [NSString stringWithFormat:@"%@ %@ %@ %@",
                            NSLocalizedString(@"enter_username_and_password", nil),
                            usernamesCaseSensitive,
                            NSLocalizedString(@"aware_username_password", nil),
                            pwWarning];
    
    
    
    //    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
    //        self.navigationController.navigationBar.tintColor = [UIUtils surespotBlue];
    //    }
    
    NSRange rr1 = [labelText rangeOfString:usernamesCaseSensitive];
    NSRange rr2 = [labelText rangeOfString:pwWarning];
    
    NSMutableAttributedString * helpString = [[NSMutableAttributedString alloc] initWithString:labelText];
    [helpString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range: rr1];
    [helpString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range: rr2];
	   
    
    _helpLabel.attributedText = helpString;
    
    _tbUsername.returnKeyType = UIReturnKeyNext;
    [_tbUsername setRightViewMode: UITextFieldViewModeNever];
    [_tbUsername setPlaceholder:NSLocalizedString(@"username", nil)];
    
    _tbPassword.returnKeyType = UIReturnKeyNext;
    [_tbPassword setPlaceholder:NSLocalizedString(@"password", nil)];
    
    _tbPasswordConfirm.returnKeyType = UIReturnKeyGo;
    [_tbPasswordConfirm setPlaceholder:NSLocalizedString(@"confirm_password", nil)];
    
    [self registerForKeyboardNotifications];
    
    if ([[[IdentityController sharedInstance] getIdentityNames] count] == 0) {
        self.navigationItem.hidesBackButton = YES;
    }
    
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"menu",nil) style:UIBarButtonItemStylePlain target:self action:@selector(showMenu)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    [_bCreateIdentity setTintColor:[UIUtils surespotBlue]];
    [_bCreateIdentity setTitle:NSLocalizedString(@"create_identity", nil) forState:UIControlStateNormal];
    
    
    
    [_scrollView setContentSize: CGSizeMake(self.view.frame.size.width, _bCreateIdentity.frame.origin.y + _bCreateIdentity.frame.size.height + 10)];
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
    
    [_tbUsername resignFirstResponder];
    [_tbPassword resignFirstResponder];
    [_tbPasswordConfirm resignFirstResponder];
    _progressView = [LoadingView showViewKey:@"create_user_progress"];
    
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
         successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
             DDLogVerbose(@"signup response: %d",  [operation.response statusCode]);
             [[IdentityController sharedInstance] createIdentityWithUsername:username andPassword:password andSalt:salt andKeys:keys];
             UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard" bundle: nil];
             LoginViewController * lvc =[storyboard instantiateViewControllerWithIdentifier:@"loginViewController"];
             SwipeViewController * svc = [storyboard instantiateViewControllerWithIdentifier:@"swipeViewController"];
             BackupIdentityViewController * bvc = [[BackupIdentityViewController alloc] initWithNibName:@"BackupIdentityView" bundle:nil];
             
             NSMutableArray *  controllers = [NSMutableArray new];
             [controllers addObject:lvc];
             [controllers addObject:svc];
             [controllers addObject:bvc];
             
             
             //show help view on iphone if it hasn't been shown
             BOOL tosClicked = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
             if (!tosClicked && ![UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
                 HelpViewController *hvc = [[HelpViewController alloc] initWithNibName:@"HelpView" bundle:nil];
                 [controllers addObject:hvc];
             }
             
             [self.navigationController setViewControllers:controllers animated:YES];
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
    _progressView = [LoadingView showViewKey:@"user_exists_progress"];
    
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
        [_progressView removeView];
        _lastCheckedUsername = nil;
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
    
    NSInteger loginButtonBottom =(_bCreateIdentity.frame.origin.y + _bCreateIdentity.frame.size.height);
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



-(void) showMenu {
    if (!_menu) {
        _menu = [self createMenu];
        if (_menu) {
            [_menu showSensiblyInView:self.view];
        }
    }
    else {
        [_menu close];
    }
    
}

-(REMenu *) createMenu {
    //menu menu
    
    NSMutableArray * menuItems = [NSMutableArray new];
    
    
    REMenuItem * restoreItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"import_identities", nil) image:[UIImage imageNamed:@"ic_menu_archive"] highlightedImage:nil action:^(REMenuItem * item){
        RestoreIdentityViewController * controller = [[RestoreIdentityViewController alloc] initWithNibName:@"RestoreIdentityViewController" bundle:[NSBundle mainBundle]];
        [self.navigationController pushViewController:controller animated:YES];
        
    }];
    
    [menuItems addObject:restoreItem];
    
    REMenuItem * aboutItem = [[REMenuItem alloc] initWithTitle:NSLocalizedString(@"about", nil) image:[UIImage imageNamed:@"surespot_logo48"] highlightedImage:nil action:^(REMenuItem * item){
        [self showAbout];
    }];

    
    [menuItems addObject:aboutItem];

    
    
    return [UIUtils createMenu: menuItems closeCompletionHandler:^{
        _menu = nil;
    }];
}


- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popover = nil;
}


-(void) showAbout {
    AboutViewController * controller = [[AboutViewController alloc] initWithNibName:@"AboutView" bundle:nil];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:controller];
        _popover.delegate = self;
        CGFloat x = self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover setPopoverContentSize:CGSizeMake(320, 480) animated:NO];
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
        
    } else {
        [self.navigationController pushViewController:controller animated:YES];
    }
    
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromOrientation
{
    
    // if the popover is showing, adjust its position after the re-orientation by presenting it again:
    if (self.popover != nil)
    {
        CGFloat x =self.view.bounds.size.width;
        CGFloat y =self.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        
        [self.popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:self.view permittedArrowDirections:0 animated:YES];
    }
}



@end
