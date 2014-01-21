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

static const NSInteger retryAttempts = 5;

@implementation MessageView (WebCache)



- (void)setMessage:(SurespotMessage *) message
          progress:(SDWebImageDownloaderProgressBlock)progressBlock
         completed:(SDWebImageCompletedBlock)completedBlock
      retryAttempt:(NSInteger) retryAttempt
{
    NSURL * url = [NSURL URLWithString:message.data];
    
    if (url)
    {
        __weak MessageView *wself = self;
        [SDWebImageManager.sharedManager downloadWithURL: url
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
                                          
                                          //do nothing if the message has changed
                                          if (![wself.message isEqual:message]) {
                                              DDLogInfo(@"cell is pointing to a different message now, not assigning data");
                                              return;
                                          }
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
                                              }
                                              if (message.formattedDate) {
                                                  wself.messageStatusLabel.text = message.formattedDate;
                                              }
                                          }
                                          else {
                                              //retry
                                              if (retryAttempt < retryAttempts) {
                                                  DDLogInfo(@"no data downloaded, retrying attempt: %d", retryAttempt+1);
                                                  [self setMessage:message progress:progressBlock completed:completedBlock retryAttempt:retryAttempt+1];
                                                  return;
                                              }
                                              else {
                                                  wself.messageStatusLabel.text = NSLocalizedString(@"error_downloading_message_data", nil);
                                              }
                                          }
                                          
                                          [wself setNeedsLayout];
                                          if (completedBlock && finished)
                                          {
                                              completedBlock(image, mimeType, error, cacheType);
                                          }
                                      });
         }];
    }
}

@end
