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
    
    self.messageData = [NSJSONSerialization JSONObjectWithData:[jsonString dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
    return self;
}

- (id) initWithMutableDictionary:(NSMutableDictionary *) dictionary {
    
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    
    self.messageData = dictionary;
    return self;
}

- (NSString *) getOtherUser {
    return [ChatUtils getOtherUserWithFrom:[_messageData objectForKey:@"from"] andTo:[_messageData objectForKey:@"to"]];
}
- (NSString *) getTheirVersion {
    NSString * otherUser = [self getOtherUser];
    if ([[_messageData objectForKey:@"from"]  isEqualToString:otherUser]) {
        return [_messageData objectForKey:@"fromVersion"];
    }
    else {
        return [_messageData objectForKey:@"toVersion"] ;
    }
    
}
- (NSString *) getOurVersion {
    NSString * otherUser = [self getOtherUser];
    if ([[_messageData objectForKey:@"from"]  isEqualToString:otherUser]) {
        return [_messageData objectForKey:@"toVersion"];
    }
    else {
        return [_messageData objectForKey:@"fromVersion"] ;
    }
    
}
@end
