#import "SDWebImageCompat.h"
#import "SDWebImageManager.h"
#import "MessageView.h"
#import "SurespotMessage.h"

@interface MessageView (WebCache)

- (void)setMessage:(SurespotMessage *) message
          progress:(SDWebImageDownloaderProgressBlock)progressBlock
         completed:(SDWebImageCompletedBlock)completedBlock
      retryAttempt:(NSInteger) retryAttempt;

@end
