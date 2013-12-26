//
//  QRInviteViewController.m
//  surespot
//
//  Created by Adam on 12/24/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "QRInviteViewController.h"
#import "QREncoder.h"
#import "SurespotConstants.h"

@interface QRInviteViewController ()
@property (strong, nonatomic) IBOutlet UITextView *inviteBlurb;
@property (strong, nonatomic) IBOutlet UIImageView *inviteImage;
@property (strong, nonatomic) NSString * username;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@end

@implementation QRInviteViewController

- (id)initWithNibName:(NSString *)nibNameOrNil username: (NSString *) username
{
    self = [super initWithNibName:nibNameOrNil bundle:nil];
    if (self) {
        // Custom initialization
        _username = username;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"qr";
    
    NSString * preString = NSLocalizedString(@"qr_pre_username_help", nil);
    NSString * inviteText = [NSString stringWithFormat:@"%@ %@ %@", preString, _username, NSLocalizedString(@"qr_post_username_help", nil)];
    
    NSMutableAttributedString * inviteString = [[NSMutableAttributedString alloc] initWithString:inviteText];
    [inviteString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(preString.length+1, _username.length)];
    
    _inviteBlurb.attributedText = inviteString;
    [_inviteBlurb setFont:[UIFont systemFontOfSize:17]];
    [_inviteBlurb setTextAlignment:NSTextAlignmentCenter];
    [_inviteImage setImage:[self generateQRInviteImage:_username]];
    _scrollView.contentSize = self.view.frame.size;
}

-(UIImage *) generateQRInviteImage: (NSString *) username {
    int qrcodeImageDimension = 250;
    NSString * baseUrl = serverSecure ?
    [NSString stringWithFormat: @"https://%@", serverBaseIPAddress] :
    [NSString stringWithFormat: @"http://%@:%d", serverBaseIPAddress, serverPort];
    NSString* inviteUrl = [NSString stringWithFormat:@"%@%@%@%@", baseUrl, @"/autoinvite/", username, @"/qr_ios"];
    
    //first encode the string into a matrix of bools, TRUE for black dot and FALSE for white. Let the encoder decide the error correction level and version
    DataMatrix* qrMatrix = [QREncoder encodeWithECLevel:QR_ECLEVEL_Q version:QR_VERSION_AUTO string:inviteUrl];
    
    //then render the matrix
    UIImage* qrcodeImage = [QREncoder renderDataMatrix:qrMatrix imageDimension:qrcodeImageDimension];
    
    return qrcodeImage;
}

@end
