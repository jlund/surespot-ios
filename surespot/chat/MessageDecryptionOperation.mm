//
//  MessageDecryptionOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "MessageDecryptionOperation.h"
#import "EncryptionController.h"
#import "UIUtils.h"

@interface MessageDecryptionOperation()
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end

@implementation MessageDecryptionOperation
-(id) initWithMessage: (SurespotMessage *) message size: (CGSize) size completionCallback:(void(^)(SurespotMessage *))  callback {
    if (self = [super init]) {
        self.callback = callback;
        self.message = message;
        self.size = size;
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
    
}


-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    
    if ([_message.mimeType isEqualToString: @"text/plain"]) {
        
        [EncryptionController symmetricDecryptString:[_message data] ourVersion:[_message getOurVersion] theirUsername:[_message getOtherUser] theirVersion:[_message getTheirVersion]  iv:[_message iv]  callback:^(NSString * plaintext){
            
            _message.plainData = plaintext;
            
            //figure out message height for both orientations
            if (plaintext){
                [UIUtils setMessageHeights:_message size:_size];
            }     
            
            [self finish];
            
        }];
    }
    else {
        _message.plainData = _message.mimeType;
        [self finish];
    }
    
}

- (void)finish
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    self.callback(_message);
    self.callback = nil;
    self.message = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end

