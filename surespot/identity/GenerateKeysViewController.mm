//
//  GenerateKeysViewController.m
//  surespot
//
//  Created by Adam on 12/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "GenerateKeysViewController.h"
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
#import "BackupIdentityViewController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface GenerateKeysViewController ()
@property (strong, nonatomic) IBOutlet UILabel *label1;
@property (strong, nonatomic) IBOutlet UILabel *label2;
@property (atomic, strong) NSArray * identityNames;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;
@property (strong, nonatomic) IBOutlet UIButton *bExecute;
@property (atomic, strong) id progressView;
@property (atomic, strong) NSString * name;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (atomic, strong) NSString * url;
@end



@implementation GenerateKeysViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.navigationItem setTitle:NSLocalizedString(@"keys", nil)];
    [_bExecute setTitle:NSLocalizedString(@"regenerate_keys", nil) forState:UIControlStateNormal];
    [self loadIdentityNames];
    self.navigationController.navigationBar.translucent = NO;
    
    _label1.text = NSLocalizedString(@"generate_new_keypairs", nil);
    _label2.text = NSLocalizedString(@"backup_identities_again_keys", nil);
    _label2.textColor = [UIColor redColor];
    
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
    NSString * name = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    _name = name;
    
    //show alert view to get password
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"create_new_keys_for", nil), name] message:[NSString stringWithFormat:NSLocalizedString(@"enter_password_for", nil), name] delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", nil) otherButtonTitles:NSLocalizedString(@"ok", nil), nil];
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
            [self rollKeysForUsername:_name password:password];
        }
    }
}

-(void) rollKeysForUsername: (NSString *) username password: (NSString *) password {
    _progressView = [LoadingView showViewKey:@"generating_keys_progress"];
    SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
    if (!identity) {
        [_progressView removeView];
        _progressView = nil;
        [UIUtils showToastKey:@"could_not_create_new_keys" duration:2];
        return;
    }
    
    NSData * decodedSalt = [NSData dataFromBase64String: [identity salt]];
    NSData * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: decodedSalt];
    NSData * encodedPassword = [derivedPassword SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
    NSString * passwordString = [derivedPassword SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    
    [[NetworkController sharedInstance] getKeyTokenForUsername:username
                                                   andPassword:passwordString
                                                  andSignature:signatureString
                                                  successBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
                                                      NSString * keyToken = [JSON objectForKey:@"token"];
                                                      NSString * keyVersion = [[JSON objectForKey:@"keyversion"] stringValue];
                                                      
                                                      NSData * tokenSignature = [EncryptionController signData1:[NSData dataFromBase64String:keyToken] data2:[passwordString dataUsingEncoding:NSUTF8StringEncoding] withPrivateKey:[identity getDsaPrivateKey]];
                                                      
                                                      NSString * tokenSignatureString = [tokenSignature SR_stringByBase64Encoding];
                                                      
                                                      IdentityKeys * keys = [EncryptionController generateKeyPairs];
                                                      [[IdentityController sharedInstance] setExpectedKeyVersionForUsername:username version:keyVersion];
                                                      [[NetworkController sharedInstance] updateKeysForUsername:username
                                                                                                       password:passwordString
                                                                                                    publicKeyDH:[EncryptionController encodeDHPublicKey:keys.dhPubKey]
                                                                                                   publicKeyDSA:[EncryptionController encodeDSAPublicKey:keys.dsaPubKey]
                                                                                                        authSig:signatureString
                                                                                                       tokenSig:tokenSignatureString keyVersion:keyVersion
                                                                                                   successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                                                       [[IdentityController sharedInstance] rollKeysForUsername: username
                                                                                                                                                       password: password
                                                                                                                                                     keyVersion: keyVersion
                                                                                                                                                           keys: keys];
                                                                                                       
                                                                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                           [_progressView removeView];
                                                                                                           _progressView = nil;
                                                                                                           [UIUtils showToastKey:@"keys_created" duration:2];
                                                                                                           
                                                                                                           
                                                                                                           BackupIdentityViewController * bvc = [[BackupIdentityViewController alloc] initWithNibName:@"BackupIdentityView" bundle:nil];
                                                                                                           
                                                                                                           UINavigationController * nav = self.navigationController;
                                                                                                           [nav popViewControllerAnimated:NO];
                                                                                                           [nav pushViewController:bvc animated:YES];
                                                                                                           
                                                                                                       });
                                                                                                       
                                                                                                   } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                                                       [[IdentityController sharedInstance] removeExpectedKeyVersionForUsername:username];
                                                                                                       dispatch_async(dispatch_get_main_queue(), ^{
                                                                                                           [_progressView removeView];                                                                                                                                                                                                                      _progressView = nil;
                                                                                                           [UIUtils showToastKey:@"could_not_create_new_keys" duration:2];
                                                                                                       });
                                                                                                   }];
                                                      
                                                  } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
                                                      dispatch_async(dispatch_get_main_queue(), ^{
                                                          [_progressView removeView];
                                                          _progressView = nil;
                                                          [UIUtils showToastKey:@"could_not_create_new_keys" duration:2];
                                                      });
                                                  }];
}

-(BOOL) shouldAutorotate {
    return (_progressView == nil);
}




@end
