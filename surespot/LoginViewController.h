//
//  SurespotViewController.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LoginViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>

@property (strong, nonatomic) IBOutlet UITextField *textUsername;
@property (strong, nonatomic) IBOutlet UITextField *textPassword;
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) IBOutlet UIPickerView *userPicker;

- (IBAction)login:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *bLogin;

@end
