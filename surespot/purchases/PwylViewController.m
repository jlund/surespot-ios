//
//  PwylViewController.m
//  surespot
//
//  Created by Adam on 1/2/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "PwylViewController.h"
#import "PurchaseDelegate.h"
#import "TTTAttributedLabel.h"
#import "UIUtils.h"

@interface PwylViewController ()
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet TTTAttributedLabel *l1;
@property (strong, nonatomic) IBOutlet UILabel *priceLabel;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *buttons;
@end

@implementation PwylViewController

-(void) viewDidLoad {
    [UIUtils setLinkLabel:_l1 delegate:self
                labelText:NSLocalizedString(@"pwyl_text", nil)
           linkMatchTexts:@[NSLocalizedString(@"eff_match", nil)]
               urlStrings:@[NSLocalizedString(@"eff_link", nil)]];
    
    [self updateButtons];
    
    NSString * price = [[PurchaseDelegate sharedInstance] formatPriceForProductId: PRODUCT_ID_PWYL_1];
    _priceLabel.text = [NSString stringWithFormat:@"1 surecoin = %@", price ];
    
    [self.navigationItem setTitle:NSLocalizedString(@"pay_what_you_like", nil)];
    self.navigationController.navigationBar.translucent = NO;
    
    _scrollView.contentSize = self.view.frame.size;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productsLoaded:) name:@"productsLoaded" object:nil];
    
    self.navigationController.navigationBar.translucent = NO;
}

-(void) productsLoaded: (NSNotification *) notification {
    [self updateButtons];
}

-(void) updateButtons {
    
    for (UIButton * button in _buttons) {
        [button setTitle: [NSString stringWithFormat:@"%d surecoin", button.tag] forState:UIControlStateNormal];
        if (button.tag < 10) {
            [button setEnabled:[[PurchaseDelegate sharedInstance] getProductForId:PRODUCT_ID_PWYL_1] != nil];
        }
        else {
            [button setEnabled:[[PurchaseDelegate sharedInstance] getProductForId:PRODUCT_ID_PWYL_10] != nil];
        }
    }

}


- (void)attributedLabel:(__unused TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}


- (IBAction)purchase:(id)sender {
    NSInteger quantity = [sender tag];
    
    NSString * productId = quantity < 10 ? PRODUCT_ID_PWYL_1 : PRODUCT_ID_PWYL_10;
    
    if (quantity >= 10) {
        quantity /= 10;
    }
    
    
    [[PurchaseDelegate sharedInstance] purchaseProductId:productId quantity:quantity];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
