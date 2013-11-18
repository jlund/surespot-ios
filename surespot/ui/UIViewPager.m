#import "UIViewPager.h"
#import "UIUtils.h"

@interface  UIViewPager()
@property UILabel *firstLabel;
@property CGFloat firstLabelWidth;
@property UILabel *secondLabel;
@property CGFloat secondLabelWidth;
@property UILabel *thirdLabel;
@property CGFloat thirdLabelWidth;
@property CGFloat horizontalOffset;
@end


@implementation UIViewPager

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _firstLabel = [self createLabel];
        _secondLabel = [self createLabel];
        _thirdLabel = [self createLabel];
        [self setBackgroundColor:[UIColor blackColor]];
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        [self addGestureRecognizer:tapGestureRecognizer];
        
    }
    return self;
}

- (id) createLabel {
    
    UILabel * label =[[UILabel alloc] initWithFrame:CGRectZero];
    label.textColor = [UIUtils surespotBlue];
    label.backgroundColor = [UIColor clearColor];
    [self addSubview:label];
    return label;
}

- (void) layoutSubviews {    
    CGFloat width = self.bounds.size.width;
    
    int currentPage = [_delegate currentPage];
    int count = [_delegate pageCount];
    float offset = _horizontalOffset - currentPage * width;
   
 //   DDLogVerbose(@"layoutsubviews, page: %d, count: %d,  adj offset: %f", currentPage, count, offset);
    
    if (count == 0) {return;}
    
    if (currentPage == 0) {
        _firstLabel.text = @"";
    }
    else {
        _firstLabel.text = [_delegate titleForLabelForPage:currentPage-1];
    }
    _firstLabelWidth = [_firstLabel sizeThatFits:self.bounds.size].width;
    
    _secondLabel.text = [_delegate titleForLabelForPage:currentPage];
    _secondLabelWidth = [_secondLabel sizeThatFits:self.bounds.size].width;
    
    if ( currentPage < count - 1) {
        _thirdLabel.text = [_delegate titleForLabelForPage:currentPage + 1];
    }
    else {
        _thirdLabel.text = @"";
    }
    _thirdLabelWidth = [_thirdLabel sizeThatFits:self.bounds.size].width;
    
    CGFloat firstLabelOffset = width/2 - _firstLabelWidth/2;
    if (offset < 0) {
        firstLabelOffset = 0;
    } else {
        firstLabelOffset = width/2 - _horizontalOffset - _firstLabelWidth/2;
    }
    if (firstLabelOffset < 0) {
        firstLabelOffset = 0;
    }
    _firstLabel.frame = CGRectMake(firstLabelOffset, 0, _firstLabelWidth, self.bounds.size.height);
    
    
    CGFloat secondLabelOffset = width/2 - _secondLabelWidth/2 - offset;
    _secondLabel.frame = CGRectMake(secondLabelOffset, 0, _secondLabelWidth, self.bounds.size.height);
    
    
    CGFloat thirdLabelOffset = width - _thirdLabelWidth;
    if (offset < 0) {
        thirdLabelOffset = width - _thirdLabelWidth;
    }
    if (_thirdLabelWidth + thirdLabelOffset > width) {
        thirdLabelOffset = width - _thirdLabelWidth;
    }
    _thirdLabel.frame = CGRectMake(thirdLabelOffset, 0, _thirdLabelWidth, self.bounds.size.height);
}

#pragma mark UIScrollViewDelegate protocol implementation.

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
   // DDLogVerbose(@"Content offset:%@",NSStringFromCGPoint(scrollView.contentOffset));
    _horizontalOffset = scrollView.contentOffset.x;
    [self setNeedsLayout];
}

- (void) tapped:(UITapGestureRecognizer *) tapGestureRecognizer {
    CGPoint locationInView = [tapGestureRecognizer locationInView:self];
    CGFloat width = self.bounds.size.width;
    NSInteger page = [_delegate currentPage];
    NSInteger count = [_delegate pageCount];
    if (locationInView.x < width/3 && page > 0) {
        [_delegate switchToPageIndex: page - 1];
    } else if (locationInView.x > width * 2/3 && page < count - 1) {           [_delegate switchToPageIndex:page+1];
    }
}

- (void) setDelegate:(id<UIViewPagerDelegate>)delegate {
    _delegate = delegate;
}

@end
