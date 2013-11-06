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

@interface LoginViewController ()
@property (atomic, strong) NSArray * identityNames;
@property (atomic, strong) id progressView;
@end

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self loadIdentityNames];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)login:(id)sender {
    NSString * username = [_identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    NSString * password = self.textPassword.text;
    
    if (!password) {
        return;
    }
    
    NSLog(@"starting login");
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [_textPassword resignFirstResponder];
    _progressView = [LoadingView loadingViewInView:self.view];
    
    dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    dispatch_async(q, ^{
        
        
        SurespotIdentity * identity = [[IdentityController sharedInstance] getIdentityWithUsername:username andPassword:password];
        
        if (!identity) {
            [UIUtils showToastView:_userPicker key: @"login_check_password" ];
            [_progressView removeView];
            self.navigationItem.rightBarButtonItem.enabled = YES;
            return;
        }
        
        
        
        
        // NSLog(@"loaded salt: %@", [identity salt]);
        
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
             NSLog(@"login response: %d",  [response statusCode]);
             
             [[IdentityController sharedInstance] userLoggedInWithIdentity:identity];
             [self performSegueWithIdentifier: @"loginToMainSegue" sender: nil ];
             [_progressView removeView];
             self.navigationItem.rightBarButtonItem.enabled = YES;
         }
         failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
             NSLog(@"response failure: %@",  Error);
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
}
@end
