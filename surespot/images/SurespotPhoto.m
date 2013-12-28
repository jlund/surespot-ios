//
//  SurespotPhoto.m
//  surespot
//
//  Created by Adam on 12/14/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotPhoto.h"
#import "SDWebImageDecoder.h"
#import "SDWebImageManager.h"
#import "MWPhotoProtocol.h"
#import "DDLog.h"
#import "SurespotConstants.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

// Private
@interface SurespotPhoto () {
    
    BOOL _loadingInProgress;
    
}

// Properties
@property (nonatomic, strong) UIImage *underlyingImage; // holds the decompressed image

// Methods
- (void)decompressImageAndFinishLoading;
- (void)imageLoadingComplete;

@end

@implementation SurespotPhoto
    

- (id)initWithURL:(NSURL *)url encryptionParams: (EncryptionParams *) params {
    if ((self = [super init])) {
        _photoURL = [url copy];
        _encryptionParams = params;
    }
    return self;
}

#pragma mark MWPhoto Protocol Methods

- (UIImage *)underlyingImage {
    return _underlyingImage;
}

- (void)loadUnderlyingImageAndNotify {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    if (_loadingInProgress) return;
    _loadingInProgress = YES;
    @try {
        if (self.underlyingImage) {
            
            // Image already loaded
            [self imageLoadingComplete];
            
        } else {
            
            // Get underlying image
            if (_image) {
                
                // We have UIImage so decompress
                self.underlyingImage = _image;
                [self decompressImageAndFinishLoading];
                
            } else if (_photoURL) {
                
                // Check what type of url it is
//                if ([[[_photoURL scheme] lowercaseString] isEqualToString:@"assets-library"]) {
//                    
//                    // Load from asset library async
//                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                        @autoreleasepool {
//                            @try {
//                                ALAssetsLibrary *assetslibrary = [[ALAssetsLibrary alloc] init];
//                                [assetslibrary assetForURL:_photoURL
//                                               resultBlock:^(ALAsset *asset){
//                                                   ALAssetRepresentation *rep = [asset defaultRepresentation];
//                                                   CGImageRef iref = [rep fullScreenImage];
//                                                   if (iref) {
//                                                       self.underlyingImage = [UIImage imageWithCGImage:iref];
//                                                   }
//                                                   [self performSelectorOnMainThread:@selector(decompressImageAndFinishLoading) withObject:nil waitUntilDone:NO];
//                                               }
//                                              failureBlock:^(NSError *error) {
//                                                  self.underlyingImage = nil;
//                                                  MWLog(@"Photo from asset library error: %@",error);
//                                                  [self performSelectorOnMainThread:@selector(decompressImageAndFinishLoading) withObject:nil waitUntilDone:NO];
//                                              }];
//                            } @catch (NSException *e) {
//                                MWLog(@"Photo from asset library error: %@", e);
//                                [self performSelectorOnMainThread:@selector(decompressImageAndFinishLoading) withObject:nil waitUntilDone:NO];
//                            }
//                        }
//                    });
//                    
//                } else
                    if ([_photoURL isFileReferenceURL]) {
                    
                    // Load from local file async
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        @autoreleasepool {
                            @try {
                                self.underlyingImage = [UIImage imageWithContentsOfFile:_photoURL.path];
                                if (!_underlyingImage) {
                                    DDLogVerbose(@"Error loading photo from path: %@", _photoURL.path);
                                }
                            } @finally {
                                [self performSelectorOnMainThread:@selector(decompressImageAndFinishLoading) withObject:nil waitUntilDone:NO];
                            }
                        }
                    });
                    
                } else {
                    
                    // Load async from web (using SDWebImage)
                    @try {
                        SDWebImageManager *manager = [SDWebImageManager sharedManager];
                        [manager downloadWithURL:_photoURL mimeType: MIME_TYPE_IMAGE  ourVersion:_encryptionParams.ourVersion theirUsername:_encryptionParams.theirUsername theirVersion:_encryptionParams.theirVersion iv:_encryptionParams.iv
                                         options:0
                                        progress:^(NSUInteger receivedSize, long long expectedSize) {
                                            float progress = receivedSize / (float)expectedSize;
                                            NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                  [NSNumber numberWithFloat:progress], @"progress",
                                                                  self, @"photo", nil];
                                            [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_PROGRESS_NOTIFICATION object:dict];
                                        }
                                       completed:^(id image,NSString * mimeType, NSError *error, SDImageCacheType cacheType, BOOL finished) {
                                           if (error) {
                                               DDLogVerbose(@"SDWebImage failed to download image: %@", error);
                                           }
                                           self.underlyingImage = image;
                                           [self decompressImageAndFinishLoading];
                                       }];
                    } @catch (NSException *e) {
                        DDLogVerbose(@"Photo from web: %@", e);
                        [self decompressImageAndFinishLoading];
                    }
                    
                }
                
            } else {
                
                // Failed - no source
                @throw [NSException exceptionWithName:nil reason:nil userInfo:nil];
                
            }
        }
    }
    @catch (NSException *exception) {
        self.underlyingImage = nil;
        _loadingInProgress = NO;
        [self imageLoadingComplete];
    }
    @finally {
        
    }
}

// Release if we can get it again from path or url
- (void)unloadUnderlyingImage {
    _loadingInProgress = NO;
    if (self.underlyingImage) {
        self.underlyingImage = nil;
    }
}

- (void)decompressImageAndFinishLoading {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    if (self.underlyingImage) {
        // Decode image async to avoid lagging when UIKit lazy loads
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.underlyingImage = [UIImage decodedImageWithImage:self.underlyingImage];
            dispatch_async(dispatch_get_main_queue(), ^{
                // Finish on main thread
                [self imageLoadingComplete];
            });
        });
    } else {
        // Failed
        [self imageLoadingComplete];
    }
}

- (void)imageLoadingComplete {
    NSAssert([[NSThread currentThread] isMainThread], @"This method must be called on the main thread.");
    // Complete so notify
    _loadingInProgress = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:MWPHOTO_LOADING_DID_END_NOTIFICATION
                                                        object:self];
}
@end
