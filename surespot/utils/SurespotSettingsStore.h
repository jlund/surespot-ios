//
//  SurespotSettingsStore.h
//  surespot
//
//  Created by Adam on 1/6/14.
//  Copyright (c) 2014 2fours. All rights reserved.
//

#import "IASKSettingsStore.h"

@interface SurespotSettingsStore : IASKAbstractSettingsStore
-(id) initWithUsername: (NSString *) username;


- (void)setObject:(id)value forKey:(NSString*)key;

/** default implementation raises an exception
 must be overridden by subclasses
 */
- (id)objectForKey:(NSString*)key;
- (BOOL)synchronize;
@end
