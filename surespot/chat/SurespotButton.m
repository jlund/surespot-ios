//
//  SurespotButton.m
//  surespot
//
//  Created by Adam on 11/9/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotButton.h"
#import "UIUtils.h"

@implementation SurespotButton 


-(void) setHighlighted:(BOOL)highlighted {
    
    if(highlighted) {
        self.backgroundColor = [UIUtils surespotBlue];
    } else {
        self.backgroundColor = [UIColor whiteColor];
    }
    [super setHighlighted:highlighted];
}


@end
