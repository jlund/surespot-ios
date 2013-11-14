//
//  SendMessageOperation.h
//  surespot
//
//  Created by Adam on 11/14/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SurespotMessage.h"


@interface SendMessageOperation : NSOperation



-(SendMessageOperation *) initWithJsonMessage: (NSString *) jsonMessage;


@end

