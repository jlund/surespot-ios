//
//  ImageDelegate.h
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "IASKAppSettingsViewController.h"
#import "MWPhotoBrowser.h"

#define kSurespotImageDelegateModeCapture 0
#define kSurespotImageDelegateModeSelect 1
#define kSurespotImageDelegateModeFriendImage 2
#define kSurespotImageDelegateModeBackgroundImage 3

@interface ImageDelegate : NSObject<UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate, MWPhotoBrowserDelegate>
@property (nonatomic, strong)  UIPopoverController* popover;
- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion
          theirUsername:(NSString *) theirUsername
           assetLibrary: (ALAssetsLibrary *) library;

+(BOOL) startCameraControllerFromViewController: (UIViewController*) controller
                                  usingDelegate: (ImageDelegate *) delegate;
+(BOOL) startImageSelectControllerFromViewController: (UIViewController*) controller
                                       usingDelegate: (ImageDelegate *) delegate;
+(BOOL) startFriendImageSelectControllerFromViewController: (UIViewController*) controller
                                             usingDelegate: (ImageDelegate *) delegate;
- (void)orientationChanged;
@property (nonatomic, assign) NSInteger mode;
+(BOOL) startBackgroundImageSelectControllerFromViewController: (IASKAppSettingsViewController*) controller
                                                 usingDelegate: (ImageDelegate *) delegate;

@end
