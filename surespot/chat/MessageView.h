//
//  OurMessageView.h
//  surespot
//
//  Created by Adam on 10/30/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FilledRectView.h"

@interface MessageView : UITableViewCell
@property (strong, nonatomic) IBOutlet FilledRectView *messageSentView;
@property (strong, nonatomic) IBOutlet UILabel *messageStatusLabel;
@property (strong, nonatomic) IBOutlet UILabel *messageLabel;
@end
