//
//  QRInviteViewController.m
//  surespot
//
//  Created by Adam on 12/24/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "QRInviteViewController.h"
#import "QREncoder.h"

@interface QRInviteViewController ()
@property (strong, nonatomic) IBOutlet UITextView *inviteBlurb;
@property (strong, nonatomic) IBOutlet UIImageView *inviteImage;
@property (strong, nonatomic) NSString * username;
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
    NSString * preString = NSLocalizedString(@"qr_pre_username_help", nil);
    NSString * inviteText = [NSString stringWithFormat:@"%@ %@ %@", preString, _username, NSLocalizedString(@"qr_post_username_help", nil)];
    
    NSMutableAttributedString * inviteString = [[NSMutableAttributedString alloc] initWithString:inviteText];
    [inviteString addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(preString.length+1, _username.length)];
    
    _inviteBlurb.attributedText = inviteString;
    [_inviteBlurb setFont:[UIFont systemFontOfSize:17]];
    [_inviteBlurb setTextAlignment:NSTextAlignmentCenter];
    [_inviteImage setImage:[self generateQRInviteImage:_username]];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(UIImage *) generateQRInviteImage: (NSString *) username {
    int qrcodeImageDimension = 250;
    NSString* inviteUrl = [NSString stringWithFormat:@"%@%@%@", @"http://192.168.10.68:8080/autoinvite/", username, @"/qr_ios"];
    
    //first encode the string into a matrix of bools, TRUE for black dot and FALSE for white. Let the encoder decide the error correction level and version
    DataMatrix* qrMatrix = [QREncoder encodeWithECLevel:QR_ECLEVEL_Q version:QR_VERSION_AUTO string:inviteUrl];
    
    //then render the matrix
    UIImage* qrcodeImage = [QREncoder renderDataMatrix:qrMatrix imageDimension:qrcodeImageDimension];
    
    return qrcodeImage;
}

@end
