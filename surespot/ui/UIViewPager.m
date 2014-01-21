#import "UIViewPager.h"
#import "UIUtils.h"
#import "DDLog.h"



@interface  UIViewPager()
@property UIImageView *homeView;
@property UILabel *firstLabel;
@property CGFloat firstLabelWidth;
@property UILabel *secondLabel;
@property CGFloat secondLabelWidth;
@property UILabel *thirdLabel;
@property CGFloat thirdLabelWidth;
@property CGFloat horizontalOffset;
@end

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_OFF;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif

static CGFloat const alpha = 0.4;


@implementation UIViewPager

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _firstLabel = [self createLabel];
        [_firstLabel setAlpha:alpha];
        _secondLabel = [self createLabel];
        _thirdLabel = [self createLabel];
        [_thirdLabel setAlpha:alpha];
        [self setBackgroundColor:[UIColor blackColor]];
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        [self addGestureRecognizer:tapGestureRecognizer];
        
        
        _homeView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"ic_menu_home_blue"]];
        _homeView.contentMode = UIViewContentModeScaleAspectFill;
        _homeView.frame = CGRectMake(0, 0, 25, 25);
        [self addSubview:_homeView];
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
    UIView * firstView;
    UIView * secondView;
    
    DDLogInfo(@"layoutsubviews, page: %d, count: %d,  adj offset: %f", currentPage, count, offset);
    
    if (count == 0) {return;}
    
    if (currentPage == 0) {
        _homeView.hidden = NO;
        
        firstView = _firstLabel;
        _firstLabel.text = @"";
        _firstLabelWidth = [_firstLabel sizeThatFits:self.bounds.size].width;
        
        secondView = _homeView;
        [_homeView setAlpha:1];
        _secondLabel.text = @"";
        _secondLabelWidth = _homeView.frame.size.width;
    }
    else {
        if (currentPage == 1) {
            _homeView.hidden = NO;
            
            firstView = _homeView;
            [_homeView setAlpha: alpha];
            _firstLabelWidth = _homeView.frame.size.width;
            _firstLabel.text = @"";
            
            secondView = _secondLabel;        ;
            _secondLabel.text = [_delegate titleForLabelForPage:currentPage];
            _secondLabelWidth = [_secondLabel sizeThatFits:self.bounds.size].width;
        }
        else {
            _homeView.hidden = YES;
            firstView = _firstLabel;
            _firstLabel.text = [_delegate titleForLabelForPage:currentPage-1];
            _firstLabelWidth = [_firstLabel sizeThatFits:self.bounds.size].width;
            
            secondView = _secondLabel;        ;
            _secondLabel.text = [_delegate titleForLabelForPage:currentPage];
            _secondLabelWidth = [_secondLabel sizeThatFits:self.bounds.size].width;
        }
    }
    
    
    
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
    
    DDLogInfo(@"1st label offset: %f", firstLabelOffset);
    
    
    
    CGFloat secondLabelOffset = width/2 - _secondLabelWidth/2 - offset;
    
    
    DDLogInfo(@"2nd label offset: %f", secondLabelOffset);
    
    CGFloat thirdLabelOffset = width - _thirdLabelWidth;
    if (offset < 0) {
        thirdLabelOffset = width - _thirdLabelWidth;
    }
    if (_thirdLabelWidth + thirdLabelOffset > width) {
        thirdLabelOffset = width - _thirdLabelWidth;
    }
    
    DDLogInfo(@"3rd label offset: %f", thirdLabelOffset);
    
    
    if (secondLabelOffset < 0) {
        secondLabelOffset = 0;
    }
    
    
    NSInteger firstLabelEndOffset = firstLabelOffset + _firstLabelWidth;
    NSInteger secondLabelEndOffset = secondLabelOffset + _secondLabelWidth;
    
    if (secondLabelEndOffset > width) {
        secondLabelOffset = width - _secondLabelWidth;
    }
    
    if (secondLabelOffset - 5 <= firstLabelEndOffset) {
        firstLabelOffset -= firstLabelEndOffset - secondLabelOffset + 5;
    }
    else {
        if (secondLabelEndOffset + 5 >= thirdLabelOffset) {
            thirdLabelOffset += secondLabelEndOffset - thirdLabelOffset + 5;
        }
    }
    
    firstView.frame = CGRectMake(firstLabelOffset, 0, _firstLabelWidth, self.bounds.size.height);
    secondView.frame = CGRectMake(secondLabelOffset, 0, _secondLabelWidth, self.bounds.size.height);
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
