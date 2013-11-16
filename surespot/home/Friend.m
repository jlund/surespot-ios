//
//  Friend.m
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "Friend.h"

#define INVITER 32
#define MESSAGE_ACTIVITY 16
#define CHAT_ACTIVE 8
#define NEW_FRIEND 4
#define INVITED 2
#define DELETED 1

@implementation Friend
- (id) initWithJSONString: (NSString *) jsonString {
    
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    
    NSDictionary * friendData = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    
    
    [self parseDictionary:friendData];
    return self;
}

- (id) initWithDictionary:(NSDictionary *) dictionary {
    
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    
    [self parseDictionary:dictionary];
    return self;
}

-(id) initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _name = [coder decodeObjectForKey:@"name"];
        _flags = [coder decodeIntegerForKey:@"flags"];
        _imageUrl = [coder decodeObjectForKey:@"imageUrl"];
        _imageIv = [coder decodeObjectForKey:@"imageIv"];
        _imageVersion = [coder decodeObjectForKey:@"imageVersion"];
    }
    return self;
}


-(void) parseDictionary:(NSDictionary *) dictionary {
    _name = [dictionary objectForKey:@"name"];
    _flags = [[dictionary  objectForKey:@"flags"] integerValue];
    _imageVersion = [dictionary objectForKey:@"imageVersion"];
    _imageUrl = [dictionary objectForKey:@"imageUrl"];
    _imageIv = [dictionary objectForKey:@"imageIv"];
}

-(void) encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_name forKey:@"name"];
    [encoder encodeInteger:_flags forKey:@"flags"];
    //  [encoder encodeObject:_imageVersion forKey:@"imageVersion"];
    //  [encoder encodeObject:_imageUrl forKey:@"imageUrl"];
    //  [encoder encodeObject:_imageIv forKey:@"imageIv"];
}

-(void) setFriend {
    //   if (set) {
    //      _flags |= NEW_FRIEND;
    _flags &= ~INVITED;
    _flags &= ~INVITER;
    _flags &= ~DELETED;
    // }
    //    else {
    //        _flags &= ~NEW_FRIEND;
    //    }
    
    
}


-(BOOL) isInviter {
    return (_flags & INVITER) == INVITER;
}

-(void) setInviter: (BOOL) set {
    if (set) {
        _flags |= INVITER;
    }
    else {
        _flags &= ~INVITER;
    }
}

-(BOOL) isInvited {
    return (_flags & INVITED) == INVITED;
}

-(void) setInvited: (BOOL) set {
    if (set) {
        _flags |= INVITED;
    }
    else {
        _flags &= ~INVITED;
    }
}

-(BOOL) isDeleted {
    return (_flags & DELETED) == DELETED;
}

-(void) setDeleted {
    int active = _flags & CHAT_ACTIVE;
    _flags = DELETED | active;
}

-(BOOL) isChatActive {
    return (_flags & CHAT_ACTIVE) == CHAT_ACTIVE;
}

-(void) setChatActive:(BOOL)set {
    if (set) {
        _flags |= CHAT_ACTIVE;
    }
    else {
        _flags &= ~CHAT_ACTIVE;
    }
}

-(BOOL) isFriend {
    return  !self.isInvited && !self.isInviter;
}

-(BOOL) isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[Friend class]])
        return NO;
    
    return [self.name isEqualToString:[other name]];
}

- (NSComparisonResult)compare:(Friend  *)other {
    NSInteger myflags = self.flags  & (CHAT_ACTIVE | MESSAGE_ACTIVITY | INVITER);
    NSInteger theirflags = other.flags  & (CHAT_ACTIVE | MESSAGE_ACTIVITY | INVITER);
    
    if ((theirflags == myflags) || (theirflags < CHAT_ACTIVE && myflags < CHAT_ACTIVE)) {
        //sort my name
        return [self.name compare: other.name options:NSNumericSearch];
    }
    else {
        //sort by flag value
        if (theirflags > myflags) return NSOrderedDescending;
        else return NSOrderedAscending;
    }
}



@end
