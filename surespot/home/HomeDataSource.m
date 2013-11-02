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
            
            
            
            NSArray * friendDicts = [JSON objectForKey:@"friends"];
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

- (void) addFriend: (Friend *) afriend withRefresh: (BOOL) refresh {
    [_friends addObject:afriend];
    if (refresh) {
        [self postRefresh];
    }
    
}
- (void) removeFriend: (Friend *) afriend withRefresh: (BOOL) refresh {
    [_friends removeObject:afriend];
    if (refresh) {
        [self postRefresh];
    }
}

-(void) postRefresh {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshHome" object:nil];
}

-(Friend *) getFriendByName: (NSString *) name {
    for (Friend * afriend in _friends) {
        if ([[afriend name] isEqualToString:name]) {
            return  afriend;
        }
    }
    
    return nil;
}

-(void) setAvailableMessageId: (NSInteger) availableId forFriendname: (NSString *) friendname {
    Friend * afriend = [self getFriendByName:friendname];
    if (afriend) {
        afriend.availableMessageId = availableId;
    }
}

-(void) setAvailableMessageControlId: (NSInteger) availableId forFriendname: (NSString *) friendname {
    Friend * afriend = [self getFriendByName:friendname];
    if (afriend) {
        afriend.availableMessageControlId = availableId;
    }
}


@end
