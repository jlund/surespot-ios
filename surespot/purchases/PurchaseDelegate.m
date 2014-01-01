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

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


static const NSString * PRODUCT_ID_VOICE_MESSAGING = @"voice_messaging";
static const NSString * PRODUCT_ID_ONE_DOLLAR = @"pwyl_1";


@interface PurchaseDelegate()
@property (strong, nonatomic) NSArray * products;
@property (strong,nonatomic) PurchaseVoiceViewController * viewController;
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
    [UIUtils showToastMessage: @"transaction complete" duration: 2];
    SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
    [queue finishTransaction:transaction];
    
    [self processTransaction:transaction];
}

-(void) failedTransaction: (SKPaymentTransaction *) transaction {
    [UIUtils showToastMessage: @"transaction failed" duration: 2];
}

-(void) restoreTransaction: (SKPaymentTransaction *) transaction {
    [self completeTransaction:transaction];
}

-(void) processTransaction: (SKPaymentTransaction *) transaction {
    if ([transaction.payment.productIdentifier isEqualToString:(NSString *)PRODUCT_ID_VOICE_MESSAGING]) {
        if (transaction.transactionState == SKPaymentTransactionStatePurchased) {
            DDLogInfo(@"transaction complete, setting has voice messaging to YES");
            [self setHasVoiceMessaging:YES];
            [self setReceipt:transaction.transactionReceipt];
            return;
        }
        
        if (transaction.transactionState == SKPaymentTransactionStateRestored) {
            if (transaction.originalTransaction.transactionState == SKPaymentTransactionStatePurchased) {
                DDLogInfo(@"transaction restored, setting has voice messaging to YES");
                [self setHasVoiceMessaging:YES];
                [self setReceipt:transaction.transactionReceipt];
                return;
            }
        }
    }
}

-(void) setHasVoiceMessaging:(BOOL)hasVoiceMessaging {
    if (hasVoiceMessaging) {
        _hasVoiceMessaging = YES;
        NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
        [storage setBool:YES forKey:@"voice_messaging"];
    }
}

-(void) setReceipt: (NSData *) receipt {
    NSString * b64receipt = [receipt base64EncodedStringWithSeparateLines:NO];
    DDLogInfo(@"saving app store receipt %@ in user defaults", b64receipt);
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    [storage setObject: b64receipt forKey:@"appStoreReceipt"];
}

-  (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
    
}

-(void) refresh {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

-(void) showPurchaseViewForController: (UIViewController *) parentController {
    
    
    PurchaseVoiceViewController * controller = [[PurchaseVoiceViewController alloc] initWithNibName:@"PurchaseVoice" bundle:nil];
    
        
    [controller setVoiceOn:_hasVoiceMessaging];
    [parentController.navigationController pushViewController:controller animated:YES];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    [UIUtils showToastMessage:@"error restoring transactions" duration:2];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    DDLogInfo(@"restore complete, transactions: %d", queue.transactions.count);
    for (SKPaymentTransaction *transaction in queue.transactions)
    {
        [self restoreTransaction:transaction];
    }
}

@end
