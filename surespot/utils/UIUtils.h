//
//  UIUtils.h
//  surespot
//
//  Created by Adam on 11/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"

@interface UIUtils : NSObject
+ (void) showNotificationToastView:(UIView *) view data:(NSDictionary *) notificationData;
+ (void) showToastView: (UIView *) view key: (NSString *) key;
+ (void) showToastView: (UIView *) view key: (NSString *) key duration: (CGFloat) duration;
+ (CGSize)threadSafeSizeString: (NSString *) string WithFont:(UIFont *)font constrainedToSize:(CGSize)size;
+ (id) createProgressView: (UIView * )view;
+ (UIColor *) surespotBlue;
+(UIColor *) surespotTransparentBlue;
+ (void)setAppAppearances;
+ (BOOL)stringIsNilOrEmpty:(NSString*)aString;
+(CGFloat) keyboardHeightAdjustedForOrientation: (CGSize) size;
+(UIColor *) surespotGrey;
+(UIColor *) surespotTransparentGrey;
+(void) setMessageHeights: (SurespotMessage *)  message size: (CGSize) size;
@end
