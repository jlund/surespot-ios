//
//  SurespotPhoto.h
//  surespot
//
//  Created by Adam on 12/14/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MWPhotoProtocol.h"
#import "EncryptionParams.h"

@interface SurespotPhoto : NSObject<MWPhoto>
// Properties
@property (nonatomic, strong) NSString *caption;
@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) NSURL *photoURL;
@property (nonatomic, strong) EncryptionParams * encryptionParams;
- (id)initWithURL:(NSURL *)url encryptionParams: (EncryptionParams *) params;
@end
