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
+(NSString *) getChatDataFilenameForSpot: (NSString *) spot;
+ (NSString*) getAppSupportDir;
+ (NSData *)gzipDeflate:(NSData *) data;
+ (NSData *)gzipInflate:(NSData *) data;
+(void) wipeDataForUsername: (NSString *) username friendUsername: (NSString *) friendUsername;
+(NSString*)getPublicKeyFilenameForUsername: (NSString *) username version: (NSString *)version;
@end
