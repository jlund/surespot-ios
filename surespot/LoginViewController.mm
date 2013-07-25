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

@interface LoginViewController ()

@end

@implementation LoginViewController

NSArray * identityNames;

- (void)viewDidLoad
{
    [super viewDidLoad];
    identityNames = [IdentityController getIdentityNames];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)login:(id)sender {
    NSString * username = [identityNames objectAtIndex:[_userPicker selectedRowInComponent:0]];
    NSString * password = self.textPassword.text;
  

    SurespotIdentity * identity = [IdentityController getIdentityWithUsername:username andPassword:password];
    
   
    
    NSLog(@"loaded salt: %@", [identity salt]);

  //  NSData * saltData = [[identity salt] dataUsingEncoding:NSUTF8StringEncoding];

    NSData * decodedSalt =     [NSData dataFromBase64String: [identity salt]];
    byte * derivedPassword = [EncryptionController deriveKeyUsingPassword:password andSalt: (byte *)[decodedSalt bytes]];
    NSData * passwordData = [NSData dataWithBytes:derivedPassword length:AES_KEY_LENGTH];
    NSData * encodedPassword = [passwordData SR_dataByBase64Encoding];
    
    NSData * signature = [EncryptionController signUsername:username andPassword: encodedPassword withPrivateKey:[identity getDsaPrivateKey]];
   // NSData * signatureData = [NSData dataWithBytes:signature length:sizeof(signature)];
    
    NSString * passwordString = [passwordData SR_stringByBase64Encoding];
    NSString * signatureString = [signature SR_stringByBase64Encoding];
    
    [[NetworkController sharedInstance] loginWithUsername:username andPassword:passwordString andSignature: signatureString];
    
    [self performSegueWithIdentifier: @"loginToMainSegue" sender: nil];
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [identityNames count];
}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    //set item per row
    return [identityNames objectAtIndex:row];
}

- (void)viewDidUnload {
    [self setUserPicker:nil];
    [super viewDidUnload];
}
@end
