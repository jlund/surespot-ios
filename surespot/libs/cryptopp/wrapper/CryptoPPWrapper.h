//
//  CryptoPPWrapper.h
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CryptoPPWrapper 
- (void) doImport:(NSData *) data;

@end

@interface SurespotCrypto : NSObject<CryptoPPWrapper> {}

@end
