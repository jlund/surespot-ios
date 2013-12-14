//
//  SDWebImageCompat.m
//  SDWebImage
//
//  Created by Olivier Poitrey on 11/12/12.
//  Copyright (c) 2012 Dailymotion. All rights reserved.
//

#import "SDWebImageCompat.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


#if !__has_feature(objc_arc)
#error SDWebImage is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

inline UIImage *SDScaledImageForKey(NSString *key, UIImage *image)
{
    if ([image.images count] > 0)
    {
        NSMutableArray *scaledImages = [NSMutableArray array];
        
        for (UIImage *tempImage in image.images)
        {
            [scaledImages addObject:SDScaledImageForKey(key, tempImage)];
        }
        
        return [UIImage animatedImageWithImages:scaledImages duration:image.duration];
    }
    else
    {
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
        {
            CGFloat scale = 1.0;
            //            if (key.length >= 8)
            //            {
            //                // Search @2x. at the end of the string, before a 3 to 4 extension length (only if key len is 8 or more @2x. + 4 len ext)
            //                NSRange range = [key rangeOfString:@"@2x." options:0 range:NSMakeRange(key.length - 8, 5)];
            //                if (range.location != NSNotFound)
            //                {
            //                    scale = 2.0;
            //                }
            //            }
            
            //scale to 200px tall
            scale = image.size.height/200;
            
            UIImage *scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
            
            
            NSLog(@"scale %f, orig image height: %f, scaled image height: %f", scale, image.size.height, scaledImage.size.height);
            image = scaledImage;
        }
        return image;
    }
}
