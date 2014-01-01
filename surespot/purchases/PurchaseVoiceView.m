//
//  PurchaseVoiceView.m
//  surespot
//
//  Created by Adam on 12/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "PurchaseVoiceView.h"
#import "PurchaseDelegate.h"
#import "UIUtils.h"

@interface PurchaseVoiceView()
@property (strong, nonatomic) IBOutlet UIButton *refreshButton;
@property (strong, nonatomic) IBOutlet UIButton *purchaseVoiceButton;
@property (strong, nonatomic) IBOutlet UIButton *oneDollarButton;


@end


@implementation PurchaseVoiceView

-(id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        [_voiceSwitch setTintColor:[UIUtils surespotBlue]];
        [_voiceSwitch setOnTintColor:[UIUtils surespotBlue]];
    }
    return self;
    
}

- (IBAction)purchase:(id)sender {
    if (sender == _refreshButton) {
        [[PurchaseDelegate sharedInstance] refresh];
        return;
    }
    
    [[PurchaseDelegate sharedInstance] purchaseProduct:[sender tag]];
    
}


@end
