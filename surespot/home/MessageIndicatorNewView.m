//
//  NewMessageIndicatorView.m
//  surespot
//
//  Created by Adam on 11/21/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "MessageIndicatorNewView.h"
#import "UIUtils.h"

@implementation MessageIndicatorNewView
- (void)drawRect:(CGRect)rect
{
    CGRect borderRect = CGRectMake(0.0, 0.0, 25.0, 25.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, (UIUtils.surespotBlue.CGColor));
    CGContextFillEllipseInRect (context, borderRect);
}
@end
