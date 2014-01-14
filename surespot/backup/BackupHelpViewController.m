//
//  HelpViewController.m
//  surespot
//
//  Created by Adam on 1/7/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "BackupHelpViewController.h"
#import "UIUtils.h"

@interface BackupHelpViewController ()
@property (strong, nonatomic) IBOutlet TTTAttributedLabel *helpLabel;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@end

@implementation BackupHelpViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSArray * matches = @[NSLocalizedString(@"aes_match", nil),
                          NSLocalizedString(@"pbkdf_match",nil),
                          NSLocalizedString(@"privatekeys_match",nil),
                          NSLocalizedString(@"bruteforce_match",nil),
                          NSLocalizedString(@"strength_match",nil)];
    
    NSArray * links = @[NSLocalizedString(@"aes_link", nil),
                        NSLocalizedString(@"pbkdf_link",nil),
                        NSLocalizedString(@"privatekeys_link",nil),
                        NSLocalizedString(@"bruteforce_link",nil),
                        NSLocalizedString(@"strength_link",nil)];
    
    
    NSString * label2Text = [NSString stringWithFormat:@"%@\n\n%@",
                             NSLocalizedString(@"help_backup_what",nil),
                             NSLocalizedString(@"help_backup_drive2", nil)];
    
    
    [UIUtils setLinkLabel:_helpLabel delegate:self labelText:label2Text linkMatchTexts:matches urlStrings:links];
    
    
    _helpLabel.preferredMaxLayoutWidth = _helpLabel.frame.size.width;
    [_helpLabel sizeToFit];
    
    CGFloat bottom =  _helpLabel.frame.origin.y + _helpLabel.frame.size.height;
    
    CGSize size = self.view.frame.size;
    size.height = bottom + 20;
    _scrollView.contentSize = size;
    
    [self.navigationItem setTitle:NSLocalizedString(@"help", nil)];
    self.navigationController.navigationBar.translucent = NO;
    
    
    
}


- (void)attributedLabel:(__unused TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}



@end
