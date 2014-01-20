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
#import "UIUtils.h"
#import "DDLog.h"


#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

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
                                                                                     options: SDWebImageRetryFailed
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
                                                                                      
                                                                                      
                                                                                      if ([image size].height > [image size].width) {
                                                                                          [wself.uiImageView setContentMode:UIViewContentModeScaleAspectFit];
                                                                                      }
                                                                                      else {
                                                                                          [wself.uiImageView setContentMode:UIViewContentModeScaleAspectFill];
                                                                                      }
//                                                                                      
//                                                                                      CGSize scaledSize = [UIUtils imageSizeAfterAspectFit:wself.uiImageView];
//                                                                                      
//                                                                                      DDLogInfo(@"image size: %fx%f", scaledSize.width, scaledSize.height);
//                                                                                      
//                                                                                      if ((message.rowLandscapeHeight == [UIUtils getDefaultImageMessageHeight] || message.rowPortraitHeight == [UIUtils getDefaultImageMessageHeight]) && scaledSize.height < [UIUtils getDefaultImageMessageHeight]) {
//                                                                                          DDLogInfo(@"setting row height to %f", scaledSize.height);
//                                                                                          message.rowPortraitHeight = scaledSize.height;
//                                                                                          message.rowLandscapeHeight = scaledSize.height;
//                                                                                          //tell table to reload itself
//                                                                                          NSMutableDictionary * dict = [NSMutableDictionary new];
//                                                                                          [dict setObject:[message getOtherUser] forKey:@"username"];
//                                                                                          [dict setObject:[NSNumber numberWithBool:NO] forKey: @"scroll" ] ;
//                                                                                          
//                                                                                          //dunno why the fuck this doesn't work
//                                                                                          //NSDictionary * dict =    [NSDictionary dictionaryWithObjectsAndKeys[:message getOtherUser], @"username", nil];
//                                                                                          //
//                                                                                          [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshMessages"
//                                                                                                                                              object:dict];
//                                                                                          
//                                                                                          
//                                                                                          
//                                                                                      }
                                                                                  }
                                                                                  if (message.formattedDate) {
                                                                                      wself.messageStatusLabel.text = message.formattedDate;
                                                                                  }
                                                                              }
                                                                              else {
                                                                                  wself.messageStatusLabel.text = NSLocalizedString(@"error_downloading_message_data", nil);
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
