//
//  SurespotIdentity.m
//  surespot
//
//  Created by Adam on 6/7/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "SurespotIdentity.h"
#import "PrivateKeyPairs.h"


@implementation SurespotIdentity 

- (void) addKeyPairs:(NSString*)version keyPairDH:(DL_Keys_EC<ECP>)keyPairDH keyPairDSA:(DL_Keys_EC<ECP>)keyPairDSA {
    if ([self.latestVersion compare:version] == NSOrderedAscending) {
        self.latestVersion = version;
    }
    //self.version = version;
    
    PrivateKeyPairs* pkp = [[PrivateKeyPairs alloc] init];
    pkp.version = version;
    pkp.keyPairDH = keyPairDH;
    pkp.keyPairDSA = keyPairDSA;
    
    [self.keyPairs setValue: pkp forKey: version];
}




@end
