//
//  SurespotControlMessage.m
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotControlMessage.h"

@implementation SurespotControlMessage
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

-(void) parseDictionary:(NSDictionary *) dictionary {
    _type = [dictionary objectForKey:@"type"];
    _controlId = [[dictionary objectForKey:@"id"] integerValue];
    _from = [dictionary objectForKey:@"from"];
    _action = [dictionary objectForKey:@"action"];
    _data = [dictionary objectForKey:@"data"];
    _moreData = [dictionary objectForKey:@"moredata"];
}

//-(BOOL) isEqual:(id)other {
//    if (other == self)
//        return YES;
//    if (!other || ![other isKindOfClass:[SurespotMessage class]])
//        return NO;
//    
//    return [self.iv isEqual:[other iv]];
//}

@end

