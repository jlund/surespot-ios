//
//  SwipeViewController.h
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SwipeView.h"
#import "KeyboardState.h"
#import "FriendDelegate.h"
#import "Friend.h"
#import "UIViewPager.h"
@interface SwipeViewController : UIViewController
<
    SwipeViewDelegate,
    SwipeViewDataSource,
    UITableViewDataSource,
    UITableViewDelegate,
    UIActionSheetDelegate,
    UIViewPagerDelegate
>
@property (nonatomic, strong) IBOutlet SwipeView *swipeView;
@property (nonatomic, strong) UITableView *friendView;
@property (strong, atomic) NSMutableDictionary *chats;
@property (strong, nonatomic) IBOutlet UITextField *textField;
@property (strong, nonatomic) KeyboardState * keyboardState;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *textBottomConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *swipeTopConstraint;
@property (strong, nonatomic) IBOutlet UIButton *theButton;
- (IBAction)buttonTouchUpInside:(id)sender;
@property (strong, nonatomic) IBOutlet UIView *textFieldContainer;
- (IBAction)textFieldChanged:(id)sender;

@end
