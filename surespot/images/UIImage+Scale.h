//
//  UIImage+Scale.h
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIImage (Scale)
- (UIImage *)imageScaledToSize:(CGSize)size;
- (UIImage *)imageScaledToMaxWidth:(CGFloat)width maxHeight:(CGFloat)height;
- (UIImage *)imageScaledToMinDimension:(CGFloat)length;
@end
