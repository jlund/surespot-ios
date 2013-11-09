//
//  UIUtils.h
//  surespot
//
//  Created by Adam on 11/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIUtils : NSObject
+ (void) showNotificationToastView:(UIView *) view data:(NSDictionary *) notificationData;
+ (void) showToastView: (UIView *) view key: (NSString *) key;
+ (void) showToastView: (UIView *) view key: (NSString *) key duration: (CGFloat) duration;
+ (CGSize)threadSafeSizeString: (NSString *) string WithFont:(UIFont *)font constrainedToSize:(CGSize)size;
+ (id) createProgressView: (UIView * )view;
+ (UIColor *) surespotBlue;
+ (void)setAppAppearances;
+ (BOOL)stringIsNilOrEmpty:(NSString*)aString;
+(CGFloat) keyboardHeightAdjustedForOrientation: (CGSize) size;
@end
