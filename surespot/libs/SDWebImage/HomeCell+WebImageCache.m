/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "HomeCell+WebImageCache.h"
#import "objc/runtime.h"
#import "HomeCell.h"
#import "EncryptionParams.h"

static char operationKey;
static char operationArrayKey;

@implementation HomeCell (WebCache)



- (void)setImageUrl: (NSString *) url withEncryptionParams: (EncryptionParams *) encryptionParams
   placeholderImage:(UIImage *)placeholder
           progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletedBlock)completedBlock
{
    [self cancelCurrentImageLoad];
    
    self.friendImage.image = placeholder;
    
    NSURL * nsurl = [NSURL URLWithString:url];
    
    if (url)
    {
        __weak HomeCell *wself = self;
        id<SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadWithURL: nsurl
                                                                                  ourVersion:encryptionParams.ourVersion
                                                                               theirUsername:encryptionParams.ourUsername
                                                                                theirVersion:encryptionParams.ourVersion
                                                                                          iv:encryptionParams.iv
                                                                                     options: 0
                                                                                    progress:progressBlock completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished)
                                             {
                                                 if (!wself) return;
                                                 dispatch_main_sync_safe(^
                                                                         {
                                                                             if (!wself) return;
                                                                             if (image)
                                                                             {
                                                                                 wself.friendImage.image = image;
                                                                                 [wself.friendImage setAlpha:1];
                                                                                 
                                                                             }
                                                                             
                                                                             [wself setNeedsLayout];
                                                                             if (completedBlock && finished)
                                                                             {
                                                                                 completedBlock(image, error, cacheType);
                                                                             }
                                                                         });
                                             }];
        objc_setAssociatedObject(self, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

//- (void)setAnimationImagesWithURLs:(NSArray *)arrayOfURLs
//{
//    [self cancelCurrentArrayLoad];
//    __weak UIImageView *wself = self;
//
//    NSMutableArray *operationsArray = [[NSMutableArray alloc] init];
//
//    for (NSURL *logoImageURL in arrayOfURLs)
//    {
//        id<SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadWithURL:logoImageURL options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished)
//        {
//            if (!wself) return;
//            dispatch_main_sync_safe(^
//            {
//                __strong UIImageView *sself = wself;
//                [sself stopAnimating];
//                if (sself && image)
//                {
//                    NSMutableArray *currentImages = [[sself animationImages] mutableCopy];
//                    if (!currentImages)
//                    {
//                        currentImages = [[NSMutableArray alloc] init];
//                    }
//                    [currentImages addObject:image];
//
//                    sself.animationImages = currentImages;
//                    [sself setNeedsLayout];
//                }
//                [sself startAnimating];
//            });
//        }];
//        [operationsArray addObject:operation];
//    }
//
//    objc_setAssociatedObject(self, &operationArrayKey, [NSArray arrayWithArray:operationsArray], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
//}

- (void)cancelCurrentImageLoad
{
    // Cancel in progress downloader from queue
    id<SDWebImageOperation> operation = objc_getAssociatedObject(self, &operationKey);
    if (operation)
    {
        [operation cancel];
        objc_setAssociatedObject(self, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)cancelCurrentArrayLoad
{
    // Cancel in progress downloader from queue
    NSArray *operations = objc_getAssociatedObject(self, &operationArrayKey);
    for (id<SDWebImageOperation> operation in operations)
    {
        if (operation)
        {
            [operation cancel];
        }
    }
    objc_setAssociatedObject(self, &operationArrayKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
