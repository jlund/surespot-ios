//
//  PurchaseDelegate.h
//  surespot
//
//  Created by Adam on 12/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

extern NSString * const PRODUCT_ID_PWYL_1;
extern NSString * const PRODUCT_ID_PWYL_10;
extern NSString * const PRODUCT_ID_VOICE_MESSAGING;

@interface PurchaseDelegate : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver, UIPopoverControllerDelegate>
- (void) purchaseProductId: (NSString *) productId quantity: (NSInteger) quantity;
+(PurchaseDelegate*)sharedInstance;
@property (nonatomic, assign) BOOL hasVoiceMessaging;
-(void) setHasVoiceMessaging:(BOOL)hasVoiceMessaging;
-(NSString *) getAppStoreReceipt;
-(void) refresh;
-(void) showPwylViewForController: (UIViewController *) parentController;
- (void)orientationChanged;
-(NSString *) formatPriceForProductId: (NSString *) productId;
-(void) showPurchaseVoiceViewForController: (UIViewController *) parentController;
-(SKProduct *) getProductForId: (NSString *) productId;
@end
