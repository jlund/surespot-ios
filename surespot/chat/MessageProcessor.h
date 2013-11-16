//
//  MessageProcessor.h
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SurespotMessage.h"

@interface MessageProcessor : NSObject
+(MessageProcessor*) sharedInstance;
-(void) decryptMessage:(SurespotMessage *) message size: (CGSize) size completionCallback:(void(^)(SurespotMessage *))  callback ;
@end
