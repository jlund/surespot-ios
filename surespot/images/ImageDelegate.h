//
//  ImageDelegate.h
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface ImageDelegate : NSObject<UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>
@property (nonatomic, strong)  UIPopoverController* popover;
- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion
          theirUsername:(NSString *) theirUsername
           assetLibrary: (ALAssetsLibrary *) library
         sourceIsCamera: (BOOL) sourceIsCamera;


+(BOOL) startCameraControllerFromViewController: (UIViewController*) controller
                                  usingDelegate: (ImageDelegate *) delegate;
+(BOOL) startImageSelectControllerFromViewController: (UIViewController*) controller
                                       usingDelegate: (ImageDelegate *) delegate;
+(BOOL) startFriendImageSelectControllerFromViewController: (UIViewController*) controller
                                             usingDelegate: (ImageDelegate *) delegate;
- (void)orientationChanged;
@property (nonatomic, assign) BOOL friendImage;

@end
