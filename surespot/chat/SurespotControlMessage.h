//
//  SurespotControlMessage.h
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SurespotControlMessage : NSObject
- (id) initWithJSONString: (NSString *) jsonString;
- (id) initWithDictionary:(NSDictionary *) dictionary;
@property (nonatomic, strong) NSString * type;
@property (nonatomic, strong) NSString * action;
@property (nonatomic, strong) NSString * data;
@property (nonatomic, strong) id moreData;
@property (nonatomic, assign) NSInteger controlId;
@property (nonatomic, strong) NSString * from;
@end
