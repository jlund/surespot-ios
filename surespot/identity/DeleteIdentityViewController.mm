//
//  DeleteIdentityViewController.m
//  surespot
//
//  Created by Adam on 12/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "DeleteIdentityViewController.h"
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

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface DeleteIdentityViewController ()
@property (strong, nonatomic) IBOutlet UILabel *label1;
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@property (strong, nonatomic) IBOutlet UIButton *bExecute;
@property (atomic, strong) LoadingView * progressView;
@property (atomic, strong) NSString * name;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (atomic, strong) NSString * url;
@end



@implementation DeleteIdentityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"delete", nil)];
    [_bExecute setTitle:NSLocalizedString(@"delete_identity", nil) forState:UIControlStateNormal];
    [self loadIdentityNames];
    self.navigationController.navigationBar.translucent = NO;
    
    _label1.text = NSLocalizedString(@"delete_identity_message_warning", nil);
    
    _scrollView.contentSize = self.view.frame.size;
    [_userPicker selectRow:[_identityNames indexOfObject:[[IdentityController sharedInstance] getLoggedInUser]] inComponent:0 animated:YES];
}

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

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 300, 37)];
    label.text =  [_identityNames objectAtIndex:row];
    [label setFont:[UIFont systemFontOfSize:22]];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (IBAction)execute:(id)sender {
    NSString * name = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    _name = name;
    
    //show alert view to get password
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"delete_identity_user", nil), name] message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
    alertView.alertViewStyle = UIAlertViewStyleSecureTextInput;
    [alertView show];
    
}

-(void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSString * password = nil;
        if (alertView.alertViewStyle == UIAlertViewStyleSecureTextInput) {
            password = [[alertView textFieldAtIndex:0] text];
        }
        
        if (![UIUtils stringIsNilOrEmpty:password]) {
            [self deleteIdentityForUsername:_name password:password];
        }
    }
}

-(void) deleteIdentityForUsername: (NSString *) username password: (NSString *) password {
    _progressView = [LoadingView showViewKey:@"delete_identity_progress"];
    SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
    if (!identity) {
        [_progressView removeView];
        _progressView = nil;
        [UIUtils showToastKey:@"could_not_delete_identity" duration:2];
        return;
    }
    
    NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
    NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
    NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
    NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    NSString * version = [identity latestVersion];
    
    [[NetworkController sharedInstance] getDeleteTokenForUsername:username
                                                      andPassword:passwordString
                                                     andSignature:signatureString
                                                     successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                         
                                                         NSString * keyToken = [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding];
                                                         
                                                         NSData * tokenSignature = [EncryptionController signData1:[NSData dataFromBase64String:keyToken] data2:[passwordString dataUsingEncoding:NSUTF8StringEncoding] withPrivateKey:[identity getDsaPrivateKey]];
                                                         
                                                         NSString * tokenSignatureString = [tokenSignature SR_stringByBase64Encoding];
                                                         
                                                         
                                                         [[NetworkController sharedInstance] deleteUsername:username
                                                                                                   password:passwordString
                                                                                                    authSig:signatureString
                                                                                                   tokenSig:tokenSignatureString
                                                                                                 keyVersion:version
                                                                                               successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                                                   
                                                                                                   
                                                                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                       [self loadIdentityNames];
                                                                                                       [[IdentityController sharedInstance] deleteIdentityUsername:username];
                                                                                                       [_progressView removeView];
                                                                                                       _progressView = nil;
                                                                                                       [UIUtils showToastKey:@"identity_deleted" duration:2];
                                                                                                   });
                                                                                                   
                                                                                               } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                                                   [[IdentityController sharedInstance] removeExpectedKeyVersionForUsername:username];
                                                                                                   dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                       [_progressView removeView];
                                                                                                       _progressView = nil;
                                                                                                       [UIUtils showToastKey:@"could_not_delete_identity" duration:2];
                                                                                                   });
                                                                                               }];
                                                         
                                                     } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                         
                                                         dispatch_async(dispatch_get_main_queue(), ^{
                                                             [_progressView removeView];
                                                             _progressView = nil;
                                                             [UIUtils showToastKey:@"could_not_delete_identity" duration:2];
                                                         });
                                                     }];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}


@end
