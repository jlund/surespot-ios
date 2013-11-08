//
//  HomeDataSource.m
//  surespot
//
//  Created by Adam on 11/2/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "HomeDataSource.h"
#import "NetworkController.h"
#import "FileController.h"
#import "DDLog.h"

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif


@interface  HomeDataSource()

@end

@implementation HomeDataSource
-(HomeDataSource*)init {
    self = [super init];
    
    if (self != nil) {
        //if we have data on file, load it
        //otherwise load from network
        NSString * path =[FileController getHomeFilename];
        DDLogVerbose(@"looking for home data at: %@", path);
        id homeData = nil;
        @try {
            homeData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        }
        @catch (NSException * e) {
            
        }
        if (homeData) {
            DDLogVerbose(@"loading home data from: %@", path);
            _currentChat = [homeData objectForKey:@"currentChat"];
            _latestUserControlId = [[homeData objectForKey:@"userControlId"] integerValue];
            _friends = [homeData objectForKey:@"friends"];
            if (!_friends) {
                [self getFriends];
            }
        }
        else {
            DDLogVerbose(@"loading home data from cloud");
            [self getFriends];
        }
    }
    
    DDLogVerbose(@"HomeDataSource init, latestUserControlId: %d, currentChat: %@", _latestUserControlId, _currentChat);
    return self;
}

-(void) getFriends {
    _friends = [[NSMutableArray alloc] init];
    [[NetworkController sharedInstance] getFriendsSuccessBlock:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        DDLogVerbose(@"get friends response: %d",  [response statusCode]);
        
        _latestUserControlId = [[JSON objectForKey:@"userControlId"] integerValue];
        _friends = [[NSMutableArray alloc] init];
        
        NSArray * friendDicts = [JSON objectForKey:@"friends"];
        for (NSDictionary * friendDict in friendDicts) {
            [_friends addObject:[[Friend alloc] initWithDictionary: friendDict]];
        };
        [self writeToDisk];
        [self postRefresh];
        
    } failureBlock:^(NSURLRequest *operation, NSHTTPURLResponse *responseObject, NSError *Error, id JSON) {
        DDLogVerbose(@"response failure: %@",  Error);
        [self postRefresh];
    }];
    
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

-(void) writeToDisk {
    if (_latestUserControlId > 0 || _friends.count > 0) {
        NSString * filename =[FileController getHomeFilename];
        DDLogVerbose(@"saving home data to disk at %@, latestUserControlId: %d, currentChat: %@",filename, _latestUserControlId, _currentChat);
        NSMutableDictionary * dict = [[NSMutableDictionary alloc] init];
        if (_friends.count > 0) {
            [dict setObject:_friends  forKey:@"friends"];
        }
        if (_latestUserControlId > 0) {
            [dict setObject:[NSNumber numberWithInteger: _latestUserControlId] forKey:@"userControlId"];
        }
        if (_currentChat) {
            [dict setObject:_currentChat forKey:@"currentChat"];
        }
        BOOL saved =[NSKeyedArchiver archiveRootObject:dict toFile:filename];
        DDLogVerbose(@"save success?: %@",saved ? @"YES" : @"NO");
    }
}

-(void) setCurrentChat: (NSString *) username {
    if (username) {
        Friend * afriend = [self getFriendByName:username];
        [afriend setChatActive:YES];
    }
  
    _currentChat = username;
    
}

@end
