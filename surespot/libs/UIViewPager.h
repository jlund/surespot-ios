
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

@property (nonatomic, strong) NSMutableArray * pagerLabels;
@property(nonatomic, unsafe_unretained) id<UIViewPagerDelegate> delegate;
-(void) scrollViewDidScroll:(UIScrollView *)scrollView;
@end
