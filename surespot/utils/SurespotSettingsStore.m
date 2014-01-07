//
//  SurespotSettingsStore.m
//  surespot
//
//  Created by Adam on 1/6/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "SurespotSettingsStore.h"

@interface SurespotSettingsStore()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, retain, readwrite) NSUserDefaults* defaults;
@end

@implementation SurespotSettingsStore

- (id)initWithUserDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if( self ) {
        _defaults = defaults;
    }
    return self;
}




-(id) initWithUsername: (NSString *) username {
    self = [self initWithUserDefaults:[NSUserDefaults standardUserDefaults]];
    if (self) {
        _username = username;
    }
    return self;
}


- (void)setObject:(id)value forKey:(NSString*)key {
    if([key hasPrefix:@"_user"]) {
        [_defaults setObject:value forKey:[_username stringByAppendingString:key]];        
    }
    else {
        [_defaults setObject:value forKey:key];
    }
}

- (id)objectForKey:(NSString*)key {
    if ([key isEqualToString:@"logged_in_user"]) {
        return _username;
    }
    else {
        //if key starts with _user then prepend username to it
        if([key hasPrefix:@"_user"]) {
            return [_defaults objectForKey:[_username stringByAppendingString:key]];
        }
        else {
            return [_defaults objectForKey:key];
        }
    }
    
}

- (BOOL)synchronize {
    return NO;
}
@end
