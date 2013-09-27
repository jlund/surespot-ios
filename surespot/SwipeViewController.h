//
//  SwipeViewController.h
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SwipeView.h"

@interface SwipeViewController : UIViewController <SwipeViewDelegate, SwipeViewDataSource, UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) IBOutlet SwipeView *swipeView;
@property (nonatomic, strong) IBOutlet UIPageControl *pageControl;
@property (nonatomic, strong) UITableView *friendView;
@property (strong, atomic) NSDictionary *friends;
- (IBAction)pageControlTapped;
@property (strong, atomic) NSMutableDictionary *chats;
@property (strong, nonatomic) IBOutlet UITextField *textField;

@end
