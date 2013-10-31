//
//  Friend.h
//  surespot
//
//  Created by Adam on 10/31/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Friend : NSObject
- (id) initWithDictionary:(NSDictionary *) dictionary;
@property (nonatomic,strong) NSString * name;
@property (nonatomic,assign) NSInteger flags;
@property (nonatomic, strong) NSString * imageUrl;
@property (nonatomic, strong) NSString * imageVersion;
@property (nonatomic, strong) NSString * imageIv;

-(BOOL) isInviter;
-(void) setInviter: (BOOL) set;
-(BOOL) isInvited;
-(void) setInvited: (BOOL) set;

-(BOOL) isDeleted;
-(void) setDeleted: (BOOL) set;




@end
