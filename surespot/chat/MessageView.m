//
//  OurMessageView.m
//  surespot
//
//  Created by Adam on 10/30/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "MessageView.h"
#import "UIUtils.h"

@implementation MessageView

-(void) setHighlighted:(BOOL)highlighted animated:(BOOL)animated{
    if (highlighted) {
        self.backgroundColor = [UIUtils surespotTransparentBlue];
    } else {
        self.backgroundColor = [UIColor whiteColor];
    }
//    self.backgroundColor = [UIColor whiteColor];
}

//
//- (void)setSelected:(BOOL)selected animated:(BOOL)animated
//{
//    
//    if (selected) {
//        self.backgroundColor = [UIUtils surespotBlue];
//    } else {
//        self.backgroundColor = [UIColor whiteColor];
//    }
//}

@end
