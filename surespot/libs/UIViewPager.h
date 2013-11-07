//
//  UIViewPager.h
//  PageSwiperIndicator
//
//  Created by xcode4 on 03/08/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SwipeView.h"

@protocol UIViewPagerDelegate <NSObject>

@required
- (int) pageCount;
- (int ) currentPage;
- (void) switchToPageIndex:(int) page;
- (NSString *) titleForLabelForPage:(int)page;

@optional
- (UIView *) tilteViewForPage:(int) page;

@end


@interface UIViewPager : UIView {
    UILabel *firstLabel;
    CGFloat firstLabelWidth;
    UILabel *secondLabel;
    CGFloat secondLabelWidth;
    UILabel *thirdLabel;
    CGFloat thirdLabelWidth;

    __unsafe_unretained id<UIViewPagerDelegate> delegate;
    CGFloat horizontalOffset;

   
}

@property(nonatomic, unsafe_unretained) id<UIViewPagerDelegate> delegate;
-(void) updateLabels;
 - (void) scrollViewDidScroll:(UIScrollView *)scrollView;
@end
