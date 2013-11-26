//
//  HomeCell.m
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "HomeCell.h"
#import "UIUtils.h"
#import "DDLog.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


#define INVITE_ACTION_BLOCK 0;
#define INVITE_ACTION_IGNORE 1;
#define INVITE_ACTION_ACCEPT 2;

@implementation HomeCell



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
