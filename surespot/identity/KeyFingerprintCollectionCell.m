//
//  KeyFingerprintCollectionCell.m
//  surespot
//
//  Created by Adam on 12/23/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "KeyFingerprintCollectionCell.h"

@implementation KeyFingerprintCollectionCell
- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(0,0,20,18)];
    self.label.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.label.textAlignment = NSTextAlignmentCenter;
    [self.label setFont:[UIFont systemFontOfSize:13]];
    [self.contentView addSubview:self.label];
    
    self.backgroundColor = [UIColor whiteColor];
    self.opaque = YES;
    self.userInteractionEnabled = NO;
    
    return self;
}
@end
