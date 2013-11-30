//
//  UIUtils.h
//  surespot
//
//  Created by Adam on 11/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"
#import "REMenu.h"

@interface UIUtils : NSObject
+ (void) showToastKey: (NSString *) key;
+ (void) showToastKey: (NSString *) key duration: (CGFloat) duration;
+ (CGSize)threadSafeSizeString: (NSString *) string WithFont:(UIFont *)font constrainedToSize:(CGSize)size;
+ (UIColor *) surespotBlue;
+(UIColor *) surespotSelectionBlue;
+(UIColor *) surespotTransparentBlue;
+ (void)setAppAppearances;
+ (BOOL)stringIsNilOrEmpty:(NSString*)aString;
+(CGFloat) keyboardHeightAdjustedForOrientation: (CGSize) size;
+(UIColor *) surespotGrey;
+(UIColor *) surespotTransparentGrey;
+(void) setMessageHeights: (SurespotMessage *)  message size: (CGSize) size;
+(void) startSpinAnimation: (UIView *) view;
+(void) stopSpinAnimation: (UIView *) view;
+(void) startPulseAnimation: (UIView *) view;
+(void) stopPulseAnimation: (UIView *) view;
+(void) showToastMessage: (NSString *) message duration: (CGFloat) duration;
+(NSString *) getMessageErrorText: (NSInteger) errorStatus;
+(REMenu *) createMenu: (NSArray *) menuItems closeCompletionHandler: (void (^)(void))completionHandler;
@end

