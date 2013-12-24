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
#import "DDLog.h"
#import "SurespotConstants.h"
#import "SurespotAppDelegate.h"
#import "QREncoder.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif



@implementation UIUtils

+(UIColor *) surespotBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:1.0];
}

+(UIColor *) surespotSelectionBlue {
    return [UIColor colorWithRed:0.2 green:0.71 blue:0.898 alpha:0.9];
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
    
    [((SurespotAppDelegate *)[[UIApplication sharedApplication] delegate]).overlayView  makeToast:message
                                                                                         duration: duration
                                                                                         position:@"center"
     ];
}

+(void) showToastKey: (NSString *) key {
    [self showToastKey:key duration:1.0];
}
+(void) showToastKey: (NSString *) key duration: (CGFloat) duration {
    
    [((SurespotAppDelegate *)[[UIApplication sharedApplication] delegate]).overlayView  makeToast:NSLocalizedString(key, nil)
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

+(CGSize) screenSizeAdjustedForOrientation {
    CGSize size = [UIScreen mainScreen].bounds.size;
    UIInterfaceOrientation  orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
        return CGSizeMake(size.height, size.width);
    }
    else {
        return CGSizeMake(size.width, size.height);
        
    }
}


+(CGSize) sizeAdjustedForOrientation: (CGSize) size {
    UIInterfaceOrientation  orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
        return CGSizeMake(size.height, size.width);
    }
    else {
        return CGSizeMake(size.width, size.height);
        
    }
}

+(void) setTextMessageHeights: (SurespotMessage *)  message size: (CGSize) size {
    NSString * plaintext = message.plainData;
    
    //figure out message height for both orientations
    if (plaintext){
        NSInteger offset = 0;
        NSInteger heightAdj = 25;
        BOOL ours = [ChatUtils isOurMessage:message];
        if (ours) {
            offset = 40;
        }
        else {
            offset = 90;
        }
        //http://stackoverflow.com/questions/12744558/uistringdrawing-methods-dont-seem-to-be-thread-safe-in-ios-6
        
        UIFont *cellFont = [UIFont fontWithName:@"Helvetica" size:17.0];
        CGSize constraintSize = CGSizeMake(size.width - offset, MAXFLOAT);
        DDLogVerbose(@"computing size for message: %@", plaintext);
        
        CGSize labelSize = [self threadSafeSizeString:plaintext WithFont:cellFont constrainedToSize:constraintSize];
        
        DDLogVerbose(@"computed portrait width %f, height: %f", labelSize.width, labelSize.height);
        
        [message setRowPortraitHeight:(int) (labelSize.height + heightAdj > 44 ? labelSize.height + heightAdj : 44) ];
        
        constraintSize = CGSizeMake( size.height - offset , MAXFLOAT);
        
        labelSize = [UIUtils threadSafeSizeString:plaintext WithFont:cellFont constrainedToSize:constraintSize];
        
        DDLogVerbose(@"computed landscape width %f, height: %f", labelSize.width, labelSize.height);
        [message setRowLandscapeHeight:(int) (labelSize.height + heightAdj > 44 ? labelSize.height + heightAdj: 44) ];
        
        DDLogVerbose(@"computed row height portrait %d landscape %d", message.rowPortraitHeight, message.rowLandscapeHeight);
    }
}

+(void) setImageMessageHeights: (SurespotMessage *)  message size: (CGSize) size {
    
    
    //figure out message height for both orientations
    
    NSInteger offset = 0;
    NSInteger heightAdj = 25;
    BOOL ours = [ChatUtils isOurMessage:message];
    if (ours) {
        offset = 40;
    }
    else {
        offset = 90;
    }
    
    [message setRowPortraitHeight: 224];// (int) (labelSize.height + heightAdj > 44 ? labelSize.height + heightAdj : 44) ];
    [message setRowLandscapeHeight: 224];//(int) (labelSize.height + heightAdj > 44 ? labelSize.height + heightAdj: 44) ];
    
    DDLogInfo(@"setting image row height portrait %d landscape %d", message.rowPortraitHeight, message.rowLandscapeHeight);
    
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
    theAnimation.toValue=[NSNumber numberWithFloat:0.33];
    [view.layer addAnimation:theAnimation forKey:@"pulse"];
}

+(void) stopPulseAnimation: (UIView *) view {
    [view.layer removeAnimationForKey:@"pulse"];
}

+(NSString *) getMessageErrorText: (NSInteger) errorStatus mimeType: (NSString *) mimeType {
    NSString * statusText = nil;
    switch (errorStatus) {
		case 400:
			statusText = NSLocalizedString(@"message_error_invalid",nil);
			break;
		case 402:
			// if it's voice message they need to have upgraded, otherwise fall through to 403
			//if (message.getMimeType().equals(SurespotConstants.MimeTypes.M4A)) {
			//	statusText = context.getString(R.string.billing_payment_required_voice);
			//	break;
			//}
		case 403:
			statusText =  NSLocalizedString(@"message_error_unauthorized",nil);
			break;
		case 404:
			statusText =  NSLocalizedString(@"message_error_unauthorized",nil);
			break;
		case 429:
			statusText =  NSLocalizedString(@"error_message_throttled",nil);
			break;
		case 500:
        default:
			if ([mimeType isEqualToString:MIME_TYPE_TEXT]) {
                statusText =  NSLocalizedString(@"error_message_generic",nil);
            }
            else {
                if([mimeType isEqualToString:MIME_TYPE_IMAGE] || [mimeType isEqualToString:MIME_TYPE_M4A]) {
                    statusText = NSLocalizedString(@"error_message_resend",nil);
                }
            }
            
			break;
    }
    
    return statusText;
}


+(REMenu *) createMenu: (NSArray *) menuItems closeCompletionHandler: (void (^)(void))completionHandler {
    REMenu * menu = [[REMenu alloc] initWithItems:menuItems];
    menu.itemHeight = 40;
    menu.backgroundColor = [UIUtils surespotGrey];
    menu.imageOffset = CGSizeMake(10, 0);
    menu.textAlignment = NSTextAlignmentLeft;
    menu.textColor = [UIColor whiteColor];
    menu.highlightedTextColor = [UIColor whiteColor];
    menu.highlightedBackgroundColor = [UIUtils surespotTransparentBlue];
    menu.textShadowOffset = CGSizeZero;
    menu.highlightedTextShadowOffset = CGSizeZero;
    menu.textOffset =CGSizeMake(64,0);
    menu.font = [UIFont systemFontOfSize:18.0];
    menu.cornerRadius = 4;
    menu.bounce = NO;
    [menu setCloseCompletionHandler:completionHandler];
    return menu;
}


+(void) showQRInvite: (NSString *) username {
    UIView * parentView = ((SurespotAppDelegate *)[[UIApplication sharedApplication] delegate]).overlayView;
    //the qrcode is square. now we make it 250 pixels wide
    int qrcodeImageDimension = 250;
    
    //the string can be very long
    NSString* aVeryLongURL = @"http://thelongestlistofthelongeststuffatthelongestdomainnameatlonglast.com/";
    
    //first encode the string into a matrix of bools, TRUE for black dot and FALSE for white. Let the encoder decide the error correction level and version
    DataMatrix* qrMatrix = [QREncoder encodeWithECLevel:QR_ECLEVEL_AUTO version:QR_VERSION_AUTO string:aVeryLongURL];
    
    //then render the matrix
    UIImage* qrcodeImage = [QREncoder renderDataMatrix:qrMatrix imageDimension:qrcodeImageDimension];
    
    //put the image into the view
    UIImageView* qrcodeImageView = [[UIImageView alloc] initWithImage:qrcodeImage];
    CGRect parentFrame = parentView.frame;
//    CGRect tabBarFrame = self.tabBarController.tabBar.frame;
    
    //center the image
    CGFloat x = (parentFrame.size.width - qrcodeImageDimension) / 2.0;
    CGFloat y = (parentFrame.size.height - qrcodeImageDimension) / 2.0;
    CGRect qrcodeImageViewFrame = CGRectMake(x, y, qrcodeImageDimension, qrcodeImageDimension);
    [qrcodeImageView setFrame:qrcodeImageViewFrame];
    
    //and that's it!
    [parentView addSubview:qrcodeImageView];
//    [qrcodeImageView release];
    
//    [((SurespotAppDelegate *)[[UIApplication sharedApplication] delegate]).overlayView  makeToast:message
//                                                                                         duration: duration
//                                                                                         position:@"center"
//     ];
}

@end
