//
//  UIUtils.m
//  surespot
//
//  Created by Adam on 11/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "UIUtils.h"
#import "Toast+UIView.h"

@implementation UIUtils

+(UIColor *) surespotBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:1.0];
}

+(void) showNotificationToastView:(UIView *) view  data:(NSDictionary *) notificationData {
    NSString * type = [notificationData valueForKeyPath:@"aps.alert.loc-key"];
    if (type && [type isEqualToString:@"notification_message"]) {
        
        
        NSString * to =[ notificationData objectForKey:@"to"];
        NSString * from =[ notificationData objectForKey:@"from"];
        [view makeToast:[NSString stringWithFormat:NSLocalizedString(@"notification_message", nil), to, from]
               duration: 1.0
               position:@"top"
         
         ];
    }
    
}

+(void) showToastView: (UIView *) view key: (NSString *) key {
    [self showToastView:view key:key duration:1.0];
}
+(void) showToastView: (UIView *) view key: (NSString *) key duration: (CGFloat) duration {
    
    [view makeToast:NSLocalizedString(key, nil)
           duration: duration
           position:@"top"
     ];
}

+ (CGSize)threadSafeSizeString: (NSString *) string WithFont:(UIFont *)font constrainedToSize:(CGSize)size {
    // http://stackoverflow.com/questions/12744558/uistringdrawing-methods-dont-seem-to-be-thread-safe-in-ios-6
    NSAttributedString *attributedText =
    [[NSAttributedString alloc]
     initWithString:string
     attributes:@
     {
     NSFontAttributeName: font
     }];
    CGRect rect = [attributedText boundingRectWithSize:size
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                               context:nil];
    return rect.size;
}

+(id) createProgressView: (UIView * )view {
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    indicator.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
    indicator.center = view.center;
    [view addSubview:indicator];
    [indicator bringSubviewToFront:view];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = TRUE;
    return indicator;
}

+ (void)setNavBarAttributes:(UINavigationBar*)bar {
    if ([bar respondsToSelector:@selector(setBarTintColor:)]) {
        [bar setBarTintColor: [UIColor colorWithRed:22/255.0f green:22/255.0f blue:22/255.0f alpha:1.0f]];
        
        
        bar.translucent = NO;
    }else {
        bar.tintColor = [UIColor colorWithRed:22/255.0f green:22/255.0f blue:22/255.0f alpha:1.0f];
        bar.opaque = YES;

    }
    [bar setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys: [UIColor lightGrayColor],  UITextAttributeTextColor,nil]];
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
}
@end
