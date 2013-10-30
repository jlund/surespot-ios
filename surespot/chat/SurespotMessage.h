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

@property (nonatomic, strong) NSString * serverid;
@property (nonatomic, strong) NSString * from;
@property (nonatomic, strong) NSString * to;
@property (nonatomic, strong) NSString * iv;
@property (nonatomic, strong) NSString * data;
@property (nonatomic, strong) NSString * toVersion;
@property (nonatomic, strong) NSString * fromVersion;
@property (nonatomic, strong) NSString * plaindata;
@property (nonatomic, strong) NSDate * dateTime;
@property (atomic, assign, getter=isLoading) BOOL loading;
@property (atomic, assign, getter=isLoaded) BOOL loaded;

- (NSString *) getOtherUser;
- (NSString *) getTheirVersion;
- (NSString *) getOurVersion;
@end
