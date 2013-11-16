//
//  MessageProcessor.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "MessageProcessor.h"
#import "MessageDecryptionOperation.h"


@interface MessageProcessor()
@property NSOperationQueue * decryptionQueue;

@end

@implementation MessageProcessor
+(MessageProcessor*)sharedInstance
{
    static MessageProcessor *sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.decryptionQueue = [[NSOperationQueue alloc] init];
    });
    
    return sharedInstance;
}

-(void) decryptMessage:(SurespotMessage *) message size: (CGSize) size completionCallback:(void(^)(SurespotMessage *))  callback {
    
    MessageDecryptionOperation * op = [[MessageDecryptionOperation alloc]initWithMessage:message size: size completionCallback:callback];
    
    [_decryptionQueue addOperation:op];
    
   
}
@end
