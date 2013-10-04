//
//  SurespotMessage.h
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SurespotMessage : NSObject
- (id) initWithJSONString: (NSString *) jsonString;
- (id) initWithMutableDictionary: (NSMutableDictionary *) dictionary;
@property (strong, nonatomic) NSMutableDictionary * messageData;
- (NSString *) getOtherUser;
- (NSString *) getTheirVersion;
- (NSString *) getOurVersion;
@end
