//
//  RestoreIdentityViewController.h
//  surespot
//
//  Created by Adam on 11/28/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RestoreIdentityViewController : UIViewController<UITableViewDataSource, UITableViewDelegate>
- (IBAction)bLoadIdentities:(id)sender;
@property (strong, nonatomic) IBOutlet UIButton *bSelect;
@property (strong, nonatomic) IBOutlet UILabel *accountLabel;

@end
