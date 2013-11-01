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
-(id) initWithMessage: (SurespotMessage *) message width: (CGFloat) width completionCallback:(void(^)(SurespotMessage *))  callback {
    if (self = [super init]) {
        self.callback = callback;
        self.message = message;
        self.width = width;
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
            
            //figure out message height
            if (plaintext){
                
                UIFont *cellFont = [UIFont fontWithName:@"Helvetica" size:17.0];
                CGSize constraintSize = CGSizeMake(_width - 40, MAXFLOAT);
                
                //http://stackoverflow.com/questions/12744558/uistringdrawing-methods-dont-seem-to-be-thread-safe-in-ios-6
                CGSize labelSize = //[plaintext sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:NSLineBreakByWord
                [UIUtils threadSafeSizeString:plaintext WithFont:cellFont constrainedToSize:constraintSize];
                [_message setRowHeight:(int) (labelSize.height + 20 > 44 ? labelSize.height + 20 : 44) ];
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

