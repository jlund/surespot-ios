//
//  Friend.h
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Friend : NSObject<NSCoding>
- (id) initWithDictionary:(NSDictionary *) dictionary;
@property (atomic,strong) NSString * name;
@property (atomic,assign) NSInteger flags;
@property (atomic, strong) NSString * imageUrl;
@property (atomic, strong) NSString * imageVersion;
@property (atomic, strong) NSString * imageIv;
@property (atomic, assign) NSInteger lastViewedMessageId;
@property (atomic, assign) NSInteger availableMessageId;
@property (atomic, assign) NSInteger lastReceivedMessageControlId;
@property (atomic, assign) NSInteger availableMessageControlId;
@property (atomic, assign) NSInteger lastReceivedUserControlId;

-(BOOL) isInviter;
-(void) setInviter: (BOOL) set;
-(BOOL) isInvited;
-(void) setInvited: (BOOL) set;

-(BOOL) isDeleted;
-(void) setDeleted: (BOOL) set;

-(id) initWithCoder:(NSCoder *)coder;
-(void) encodeWithCoder:(NSCoder *)encoder;



@end
