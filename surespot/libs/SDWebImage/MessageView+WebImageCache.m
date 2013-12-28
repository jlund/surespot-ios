/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MessageView+WebImageCache.h"
#import "objc/runtime.h"
#import "MessageView.h"
#import "SurespotConstants.h"

static char operationKey;
static char operationArrayKey;

@implementation MessageView (WebCache)



- (void)setMessage:(SurespotMessage *) message
          progress:(SDWebImageDownloaderProgressBlock)progressBlock completed:(SDWebImageCompletedBlock)completedBlock
{
    [self cancelCurrentImageLoad];
    
    //    self.uiImageView.image = placeholder;
    
    NSURL * url = [NSURL URLWithString:message.data];
    
    if (url)
    {
        __weak MessageView *wself = self;
        id<SDWebImageOperation> operation = [SDWebImageManager.sharedManager downloadWithURL: url
                                                                                    mimeType: [message mimeType]
                                                                                  ourVersion: [message getOurVersion]
                                                                               theirUsername: [message getOtherUser]
                                                                                theirVersion: [message getTheirVersion]
                                                                                          iv: [message iv]
                                             
                                                                                     options: 0
                                                                                    progress:progressBlock completed:^(id image, NSString * mimeType, NSError *error, SDImageCacheType cacheType, BOOL finished)
                                             {
                                                 if (!wself) return;
                                                 dispatch_main_async_safe(^
                                                                          {
                                                                              if (!wself) return;
                                                                              if (image)
                                                                              {
                                                                                  if ([mimeType isEqualToString:MIME_TYPE_IMAGE]) {
                                                                                      wself.uiImageView.image = image;
                                                                                  }
                                                                                  else {
                                                                                      wself.messageStatusLabel.text = @"audio";
                                                                                  }
                                                                                  if (message.formattedDate) {
                                                                                      wself.messageStatusLabel.text = message.formattedDate;
                                                                                  }
                                                                                  
                                                                              }
                                                                              else {
                                                                                  wself.messageStatusLabel.text = NSLocalizedString(@"message_error_generic", nil);
                                                                                  
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
