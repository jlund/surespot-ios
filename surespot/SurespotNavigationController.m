//
//  SurespotNavigationController.m
//  surespot
//
//  Created by Adam on 12/30/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotNavigationController.h"

@implementation SurespotNavigationController

-(NSUInteger)supportedInterfaceOrientations {
    UIViewController *top = self.topViewController;
    return top.supportedInterfaceOrientations;
}

-(BOOL)shouldAutorotate {
    UIViewController *top = self.topViewController;
    return [top shouldAutorotate];
}

@end
