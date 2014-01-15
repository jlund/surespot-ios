//
//  HelpViewController.m
//  surespot
//
//  Created by Adam on 1/7/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "HelpViewController.h"
#import "UIUtils.h"

@interface HelpViewController ()
@property (strong, nonatomic) IBOutlet TTTAttributedLabel *helpLabel;
@property (strong, nonatomic) IBOutlet UILabel *helpLabel2;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet TTTAttributedLabel *tosLabel;
@property (strong, nonatomic) IBOutlet UIButton *tosButton;
@end

@implementation HelpViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSArray * matches = @[NSLocalizedString(@"end_to_end_match", nil),
                          NSLocalizedString(@"symmetric_key_match",nil),
                          NSLocalizedString(@"aes_gcm_match",nil),
                          NSLocalizedString(@"ecdh_match",nil)];
    
    NSArray * links = @[NSLocalizedString(@"end_to_end_link",nil),
                        NSLocalizedString(@"symmetric_key_link",nil),
                        NSLocalizedString(@"aes_gcm_link",nil),
                        NSLocalizedString(@"ecdh_link",nil)];
    
    
    NSString * labelText = NSLocalizedString(@"welcome_to_surespot",nil);
    
    
	
    [UIUtils setLinkLabel:_helpLabel delegate:self labelText:labelText linkMatchTexts:matches urlStrings:links];
    NSString * helpBackupIdsString1 = NSLocalizedString(@"help_backupIdentities1", nil);
    
    NSString * label2Text = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@\n\n%@",
                             
                             NSLocalizedString(@"help_invite", nil),
                             NSLocalizedString(@"share_link_help", nil),
                             helpBackupIdsString1, //red
                             NSLocalizedString(@"help_backupIdentities2", nil),
                             NSLocalizedString(@"navigate_between_chat_tabs", nil),
                             NSLocalizedString(@"voice_help_1", nil),
                             NSLocalizedString(@"voice_help_2", nil),
                             NSLocalizedString(@"voice_help_3", nil),
                             NSLocalizedString(@"voice_help_4", nil),
                             NSLocalizedString(@"help_holdmessage", nil),
                             NSLocalizedString(@"help_holdfriend", nil),
                             NSLocalizedString(@"help_imageZoom", nil),
                             NSLocalizedString(@"help_messageHistory", nil)
                             ];
    
    
    NSMutableAttributedString * label2String = [[NSMutableAttributedString alloc] initWithString:label2Text];
    [label2String addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:[label2Text rangeOfString: helpBackupIdsString1]];
    
    
    _helpLabel2.preferredMaxLayoutWidth = _helpLabel2.frame.size.width;
    _helpLabel2.attributedText = label2String;
    [_helpLabel2 sizeToFit];
    
    
    BOOL hasClickTOS = [[NSUserDefaults standardUserDefaults] boolForKey:@"hasClickedTOS"];
    
    CGFloat label2bottom =  _helpLabel2.frame.origin.y + _helpLabel2.frame.size.height;
    CGFloat bottom = 0;
    
    if (!hasClickTOS) {
        
        NSArray * matches = @[NSLocalizedString(@"tos_match", nil)];
        NSArray * links = @[NSLocalizedString(@"tos_link",nil)];
        NSString * tosText = NSLocalizedString(@"help_agreement",nil);
        
        [UIUtils setLinkLabel:_tosLabel delegate:self labelText:tosText linkMatchTexts:matches urlStrings:links];
        [_tosButton setTitle:NSLocalizedString(@"ok", nil) forState:UIControlStateNormal];
        [_tosButton setTintColor:[UIUtils surespotBlue]];
        _tosLabel.hidden = NO;
        _tosButton.hidden = NO;
        
        CGRect frame = _tosLabel.frame;
        frame.origin.y = label2bottom + 10;
        _tosLabel.frame = frame;
        
        frame = _tosButton.frame;
        frame.origin.y = _tosLabel.frame.origin.y + _tosLabel.frame.size.height + 10;
        _tosButton.frame = frame;
        
        bottom =  _tosButton.frame.origin.y + _tosButton.frame.size.height;
        self.navigationItem.hidesBackButton = YES;
    }
    else {
        _tosLabel.hidden = YES;
        _tosButton.hidden = YES;
        bottom = label2bottom;
        self.navigationItem.hidesBackButton = NO;
    }
    
    CGSize size = CGSizeMake(self.view.frame.size.width, bottom + 20);
    _scrollView.contentSize = size;
    
    [self.navigationItem setTitle:NSLocalizedString(@"help", nil)];
    self.navigationController.navigationBar.translucent = NO;
    
}
- (IBAction)tosClick:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"hasClickedTOS"];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [_poController dismissPopoverAnimated:YES];
        
    }
    else {
        [self.navigationController popViewControllerAnimated:YES];
    }
    _poController = nil;
}


- (void)attributedLabel:(__unused TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}


@end
