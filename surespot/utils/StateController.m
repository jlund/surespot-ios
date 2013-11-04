//
//  StateController.m
//  surespot
//
//  Created by Adam on 11/4/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "StateController.h"

@implementation StateController
+(StateController*)sharedInstance
{
    static StateController *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}


@end
