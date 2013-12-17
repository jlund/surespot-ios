//
//  ImageDelegate.h
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface ImageDelegate : NSObject<UIImagePickerControllerDelegate, UINavigationControllerDelegate>

- (id) initWithUsername: (NSString *) username
             ourVersion:(NSString *) ourVersion
          theirUsername:(NSString *) theirUsername
           assetLibrary: (ALAssetsLibrary *) library
         sourceIsCamera: (BOOL) sourceIsCamera;

+(BOOL) startCameraControllerFromViewController: (UIViewController*) controller
                                  usingDelegate: (id <UIImagePickerControllerDelegate,
                                                  UINavigationControllerDelegate>) delegate;
+(BOOL) startImageSelectControllerFromViewController: (UIViewController*) controller
                                       usingDelegate: (id <UIImagePickerControllerDelegate,
                                                       UINavigationControllerDelegate>) delegate;
@end
