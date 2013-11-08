//
//  LineNumberLogFormatter.m
//  surespot
//
//  Created by Adam on 11/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotLogFormatter.h"


@implementation SurespotLogFormatter

- (id)init
{
    if((self = [super init]))
    {
        threadUnsafeDateFormatter = [[NSDateFormatter alloc] init];
        [threadUnsafeDateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
        [threadUnsafeDateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss:SSS"];
    }
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    NSString *logLevel;
    switch (logMessage->logFlag)
    {
        case LOG_FLAG_ERROR : logLevel = @"E"; break;
        case LOG_FLAG_WARN  : logLevel = @"W"; break;
        case LOG_FLAG_INFO  : logLevel = @"I"; break;
        default             : logLevel = @"V"; break;
    }
    
    NSString * function = [[NSString stringWithCString: logMessage->function encoding:NSASCIIStringEncoding] stringByPaddingToLength:12 withString:@" " startingAtIndex:0];
    
    NSString *dateAndTime = [threadUnsafeDateFormatter stringFromDate:(logMessage->timestamp)];
    NSString *path = [NSString stringWithCString:logMessage->file encoding:NSASCIIStringEncoding];
    NSString *fileName = [[[path lastPathComponent] stringByDeletingPathExtension] stringByPaddingToLength:12 withString:@" " startingAtIndex:0];
    
//    NSString *qLabel = [NSString stringWithUTF8String:logMessage->queueLabel] substringFromIndex:
    return [NSString stringWithFormat:@"%@ %@ [%5u:%.12s] [%8@:%@ %3d] %@",logLevel, dateAndTime, logMessage->machThreadID, logMessage->queueLabel, fileName, function, logMessage->lineNumber, logMessage->logMsg];
}
@end
