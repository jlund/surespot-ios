//
//  KeyFingerprintCell.h
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeyFingerprintCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UILabel *versionLabel;
@property (strong, nonatomic) IBOutlet UILabel *versionValue;
@property (strong, nonatomic) IBOutlet UILabel *timeLabel;
@property (strong, nonatomic) IBOutlet UILabel *timeValue;
@property (strong, nonatomic) IBOutlet UIView *dsaView;
@property (strong, nonatomic) IBOutlet UIView *dhView;
@end
