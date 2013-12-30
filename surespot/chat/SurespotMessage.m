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
        _serverid = [[coder decodeObjectForKey:@"id"] integerValue];
        _to = [coder decodeObjectForKey:@"to"];
        _from = [coder decodeObjectForKey:@"from"];
        _fromVersion = [coder decodeObjectForKey:@"fromVersion"];
        _toVersion = [coder decodeObjectForKey:@"toVersion"];
        _data =[coder decodeObjectForKey:@"data"];
        _iv = [coder decodeObjectForKey:@"iv"];
        _mimeType = [coder decodeObjectForKey:@"mimeType"];
        _dateTime = [coder decodeObjectForKey:@"datetime"];
        _shareable = [coder decodeBoolForKey:@"shareable"];
        _errorStatus = [coder decodeIntegerForKey:@"errorStatus"];
        _dataSize = [coder decodeIntegerForKey:@"dataSize"];
        _voicePlayed = [coder decodeBoolForKey:@"voicePlayed"];
    }
    return self;
}
-(void) parseDictionary:(NSDictionary *) dictionary {
    _serverid = [[dictionary objectForKey:@"id"] integerValue];
    _to = [dictionary objectForKey:@"to"];
    _from = [dictionary objectForKey:@"from"];
    _fromVersion = [dictionary objectForKey:@"fromVersion"];
    _toVersion = [dictionary objectForKey:@"toVersion"];
    _data =[dictionary objectForKey:@"data"];
    _iv = [dictionary objectForKey:@"iv"];
    _mimeType = [dictionary objectForKey:@"mimeType"];
    _shareable = [[dictionary objectForKey:@"shareable"] boolValue];
    _dataSize = [[dictionary objectForKey:@"dataSize"] integerValue];
    
    id dateTime = [dictionary objectForKey:@"datetime"];
    if (dateTime) {
        _dateTime = [NSDate dateWithTimeIntervalSince1970: [dateTime doubleValue]/1000];
    }
    else {
        _dateTime = nil;
    }
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
    NSString * serverid = [@(_serverid) stringValue];
    [encoder encodeObject: serverid forKey:@"id"];
    [encoder encodeObject:_to forKey:@"to"];
    [encoder encodeObject:_from forKey:@"from"];
    [encoder encodeObject:_fromVersion forKey:@"fromVersion"];
    [encoder encodeObject:_toVersion forKey:@"toVersion"];
    [encoder encodeObject:_data forKey:@"data"];
    [encoder encodeObject:_iv forKey:@"iv"];
    [encoder encodeObject:_mimeType forKey:@"mimeType"];
    [encoder encodeBool:_shareable forKey:@"shareable"];
    [encoder encodeBool:_voicePlayed forKey:@"voicePlayed"];
    
    if (_dateTime) {
        [encoder encodeObject:_dateTime forKey:@"datetime"];
    }
    if (_errorStatus > 0) {
        [encoder encodeInteger:_errorStatus forKey:@"errorStatus"];
    }
    if (_dataSize > 0) {
        [encoder encodeInteger:_dataSize forKey:@"dataSize"];
    }
    
}


- (NSMutableDictionary * ) toNSDictionary {
    NSMutableDictionary * dict =[NSMutableDictionary new];
    NSString * serverid = [@(_serverid) stringValue];
    [dict setObject:serverid forKey:@"id"];
    [dict setObject:_to forKey:@"to"];
    [dict setObject:_from forKey:@"from"];
    [dict setObject:_fromVersion forKey:@"fromVersion"];
    [dict setObject:_toVersion forKey:@"toVersion"];
    [dict setObject:_data forKey:@"data"];
    [dict setObject:_iv forKey:@"iv"];
    [dict setObject:_mimeType forKey:@"mimeType"];
    [dict setObject:[NSNumber numberWithBool:_shareable] forKey:@"shareable"];
    if (_dateTime) {
        [dict setObject:[@([_dateTime timeIntervalSince1970]*1000/1000) stringValue] forKey:@"datetime"];
    }
    
    if (_resendId > 0) {
        [dict setObject:[@(_resendId) stringValue] forKey:@"resendId"];
    }
    
    return dict;
}


- (NSString * ) toJsonString {
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[self toNSDictionary] options:0 error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
    
}

-(BOOL) readyToSend {
    return self.from && self.to && self.fromVersion && self.iv && self.toVersion && self.data && self.mimeType && self.serverid == 0;
}

-(id) copyWithZone:(NSZone *)zone {
    SurespotMessage * message = [SurespotMessage new];
    message.serverid = self.serverid;
    message.from = [self.from copyWithZone:zone];
    message.to = [self.to copyWithZone:zone];
    message.iv = [self.iv copyWithZone:zone];
    message.data  = [self.data copyWithZone:zone];
    message.toVersion = [self.toVersion copyWithZone:zone];
    message.fromVersion = [self.fromVersion copyWithZone:zone];
    message.mimeType = [self.mimeType copyWithZone:zone];
    message.plainData = [self.plainData copyWithZone:zone];
    message.dateTime = [self.dateTime copyWithZone:zone];
    message.errorStatus = self.errorStatus;
    message.formattedDate = [self.formattedDate copyWithZone:zone];
    message.dataSize = self.dataSize;
    message.resendId = self.resendId;
    message.loading = self.loading;
    message.loaded = self.loaded;
    message.rowPortraitHeight = self.rowPortraitHeight;
    message.rowLandscapeHeight = self.rowLandscapeHeight;
    message.shareable = self.shareable;
    message.voicePlayed = self.voicePlayed;
    message.playVoice = self.playVoice;
    return message;
}

@end
