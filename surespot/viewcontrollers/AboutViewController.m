//
//  AboutViewController.m
//  surespot
//
//  Created by Adam on 1/8/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "AboutViewController.h"
#import "UIUtils.h"

@interface AboutViewController ()
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UILabel *surespotLabel;
@property (strong, nonatomic) IBOutlet TTTAttributedLabel *aboutLabel;
@end

@implementation AboutViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    _surespotLabel.text = NSLocalizedString(@"about_about", nil);

    
    NSArray * matches = @[NSLocalizedString(@"about_website_match", nil),
                          NSLocalizedString(@"tos_match",nil),
                          NSLocalizedString(@"pp_match",nil),
                          NSLocalizedString(@"threat_match",nil),
                          NSLocalizedString(@"github_match",nil),
                          NSLocalizedString(@"howsurespotworks_match",nil),
                          NSLocalizedString(@"support_match",nil),
                          NSLocalizedString(@"email_match",nil)];
    
    NSArray * links = @[NSLocalizedString(@"about_website_link", nil),
                        NSLocalizedString(@"tos_link",nil),
                        NSLocalizedString(@"pp_link",nil),
                        NSLocalizedString(@"threat_link",nil),
                        NSLocalizedString(@"github_link",nil),
                        NSLocalizedString(@"howsurespotworks_link",nil),
                        NSLocalizedString(@"support_link",nil),
                        NSLocalizedString(@"email_link",nil)];
    
    [UIUtils setLinkLabel:_aboutLabel delegate:self labelText:NSLocalizedString(@"about_website", nil) linkMatchTexts:matches urlStrings:links];

    
    [self.navigationItem setTitle:NSLocalizedString(@"about_action_bar_right", nil)];
    self.navigationController.navigationBar.translucent = NO;
    
    _scrollView.contentSize = self.view.frame.size;
    
}


- (void)attributedLabel:(__unused TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}


@end
