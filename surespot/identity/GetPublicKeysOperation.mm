//
//  GetPublicKeysOperation.m
//  surespot
//
//  Created by Adam on 10/20/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

//
//  GenerateSharedSecretOperation.m
//  surespot
//
//  Created by Adam on 10/19/13.
//  Copyright (c) 2013 2fours. All rights reserved.
//

#import "GetPublicKeysOperation.h"
#import "IdentityController.h"

@interface GetPublicKeysOperation()
@property (nonatomic, strong) NSString * username;
@property (nonatomic, strong) NSString * version;
@property (nonatomic) BOOL isExecuting;
@property (nonatomic) BOOL isFinished;
@end




@implementation GetPublicKeysOperation

-(id) initWithUsername: (NSString *) username version: (NSString *) version completionCallback:(void(^)(PublicKeys *))  callback {
    if (self = [super init]) {
        self.callback = callback;
        self.username = username;
        self.version = version;
        
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
}

-(void) start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    

        //need to download the public key
        [[IdentityController sharedInstance] getPublicKeysForUsername:self.username andVersion:self.version callback: ^(PublicKeys * publicKeys) {
            [self finish:publicKeys];
        }];
    
    
    
}

- (void)finish: (PublicKeys *) publicKeys
{
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
    
    _callback(publicKeys);
    _callback = nil;
}


- (BOOL)isConcurrent
{
    return YES;
}

@end
