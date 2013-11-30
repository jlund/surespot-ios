//
//  PrivateKeyPairs.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "IdentityKeys.h"

@implementation IdentityKeys
-(void) dealloc {
    delete _dhPrivKey;
    delete _dhPubKey;
    delete _dsaPrivKey;
    delete _dsaPubKey;
    
}
@end
