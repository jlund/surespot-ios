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

@end
