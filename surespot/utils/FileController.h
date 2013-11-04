//
//  FileController.h
//  surespot
//
//  Created by Adam on 7/22/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileController : NSObject
+(NSString *) getHomeFilename;
+ (NSString*) getAppSupportDir;
+ (NSData *)gzipDeflate:(NSData *) data;
+ (NSData *)gzipInflate:(NSData *) data;
@end
