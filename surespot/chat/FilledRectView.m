//
//  MessageStatusView.m
//  surespot
//
//  Created by Adam on 11/26/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "FilledRectView.h"

@implementation FilledRectView
- (void)setForegroundColor:(UIColor *)foregroundColor
{
    _foregroundColor = foregroundColor;
    [self setNeedsDisplay]; // This is need so that drawRect: is called
}

-(void) drawRect:(CGRect)rect {
    CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext(), _foregroundColor.CGColor);
    CGContextFillRect (UIGraphicsGetCurrentContext(),  self.bounds);

}
@end
