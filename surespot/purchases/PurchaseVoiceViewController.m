//
//  PurchaseVoiceView.m
//  surespot
//
//  Created by Adam on 12/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "PurchaseVoiceViewController.h"
#import "PurchaseDelegate.h"
#import "UIUtils.h"

@interface PurchaseVoiceViewController()
@property (strong, nonatomic) IBOutlet UIButton *purchaseVoiceButton;
@property (strong, nonatomic) IBOutlet UITextView *blurbTextView;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UISwitch *voiceSwitch;
@property (strong, nonatomic) IBOutlet UILabel *voiceTitle;
@property (strong, nonatomic) IBOutlet UILabel *dontAskMeAgainLabel;
@property (strong, nonatomic) IBOutlet UIButton *refreshButton;
@property (strong, nonatomic) IBOutlet UIButton *videoDemonstrationButton;
@property (strong, nonatomic) IBOutlet UISwitch *dontAskSwitch;
@end

@implementation PurchaseVoiceViewController

-(void) viewDidLoad {
    _blurbTextView.text = NSLocalizedString(@"voice_messaging_purchase_1", nil);
    
    [_refreshButton setTitle:NSLocalizedString(@"restore", nil)forState:UIControlStateNormal ];
    
    _voiceTitle.text = NSLocalizedString(@"voice_messaging", nil);
    
    
    
    _dontAskMeAgainLabel.text = NSLocalizedString(@"voice_message_suppress_purchase_ask", nil);
    [self.navigationItem setTitle:NSLocalizedString(@"menu_purchase_voice_messaging", nil)];
    self.navigationController.navigationBar.translucent = NO;
    UIBarButtonItem *anotherButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"refresh",nil) style:UIBarButtonItemStylePlain target:self action:@selector(refresh)];
    self.navigationItem.rightBarButtonItem = anotherButton;
    
    NSString * price = [[PurchaseDelegate sharedInstance] formatPriceForProductId: PRODUCT_ID_VOICE_MESSAGING];
    if (!price) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productsLoaded:) name:@"productsLoaded" object:nil];
    }
    else {
        [self updatePrices];
    }
    
    _scrollView.contentSize = self.view.frame.size;
    
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    [_voiceSwitch setOn:[storage boolForKey:@"voice_messaging"]];
    [_dontAskSwitch setOn:[storage boolForKey:@"pref_dont_ask"] animated:NO];
}

-(void) productsLoaded {
    [self updatePrices];
}

-(void) updatePrices {
    NSString * price = [[PurchaseDelegate sharedInstance] formatPriceForProductId: PRODUCT_ID_VOICE_MESSAGING];
    [_purchaseVoiceButton setTitle:[NSString stringWithFormat: NSLocalizedString(@"voice_messaging_purchase_button", nil), price] forState:UIControlStateNormal];
    [_videoDemonstrationButton setTitle: NSLocalizedString(@"video_demonstration", nil) forState:UIControlStateNormal];
    
    [_purchaseVoiceButton setEnabled:YES];
    
}


- (IBAction)demoClick:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://www.youtube.com/watch?v=3mifzH1DXDk"]];
}


- (IBAction)purchase:(id)sender {
    [[PurchaseDelegate sharedInstance] purchaseProductId:PRODUCT_ID_VOICE_MESSAGING quantity:1];
}

-(void) setVoiceOn: (BOOL) on {
    [_voiceSwitch setOn:on animated:YES];
}

-(void) setDontAsk:(BOOL)dontAsk {
    [_dontAskSwitch setOn:dontAsk animated:YES];
}

- (IBAction)refresh {
    [[PurchaseDelegate sharedInstance] refresh];
}

- (IBAction)dontAskValueChanged:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[sender isOn]  forKey:@"pref_dont_ask"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"purchaseStatusChanged" object:nil];
}


@end
