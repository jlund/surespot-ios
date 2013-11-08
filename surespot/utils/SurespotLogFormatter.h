//
//  LineNumberLogFormatter.h
//  surespot
//
//  Created by Adam on 11/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DDLog.h"

@interface SurespotLogFormatter : NSObject<DDLogFormatter> {
    int loggerCount;
    NSDateFormatter *threadUnsafeDateFormatter;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage;

@end