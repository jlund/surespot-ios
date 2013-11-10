//
//  KeyboardState.h
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeyboardState : NSObject
@property (nonatomic) CGFloat keyboardHeight;
@property (nonatomic) UIEdgeInsets contentInset;
@property (nonatomic) UIEdgeInsets indicatorInset;
//@property (nonatomic, strong) NSMutableDictionary * offsets;
@end
