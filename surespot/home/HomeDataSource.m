//
//  HomeDataSource.m
//  surespot
//
//  Created by Adam on 11/2/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "HomeDataSource.h"
#import "NetworkController.h"

@implementation HomeDataSource
-(HomeDataSource*)init {
    //call super init
    self = [super init];
    
    if (self != nil) {
        [self setFriends:[[NSMutableArray alloc] init]];
        [[NetworkController sharedInstance] getFriendsSuccessBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            NSLog(@"get friends response: %d",  [response statusCode]);
            self.friends = [[NSMutableArray alloc ] init];
            
            
            
            NSArray * friendDicts = [((NSDictionary *) JSON) objectForKey:@"friends"];
            for (NSDictionary * friendDict in friendDicts) {
                [_friends addObject:[[Friend alloc] initWithDictionary: friendDict]];
            };
            
            [self postRefresh];
            
        } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
            NSLog(@"response failure: %@",  Error);
            [self postRefresh];  
        }];
        
        
    }
    
    return self;
}

- (void) addFriend: (Friend *) afriend {
    [_friends addObject:afriend];
    
}
- (void) removeFriend: (Friend *) afriend {
    [_friends removeObject:afriend];
}

-(void) postRefresh {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshHome" object:nil];
}

@end