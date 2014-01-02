//
//  PurchaseDelegate.m
//  surespot
//
//  Created by Adam on 12/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "PurchaseDelegate.h"
#import "UIUtils.h"
#import "DDLog.h"
#import "NSData+Base64.h"
#import "PurchaseVoiceViewController.h"
#import "NSData+SRB64Additions.h"
#import "NetworkController.h"
#import "PwylViewController.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


static const NSString * PRODUCT_ID_VOICE_MESSAGING = @"voice_messaging";
static const NSString * PRODUCT_ID_ONE_DOLLAR = @"pwyl_1";


@interface PurchaseDelegate()
@property (strong, nonatomic) NSArray * products;
@property (strong, nonatomic) PurchaseVoiceViewController * viewController;
@property (strong, nonatomic) PwylViewController * pwylViewController;
@property (strong, nonatomic) UIPopoverController * popover;
@property (strong, nonatomic) UIViewController * parentController;
@end

@implementation PurchaseDelegate

+(PurchaseDelegate*)sharedInstance
{
    static PurchaseDelegate *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}

-(id) init {
    self = [super init];
    if (self) {
        NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
        [self setHasVoiceMessaging:[storage boolForKey:@"voice_messaging"]];
        [self validateProductIdentifiers: @[PRODUCT_ID_ONE_DOLLAR, PRODUCT_ID_VOICE_MESSAGING]];
    }
    return self;
}

-(NSString *) getAppStoreReceipt {
    
    NSData * appStoreReceipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    NSString * encodedReceipt = [appStoreReceipt base64EncodedStringWithSeparateLines:NO];
    return encodedReceipt;
}

-(void) validateProductIdentifiers:(NSArray *)productIdentifiers
{
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
}


- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    DDLogInfo(@"productsRequest %@", request);
    self.products = response.products;
    
    for (NSString *invalidIdentifier in response.invalidProductIdentifiers) {
        // Handle any invalid product identifiers.
    }
    
    //hide/show dynamically
}

- (void) purchaseProduct: (NSInteger) productIndex {
    
    SKProduct *product = _products[productIndex];
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = 1;
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    DDLogInfo(@"updatedTransactions");
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
                // Call the appropriate custom method.
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
            default:
                break;
        }
    }
}

-(void) completeTransaction: (SKPaymentTransaction *) transaction {
    SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
    [queue finishTransaction:transaction];
    [self processTransaction:transaction];
}

-(void) failedTransaction: (SKPaymentTransaction *) transaction {
    DDLogWarn(@"payment failed: %@", transaction.error);
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [UIUtils showToastMessage: transaction.error.localizedDescription duration: 2];
    }
}

-(void) restoreTransaction: (SKPaymentTransaction *) transaction {
    DDLogInfo(@"restoreTransaction");
    [self completeTransaction:transaction];
}

-(void) processTransaction: (SKPaymentTransaction *) transaction {
    DDLogInfo(@"processTransaction");
    if ([transaction.payment.productIdentifier isEqualToString:(NSString *)PRODUCT_ID_VOICE_MESSAGING]) {
        if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
            DDLogInfo(@"transaction complete, setting has voice messaging to YES");
            [self setHasVoiceMessaging:YES];
            [self setReceipt:transaction.transactionReceipt];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"purchaseStatusChanged" object:nil];
            return;
        }
        
        if (transaction.transactionState == SKPaymentTransactionStateRestored) {
            if (transaction.originalTransaction.transactionState == SKPaymentTransactionStatePurchased) {
                DDLogInfo(@"transaction restored, setting has voice messaging to YES");
                [self setHasVoiceMessaging:YES];
                [self setReceipt:transaction.transactionReceipt];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"purchaseStatusChanged" object:nil];
                return;
            }
        }
    }
}

-(void) setHasVoiceMessaging:(BOOL)hasVoiceMessaging {
    _hasVoiceMessaging = hasVoiceMessaging;
    [_viewController setVoiceOn:hasVoiceMessaging];
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    [storage setBool:hasVoiceMessaging forKey:@"voice_messaging"];
    if (!hasVoiceMessaging) {
        [storage removeObjectForKey:@"appStoreReceipt"];
    }

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"pref_dont_ask"];
    [_viewController setDontAsk: NO];
}

-(void) setReceipt: (NSData *) receipt {
    NSString * b64receipt = [receipt base64EncodedStringWithSeparateLines:NO];
    DDLogInfo(@"saving app store receipt %@ in user defaults", b64receipt);
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    [storage setObject: b64receipt forKey:@"appStoreReceipt"];
    
    //upload to server
    [[NetworkController sharedInstance] uploadReceipt:b64receipt successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
        
    } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
        DDLogInfo(@"could not validate purchase receipt on server, please login to validate");
        [UIUtils showToastKey:@"login_to_validate" duration:2];
    }];
}

-  (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
}

-(void) refresh {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

-(void) showPurchaseVoiceViewForController: (UIViewController *) parentController {
    _parentController = parentController;
    _viewController = [[PurchaseVoiceViewController alloc] initWithNibName:@"PurchaseVoiceView" bundle:nil];
    [_viewController setVoiceOn:_hasVoiceMessaging];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:_viewController];
        _popover.delegate = self;
        CGFloat x =_parentController.view.bounds.size.width;
        CGFloat y =_parentController.view.bounds.size.height;
        [_popover setPopoverContentSize:CGSizeMake(578, 450) animated:NO];
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:parentController.view permittedArrowDirections:0 animated:YES];
    } else {
        [parentController.navigationController pushViewController:_viewController animated:YES];
    }
}


-(void) showPwylViewForController: (UIViewController *) parentController {
    _parentController = parentController;
    _pwylViewController = [[PwylViewController alloc] initWithNibName:@"PayWhatYouLikeView" bundle:nil];

    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:_pwylViewController];
        _popover.delegate = self;
        CGFloat x =_parentController.view.bounds.size.width;
        CGFloat y =_parentController.view.bounds.size.height;
        [_popover setPopoverContentSize:CGSizeMake(578, 450) animated:NO];
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:parentController.view permittedArrowDirections:0 animated:YES];
    } else {
        [parentController.navigationController pushViewController:_pwylViewController animated:YES];
    }
}


- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    DDLogWarn(@"payment failed: %@", error);
    if (error.code != SKErrorPaymentCancelled) {
        [UIUtils showToastMessage:error.localizedDescription duration:2];
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    DDLogInfo(@"restore complete, transactions: %d", queue.transactions.count);
    for (SKPaymentTransaction *transaction in queue.transactions)
    {
        [self restoreTransaction:transaction];
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    self.popover = nil;
    _parentController = nil;
    _pwylViewController = nil;
    _viewController = nil;
}

- (void)orientationChanged
{
    // if the popover is showing, adjust its position after the re-orientation by presenting it again:
    if (self.popover != nil)  // if the popover is showing (replace with your own test if you wish)
    {
        CGFloat x =_parentController.view.bounds.size.width;
        CGFloat y =_parentController.view.bounds.size.height;
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        
        [self.popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:_parentController.view permittedArrowDirections:0 animated:YES];
    }
}

@end
