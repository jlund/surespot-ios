//
//  SwipeViewController.h
//  surespot
//
//  Created by Adam on 9/25/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SwipeView.h"
#import "KeyboardState.h"
#import "FriendDelegate.h"
#import "Friend.h"
#import "UIViewPager.h"
#import "IASKAppSettingsViewController.h"
#import "MWPhotoBrowser.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "ALAssetsLibrary+CustomPhotoAlbum.h"
#import "TTTAttributedLabel.h"
#import "HPGrowingTextView.h"

@interface SwipeViewController : UIViewController
<
    SwipeViewDelegate,
    SwipeViewDataSource,
    UITableViewDataSource,
    UITableViewDelegate,
    UIActionSheetDelegate,
    UIViewPagerDelegate,
    IASKSettingsDelegate,
    MWPhotoBrowserDelegate,
    UIPopoverControllerDelegate,
    TTTAttributedLabelDelegate,
    HPGrowingTextViewDelegate
>
@end
