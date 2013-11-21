//
//  SurespotMessage.h
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SurespotErrorMessage : NSObject
- (id) initWithDictionary: (NSDictionary *) dictionary;

@property (nonatomic, assign) NSInteger status;
@property (nonatomic, strong) NSString * data;
@end
