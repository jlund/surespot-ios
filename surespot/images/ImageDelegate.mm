//
//  ImageDelegate.m
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "ImageDelegate.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "UIImage+Scale.h"
#import "EncryptionController.h"
#import "NetworkController.h"
#import "SurespotConstants.h"
#import "IdentityController.h"
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import "SwipeViewController.h"
#import "SurespotMessage.h"
#import "FileController.h"
#import "ChatController.h"
#import "NSData+Base64.h"
#import "SDWebImageManager.h"
#import "DDLog.h"
#import "UIUtils.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

@interface ImageDelegate()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * theirUsername;
@property (nonatomic, strong) NSString * ourVersion;
@property (nonatomic, assign) BOOL sourceIsCamera;
@property (nonatomic, weak) ALAssetsLibrary * assetsLibrary;
@end


@implementation ImageDelegate


- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion
          theirUsername:(NSString *) theirUsername
           assetLibrary: (ALAssetsLibrary *) library
         sourceIsCamera: (BOOL) sourceIsCamera;

{
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    _username = username;
    _ourVersion = ourVersion;
    _theirUsername = theirUsername;
    _assetsLibrary = library;
    _sourceIsCamera = sourceIsCamera;
    
    
    return self;
}



// For responding to the user tapping Cancel.
- (void) imagePickerControllerDidCancel: (UIImagePickerController *) picker {
    
    [[picker parentViewController] dismissViewControllerAnimated: YES completion:nil];
}

// For responding to the user accepting a newly-captured picture or movie
- (void) imagePickerController: (UIImagePickerController *) picker
 didFinishPickingMediaWithInfo: (NSDictionary *) info {
    
    [[picker presentingViewController] dismissViewControllerAnimated: YES completion:nil];
    
    
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    UIImage *originalImage, *editedImage, *imageToSave;
    
    // Handle a still image capture
    if (CFStringCompare ((CFStringRef) mediaType, kUTTypeImage, 0)
        == kCFCompareEqualTo) {
        
        editedImage = (UIImage *) [info objectForKey:
                                   UIImagePickerControllerEditedImage];
        originalImage = (UIImage *) [info objectForKey:
                                     UIImagePickerControllerOriginalImage];
        
        if (editedImage) {
            imageToSave = editedImage;
        } else {
            imageToSave = originalImage;
        }
        
        
        // Save the new image (original or edited) to the Camera Roll if we took it with the camera
        if (_sourceIsCamera) {
            
            [_assetsLibrary saveImage:imageToSave toAlbum:@"surespot" withCompletionBlock:^(NSError *error, NSURL * url) {
                _assetsLibrary = nil;
                if (error) {
                    
                    return;
                    
                }
                
                [self uploadImage:imageToSave];
                
            }];
        }
        
        else {
            _assetsLibrary = nil;
            [self uploadImage:imageToSave];
        }
        
        
    }
}

-(void) uploadImage: (UIImage *) image {
    if (!image) return;
    
    [[IdentityController sharedInstance] getTheirLatestVersionForUsername:_theirUsername callback:^(NSString *version) {
        if (version) {
            //compress encrypt and upload the image
            UIImage * scaledImage = [image imageScaledToMaxWidth:400 maxHeight:400];
            NSData * imageData = UIImageJPEGRepresentation(scaledImage, 0.5);
            NSData * iv = [EncryptionController getIv];
            
            //encrypt
            [EncryptionController symmetricEncryptData:imageData
                                            ourVersion:_ourVersion
                                         theirUsername:_theirUsername
                                          theirVersion:version
                                                    iv:iv
                                              callback:^(NSData * encryptedImageData) {
                                                  if (encryptedImageData) {
                                                      //create message
                                                      SurespotMessage * message = [SurespotMessage new];
                                                      message.from = _username;
                                                      message.fromVersion = _ourVersion;
                                                      message.to = _theirUsername;
                                                      message.toVersion = version;
                                                      message.mimeType = MIME_TYPE_IMAGE;
                                                      message.iv = [iv base64EncodedStringWithSeparateLines:NO];
                                                      NSString * key = [@"imageKey_" stringByAppendingString: message.iv];
                                                      message.data = key;
                                                      
                                                      DDLogInfo(@"adding local image to cache %@", key);
                                                      [[[SDWebImageManager sharedManager] imageCache] storeImage:scaledImage imageData:encryptedImageData forKey:key toDisk:YES];
                                                      
                                                      //add message locally before we upload it
                                                      ChatDataSource * cds = [[ChatController sharedInstance] getDataSourceForFriendname:_theirUsername];
                                                      [cds addMessage:message refresh:YES];
                                                      
                                                      //upload image to server
                                                      DDLogInfo(@"uploading image %@ to server", key);
                                                      [[NetworkController sharedInstance] postFileStreamData:encryptedImageData
                                                                                                  ourVersion:_ourVersion
                                                                                               theirUsername:_theirUsername
                                                                                                theirVersion:version
                                                                                                      fileid:[iv SR_stringByBase64Encoding]
                                                                                                    mimeType:MIME_TYPE_IMAGE
                                                                                                successBlock:^(AFHTTPRequestOperation *operation, id responseObject) {
                                                                                                    DDLogInfo(@"uploaded image %@ to server successfully", key);
                                                                                                    
                                                                                                    
                                                                                                } failureBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
                                                                                                    DDLogInfo(@"uploaded image %@ to server failed, statuscode: %d", key, operation.response.statusCode);
                                                                                                    
                                                                                                    if (operation.response.statusCode == 402) {
                                                                                                        message.errorStatus = 402;
                                                                                                    }
                                                                                                    else {
                                                                                                        message.errorStatus = 500;
                                                                                                    }
                                                                                                    
                                                                                                    [cds postRefresh];
                                                                                                }];
                                                  }
                                                  else {
                                                      //error
                                                  }
                                              }];
            
        }
        else {
            //TODO error message
        }
        
        
        
    }];
    //      }
    
    //    }];
    
}

+(BOOL) startCameraControllerFromViewController: (UIViewController*) controller
                                  usingDelegate: (id <UIImagePickerControllerDelegate,
                                                  UINavigationControllerDelegate>) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeCamera] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    cameraUI.delegate = delegate;
    
    //cameraUI
    
    [controller presentViewController: cameraUI animated: YES completion:nil];
    return YES;
}

+(BOOL) startImageSelectControllerFromViewController: (UIViewController*) controller
                                       usingDelegate: (id <UIImagePickerControllerDelegate,
                                                       UINavigationControllerDelegate>) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeSavedPhotosAlbum] == NO)
        || (delegate == nil)
        || (controller == nil))
        return NO;
    
    
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    cameraUI.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects: (NSString *) kUTTypeImage, nil];
    
    // Hides the controls for moving & scaling pictures, or for
    // trimming movies. To instead show the controls, use YES.
    cameraUI.allowsEditing = NO;
    cameraUI.delegate = delegate;
    
    //cameraUI
    
    [controller presentViewController: cameraUI animated: YES completion:nil];
    return YES;
}


+(UIImage *) scaleImage: (UIImage *) image {
    CGSize newSize = CGSizeMake(100, 100);
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}



@end
