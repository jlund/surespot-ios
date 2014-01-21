/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCompat.h"
#import "SDWebImageManager.h"
#import "HomeCell.h"
#import "EncryptionParams.h"
#import "Friend.h"

@interface HomeCell (WebCache)

- (void)setImageForFriend: (Friend *) afriend
     withEncryptionParams: (EncryptionParams *) encryptionParams
         placeholderImage:(UIImage *)placeholder
                 progress:(SDWebImageDownloaderProgressBlock)progressBlock
                completed:(SDWebImageCompletedBlock)completedBlock
             retryAttempt:(NSInteger) retryAttempt;



@end
