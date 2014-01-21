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
#import "SurespotConstants.h"
#import "DDLog.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


static char operationKey;
static char operationArrayKey;

static NSInteger const retryAttempts = 5;

@implementation HomeCell (WebCache)



- (void)setImageForFriend: (Friend *) afriend
     withEncryptionParams: (EncryptionParams *) encryptionParams
         placeholderImage:(UIImage *)placeholder
                 progress:(SDWebImageDownloaderProgressBlock)progressBlock
                completed:(SDWebImageCompletedBlock)completedBlock
             retryAttempt: (NSInteger) retryAttempt
{
   // [self cancelCurrentImageLoad];
    
    self.friendImage.image = placeholder;
    [self.friendImage setAlpha:0.5];
    
    
    
    
    if (afriend.imageUrl)
    {
        NSURL * nsurl = [NSURL URLWithString:afriend.imageUrl];
        __weak HomeCell *wself = self;
        id<SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadWithURL: nsurl
                                                                                    mimeType: MIME_TYPE_IMAGE
                                                                                  ourVersion:encryptionParams.ourVersion
                                                                               theirUsername:encryptionParams.ourUsername
                                                                                theirVersion:encryptionParams.ourVersion
                                                                                          iv:encryptionParams.iv
                                                                                     options: SDWebImageRetryFailed
                                                                                    progress:progressBlock completed:^(id image, NSString * mimeType,  NSError *error, SDImageCacheType cacheType, BOOL finished)
                                             {
                                                 if (!wself) return;
                                                 dispatch_main_async_safe(^
                                                                          {
                                                                              if (!wself) return;
                                                                              
                                                                              DDLogInfo(@"initial friend: %@, current friend: %@", afriend.name, wself.friendName);
                                                                              //cell is not pointing to the same user
                                                                              if (![wself.friendName isEqualToString:afriend.name]) return;
                                                                              if (image)
                                                                              {
                                                                                  wself.friendImage.image = image;
                                                                                  [wself.friendImage setAlpha:1];
                                                                                  
                                                                              }
                                                                              else {
                                                                                  //retry
                                                                                  if (retryAttempt < retryAttempts) {
                                                                                      DDLogInfo(@"no friend image data downloaded, retrying attempt: %d", retryAttempt+1);
                                                                                      [self setImageForFriend:afriend withEncryptionParams:encryptionParams placeholderImage:placeholder progress:progressBlock completed:completedBlock retryAttempt:retryAttempt+1];
                                                                                      return;
                                                                                  }
                                                                              }
                                                                              
                                                                              [wself setNeedsLayout];
                                                                              if (completedBlock && finished)
                                                                              {
                                                                                  completedBlock(image, mimeType, error, cacheType);
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
