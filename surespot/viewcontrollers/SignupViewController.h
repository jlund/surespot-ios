//
//  SignupViewController.h
//  surespot
//
//  Created by Adam on 7/22/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SignupViewController : UIViewController<UIPopoverControllerDelegate>
@property (strong, nonatomic) IBOutlet UIButton *bCreateIdentity;
@property (strong, nonatomic) IBOutlet UITextField *tbUsername;
@property (strong, nonatomic) IBOutlet UITextField *tbPassword;
- (IBAction)createIdentity:(id)sender;

@property (strong, nonatomic) IBOutlet UITextField *tbPasswordConfirm;
@end
