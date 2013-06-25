//
//  SurespotViewController.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LoginViewController : UIViewController
@property (weak, nonatomic) IBOutlet UITextField *textUsername;
- (IBAction)login:(id)sender;
@property (weak, nonatomic) IBOutlet UITextField *textPassword;

@property (copy, nonatomic) NSString *username;


@end