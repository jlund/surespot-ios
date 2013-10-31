//
//  MessageDecryptionOperation.h
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"

@interface MessageDecryptionOperation : NSOperation


@property (nonatomic, strong) SurespotMessage * message;
@property (nonatomic, strong) void (^callback) (SurespotMessage *);
@property (nonatomic, assign) CGFloat width;

-(id) initWithMessage: (SurespotMessage *) message width: (CGFloat) width completionCallback:(void(^)(SurespotMessage *))  callback;
@end


