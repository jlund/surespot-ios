//
//  HomeCell.h
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FriendDelegate.h"

@interface HomeCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UIImageView *friendImage;
@property (strong, nonatomic) IBOutlet UIView *activeStatus;
@property (strong, nonatomic) IBOutlet UIButton *blockButton;
@property (strong, nonatomic) IBOutlet UIButton *ignoreButton;
@property (strong, nonatomic) IBOutlet UIButton *acceptButton;
@property (strong, nonatomic) IBOutlet UILabel *friendLabel;
- (IBAction)inviteAction:(id)sender;
@property (weak, nonatomic) id <FriendDelegate> friendDelegate;
@property (strong, nonatomic) NSString * friendName;
@end
