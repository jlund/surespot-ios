//
//  SurespotMessage.m
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotMessage.h"
#import "ChatUtils.h"

@implementation SurespotMessage
- (id) initWithJSONString: (NSString *) jsonString {
    
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    
    NSDictionary * messageData = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    
    
    [self parseDictionary:messageData];
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
        _serverid = [coder decodeObjectForKey:@"id"];
        _to = [coder decodeObjectForKey:@"to"];
        _from = [coder decodeObjectForKey:@"from"];
        _fromVersion = [coder decodeObjectForKey:@"fromVersion"];
        _toVersion = [coder decodeObjectForKey:@"toVersion"];
        _data =[coder decodeObjectForKey:@"data"];
        _iv = [coder decodeObjectForKey:@"iv"];
        _mimeType = [coder decodeObjectForKey:@"mimeType"];
        _dateTime = [coder decodeObjectForKey:@"datetime"];
    }
    return self;
}
-(void) parseDictionary:(NSDictionary *) dictionary {
    _serverid = [dictionary objectForKey:@"id"];
    _to = [dictionary objectForKey:@"to"];
    _from = [dictionary objectForKey:@"from"];
    _fromVersion = [dictionary objectForKey:@"fromVersion"];
    _toVersion = [dictionary objectForKey:@"toVersion"];
    _data =[dictionary objectForKey:@"data"];
    _iv = [dictionary objectForKey:@"iv"];
    _mimeType = [dictionary objectForKey:@"mimeType"];
    _dateTime = [NSDate dateWithTimeIntervalSince1970: [[dictionary objectForKey:@"datetime"] doubleValue]/1000];
}

- (NSString *) getOtherUser {
    return [ChatUtils getOtherUserWithFrom:_from andTo:_to];
}
- (NSString *) getTheirVersion {
    NSString * otherUser = [self getOtherUser];
    if ([_from  isEqualToString:otherUser]) {
        return _fromVersion;
    }
    else {
        return _toVersion;
    }
    
}
- (NSString *) getOurVersion {
    NSString * otherUser = [self getOtherUser];
    if ([_from  isEqualToString:otherUser]) {
        return _toVersion;
    }
    else {
        return _fromVersion;
    }
}

-(BOOL) isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[SurespotMessage class]])
        return NO;
    
    return [self.iv isEqual:[other iv]];
}

- (void)encodeWithCoder:(NSCoder *)encoder{
    [encoder encodeObject:_serverid forKey:@"id"];
    [encoder encodeObject:_to forKey:@"to"];
    [encoder encodeObject:_from forKey:@"from"];
    [encoder encodeObject:_fromVersion forKey:@"fromVersion"];
    [encoder encodeObject:_toVersion forKey:@"toVersion"];
    [encoder encodeObject:_data forKey:@"data"];
    [encoder encodeObject:_iv forKey:@"iv"];
    [encoder encodeObject:_mimeType forKey:@"mimeType"];
    [encoder encodeObject:_dateTime forKey:@"datetime"];


   

}



@end
