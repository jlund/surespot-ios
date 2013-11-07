
#import "UIViewPager.h"

@implementation UIViewPager

@synthesize delegate;

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        firstLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        firstLabel.backgroundColor = [UIColor clearColor];
        firstLabel.text = @"home";
//        [firstLabel sizeToFit];
        [self addSubview:firstLabel];
        
        secondLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        secondLabel.text = @"chat 1";
        secondLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:secondLabel];
//        [secondLabel sizeToFit];
        
        
        thirdLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        thirdLabel.text = @"chat 1";
        thirdLabel.backgroundColor = [UIColor clearColor];
        [self addSubview:thirdLabel];
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
        [self addGestureRecognizer:tapGestureRecognizer];
        [self setBackgroundColor:[UIColor whiteColor]];
    }
    return self;
}

- (void) layoutSubviews {
    CGFloat width = self.bounds.size.width;
    CGFloat firstLabelOffset = 0;
    firstLabel.frame = CGRectMake(firstLabelOffset, 0, firstLabelWidth, self.bounds.size.height);
   
    float remainder = fmod(horizontalOffset+width,width);
   
    float offset = width/2 - remainder/2;

    NSLog(@"hor offset: %f, remainder: %f, offset %f",horizontalOffset, remainder,offset);
    
    
    CGFloat secondLabelOffset = width/2 + offset-  secondLabelWidth/2;//width - secondLabelWidth/2;
 //   if (horizontalOffset < width/2) {
       // secondLabelOffset = width - secondLabelWidth/2;
//    } else {
       // secondLabelOffset = width - (horizontalOffset - width/2) - secondLabelWidth/2;
//    }
   if (secondLabelWidth + secondLabelOffset > width) {
        secondLabelOffset = width/2 - secondLabelWidth/2;
    }
   else {
       if (secondLabelOffset < 0) {
                   secondLabelOffset = width/2 - secondLabelWidth/2;
       }
   }
    
    
    secondLabel.frame = CGRectMake(secondLabelOffset, 0, secondLabelWidth, self.bounds.size.height);
    
    CGFloat thirdLabelOffset = width - thirdLabelWidth/2;
   
    thirdLabelOffset = width -  thirdLabelWidth;
    
       thirdLabel.frame = CGRectMake(thirdLabelOffset, 0, thirdLabelWidth, self.bounds.size.height);
}

#pragma mark UIScrollViewDelegate protocol implementation.

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    NSLog(@"Content offset:%@",NSStringFromCGPoint(scrollView.contentOffset));
    horizontalOffset = scrollView.contentOffset.x;
    [self updateLabels];
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
    [self updateLabels];
}

-(void) updateLabels {
    int count = [delegate pageCount];
    int page = [delegate currentPage];
    NSString * currentTitle = [delegate titleForLabelForPage:page];

 secondLabel.text = currentTitle;
   
    if (page == 0) {
        if (horizontalOffset < 0.5) {
            firstLabel.text = currentTitle;
            firstLabelWidth = [firstLabel sizeThatFits:self.bounds.size].width;
            
        }
        else {
            firstLabel.text =nil;
        }
    }
    else {
        if  (page == count) {
            if (horizontalOffset > count - 0.5) {
                thirdLabel.text = nil;
            }
            else {
                thirdLabel.text = currentTitle;
            }
            
        }
        else {
                secondLabel.text = currentTitle;
        }
    }
    
    
    
    
    firstLabel.text = @"1";
    firstLabelWidth = [firstLabel sizeThatFits:self.bounds.size].width;
    
    secondLabel.text =@"2";
    secondLabelWidth = [secondLabel sizeThatFits:self.bounds.size].width;
   
    
    thirdLabel.text =@"3";
    thirdLabelWidth = [thirdLabel sizeThatFits:self.bounds.size].width;

 
}
@end
