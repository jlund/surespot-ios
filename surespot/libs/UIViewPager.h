
#import <Foundation/Foundation.h>
#import "SwipeView.h"

@protocol UIViewPagerDelegate <NSObject>

@required
- (NSInteger) pageCount;
- (NSInteger) currentPage;
- (void) switchToPageIndex:(NSInteger) page;
- (NSString *) titleForLabelForPage:(NSInteger)page;

@optional
- (UIView *) titleViewForPage:(NSInteger) page;

@end


@interface UIViewPager : UIView 
@property (nonatomic, strong) NSMutableArray * pagerLabels;
@property (nonatomic, unsafe_unretained) id<UIViewPagerDelegate> delegate;
-(void) scrollViewDidScroll:(UIScrollView *)scrollView;
@end
