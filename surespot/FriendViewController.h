//
//  FriendViewController.h
//  surespot
//
//  Created by Adam on 6/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FriendViewController : UITableViewController
@property (nonatomic, strong) IBOutlet UITableView *friendTableView;
@property (strong, nonatomic) IBOutlet UITextField *inviteText;
@property (strong, atomic) NSDictionary *friends;
@end
