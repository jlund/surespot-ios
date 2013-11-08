//
//  LineNumberLogFormatter.m
//  surespot
//
//  Created by Adam on 11/8/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotLogFormatter.h"

@implementation SurespotLogFormatter
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
    
    NSString *path = [NSString stringWithCString:logMessage->file encoding:NSASCIIStringEncoding];
    NSString *fileName = [[path lastPathComponent] stringByDeletingPathExtension];
    return [NSString stringWithFormat:@"%@ %@ [%u:%s] [%@:%s %d] %@",logLevel, logMessage->timestamp, logMessage->machThreadID, logMessage->queueLabel, fileName, logMessage->function, logMessage->lineNumber, logMessage->logMsg];
}
@end
