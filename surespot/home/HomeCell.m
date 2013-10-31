//
//  HomeCell.m
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "HomeCell.h"
#define INVITE_ACTION_BLOCK 0;
#define INVITE_ACTION_IGNORE 1;
#define INVITE_ACTION_ACCEPT 2;

@implementation HomeCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

- (IBAction)inviteAction:(id)sender {
    NSString * action;
    switch ([sender tag]) {
        case 0:
            action = @"block";
            break;
        case 1:
            action = @"ignore";
            break;
        case 2:
            action = @"accept";
            break;
    }
    if (action) {
        
        [_friendDelegate inviteAction:action forUsername:_friendName];
    }
}



@end
