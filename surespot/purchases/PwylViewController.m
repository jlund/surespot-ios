//
//  PwylViewController.m
//  surespot
//
//  Created by Adam on 1/2/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "PwylViewController.h"
#import "PurchaseDelegate.h"

@interface PwylViewController ()

@end

@implementation PwylViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void) viewDidLoad {
   // _blurbTextView.text = NSLocalizedString(@"voice_messaging_purchase_1", nil);
    
    // _blurbTextView.dataDetectorTypes = UIDataDetectorTypeLink;
    
   // [_refreshButton setTitle:NSLocalizedString(@"refresh", nil)forState:UIControlStateNormal ];
    
//    _voiceTitle.text = NSLocalizedString(@"voice_messaging", nil);
//    [_purchaseVoiceButton setTitle:NSLocalizedString(@"voice_messaging_purchase_button", nil)forState:UIControlStateNormal ];
//    _dontAskMeAgainLabel.text = NSLocalizedString(@"voice_message_suppress_purchase_ask", nil);
    
    
    [self.navigationItem setTitle:NSLocalizedString(@"pay_what_you_like", nil)];
    self.navigationController.navigationBar.translucent = NO;
    
    
    
//    _scrollView.contentSize = self.view.frame.size;
    
  
}


- (IBAction)purchase:(id)sender {
    [[PurchaseDelegate sharedInstance] purchaseProduct:[sender tag]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
