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



NSString * const PRODUCT_ID_PWYL_1 = @"pwyl_1";
//static const NSString * PRODUCT_ID_PWYL_2 = @"pwyl_2";
//static const NSString * PRODUCT_ID_PWYL_3 = @"pwyl_3";
//static const NSString * PRODUCT_ID_PWYL_4 = @"pwyl_4";
//static const NSString * PRODUCT_ID_PWYL_5 = @"pwyl_5";
NSString * const PRODUCT_ID_PWYL_10 = @"pwyl_10";
//static const NSString * PRODUCT_ID_PWYL_20 = @"pwyl_20";
//static const NSString * PRODUCT_ID_PWYL_50 = @"pwyl_50";
//static const NSString * PRODUCT_ID_PWYL_100 = @"pwyl_100";
NSString *  const PRODUCT_ID_VOICE_MESSAGING = @"voice_messaging";


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
        
        
        
        [self setHasVoiceMessaging:YES];
        //TODO production
       // NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
        //        [self setHasVoiceMessaging:[storage boolForKey:@"voice_messaging"]];
        [self validateProductIdentifiers: @[PRODUCT_ID_PWYL_1, PRODUCT_ID_PWYL_10, PRODUCT_ID_VOICE_MESSAGING]];
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
    
    //hide/show dynamically
    [[NSNotificationCenter defaultCenter] postNotificationName:@"productsLoaded" object:nil];
}



- (void) purchaseProductId: (NSString *) productId quantity: (NSInteger) quantity {
    SKProduct *product = [self getProductForId: productId];
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    payment.quantity = quantity;
    
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
    //1005 is "could not sign in with test account" error apparently
    if (transaction.error.code != SKErrorPaymentCancelled && transaction.error.code != SKErrorPaymentNotAllowed && transaction.error.code != 1005) {
        [UIUtils showToastMessage: [NSString stringWithFormat:@"%@%@ - %@",@"In App Purchase Error: ",transaction.error.localizedDescription, transaction.error.localizedFailureReason] duration: 4];
    }
}

-(void) restoreTransaction: (SKPaymentTransaction *) transaction {
    DDLogInfo(@"restoreTransaction");
    [self completeTransaction:transaction];
}

-(void) processTransaction: (SKPaymentTransaction *) transaction {
    DDLogInfo(@"processTransaction");
    if ([transaction.payment.productIdentifier isEqualToString:PRODUCT_ID_VOICE_MESSAGING]) {
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
    
    if ([transaction.payment.productIdentifier isEqualToString:PRODUCT_ID_PWYL_1] || [transaction.payment.productIdentifier isEqualToString:PRODUCT_ID_PWYL_10]  ) {
        if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
            DDLogInfo(@"transaction complete, surecoin purchased");
            [UIUtils showToastKey:@"surecoin_purchase_complete" duration:2];
            return;
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
    _pwylViewController = [[PwylViewController alloc] initWithNibName:@"PWYLView" bundle:nil];
    
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:_pwylViewController];
        _popover.delegate = self;
        CGFloat x =_parentController.view.bounds.size.width;
        CGFloat y =_parentController.view.bounds.size.height;
        [_popover setPopoverContentSize:CGSizeMake(320, 420) animated:NO];
        DDLogInfo(@"setting popover x, y to: %f, %f", x/2,y/2);
        [_popover presentPopoverFromRect:CGRectMake(x/2,y/2, 1,1 ) inView:parentController.view permittedArrowDirections:0 animated:YES];
    } else {
        [parentController.navigationController pushViewController:_pwylViewController animated:YES];
    }
}


- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    DDLogWarn(@"payment failed: %@", error);
    if (error.code != SKErrorPaymentCancelled && error.code != SKErrorPaymentNotAllowed) {
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

-(SKProduct *) getProductForId: (NSString *) productId {
    for (SKProduct *product in _products) {
        if ([product.productIdentifier isEqualToString:productId]) {
            return product;
        }
    }
    return nil;
}


-(NSString *) formatPriceForProductId: (NSString *) productId {
    SKProduct * product = [self getProductForId:productId];
    
    if (product) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [numberFormatter setLocale:product.priceLocale];
        NSString *formattedPrice = [numberFormatter stringFromNumber:product.price];
        return formattedPrice;
    }
    
    return nil;
}

@end
