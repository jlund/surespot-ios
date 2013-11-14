//
//  SendMessageOperation.m
//  surespot
//
//  Created by Adam on 11/14/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SendMessageOperation.h"
#import "DDLog.h"
#import "ChatController.h" 

#ifdef DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_OFF;
#endif



@interface SendMessageOperation()
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@property (nonatomic, strong) NSString * jsonMessage;
@end




@implementation SendMessageOperation


-(SendMessageOperation *) initWithJsonMessage: (NSString *) jsonMessage {
    
    if (self = [super init]) {
        self.jsonMessage = jsonMessage;
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    
    [[ChatController sharedInstance] sendMessageOnSocket:_jsonMessage];
    
    DDLogVerbose(@"executing");
    
    
}

- (void)finish: (NSData *) secret
{
    DDLogVerbose(@"finished");
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
