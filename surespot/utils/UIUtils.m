//
//  UIUtils.m
//  surespot
//
//  Created by Adam on 11/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "UIUtils.h"
#import "Toast+UIView.h"
#import "ChatUtils.h"

@implementation UIUtils

+(UIColor *) surespotBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:1.0];
}

+(UIColor *) surespotTransparentBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:0.5];
}

+(UIColor *) surespotGrey {
    return [UIColor colorWithRed:22/255.0f green:22/255.0f blue:22/255.0f alpha:1.0f];
}

+(UIColor *) surespotTransparentGrey {
    return [UIColor colorWithRed:22/255.0f green:22/255.0f blue:22/255.0f alpha:0.5f];
}



+(void) showToastMessage: (NSString *) message duration: (CGFloat) duration {
    
    [[[UIApplication sharedApplication] keyWindow]  makeToast:message
                                                     duration: duration
                                                     position:@"center"
     ];
}

+(void) showToastKey: (NSString *) key {
    [self showToastKey:key duration:1.0];
}
+(void) showToastKey: (NSString *) key duration: (CGFloat) duration {
    
    [[[UIApplication sharedApplication] keyWindow]  makeToast:NSLocalizedString(key, nil)
                                                     duration: duration
                                                     position:@"center"
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

+ (void)setAppAppearances {
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1) {
        [[UINavigationBar appearance] setBarTintColor: [self surespotGrey]];
    }
    else {
        [[UINavigationBar appearance] setTintColor: [self surespotGrey]];
        //  [[UINavigationBar appearance] setOpaque:YES];
    }
    
    [[UIBarButtonItem appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys: [self surespotBlue],  UITextAttributeTextColor,nil] forState:UIControlStateNormal];
    
    [[UIButton appearance] setTitleColor:[self surespotBlue] forState:UIControlStateNormal];
    
    
    [[UINavigationBar appearance] setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys: [UIColor lightGrayColor],  UITextAttributeTextColor,nil]];
    [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    
    
}

+(BOOL)stringIsNilOrEmpty:(NSString*)aString {
    return !(aString && aString.length);
}

+(CGFloat) keyboardHeightAdjustedForOrientation: (CGSize) size {
    UIInterfaceOrientation  orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
        return size.width;
    }
    else {
        return size.height;
    }
}

+(void) setMessageHeights: (SurespotMessage *)  message size: (CGSize) size {
    NSString * plaintext = message.plainData;
    
    //figure out message height for both orientations
    if (plaintext){
        
        //BOOL ours = [ChatUtils isOurMessage:message];
        
        UIFont *cellFont = [UIFont fontWithName:@"Helvetica" size:17.0];
        CGSize constraintSize = CGSizeMake(size.width -70, MAXFLOAT);
        
        //http://stackoverflow.com/questions/12744558/uistringdrawing-methods-dont-seem-to-be-thread-safe-in-ios-6
        CGSize labelSize =       [self threadSafeSizeString:plaintext WithFont:cellFont constrainedToSize:constraintSize];
        [message setRowPortraitHeight:(int) (labelSize.height + 20 > 44 ? labelSize.height + 20 : 44) ];
        
        constraintSize = CGSizeMake(size.height - 70 , MAXFLOAT);
        
        labelSize =      [UIUtils threadSafeSizeString:plaintext WithFont:cellFont constrainedToSize:constraintSize];
        [message setRowLandscapeHeight:(int) (labelSize.height + 20 > 44 ? labelSize.height + 20 : 44) ];
    }
}


+(void) startSpinAnimation: (UIView *) view {
    CABasicAnimation *rotation;
    rotation = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    rotation.fromValue = [NSNumber numberWithFloat:0];
    rotation.toValue = [NSNumber numberWithFloat:(2*M_PI)];
    rotation.duration = 1.1; // Speed
    rotation.repeatCount = HUGE_VALF; //
    [view.layer addAnimation:rotation forKey:@"spin"];
}

+(void) stopSpinAnimation: (UIView *) view {
    [view.layer removeAnimationForKey:@"spin"];
}

+(void) startPulseAnimation: (UIView *) view {
    CABasicAnimation *theAnimation;
    
    theAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
    theAnimation.duration=1.0;
    theAnimation.repeatCount=HUGE_VALF;
    theAnimation.autoreverses=YES;
    theAnimation.fromValue=[NSNumber numberWithFloat:1.0];
    theAnimation.toValue=[NSNumber numberWithFloat:0.5];
    [view.layer addAnimation:theAnimation forKey:@"pulse"];
}

+(void) stopPulseAnimation: (UIView *) view {
    [view.layer removeAnimationForKey:@"pulse"];
}

@end
