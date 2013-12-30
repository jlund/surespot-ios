//
//  SurespotMessage.h
//  surespot
//
//  Created by Adam on 10/3/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SurespotMessage : NSObject<NSCoding, NSCopying>
- (id) initWithJSONString: (NSString *) jsonString;
- (id) initWithDictionary: (NSDictionary *) dictionary;


@property (nonatomic, assign) NSInteger serverid;
@property (nonatomic, strong) NSString * from;
@property (nonatomic, strong) NSString * to;
@property (nonatomic, strong) NSString * iv;
@property (nonatomic, strong) NSString * data;
@property (nonatomic, strong) NSString * toVersion;
@property (nonatomic, strong) NSString * fromVersion;
@property (nonatomic, strong) NSString * mimeType;
@property (nonatomic, strong) NSString * plainData;
@property (nonatomic, strong) NSDate * dateTime;
@property (nonatomic, assign) NSInteger errorStatus;
@property (nonatomic, strong) NSString * formattedDate;
@property (nonatomic, assign) NSInteger dataSize;
@property (nonatomic, assign) NSInteger resendId;
@property (atomic, assign, getter=isLoading) BOOL loading;
@property (atomic, assign, getter=isLoaded) BOOL loaded;
@property (nonatomic, assign) NSInteger rowPortraitHeight;
@property (nonatomic, assign) NSInteger rowLandscapeHeight;
@property (nonatomic, assign) BOOL shareable;
@property (nonatomic, assign) BOOL voicePlayed;
@property (nonatomic, assign) BOOL playVoice;


- (NSString *) getOtherUser;
- (NSString *) getTheirVersion;
- (NSString *) getOurVersion;
- (NSString * ) toJsonString;
- (NSMutableDictionary * ) toNSDictionary;
- (BOOL) readyToSend;
@end
