//
//  SurespotMessage.m
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotErrorMessage.h"
#import "ChatUtils.h"

@implementation SurespotErrorMessage
- (id) initWithDictionary:(NSDictionary *) dictionary {
    
    // Call superclass's initializer
    self = [super init];
    if( !self ) return nil;
    
    [self parseDictionary:dictionary];
    return self;
}

-(void) parseDictionary:(NSDictionary *) dictionary {
    _data = [dictionary objectForKey:@"id"];
    _status = [[dictionary objectForKey:@"status"] integerValue];
}


@end
