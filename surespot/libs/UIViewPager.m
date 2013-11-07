#import "UIViewPager.h"


@implementation UIViewPager

@synthesize delegate;

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        firstLabel = [self createLabel];
        secondLabel = [self createLabel];
        thirdLabel = [self createLabel];
        [self setBackgroundColor:[UIColor whiteColor]];
        
    }
    return self;
}

- (id) createLabel {
    
    UILabel * label =[[UILabel alloc] initWithFrame:CGRectZero];
    // label.backgroundColor = [UIColor clearColor];
    //  label.text = labelText;
    
    [self addSubview:label];
    return label;
}



- (void) layoutSubviews {
    CGFloat width = self.bounds.size.width;
    
    int currentPage = [delegate currentPage];
    int count = [delegate pageCount];
    float offset = horizontalOffset - currentPage * width;
    
    NSLog(@"layoutsubviews, page: %d, count: %d,  adj offset: %f", currentPage, count, offset);
    
    if (count == 0) {return;}
    
    if (currentPage == 0) {
        firstLabel.text =@"";
        firstLabelWidth = [firstLabel sizeThatFits:self.bounds.size].width;
        
        secondLabel.text = [delegate titleForLabelForPage:currentPage];
        secondLabelWidth = [secondLabel sizeThatFits:self.bounds.size].width;
    }
    else {
        firstLabel.text = [delegate titleForLabelForPage:currentPage-1];
        firstLabelWidth = [firstLabel sizeThatFits:self.bounds.size].width;
    }
    
    secondLabel.text = [delegate titleForLabelForPage:currentPage];
    secondLabelWidth = [secondLabel sizeThatFits:self.bounds.size].width;
    
    if ( currentPage < count - 1) {
        thirdLabel.text = [delegate titleForLabelForPage:currentPage + 1];
        thirdLabelWidth = [thirdLabel sizeThatFits:self.bounds.size].width;
    }
    else {
        thirdLabel.text= @"";
    }
    
    CGFloat firstLabelOffset = width/2 - firstLabelWidth/2;
    if (offset < 0) {
        firstLabelOffset = 0;
    } else {
        firstLabelOffset = width/2 - horizontalOffset - firstLabelWidth/2;
    }
    if (firstLabelOffset < 0) {
        firstLabelOffset = 0;
    }
    firstLabel.frame = CGRectMake(firstLabelOffset, 0, firstLabelWidth, self.bounds.size.height);
    
    
    CGFloat secondLabelOffset = width/2 - secondLabelWidth/2 - offset;
    secondLabel.frame = CGRectMake(secondLabelOffset, 0, secondLabelWidth, self.bounds.size.height);
    
    
    CGFloat thirdLabelOffset = width - thirdLabelWidth;
    if (offset < 0) {
        thirdLabelOffset = width - thirdLabelWidth;
    }
    if (thirdLabelWidth + thirdLabelOffset > width) {
        thirdLabelOffset = width - thirdLabelWidth;
    }
    thirdLabel.frame = CGRectMake(thirdLabelOffset, 0, thirdLabelWidth, self.bounds.size.height);    
}

#pragma mark UIScrollViewDelegate protocol implementation.

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"Content offset:%@",NSStringFromCGPoint(scrollView.contentOffset));
    horizontalOffset = scrollView.contentOffset.x;
    [self setNeedsLayout];
}

- (void) drawRect:(CGRect)rect {
    [super drawRect:rect];
    
    //TODO: draw a small triangle.
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    //    CGFloat halfWidth = self.bounds.size.width / 2;
    CGFloat height = self.bounds.size.height - 3;
    //
    //    CGContextBeginPath(ctx);
    //    CGContextMoveToPoint   (ctx, halfWidth - 8/2, height);
    //    CGContextAddLineToPoint(ctx, halfWidth, height - 8/2 /** sqrt(3)*/);
    //    CGContextAddLineToPoint(ctx, halfWidth + 8/2, height);
    //    CGContextClosePath(ctx);
    //
    //    CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
    ////    CGContextSetStrokeColorWithColor(ctx, [UIColor redColor].CGColor);
    ////    CGContextStrokePath(ctx);
    //    CGContextFillPath(ctx);
    
    CGContextFillRect(ctx, CGRectMake(0, height, self.bounds.size.width, 3));
}

- (void) tapped:(UITapGestureRecognizer *) tapGestureRecognizer {
    CGPoint locationInView = [tapGestureRecognizer locationInView:self];
    CGFloat width = self.bounds.size.width;
    if (locationInView.x < width/3) {
        if (horizontalOffset >= width / 2) {
            [delegate switchToPageIndex:0];
        }
    } else if (locationInView.x > width * 2/3) {
        if (horizontalOffset <= width/2) {
            [delegate switchToPageIndex:1];
        }
    }
}

- (void) setDelegate:(id<UIViewPagerDelegate>)delegate_ {
    delegate = delegate_;
}


-(void) refreshViews {
    
    UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [self addGestureRecognizer:tapGestureRecognizer];
    
}
@end
