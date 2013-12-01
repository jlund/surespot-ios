//
//  NSString+Sensitivize.m
//  surespot
//
//  Created by Adam on 12/1/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "NSString+Sensitivize.h"

@implementation NSString (Sensitivize)

-(NSString *) caseInsensitivize {
    NSMutableString * sb = [NSMutableString new];
    
    for (int i = 0; i < [self length]; i++) {
        unichar uni = [self characterAtIndex:i];
        
        if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:uni]) {
            [sb appendString:@"_"];
            [sb appendFormat:@"%c",[self characterAtIndex:i]];
        }
        else {
            [sb appendFormat:@"%c",uni];
        }
    }
    return sb;
}

-(NSString *) caseSensitivize {
    NSMutableString * sb = [NSMutableString new];
    
    for (int i = 0; i < [self length]; i++) {
        unichar uni = [self characterAtIndex:i];
        
        if (uni == '_') {
            [sb appendFormat: @"%c",[[self uppercaseString] characterAtIndex: ++i]];
        }
        else {
            [sb appendFormat: @"%c",uni];
        }
    }
    
    return sb;
}

@end
